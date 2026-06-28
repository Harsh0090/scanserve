import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../context/AuthContext.dart';
import '../../utils/apiClient.dart';

class MenuModal extends ConsumerStatefulWidget {
  final Map<String, dynamic>? table;
  final VoidCallback onClose;
  final Function(dynamic)? onOrderPlaced;
  final Map<String, dynamic>? sendAppendOrder;
  final Function(List<dynamic>)? onCartConfirmed;

  const MenuModal({
    this.table,
    required this.onClose,
    this.onOrderPlaced,
    this.sendAppendOrder,
    this.onCartConfirmed,
    super.key,
  });

  @override
  ConsumerState<MenuModal> createState() => _MenuModalState();
}

class _MenuModalState extends ConsumerState<MenuModal> {
  bool _isLoading = true;
  bool _isSubmitting = false;

  List<dynamic> _categories = [];
  List<dynamic> _allItems = [];
  String _selectedCategory = 'All';
  String _searchQuery = "";
  late TextEditingController _searchController;

  Map<String, dynamic> _cart = {};
  Map<String, dynamic> _existingItems = {};
  Map<String, int> _originalQuantities = {};

  String? _mode; 
  bool _nameEnabled = false;
  String _customerName = "";
  String _customerPhone = "";

  bool _postOrderModal = false;
  Map<String, dynamic>? _createdOrderRef;
  bool _paymentProcessing = false;
  bool _showQR = false;
  Map<String, dynamic>? _qrData;

  bool _mobileSheetExpanded = false;

  bool get _isExistingOrder => widget.sendAppendOrder != null && widget.sendAppendOrder!['currentOrderId'] != null;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _initPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initRoleAndData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameEnabled = prefs.getBool('customerDetailsEnabled') ?? false;
    });
  }

  Future<void> _initRoleAndData() async {
    final user = ref.read(authProvider).user;
    if (user == null || user['restaurantId'] == null) return;

    try {
      final res = await apiFetch('/api/restaurants/${user['restaurantId']}/context');
      setState(() {
        if (res['orgMode'] == 'quick') {
          _mode = 'quick';
        } else if (res['businessType'] == 'FOOD_TRUCK') {
          _mode = 'foodtruck';
        } else {
          _mode = 'restaurant';
        }
      });
    } catch (e) {
      setState(() {
        _mode = user['businessType'] == 'FOOD_TRUCK' ? 'foodtruck' : 'restaurant';
      });
    }

    await _fetchMenu(user['restaurantId']);

    if (_isExistingOrder) {
      if (widget.sendAppendOrder!['items'] != null && (widget.sendAppendOrder!['items'] as List).isNotEmpty) {
        _loadExistingItemsFromOrder(widget.sendAppendOrder!);
      } else {
        await _fetchExistingOrderFromLive(widget.sendAppendOrder!['currentOrderId']);
      }
    }
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
      debugPrint('Failed to load menu: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchExistingOrderFromLive(String orderId) async {
    try {
      final res = await apiFetch('/api/admin/orders/live?t=${DateTime.now().millisecondsSinceEpoch}');
      if (res is List) {
        final order = res.firstWhere((o) => o['_id'] == orderId, orElse: () => null);
        if (order != null) {
          _loadExistingItemsFromOrder(order);
        }
      }
    } catch (e) {
      debugPrint('Failed to load live order: $e');
    }
  }

  void _loadExistingItemsFromOrder(Map<String, dynamic> order) {
    final items = order['items'] as List<dynamic>? ?? [];
    Map<String, dynamic> map = {};
    Map<String, int> origQty = {};
    for (var i in items) {
      final id = i['_id'] as String;
      final quantity = i['quantity'] is int ? i['quantity'] as int : (i['quantity'] as double?)?.toInt() ?? 0;
      map[id] = {
        '_id': id,
        'itemRefId': i['item']?['_id'],
        'name': i['item']?['branchName'] ?? i['name'] ?? '',
        'basePrice': (i['item']?['branchPrice'] ?? i['basePrice'] ?? 0).toDouble(),
        'quantity': quantity,
      };
      origQty[id] = quantity;
    }
    setState(() {
      _existingItems = map;
      _originalQuantities = origQty;
    });
  }

  void _updateQuantity(Map<String, dynamic> item, int delta) {
    setState(() {
      final id = item['_id'] as String;
      int qty = _cart.containsKey(id) ? (_cart[id]['quantity'] as int) : 0;
      int nextQty = qty + delta;
      if (nextQty <= 0) {
        _cart.remove(id);
      } else {
        _cart[id] = {...item, 'quantity': nextQty};
      }
    });
  }

  void _updateExistingQuantity(String lineId, int delta) {
    setState(() {
      if (!_existingItems.containsKey(lineId)) return;
      final line = _existingItems[lineId];
      int nextQty = (line['quantity'] as int) + delta;
      if (nextQty <= 0) {
        _existingItems.remove(lineId);
      } else {
        _existingItems[lineId] = {...line, 'quantity': nextQty};
      }
    });
  }

  void _removeExistingLine(String lineId) {
    setState(() {
      _existingItems.remove(lineId);
    });
  }

  bool _hasAnyChanges() {
    if (_cart.isNotEmpty) return true;
    for (var line in _existingItems.values) {
      final id = line['_id'];
      if (_originalQuantities[id] != line['quantity']) return true;
    }
    for (var id in _originalQuantities.keys) {
      if (!_existingItems.containsKey(id)) return true;
    }
    return false;
  }

  double _newItemsTotal() {
    double total = 0;
    for (var item in _cart.values) {
      total += (item['basePrice'] ?? 0) * (item['quantity'] ?? 0);
    }
    return total;
  }

  double _existingItemsTotal() {
    double total = 0;
    for (var item in _existingItems.values) {
      total += (item['basePrice'] ?? 0) * (item['quantity'] ?? 0);
    }
    return total;
  }

  double _totalPrice() => _newItemsTotal() + _existingItemsTotal();

  int _totalItemQuantity() {
    int total = 0;
    for (var item in _cart.values) total += item['quantity'] as int;
    for (var item in _existingItems.values) total += item['quantity'] as int;
    return total;
  }

  Future<void> _handleSendOrder() async {
    if (_isSubmitting) return;

    if (widget.onCartConfirmed != null) {
      if (_cart.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Your cart is empty")));
        return;
      }
      widget.onCartConfirmed!(_cart.values.toList());
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_isExistingOrder) {
        if (!_hasAnyChanges()) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No changes to save")));
          setState(() => _isSubmitting = false);
          return;
        }

        final orderId = widget.sendAppendOrder!['currentOrderId'] as String;

        List<String> removedIds = [];
        for (var id in _originalQuantities.keys) {
          if (!_existingItems.containsKey(id)) removedIds.add(id);
        }

        List<Map<String, dynamic>> reducedLines = [];
        for (var line in _existingItems.values) {
          final id = line['_id'];
          final orig = _originalQuantities[id];
          if (orig != null && line['quantity'] < orig && line['quantity'] > 0) {
            reducedLines.add(line);
          }
        }

        List<Map<String, dynamic>> newCartItems = _cart.values.map((i) => {
          'itemId': i['_id'],
          'quantity': i['quantity'],
          'isUpsell': false,
        }).toList();

        for (var line in reducedLines) {
          await apiFetch('/api/orders/$orderId/update-item', method: 'PATCH', data: {
            'lineId': line['_id'],
            'quantity': line['quantity'],
          });
        }

        if (newCartItems.isNotEmpty) {
          await apiFetch('/api/orders/append-items', method: 'PUT', data: {
            'orderId': orderId,
            'items': newCartItems,
          });
        }

        for (var lineId in removedIds) {
          await apiFetch('/api/admin/orders/$orderId/remove-item', method: 'PATCH', data: {
            'itemId': lineId,
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order updated successfully!'), backgroundColor: Colors.green));
          setState(() => _cart = {});
          Future.delayed(const Duration(milliseconds: 300), widget.onClose);
        }
        return;
      }

      if (_cart.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Your cart is empty")));
        setState(() => _isSubmitting = false);
        return;
      }

      final Map<String, dynamic> payload = {
        'items': _cart.values.map((i) => {
          'itemId': i['_id'],
          'quantity': i['quantity'],
          'isUpsell': false,
        }).toList(),
        'placedBy': 'STAFF',
      };

      if (_mode == 'quick') {
        payload['paymentMode'] = 'POSTPAID';
        payload['customerPhone'] = null;
      }
      if (_mode == 'restaurant') {
        payload['tableNumber'] = widget.table?['tableName'] ?? 'NA';
        payload['customerPhone'] = 'NA';
        payload['paymentMode'] = 'POSTPAID';
        if (_nameEnabled) {
          payload['customerName'] = _customerName.trim().isEmpty ? 'Guest' : _customerName.trim();
        }
      }
      if (_mode == 'quick' || _mode == 'foodtruck') {
        payload['paymentMode'] = 'POSTPAID';
        if (_nameEnabled) {
          payload['customerName'] = _customerName.trim().isEmpty ? 'Guest' : _customerName.trim();
          payload['customerPhone'] = _customerPhone.trim().isEmpty ? null : _customerPhone.trim();
        } else {
          payload['customerName'] = 'Guest';
          payload['customerPhone'] = null;
        }
      }

      final res = await apiFetch('/api/orders', method: 'POST', data: payload);
      
      dynamic createdOrder;
      if (res is Map) {
        createdOrder = res['data'] ?? res['order'] ?? res;
      } else if (res is List && res.isNotEmpty) {
        createdOrder = res[0];
      } else {
        createdOrder = res;
      }

      if (mounted) {
        if (widget.onOrderPlaced != null) widget.onOrderPlaced!(createdOrder);

        if (_mode == 'foodtruck') {
          setState(() {
            _createdOrderRef = createdOrder;
            _postOrderModal = true;
            _isSubmitting = false;
          });
          return;
        }

        setState(() => _cart = {});
        Future.delayed(const Duration(milliseconds: 800), widget.onClose);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetAndClose() {
    setState(() {
      _postOrderModal = false;
      _createdOrderRef = null;
      _cart = {};
      _customerName = "";
      _customerPhone = "";
    });
    widget.onClose();
  }

  Future<void> _handlePostOrderPayment(String method) async {
    if (method == 'PAY_LATER') {
      _resetAndClose();
      return;
    }
    try {
      setState(() => _paymentProcessing = true);
      await apiFetch('/api/admin/orders/collect-payment', method: 'PATCH', data: {
        'orderId': _createdOrderRef!['_id'],
        'paymentMethod': method,
      });

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
        } catch (_) {}
      }
      _resetAndClose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _paymentProcessing = false);
    }
  }

  String _confirmButtonLabel() {
    if (_isSubmitting) {
      return _isExistingOrder ? "SAVING..." : "PLACING...";
    }
    if (widget.onCartConfirmed != null) return "✅ DONE — ADD TO ORDER";
    return "PLACE ORDER";
  }

  bool _isSubmitDisabled() {
    if (_isSubmitting) return true;
    if (_isExistingOrder) return !_hasAnyChanges();
    return _cart.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> filteredItems = [];
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredItems = _allItems.where((i) => (i['name'] ?? '').toLowerCase().contains(q)).toList();
    } else if (_selectedCategory != 'All') {
      filteredItems = _allItems.where((i) => i['category'] == _selectedCategory).toList();
    } else {
      filteredItems = _allItems;
    }

    final showOrderPanel = widget.onCartConfirmed == null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: widget.onClose,
                            child: Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(LucideIcons.arrowLeft, size: 18.sp),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.onCartConfirmed != null
                                    ? "ADD ITEMS TO VOICE ORDER"
                                    : _isExistingOrder
                                        ? "TABLE ${widget.table?['tableName'] ?? widget.sendAppendOrder?['customerName'] ?? ""}"
                                        : _mode == "restaurant"
                                            ? "TABLE ${widget.table?['tableName'] ?? ""}"
                                            : "QUICK ORDER",
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (widget.onCartConfirmed != null)
                                Text(
                                  "SELECT ITEMS → TAP DONE TO ADD",
                                  style: TextStyle(
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                    letterSpacing: 1,
                                  ),
                                ),
                              if (_isExistingOrder && widget.onCartConfirmed == null)
                                Text(
                                  "ORDER #${widget.sendAppendOrder!['currentOrderId']?.toString().substring(widget.sendAppendOrder!['currentOrderId'].toString().length - 4).toUpperCase()} — EDITING",
                                  style: TextStyle(
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange,
                                    letterSpacing: 1,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (widget.sendAppendOrder == null && widget.onCartConfirmed == null)
                            GestureDetector(
                              onTap: () async {
                                final next = !_nameEnabled;
                                setState(() {
                                  _nameEnabled = next;
                                  if (!next) {
                                    _customerName = "";
                                    _customerPhone = "";
                                  }
                                });
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setBool('customerDetailsEnabled', next);
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: _nameEnabled ? Colors.orange.shade50 : Colors.grey.shade50,
                                  border: Border.all(color: _nameEnabled ? Colors.orange.shade200 : Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.user, size: 13.sp, color: _nameEnabled ? Colors.orange : Colors.grey),
                                    SizedBox(width: 6.w),
                                    Icon(_nameEnabled ? LucideIcons.toggleRight : LucideIcons.toggleLeft, size: 16.sp, color: _nameEnabled ? Colors.orange : Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          SizedBox(width: 8.w),
                          GestureDetector(
                            onTap: widget.onClose,
                            child: Padding(
                              padding: EdgeInsets.all(8.r),
                              child: Icon(LucideIcons.x, size: 24.sp, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_nameEnabled && widget.sendAppendOrder == null && widget.onCartConfirmed == null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildInput('Customer Name (optional)', _customerName, (val) => setState(() => _customerName = val), LucideIcons.user),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildInput('Phone (optional)', _customerPhone, (val) => setState(() => _customerPhone = val), LucideIcons.phone),
                        ),
                      ],
                    ),
                  ),

                Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: "Search items...",
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            prefixIcon: Icon(LucideIcons.search, size: 16.sp, color: Colors.grey.shade400),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(LucideIcons.x, size: 16.sp, color: Colors.grey.shade400),
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = "";
                                        _searchController.clear();
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildCategoryPill('All', 'ALL'),
                            ..._categories.map((cat) => _buildCategoryPill(cat['_id'], cat['name'])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Container(
                    color: Colors.grey.shade50,
                    padding: EdgeInsets.symmetric(horizontal: 16.w).copyWith(bottom: 140.h),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                        : filteredItems.isEmpty
                            ? const Center(
                                child: Text('No items found', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              )
                            : GridView.builder(
                                padding: EdgeInsets.only(top: 8.h),
                                physics: const BouncingScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                                  mainAxisSpacing: 10.h,
                                  crossAxisSpacing: 10.w,
                                  childAspectRatio: 2.2,
                                ),
                                itemCount: filteredItems.length,
                                itemBuilder: (ctx, idx) {
                                  final item = filteredItems[idx];
                                  final qty = _cart[item['_id']]?['quantity'] ?? 0;
                                  return Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: qty > 0 ? Colors.orange.shade400 : Colors.grey.shade100,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                (item['name'] ?? '').toString().toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 4.h),
                                              Text(
                                                '₹${item['basePrice']}',
                                                style: TextStyle(
                                                  fontSize: 13.sp,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.blueGrey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (qty > 0)
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius: BorderRadius.circular(8.r),
                                            ),
                                            padding: EdgeInsets.all(4.r),
                                            child: Row(
                                              children: [
                                                GestureDetector(
                                                  onTap: () => _updateQuantity(item, -1),
                                                  child: Icon(LucideIcons.minus, size: 12.sp, color: Colors.white),
                                                ),
                                                SizedBox(width: 4.w),
                                                Text('$qty', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900, color: Colors.white)),
                                                SizedBox(width: 4.w),
                                                GestureDetector(
                                                  onTap: () => _updateQuantity(item, 1),
                                                  child: Icon(LucideIcons.plus, size: 12.sp, color: Colors.white),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          GestureDetector(
                                            onTap: () => _updateQuantity(item, 1),
                                            child: Container(
                                              padding: EdgeInsets.all(6.r),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(8.r),
                                              ),
                                              child: Icon(LucideIcons.plus, size: 14.sp, color: Colors.grey.shade500),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ),
              ],
            ),

            if (showOrderPanel && (_cart.isNotEmpty || _existingItems.isNotEmpty))
              _buildBottomSheet(),

            if (widget.onCartConfirmed != null && _cart.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(24.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40)],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("SELECTED", style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                          Text("₹${_newItemsTotal()}", style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900, color: Colors.black)),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: _handleSendOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 16.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        ),
                        child: Text(_confirmButtonLabel(), style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
                    ],
                  ),
                ),
              ),

            if (_showQR && _qrData != null)
              Container(
                color: Colors.black87,
                alignment: Alignment.center,
                child: Container(
                  margin: EdgeInsets.all(32.r),
                  padding: EdgeInsets.all(24.r),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24.r)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Scan & Pay", style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
                      SizedBox(height: 16.h),
                      if (_qrData!['qrImageUrl'] != null)
                        Image.network(_qrData!['qrImageUrl'], height: 200.h, width: 200.w),
                      SizedBox(height: 12.h),
                      Text("UPI ID: ${_qrData!['upiId']}", style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 24.h),
                      ElevatedButton(
                        onPressed: _resetAndClose,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h)),
                        child: const Text("Done", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String hint, String value, Function(String) onChanged, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TextField(
        onChanged: onChanged,
        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(icon, size: 14.sp, color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        ),
      ),
    );
  }

  Widget _buildCategoryPill(String id, String name) {
    final isSelected = _selectedCategory == id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = id;
          _searchQuery = "";
          _searchController.clear();
        });
      },
      child: Container(
        margin: EdgeInsets.only(right: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black87 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(30.r),
        ),
        child: Text(
          name.toUpperCase(),
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w900,
            color: isSelected ? Colors.white : Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      bottom: _mobileSheetExpanded ? 0 : -(MediaQuery.of(context).size.height * 0.78 - 140.h),
      left: 0,
      right: 0,
      height: MediaQuery.of(context).size.height * 0.78,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta! > 10) {
            setState(() => _mobileSheetExpanded = false);
          } else if (details.primaryDelta! < -10) {
            setState(() => _mobileSheetExpanded = true);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 32.r,
                offset: Offset(0, -6.h),
              ),
            ],
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => setState(() => _mobileSheetExpanded = !_mobileSheetExpanded),
                child: Container(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 10.h, bottom: 6.h),
                        child: Container(
                          width: 36.w,
                          height: 3.h,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_totalItemQuantity()} items',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  _mobileSheetExpanded ? 'tap to collapse' : 'tap to view order',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'TOTAL',
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.grey,
                                    letterSpacing: 1,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  '₹${_totalPrice()}',
                                  style: TextStyle(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!_mobileSheetExpanded)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w).copyWith(bottom: 16.h),
                          child: _buildPlaceOrderBtn(),
                        ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade100, thickness: 1),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    ..._existingItems.values.map((line) => _buildCartLine(line, true)),
                    ..._cart.values.map((item) => _buildCartLine(item, false)),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade100)),
                ),
                child: _buildPlaceOrderBtn(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartLine(Map<String, dynamic> item, bool isExisting) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      color: isExisting ? Colors.transparent : Colors.green.shade50.withOpacity(0.4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isExisting)
                  Container(
                    margin: EdgeInsets.only(bottom: 4.h),
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      'NEW',
                      style: TextStyle(
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.green.shade700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                Text(
                  (item['name'] ?? '').toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  '₹${item['basePrice']} each',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isExisting ? Colors.grey.shade100 : Colors.black87,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                padding: EdgeInsets.all(4.r),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => isExisting ? _updateExistingQuantity(item['_id'], -1) : _updateQuantity(item, -1),
                      child: Padding(
                        padding: EdgeInsets.all(4.r),
                        child: Icon(
                          LucideIcons.minus,
                          size: 13.sp,
                          color: isExisting ? Colors.grey.shade600 : Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '${item['quantity']}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w900,
                        color: isExisting ? Colors.black87 : Colors.white,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    GestureDetector(
                      onTap: () => isExisting ? _updateExistingQuantity(item['_id'], 1) : _updateQuantity(item, 1),
                      child: Padding(
                        padding: EdgeInsets.all(4.r),
                        child: Icon(
                          LucideIcons.plus,
                          size: 13.sp,
                          color: isExisting ? Colors.grey.shade600 : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isExisting) ...[
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: () => _removeExistingLine(item['_id']),
                  child: Padding(
                    padding: EdgeInsets.all(4.r),
                    child: Icon(
                      LucideIcons.trash2,
                      size: 14.sp,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceOrderBtn() {
    bool disabled = _isSubmitDisabled();
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: disabled
            ? null
            : () {
                setState(() => _mobileSheetExpanded = false);
                _handleSendOrder();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: disabled ? Colors.grey.shade300 : Colors.deepOrange,
          foregroundColor: Colors.white,
          elevation: disabled ? 0 : 8,
          shadowColor: Colors.deepOrange.withOpacity(0.4),
          padding: EdgeInsets.symmetric(vertical: 14.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: Text(
          _confirmButtonLabel(),
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
