import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../context/AuthContext.dart';
import '../../utils/apiClient.dart';

class MenuModal extends ConsumerStatefulWidget {
  final Map<String, dynamic>? table; // Null for food truck
  final VoidCallback onClose;
  final Function(dynamic)? onOrderPlaced;
  final Map<String, dynamic>? sendAppendOrder; // For running tables

  const MenuModal({
    this.table,
    required this.onClose,
    this.onOrderPlaced,
    this.sendAppendOrder,
    super.key,
  });

  @override
  ConsumerState<MenuModal> createState() => _MenuModalState();
}

class _MenuModalState extends ConsumerState<MenuModal> {
  bool _isLoading = true;
  bool _isOrdering = false;

  List<dynamic> _categories = [];
  List<dynamic> _allItems = [];
  String _selectedCategory = 'All';

  Map<String, dynamic> _cart = {};

  bool _isFoodTruck = false;
  bool _isRestaurant = false;

  String _customerName = "";
  String _customerPhone = "";
  String? _paymentMode;
  String? _paymentMethod;

  // QR Logic
  bool _showQR = false;
  Map<String, dynamic>? _qrData;

  // New states for sync with JS
  String? _mode; // 'quick' | 'foodtruck' | 'restaurant'
  bool _postOrderModal = false;
  Map<String, dynamic>? _createdOrderRef;
  bool _paymentProcessing = false;

  late TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  bool _showCartView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initRoleAndData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initRoleAndData() async {
    final user = ref.read(authProvider).user;
    if (user == null || user['restaurantId'] == null) return;

    // Priority: org mode first, then businessType fallback
    try {
      final res = await apiFetch(
        '/api/restaurants/${user['restaurantId']}/context',
      );
      setState(() {
        if (res['orgMode'] == 'quick') {
          _mode = 'quick';
          _isFoodTruck = false;
          _isRestaurant = false;
        } else if (res['businessType'] == 'FOOD_TRUCK') {
          _mode = 'foodtruck';
          _isFoodTruck = true;
          _isRestaurant = false;
        } else {
          _mode = 'restaurant';
          _isRestaurant = true;
          _isFoodTruck = false;
        }
      });
    } catch (e) {
      // fallback to cached businessType from user object
      setState(() {
        if (user['businessType'] == 'FOOD_TRUCK') {
          _mode = 'foodtruck';
          _isFoodTruck = true;
          _isRestaurant = false;
        } else {
          _mode = 'restaurant';
          _isRestaurant = true;
          _isFoodTruck = false;
        }
      });
    }

    await _fetchMenu(user['restaurantId']);
  }

  Future<void> _fetchMenu(String restaurantId) async {
    setState(() => _isLoading = true);
    try {
      final data = await apiFetch('/api/public/menu/$restaurantId');
      if (mounted) {
        setState(() {
          _categories = data['categories'] ?? [];
          _allItems = data['items'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load menu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateQuantity(dynamic item, int delta) {
    setState(() {
      final itemId = item['_id'] as String;
      int currentQty = _cart.containsKey(itemId)
          ? _cart[itemId]['quantity'] as int
          : 0;
      int nextQty = currentQty + delta;

      if (nextQty <= 0) {
        _cart.remove(itemId);
      } else {
        _cart[itemId] = {...item, 'quantity': nextQty};
      }
    });
  }

  Future<void> _handleSendOrder() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validation only for non-quick modes if needed (JS doesn't validate much in quick mode)
    // Actually, JS validates foodtruck inputs before placing order in some versions,
    // but the latest one seems to place order first and collect payment after.
    // Wait, the latest JS code shows:
    // if (mode === "foodtruck") { payload.paymentMode = "POSTPAID"; payload.customerPhone = null; }
    // It doesn't seem to validate customerName before placing order in the LATEST version?
    // Let's check:
    // if (mode === "foodtruck") { if (!customerName) return toast.error("Customer name is required"); ... }
    // Ah, it DOES validate customerName for foodtruck.

    if (_mode == 'foodtruck') {
      if (_customerName.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer name is required'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isOrdering = true);
    ScaffoldMessenger.of(context).clearSnackBars(); // Clear previous toasts

    final Map<String, dynamic> payload = {
      'items': _cart.values
          .map(
            (i) => {
              'itemId': i['_id'],
              'quantity': i['quantity'],
              'isUpsell': false,
            },
          )
          .toList(),
      'placedBy': 'STAFF',
    };

    try {
      if (widget.sendAppendOrder != null) {
        // APPEND ITEMS
        final appendPayload = {
          'orderId': widget.sendAppendOrder!['currentOrderId'],
          'items': payload['items'],
        };
        await apiFetch(
          '/api/orders/append-items',
          method: 'PUT',
          data: appendPayload,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Items added to existing order!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _resetAndClose();
        return;
      }

      // ── QUICK MODE ───────────────────────────────────────────────────────
      if (_mode == 'quick') {
        payload['paymentMode'] = 'POSTPAID';
        payload['customerPhone'] = null;
      }

      // ── RESTAURANT MODE ──────────────────────────────────────────────────
      if (_mode == 'restaurant') {
        payload['tableNumber'] = widget.table?['tableName'] ?? 'NA';
        payload['customerPhone'] = 'NA';
        payload['paymentMode'] = 'POSTPAID';
      }

      // ── FOOD TRUCK MODE ──────────────────────────────────────────────────
      if (_mode == 'foodtruck') {
        payload['customerName'] = _customerName;
        payload['customerPhone'] = _customerPhone.isEmpty
            ? null
            : _customerPhone;
        payload['paymentMode'] = 'POSTPAID'; // always POSTPAID first
      }

      final res = await apiFetch('/api/orders', method: 'POST', data: payload);

      // Robustly extract the order object
      dynamic createdOrder;
      if (res is Map) {
        createdOrder = res['data'] ?? res['order'] ?? res;
      } else if (res is List && res.isNotEmpty) {
        createdOrder = res[0];
      } else {
        createdOrder = res;
      }

      if (mounted) {
        if (widget.onOrderPlaced != null) {
          widget.onOrderPlaced!(createdOrder);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed!'),
            backgroundColor: Colors.green,
          ),
        );

        // ── For food truck: open payment picker modal ─────────────────────────
        if (_mode == 'foodtruck') {
          setState(() {
            _createdOrderRef = createdOrder;
            _postOrderModal = true;
            _isOrdering = false;
          });
          return;
        }

        // ── For other modes: close immediately ──────────────────────────────
        _resetAndClose();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOrdering = false);
    }
  }

  Future<void> _handlePostOrderPayment(String method) async {
    if (method == 'PAY_LATER') {
      _resetAndClose();
      return;
    }

    try {
      setState(() => _paymentProcessing = true);
      await _collectPaymentRequest(_createdOrderRef!['_id'], method);

      // UPI: show QR if restaurant has one set up
      if (method == 'UPI') {
        try {
          final res = await apiFetch('/api/restaurants/payment');
          if (res['payment'] != null && res['payment']['qrImageUrl'] != null) {
            setState(() {
              _qrData = res['payment'];
              _postOrderModal = false;
              _showQR = true;
            });
            return;
          }
        } catch (_) {
          // no QR configured, fall through
        }
      }

      _resetAndClose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _paymentProcessing = false);
    }
  }

  Future<dynamic> _collectPaymentRequest(
    String orderId,
    String paymentMethod,
  ) async {
    return await apiFetch(
      '/api/admin/orders/collect-payment',
      method: 'PATCH',
      data: {'orderId': orderId, 'paymentMethod': paymentMethod},
    );
  }

  void _resetAndClose() {
    setState(() {
      _postOrderModal = false;
      _createdOrderRef = null;
      _cart = {};
      _customerName = "";
      _customerPhone = "";
      _paymentMode = null;
      _paymentMethod = null;
    });
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine items to show
    List<dynamic> filteredItems = _searchQuery.isNotEmpty
        ? _allItems.where((i) {
            final name = (i['name'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList()
        : (_selectedCategory == 'All'
              ? _allItems
              : _allItems.where((i) {
                  return i['category'] == _selectedCategory;
                }).toList());

    double totalPrice = 0;
    for (var item in _cart.values) {
      totalPrice += (item['basePrice'] ?? 0) * (item['quantity'] ?? 0);
    }

    return Stack(
      children: [
        Container(
          width: 450.w, // Drawer width
          color: Colors.white,
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // HEADER
                    SliverToBoxAdapter(
                      child: Container(
                        padding: EdgeInsets.all(24.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: widget.onClose,
                                      icon: Icon(
                                        LucideIcons.arrowLeft,
                                        size: 20.sp,
                                      ),
                                      splashRadius: 24.r,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      _showCartView
                                          ? "YOUR CART"
                                          : (_isRestaurant
                                                ? "TABLE ${widget.table?['tableName'] ?? ''}"
                                                : "QUICK ORDER"),
                                      style: TextStyle(
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    if (_cart.isNotEmpty)
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          IconButton(
                                            onPressed: () => setState(
                                              () => _showCartView =
                                                  !_showCartView,
                                            ),
                                            icon: Icon(
                                              _showCartView
                                                  ? LucideIcons.layoutList
                                                  : LucideIcons.shoppingCart,
                                              size: 24.sp,
                                              color: _showCartView
                                                  ? Colors.orange
                                                  : Colors.grey,
                                            ),
                                            splashRadius: 24.r,
                                          ),
                                          Positioned(
                                            right: 4.w,
                                            top: 4.h,
                                            child: Container(
                                              padding: EdgeInsets.all(4.r),
                                              decoration: BoxDecoration(
                                                color: Colors.orange,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2.r,
                                                ),
                                              ),
                                              constraints: BoxConstraints(
                                                minWidth: 16.w,
                                                minHeight: 16.h,
                                              ),
                                              child: Text(
                                                '${_cart.length}',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8.sp,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    IconButton(
                                      onPressed: widget.onClose,
                                      icon: Icon(
                                        LucideIcons.x,
                                        size: 28.sp,
                                        color: Colors.grey,
                                      ),
                                      splashRadius: 24.r,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),
                            if (!_showCartView) ...[
                              _buildSearchBar(),
                              SizedBox(height: 16.h),
                              // CATEGORIES
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildCategoryChip('All', 'All'),
                                    ..._categories.map((cat) {
                                      String catId = cat is Map
                                          ? cat['_id']
                                          : cat.toString();
                                      String catName = cat is Map
                                          ? cat['name']
                                          : cat.toString();
                                      return _buildCategoryChip(catId, catName);
                                    }),
                                  ],
                                ),
                              ),
                            ] else
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_cart.length} items selected',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _cart.clear();
                                        _showCartView = false;
                                      });
                                    },
                                    icon: Icon(
                                      LucideIcons.trash2,
                                      size: 16.sp,
                                      color: Colors.red,
                                    ),
                                    label: const Text(
                                      'Clear',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),

                    // FOOD TRUCK INPUTS — hidden in quick mode
                    if (_mode == 'foodtruck')
                      SliverToBoxAdapter(
                        child: Container(
                          padding: EdgeInsets.all(24.r),
                          color: Colors.grey.shade50,
                          child: Column(
                            children: [
                              _buildTextField(
                                'Customer Name',
                                _customerName,
                                (val) => setState(() => _customerName = val),
                              ),
                              SizedBox(height: 12.h),
                              _buildTextField(
                                'Customer Phone (Optional)',
                                _customerPhone,
                                (val) => setState(() => _customerPhone = val),
                              ),
                              SizedBox(height: 16.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionBtn(
                                      'PAID',
                                      _paymentMode == 'PREPAID',
                                      () => setState(
                                        () => _paymentMode = 'PREPAID',
                                      ),
                                      true,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: _buildActionBtn(
                                      'PAY LATER',
                                      _paymentMode == 'POSTPAID',
                                      () => setState(
                                        () => _paymentMode = 'POSTPAID',
                                      ),
                                      false,
                                    ),
                                  ),
                                ],
                              ),
                              if (_paymentMode == 'PREPAID') ...[
                                SizedBox(height: 16.h),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildPaymentMethodBtn(
                                        'CASH',
                                        LucideIcons.banknote,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: _buildPaymentMethodBtn(
                                        'UPI',
                                        LucideIcons.smartphone,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: _buildPaymentMethodBtn(
                                        'CARD',
                                        LucideIcons.creditCard,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                    // MENU ITEMS
                    if (_isLoading)
                      const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.orange,
                          ),
                        ),
                      )
                    else if (_showCartView
                        ? _cart.isEmpty
                        : filteredItems.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _showCartView
                                    ? LucideIcons.shoppingCart
                                    : LucideIcons.utensilsCrossed,
                                size: 48,
                                color: Colors.grey.shade300,
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                _showCartView
                                    ? 'Your cart is empty'
                                    : 'No items found',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.all(24.r).copyWith(bottom: 120.h),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, idx) {
                              final List<dynamic> itemsToShow = _showCartView
                                  ? _cart.values.toList()
                                  : filteredItems;
                              final item = itemsToShow[idx];
                              final itemId = item['_id'];
                              final qty = _cart.containsKey(itemId)
                                  ? _cart[itemId]['quantity'] as int
                                  : 0;

                              return Container(
                                margin: EdgeInsets.only(bottom: 16.h),
                                padding: EdgeInsets.all(20.r),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24.r),
                                  border: Border.all(
                                    color: qty > 0
                                        ? Colors.orange
                                        : Colors.grey.shade200,
                                    width: qty > 0 ? 2.r : 1.r,
                                  ),
                                  boxShadow: qty > 0
                                      ? [
                                          BoxShadow(
                                            color: Colors.orange.withAlpha(20),
                                            blurRadius: 10.r,
                                            offset: Offset(0, 4.h),
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(5),
                                            blurRadius: 10.r,
                                          ),
                                        ],
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(12.r),
                                            decoration: BoxDecoration(
                                              color: qty > 0
                                                  ? Colors.orange.shade50
                                                  : Colors.grey.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(16.r),
                                            ),
                                            child: Icon(
                                              LucideIcons.utensilsCrossed,
                                              color: qty > 0
                                                  ? Colors.orange
                                                  : Colors.grey,
                                            ),
                                          ),
                                          SizedBox(width: 16.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['name'] ?? '',
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF0F172A),
                                                    letterSpacing: 1,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: 4.h),
                                                Text(
                                                  '₹${item['basePrice'] ?? 0}',
                                                  style: TextStyle(
                                                    fontSize: 20.sp,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    qty > 0
                                        ? Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F172A),
                                              borderRadius:
                                                  BorderRadius.circular(24.r),
                                            ),
                                            child: Row(
                                              children: [
                                                IconButton(
                                                  onPressed: () =>
                                                      _updateQuantity(item, -1),
                                                  icon: Icon(
                                                    LucideIcons.minus,
                                                    color: Colors.white,
                                                    size: 16.sp,
                                                  ),
                                                  constraints:
                                                      const BoxConstraints(),
                                                  padding: EdgeInsets.all(12.r),
                                                ),
                                                Text(
                                                  '$qty',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16.sp,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () =>
                                                      _updateQuantity(item, 1),
                                                  icon: Icon(
                                                    LucideIcons.plus,
                                                    color: Colors.white,
                                                    size: 16.sp,
                                                  ),
                                                  constraints:
                                                      const BoxConstraints(),
                                                  padding: EdgeInsets.all(12.r),
                                                ),
                                              ],
                                            ),
                                          )
                                        : ElevatedButton(
                                            onPressed: () =>
                                                _updateQuantity(item, 1),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.grey.shade100,
                                              foregroundColor: Colors.black87,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 24.w,
                                                vertical: 16.h,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(24.r),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: Text(
                                              'ADD +',
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                  ],
                                ),
                              );
                            },
                            childCount: _showCartView
                                ? _cart.length
                                : filteredItems.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // BOTTOM BAR
              if (_cart.isNotEmpty)
                Container(
                  padding: EdgeInsets.all(24.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 20.r,
                        offset: Offset(0, -5.h),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GRAND TOTAL',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            '₹$totalPrice',
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: _isOrdering ? null : _handleSendOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 32.w,
                            vertical: 20.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32.r),
                          ),
                        ),
                        child: _isOrdering
                            ? SizedBox(
                                width: 20.w,
                                height: 20.h,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'PLACE ORDER',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // 🔥 QR OVERLAY
        if (_showQR && _qrData != null)
          Positioned.fill(
            child: Container(
              color: Colors.black.withAlpha(180),
              padding: EdgeInsets.all(24.r),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(32.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32.r),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Scan & Pay',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      if (_qrData!['qrImageUrl'] != null)
                        Image.network(
                          _qrData!['qrImageUrl'],
                          height: 240.h,
                          width: 240.w,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, stack) => Container(
                            height: 240.h,
                            width: 240.w,
                            color: Colors.grey.shade100,
                            child: Center(
                              child: Icon(
                                Icons.qr_code,
                                size: 64.r,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      SizedBox(height: 16.h),
                      Text(
                        'UPI ID: ${_qrData!['upiId'] ?? 'N/A'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 32.h),
                      ElevatedButton(
                        onPressed: _resetAndClose,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 48.w,
                            vertical: 16.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 🔥 POST-ORDER PAYMENT MODAL (Food Truck only)
        if (_postOrderModal && _createdOrderRef != null)
          _buildPostOrderPaymentModal(),
      ],
    );
  }

  Widget _buildCategoryChip(String id, String name) {
    bool isSelected = _selectedCategory == id;
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = id;
            _searchQuery = "";
            _searchController.clear();
          });
        },
        borderRadius: BorderRadius.circular(24.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w900,
              color: isSelected ? Colors.white : Colors.grey,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    String value,
    Function(String) onChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        onChanged: onChanged,
        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintStyle: TextStyle(color: Colors.grey),
          hintText: hint,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 14.h,
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn(
    String text,
    bool active,
    VoidCallback onTap,
    bool isPositive,
  ) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: active
            ? (isPositive ? Colors.green : Colors.orange)
            : Colors.white,
        foregroundColor: active
            ? Colors.white
            : const Color.fromARGB(162, 0, 0, 0),
        elevation: active ? 4 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(
            color: active ? Colors.transparent : Colors.grey.shade200,
          ),
        ),
        padding: EdgeInsets.symmetric(vertical: 16.h),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildPaymentMethodBtn(String text, IconData icon) {
    bool active = _paymentMethod == text;
    return ElevatedButton.icon(
      onPressed: () => setState(() => _paymentMethod = text),
      icon: Icon(icon, size: 14.sp),
      label: Text(
        text,
        style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w900),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? Colors.blue : Colors.white,
        foregroundColor: active ? Colors.white : Colors.grey,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(
            color: active ? Colors.transparent : Colors.grey.shade200,
          ),
        ),
        padding: EdgeInsets.symmetric(vertical: 12.h),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: "Search items...",
          hintStyle: TextStyle(
            color: Colors.grey,
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
          ),
          prefixIcon: Icon(LucideIcons.search, size: 16.sp, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(LucideIcons.x, size: 16.sp, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _searchQuery = "";
                      _searchController.clear();
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 14.h,
          ),
        ),
      ),
    );
  }

  Widget _buildPostOrderPaymentModal() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha(120),
        padding: EdgeInsets.all(24.r),
        child: Center(
          child: Container(
            width: 320.w,
            padding: EdgeInsets.all(32.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32.r),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 30.r),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64.r,
                  height: 64.r,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.checkCircle2,
                    color: Colors.green,
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  'Order Placed!',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '#${_createdOrderRef!['_id'].toString().substring(_createdOrderRef!['_id'].toString().length - 4).toUpperCase()} ${_createdOrderRef!['customerName'] ?? ""}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 24.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    vertical: 16.h,
                    horizontal: 24.w,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'TOTAL AMOUNT',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '₹${_createdOrderRef!['totalAmount'] ?? 0}',
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'HOW ARE THEY PAYING?',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 16.h),
                _buildPostPaymentOption('CASH', '💵 Cash', Colors.black),
                SizedBox(height: 12.h),
                _buildPostPaymentOption('UPI', '📱 UPI', Colors.green),
                SizedBox(height: 12.h),
                _buildPostPaymentOption('CARD', '💳 Card', Colors.blue),
                SizedBox(height: 12.h),
                TextButton(
                  onPressed: _paymentProcessing
                      ? null
                      : () => _handlePostOrderPayment('PAY_LATER'),
                  child: _paymentProcessing
                      ? SizedBox(
                          width: 16.w,
                          height: 16.h,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey,
                          ),
                        )
                      : Text(
                          'PAY LATER',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostPaymentOption(String method, String label, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _paymentProcessing
            ? null
            : () => _handlePostOrderPayment(method),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
