import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../utils/apiClient.dart';
import '../../utils/apiConfig.dart';

class RestaurantMenuPage extends StatefulWidget {
  final String restaurantId;
  final String? tableNumber;

  const RestaurantMenuPage({
    super.key,
    required this.restaurantId,
    this.tableNumber,
  });

  @override
  State<RestaurantMenuPage> createState() => _RestaurantMenuPageState();
}

class _RestaurantMenuPageState extends State<RestaurantMenuPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic>? _menu;
  List<dynamic> _categories = [];
  List<dynamic> _allItems = [];
  String? _activeCategory;
  String _searchQuery = '';

  Map<String, dynamic> _cart = {};
  bool _businessTypeFoodTruck = false;

  bool _isReviewModalOpen = false;
  bool _isCheckingOut = false;
  bool _orderProcessing = false;
  bool _orderSuccess = false;

  String _customerName = "";
  String _customerPhone = "";
  bool _rememberMe = false;
  String? _orderId;

  Map<String, dynamic> _upsellData = {};
  String? _activeUpsellId;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<String> _waitingMessages = [
    "Our chef is currently negotiating with the ingredients...",
    "The pizza is doing its final stretches in the oven!",
    "Searching for the perfect garnish. This might take a second.",
    "Making sure your food is 100% delicious and 0% burnt.",
    "Your order is currently being treated like royalty.",
    "Adding a pinch of magic and a dash of 'Ooh-la-la'!",
  ];
  late String _randomMessage;

  @override
  void initState() {
    super.initState();
    _randomMessage =
        _waitingMessages[Random().nextInt(_waitingMessages.length)];
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _initData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDataStr = prefs.getString("customer_info");
    if (savedDataStr != null) {
      try {
        final parsed = jsonDecode(savedDataStr);
        _customerName = parsed['name'] ?? '';
        _customerPhone = parsed['phone'] ?? '';
        _rememberMe = true;
      } catch (_) {}
    }

    try {
      final ctxRes = await apiFetch(
        '/api/restaurants/${widget.restaurantId}/context',
      );
      if (ctxRes['businessType'] == 'FOOD_TRUCK') _businessTypeFoodTruck = true;
    } catch (_) {}

    try {
      final menuData = await apiFetch(
        '/api/public/menu/${widget.restaurantId}',
      );
      _menu = menuData;

      List<dynamic> items = menuData['items'] ?? [];
      items = items.map((i) {
        return {
          ...i,
          'name': i['globalItem']?['name'] ?? i['name'] ?? 'Unnamed Item',
          'basePrice': i['globalItem']?['basePrice'] ?? i['basePrice'] ?? 0,
          'imageUrl': i['globalItem']?['imageUrl'] ?? i['imageUrl'],
        };
      }).toList();

      _allItems = items;
      _categories = menuData['categories'] ?? [];
      if (_categories.isNotEmpty) {
        _activeCategory = _categories[0]['_id'];
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load menu: $err')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _fadeController.forward();
      }
    }
  }

  Future<void> _fetchUpsell(String branchItemId) async {
    try {
      final res = await apiFetch(
        '/api/public/upsell?branchItemId=$branchItemId',
      );
      if (res['suggestions'] != null &&
          (res['suggestions'] as List).isNotEmpty) {
        if (mounted) {
          setState(() {
            _upsellData[branchItemId] = res;
            _activeUpsellId = branchItemId;
          });
        }
      }
    } catch (_) {}
  }

  void _updateQuantity(dynamic item, int delta) {
    setState(() {
      final itemId = item['_id'] as String;
      int currentQty = _cart.containsKey(itemId)
          ? _cart[itemId]['quantity'] as int
          : 0;
      int nextQty = max(0, currentQty + delta);

      if (currentQty == 0 && nextQty == 1 && !(item['isUpsell'] == true)) {
        _fetchUpsell(itemId);
      }

      if (nextQty == 0) {
        _cart.remove(itemId);
      } else {
        _cart[itemId] = {
          ...item,
          'quantity': nextQty,
          'isUpsell': _cart[itemId]?['isUpsell'] ?? item['isUpsell'] ?? false,
        };
      }
    });
  }

  Future<void> _downloadBill() async {
    if (_orderId == null) return;
    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/api/orders/$_orderId/invoice',
      );
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to download: $err')));
        debugPrint('Failed to download: $err');
      }
    }
  }

  Future<void> _finalOrderPlacement() async {
    if (_customerPhone.isEmpty || _customerPhone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _orderProcessing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString(
          "customer_info",
          jsonEncode({'name': _customerName, 'phone': _customerPhone}),
        );
      } else {
        await prefs.remove("customer_info");
      }

      final payload = {
        'placedBy': "CUSTOMER",
        'tableNumber': _businessTypeFoodTruck
            ? null
            : (widget.tableNumber ?? "1"),
        'customerName': _customerName.isEmpty ? "Guest" : _customerName,
        'customerPhone': _customerPhone,
        'items': _cart.values
            .map(
              (i) => {
                'itemId': i['_id'],
                'quantity': i['quantity'],
                'isUpsell': i['isUpsell'] ?? false,
              },
            )
            .toList(),
      };

      final orderRes = await apiFetch(
        '/api/orders',
        method: 'POST',
        data: payload,
      );

      if (mounted) {
        setState(() {
          _orderId = orderRes['_id'];
          _cart.clear();
          _orderSuccess = true;
        });
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place order: $err'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _orderProcessing = false);
    }
  }

  List<dynamic> get _cartItemsArray => _cart.values.toList();
  double get _totalPrice => _cartItemsArray.fold(
    0.0,
    (sum, i) => sum + ((i['basePrice'] ?? 0) * i['quantity']),
  );

  List<dynamic> get _currentSuggestions {
    if (_activeUpsellId == null || !_upsellData.containsKey(_activeUpsellId)) {
      return [];
    }
    List<dynamic> raw = _upsellData[_activeUpsellId]['suggestions'] ?? [];
    return raw.where((sug) => !_cart.containsKey(sug['_id'])).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    if (_orderSuccess) {
      return _buildSuccessScreen();
    }

    // Filter items
    List<dynamic> filteredItems = _allItems.where((i) {
      final catId = (i['category'] is Map)
          ? i['category']['_id']
          : i['category'].toString();
      return catId == _activeCategory &&
          (i['name'] as String).toLowerCase().contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverHeader(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.0.w,
                    vertical: 16.0.h,
                  ),
                  child: Column(
                    children: [
                      _buildSearchBar(),
                      SizedBox(height: 16.h),
                      _buildCategoryScroller(),
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24.0.w,
                ).copyWith(bottom: 120.h),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((ctx, index) {
                    final item = filteredItems[index];
                    final itemId = item['_id'];
                    final isInCart =
                        _cart.containsKey(itemId) &&
                        _cart[itemId]['quantity'] > 0;
                    final showsUpsell =
                        _activeUpsellId == itemId &&
                        _currentSuggestions.isNotEmpty &&
                        isInCart;

                    return Column(
                      children: [
                        _buildMenuItemCard(item, isInCart),
                        if (showsUpsell) _buildUpsellSection(),
                      ],
                    );
                  }, childCount: filteredItems.length),
                ),
              ),
            ],
          ),

          // Floating Cart Bar
          if (_cart.isNotEmpty)
            Positioned(
              bottom: 32.h,
              left: 24.w,
              right: 24.w,
              child: _buildFloatingCartBar(),
            ),

          // Review/Checkout Modal Overlay
          if (_isReviewModalOpen) _buildReviewCheckoutModal(),
        ],
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white.withAlpha(240),
      automaticallyImplyLeading: false,
      expandedHeight: 100.h,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ORDERING FROM',
                  style: TextStyle(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.orange,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  _menu?['restaurant']?['name'] ?? 'Restaurant',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    LucideIcons.shoppingBag,
                    color: Colors.white,
                    size: 16.sp,
                  ),
                ),
                if (_cart.isNotEmpty)
                  Positioned(
                    right: -4.w,
                    top: -4.h,
                    child: Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.w),
                      ),
                      child: Text(
                        '${_cartItemsArray.length}',
                        style: TextStyle(
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search dishes...',
          prefixIcon: Icon(
            LucideIcons.search,
            size: 18.sp,
            color: Colors.grey,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 16.h),
        ),
      ),
    );
  }

  Widget _buildCategoryScroller() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final catId = cat['_id'];
          final isActive = catId == _activeCategory;
          return Padding(
            padding: EdgeInsets.only(right: 8.0.w),
            child: InkWell(
              onTap: () => setState(() => _activeCategory = catId),
              borderRadius: BorderRadius.circular(24.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: isActive ? Colors.orange : Colors.white,
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.orange.withAlpha(50),
                            blurRadius: 10.r,
                            offset: Offset(0, 4.h),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  cat['name'] ?? '',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                    color: isActive ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuItemCard(dynamic item, bool isInCart) {
    return Container(
      margin: EdgeInsets.only(bottom: 24.h),
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 20.r,
            offset: Offset(0, 10.h),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 16.w,
                  height: 16.w,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green, width: 2.w),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 6.w,
                    height: 6.w,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  item['name'],
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '₹${item['basePrice']}',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  item['description'] ??
                      "Authentic ingredients prepared fresh for your table.",
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          SizedBox(
            width: 110.w,
            child: Column(
              children: [
                Container(
                  width: 110.w,
                  height: 110.w,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24.r),
                    child: item['imageUrl'] != null
                        ? Image.network(
                            item['imageUrl'],
                            fit: BoxFit.cover,
                            height: 110.w,
                            width: 110.w,
                            errorBuilder: (c, e, s) => const Icon(
                              LucideIcons.image,
                              color: Colors.grey,
                            ),
                          )
                        : Icon(LucideIcons.image, color: Colors.grey, size: 32.sp),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, -16.h),
                  child: isInCart
                      ? Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withAlpha(50),
                                blurRadius: 10.r,
                                offset: Offset(0, 4.h),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => _updateQuantity(item, -1),
                                child: Padding(
                                  padding: EdgeInsets.all(4.r),
                                  child: Icon(
                                    LucideIcons.minus,
                                    color: Colors.white,
                                    size: 14.sp,
                                  ),
                                ),
                              ),
                              Text(
                                '${_cart[item['_id']]['quantity']}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14.sp,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _updateQuantity(item, 1),
                                child: Padding(
                                  padding: EdgeInsets.all(4.r),
                                  child: Icon(
                                    LucideIcons.plus,
                                    color: Colors.white,
                                    size: 14.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () => _updateQuantity(item, 1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.orange,
                            elevation: 4,
                            shadowColor: Colors.black.withAlpha(20),
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 12.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            'ADD +',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpsellSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Transform.translate(
        offset: Offset(0, -16.h),
        child: Container(
          margin: EdgeInsets.only(bottom: 24.h, left: 16.w, right: 16.w),
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(32.r),
            border: Border.all(color: Colors.orange.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withAlpha(20),
                blurRadius: 20.r,
                offset: Offset(0, 10.h),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      LucideIcons.sparkles,
                      color: Colors.white,
                      size: 12.sp,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MAKE IT A PERFECT MEAL',
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'HANDPICKED FOR YOU',
                        style: TextStyle(
                          fontSize: 8.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              SizedBox(
                height: 160.h,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: _currentSuggestions.take(2).map((sug) {
                    return Container(
                      width: 140.w,
                      margin: EdgeInsets.only(right: 12.w),
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            height: 60.h,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16.r),
                                  child: sug['imageUrl'] != null
                                      ? Image.network(
                                          sug['imageUrl'],
                                          fit: BoxFit.cover,
                                        )
                                      : Icon(
                                          LucideIcons.utensils,
                                          color: Colors.grey,
                                          size: 24.sp,
                                        ),
                                ),
                                Positioned(
                                  bottom: 4.h,
                                  right: 4.w,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6.w,
                                      vertical: 2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Text(
                                      '₹${sug['price']}',
                                      style: TextStyle(
                                        fontSize: 8.sp,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            sug['name'],
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _updateQuantity({
                                ...sug,
                                '_id': sug['_id'],
                                'basePrice': sug['price'],
                                'isUpsell': true,
                              }, 1),
                              icon: Icon(LucideIcons.plus, size: 10.sp),
                              label: Text(
                                'ADD',
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF0F172A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  side: const BorderSide(
                                    color: Color(0xFF0F172A),
                                    width: 1.5,
                                  ),
                                ),
                                elevation: 0,
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingCartBar() {
    return InkWell(
      onTap: () => setState(() => _isReviewModalOpen = true),
      borderRadius: BorderRadius.circular(32.r),
      child: Container(
        padding: EdgeInsets.only(left: 24.w, right: 8.w, top: 8.h, bottom: 8.h),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(40.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(50),
              blurRadius: 20.r,
              offset: Offset(0, 10.h),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'REVIEW BASKET',
                  style: TextStyle(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white54,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  '${_cartItemsArray.length} Items • ₹$_totalPrice',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(32.r),
              ),
              child: Row(
                children: [
                  Text(
                    'ORDER NOW',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(LucideIcons.arrowRight, color: Colors.white, size: 16.sp),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCheckoutModal() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _isReviewModalOpen = false;
            _isCheckingOut = false;
          }),
          child: Container(color: const Color(0xFF0F172A).withAlpha(150)),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: 500.w, maxHeight: 700.h),
            padding: EdgeInsets.all(32.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(40.r)),
            ),
            child: !_isCheckingOut ? _buildBasketView() : _buildCheckoutView(),
          ),
        ),
      ],
    );
  }

  Widget _buildBasketView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 48.w,
            height: 6.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
        ),
        SizedBox(height: 24.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'YOUR BASKET',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _isReviewModalOpen = false),
              icon: const Icon(LucideIcons.x, color: Colors.grey),
            ),
          ],
        ),
        SizedBox(height: 24.h),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: _cartItemsArray.map((i) {
              return Padding(
                padding: EdgeInsets.only(bottom: 24.0.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i['name'],
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '₹${i['basePrice']} x ${i['quantity']}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _updateQuantity(i, -1),
                            child: Padding(
                              padding: EdgeInsets.all(8.r),
                              child: Icon(
                                LucideIcons.minus,
                                color: Colors.grey,
                                size: 14.sp,
                              ),
                            ),
                          ),
                          Text(
                            '${i['quantity']}',
                            style: TextStyle(
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w900,
                              fontSize: 14.sp,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _updateQuantity(i, 1),
                            child: Padding(
                              padding: EdgeInsets.all(8.r),
                              child: Icon(
                                LucideIcons.plus,
                                color: Colors.grey,
                                size: 14.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PAYABLE TOTAL',
                  style: TextStyle(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  '₹$_totalPrice',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => setState(() => _isCheckingOut = true),
              icon: Icon(LucideIcons.arrowRight, size: 18.sp),
              label: const Text(
                'NEXT',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 20.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32.r),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckoutView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CONFIRM DETAILS',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _isCheckingOut = false),
              child: Text(
                'BACK',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 24.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.user, color: Colors.grey, size: 18.sp),
              SizedBox(width: 16.w),
              Expanded(
                child: TextField(
                  onChanged: (v) => _customerName = v,
                  controller: TextEditingController(text: _customerName),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Customer Name',
                    hintStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.phone, color: Colors.grey, size: 18.sp),
              SizedBox(width: 16.w),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.phone,
                  onChanged: (v) => _customerPhone = v,
                  controller: TextEditingController(text: _customerPhone),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Mobile Number *',
                    hintStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),
        InkWell(
          onTap: () => setState(() => _rememberMe = !_rememberMe),
          child: Row(
            children: [
              Container(
                width: 24.w,
                height: 24.w,
                decoration: BoxDecoration(
                  color: _rememberMe ? Colors.orange : Colors.white,
                  border: Border.all(
                    color: _rememberMe ? Colors.orange : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: _rememberMe
                    ? Icon(LucideIcons.check, color: Colors.white, size: 16.sp)
                    : null,
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SAVE MY DETAILS',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'For a faster checkout next time',
                    style: TextStyle(
                      fontSize: 8.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 32.h),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _orderProcessing ? null : _finalOrderPlacement,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 24.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32.r),
              ),
            ),
            child: _orderProcessing
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'CONFIRM & PLACE ORDER',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100.w,
              height: 100.w,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.checkCircle2,
                color: Colors.green,
                size: 50.sp,
              ),
            ),
            SizedBox(height: 32.h),
            Text(
              'ORDER SENT!',
              style: TextStyle(
                fontSize: 32.sp,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                letterSpacing: -1,
              ),
            ),
            SizedBox(height: 16.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.w),
              child: Text(
                _randomMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            SizedBox(height: 48.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(32.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.utensils, color: Colors.orange, size: 16.sp),
                  SizedBox(width: 12.w),
                  Text(
                    'WAIT FOR GOOD FOOD!',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 40.h),
            TextButton(
              onPressed: () => setState(() {
                _orderSuccess = false;
                _isReviewModalOpen = false;
                _isCheckingOut = false;
              }),
              child: Text(
                'BACK TO MENU',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey,
                  letterSpacing: 2,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _downloadBill,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 20.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                ),
              ),
              child: const Text(
                'DOWNLOAD INVOICE',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
