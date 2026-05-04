import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../utils/apiClient.dart';
import '../../../utils/apiConfig.dart';
import '../../context/AuthContext.dart';
import '../../components/MenuModal.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<dynamic> _orders = [];
  List<dynamic> _servedOrders = [];
  String _activeFilter = 'All';
  String _searchQuery = '';
  bool _isLoading = false;
  // Removed local _businessTypeFoodTruck to use reactive authState

  // Modals & States
  dynamic _viewDetails;
  dynamic _shiftingOrder;
  dynamic _paymentOrder;
  String _newTableValue = '';
  String? _statusUpdating;
  bool _paymentModal = false;

  IO.Socket? _socket;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to avoid illegal state update during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authProvider).user != null) {
        _initRoleAndData();
      }
    });
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _initRoleAndData() async {
    final rawUser = ref.read(authProvider).user;
    if (rawUser == null || _socket != null) return; // Already init or no user

    // Robust recovery of restaurantId from different session types
    final String? restaurantId =
        rawUser['restaurantId'] ??
        rawUser['data']?['restaurantId'] ??
        rawUser['restaurant']?['_id'] ??
        rawUser['restaurant'];

    if (restaurantId == null) {
      debugPrint("⚠️ Socket.IO: No restaurantId found in user session.");
      return;
    }

    // Removed local _businessTypeFoodTruck setter

    _setupSocket(restaurantId);
    await _fetchOrders();
  }

  void _setupSocket(String restaurantId) {
    _socket = IO.io(ApiConfig.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'path': '/socket.io',
      'auth': {'restaurantId': restaurantId},
    });

    _socket?.onConnect((_) {
      debugPrint('✅ Socket connected: ${_socket?.id}');
    });

    _socket?.onDisconnect((reason) {
      debugPrint('❌ Socket disconnected: $reason');
    });

    _socket?.onConnectError((err) {
      debugPrint('⚠️ Socket connection error: $err');
    });

    _socket?.on('new_order', (data) {
      if (!mounted) return;
      debugPrint('📩 New order received via socket: $data');
      setState(() {
        if (data is List) {
          for (var o in data) {
            if (o is Map) _orders.insert(0, o);
          }
        } else if (data is Map) {
          _orders.insert(0, data);
        }
      });
    });

    _socket?.on('order_updated', (data) {
      if (!mounted) return;
      debugPrint('📩 Order updated via socket: $data');

      final updatedOrder = (data is List && data.isNotEmpty) ? data[0] : data;
      if (updatedOrder is! Map) return;

      setState(() {
        final orderId = updatedOrder['_id'];
        final idx = _orders.indexWhere((o) => o is Map && o['_id'] == orderId);
        if (idx != -1) {
          _orders[idx] = updatedOrder;
        } else {
          _orders.insert(0, updatedOrder);
        }
      });
    });
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final data = await apiFetch('/api/admin/orders/live');
      if (mounted && data is List) setState(() => _orders = data);
    } catch (e) {
      debugPrint("Live Orders Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchServedOrders() async {
    setState(() => _isLoading = true);
    try {
      final data = await apiFetch('/api/orders/served');
      if (mounted && data is Map && data['orders'] != null) {
        setState(
          () => _servedOrders = data['orders'] is List ? data['orders'] : [],
        );
      }
    } catch (e) {
      debugPrint("Served Orders Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onFilterChanged(String filter) {
    setState(() => _activeFilter = filter);
    if (filter == 'SERVED' && _servedOrders.isEmpty) {
      _fetchServedOrders();
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Are you sure?',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp),
        ),
        content: Text(
          "You won't be able to revert this cancellation!",
          style: TextStyle(fontSize: 14.sp),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'No, keep it',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12.sp,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            ),
            child: Text(
              'Yes, cancel it!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await apiFetch('/api/admin/orders/$orderId/cancel', method: 'PATCH');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order Cancelled!'),
            backgroundColor: Colors.green,
          ),
        );
      _fetchOrders();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
    }
  }

  Future<void> _confirmTableShift() async {
    if (_newTableValue.isEmpty ||
        (_shiftingOrder != null &&
            _newTableValue == _shiftingOrder['tableNumber']?.toString())) {
      setState(() => _shiftingOrder = null);
      return;
    }
    try {
      await apiFetch(
        '/api/admin/orders/${_shiftingOrder['_id']}/shift',
        method: 'PATCH',
        data: {'newTableNumber': _newTableValue},
      );
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Table Shifted!')));
      setState(() {
        _shiftingOrder = null;
        _newTableValue = "";
      });
      _fetchOrders();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
    }
  }

  Future<void> _collectPayment(String method) async {
    if (_paymentOrder == null) return;
    try {
      await apiFetch(
        '/api/admin/orders/collect-payment',
        method: 'PATCH',
        data: {'orderId': _paymentOrder['_id'], 'paymentMethod': method},
      );
      setState(() {
        _paymentModal = false;
        _paymentOrder = null;
      });
      _fetchOrders();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment Collected!')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  Future<void> _updateStatus(dynamic order, String nextStatus) async {
    try {
      setState(() => _statusUpdating = order['_id']);
      await apiFetch(
        '/api/admin/orders/${order['_id']}/status',
        method: 'PATCH',
        data: {'status': nextStatus},
      );
      if (nextStatus == 'SERVED') {
        _printOrderBill(order);
      }
      await _fetchOrders();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _statusUpdating = null);
    }
  }

  Future<void> _printOrderBill(dynamic order) async {
    try {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sending to printer...'),
            backgroundColor: Colors.green,
          ),
        );
      await apiFetch(
        '/api/admin/orders/${order['_id']}/print-bill',
        method: 'PATCH',
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Printer Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  List<Map<String, dynamic>> _getTopSelling() {
    final Map<String, Map<String, dynamic>> counts = {};
    for (var order in _servedOrders) {
      if (order is! Map) continue;
      final items = order['items'];
      if (items is! List) continue;
      for (var item in items) {
        if (item is! Map) continue;
        final name = item['name']?.toString() ?? 'Unknown';
        final qty = num.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
        final price = num.tryParse((item['basePrice'] ?? 0).toString()) ?? 0;
        if (counts.containsKey(name)) {
          counts[name]!['totalQty'] += qty;
          counts[name]!['revenue'] += (price * qty);
        } else {
          counts[name] = {
            'name': name,
            'totalQty': qty,
            'revenue': (price * qty),
          };
        }
      }
    }
    final list = counts.values.toList();
    list.sort((a, b) => (b['totalQty'] as num).compareTo(a['totalQty'] as num));
    return list.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isFoodTruck = authState.user?['businessType'] == "FOOD_TRUCK";

    // Reactive: If user just loaded, initialize data
    if (authState.user != null && _socket == null && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initRoleAndData();
      });
    }

    final isMobile = 1.sw < 768;
    List<dynamic> displayList = _activeFilter == 'SERVED'
        ? _servedOrders
        : _activeFilter == 'All'
        ? _orders
        : _orders
              .where((o) => o is Map && o['status'] == _activeFilter)
              .toList();

    displayList = displayList
        .where((o) => o is Map && o['status'] != 'CANCELLED')
        .toList();

    if (_searchQuery.isNotEmpty) {
      displayList = displayList
          .where(
            (o) =>
                (o['customerName'] ?? '').toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                (o['tableNumber'] ?? '').toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
          )
          .toList();
    }

    final filters = ["All", "NEW", "ACCEPTED", "PREPARING", "READY", "SERVED"];
    final topSelling = _getTopSelling();

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: MenuModal(
        onClose: () => _scaffoldKey.currentState?.closeEndDrawer(),
        onOrderPlaced: (newOrder) {
          if (newOrder is Map) {
            setState(() {
              _orders.insert(0, newOrder);
            });
          }
        },
      ),
      backgroundColor: const Color(0xFFFDFCF8),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 16.0.w : 24.0.w,
                  isMobile ? 16.0.h : 24.0.h,
                  isMobile ? 16.0.w : 24.0.w,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER
                      if (isMobile)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 12.r,
                                  height: 12.r,
                                  decoration: const BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  'LIVE ORDERS',
                                  style: TextStyle(
                                    fontSize: 24.sp,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(
                                    LucideIcons.externalLink,
                                    color: Colors.orange,
                                    size: 20.sp,
                                  ),
                                  onPressed: () {
                                    final resId = ref
                                        .read(authProvider)
                                        .user?['restaurantId'];
                                    if (resId != null) context.push('/$resId');
                                  },
                                ),
                              ],
                            ),
                            Text(
                              'KITCHEN COMMAND CENTER',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 2.w,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: TextField(
                                      onChanged: (val) =>
                                          setState(() => _searchQuery = val),
                                      decoration: InputDecoration(
                                        hintText: 'Search name or table...',
                                        prefixIcon: Icon(
                                          LucideIcons.search,
                                          size: 18.sp,
                                          color: Colors.grey,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 14.h,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (isFoodTruck) ...[
                                  SizedBox(width: 8.w),
                                  ElevatedButton.icon(
                                    onPressed: () => _scaffoldKey.currentState
                                        ?.openEndDrawer(),
                                    icon: Icon(LucideIcons.plus, size: 16.sp),
                                    label: Text(
                                      'CREATE ORDER',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F172A),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                        vertical: 14.h,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 12.r,
                                      height: 12.r,
                                      decoration: const BoxDecoration(
                                        color: Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'LIVE ORDERS',
                                      style: TextStyle(
                                        fontSize: 28.sp,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'KITCHEN COMMAND CENTER',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 2.w,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    final resId = ref
                                        .read(authProvider)
                                        .user?['restaurantId'];
                                    if (resId != null) context.push('/$resId');
                                  },
                                  icon: Icon(
                                    LucideIcons.externalLink,
                                    size: 16.sp,
                                  ),
                                  label: Text(
                                    'Live Menu',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                  ),
                                ),
                                SizedBox(width: 16.w),
                                Container(
                                  width: 250.w,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: TextField(
                                    onChanged: (val) =>
                                        setState(() => _searchQuery = val),
                                    decoration: InputDecoration(
                                      hintText: 'Search name or table...',
                                      prefixIcon: Icon(
                                        LucideIcons.search,
                                        size: 18.sp,
                                        color: Colors.grey,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 14.h,
                                      ),
                                    ),
                                  ),
                                ),
                                if (isFoodTruck) ...[
                                  SizedBox(width: 12.w),
                                  ElevatedButton.icon(
                                    onPressed: () => _scaffoldKey.currentState
                                        ?.openEndDrawer(),
                                    icon: Icon(LucideIcons.plus, size: 16.sp),
                                    label: Text(
                                      'CREATE ORDER',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F172A),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20.w,
                                        vertical: 16.h,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      SizedBox(height: 24.h),

                      // FILTERS
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: filters.map((f) {
                            final isActive = _activeFilter == f;
                            final count = f == "All"
                                ? _orders
                                      .where(
                                        (o) =>
                                            o is Map &&
                                            o['status'] != 'CANCELLED',
                                      )
                                      .length
                                : _orders
                                      .where(
                                        (o) => o is Map && o['status'] == f,
                                      )
                                      .length;
                            return Padding(
                              padding: EdgeInsets.only(right: 8.0.w),
                              child: InkWell(
                                onTap: () => _onFilterChanged(f),
                                borderRadius: BorderRadius.circular(24.r),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20.w,
                                    vertical: 10.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? const Color(0xFF0F172A)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(24.r),
                                    border: Border.all(
                                      color: isActive
                                          ? const Color(0xFF0F172A)
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        f == "PREPARING" ? "COOKING" : f,
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w900,
                                          color: isActive
                                              ? Colors.white
                                              : Colors.grey,
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6.w,
                                          vertical: 2.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? Colors.orange
                                              : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            6.r,
                                          ),
                                        ),
                                        child: Text(
                                          '$count',
                                          style: TextStyle(
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.bold,
                                            color: isActive
                                                ? Colors.white
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: 24.h),

                      // TOP SELLING ITEMS
                      if (_activeFilter == 'SERVED' && topSelling.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(bottom: 24.h),
                          padding: EdgeInsets.all(32.r),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(40.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(50),
                                blurRadius: 20.r,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    LucideIcons.trendingUp,
                                    color: Colors.greenAccent,
                                    size: 20.sp,
                                  ),
                                  SizedBox(width: 12.w),
                                  Text(
                                    'TOP SELLING ITEMS',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 3.w,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 24.h),
                              LayoutBuilder(
                                builder: (ctx, consts) {
                                  int crossCount = consts.maxWidth < 600
                                      ? 1
                                      : consts.maxWidth < 900
                                      ? 2
                                      : 4;
                                  return GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: crossCount,
                                          crossAxisSpacing: 16.w,
                                          mainAxisSpacing: 16.h,
                                          childAspectRatio: 2.5,
                                        ),
                                    itemCount: topSelling.length,
                                    itemBuilder: (ctx, idx) {
                                      final Map<String, dynamic> item =
                                          topSelling[idx];
                                      return Container(
                                        padding: EdgeInsets.all(20.r),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(15),
                                          borderRadius: BorderRadius.circular(
                                            24.r,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withAlpha(25),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'RANK #${idx + 1}',
                                                    style: TextStyle(
                                                      color: Colors.greenAccent,
                                                      fontSize: 10.sp,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4.h),
                                                  Text(
                                                    item['name'],
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14.sp,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  "${item['totalQty']}",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 24.sp,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                Text(
                                                  'SOLD',
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 9.sp,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.w,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                      // Close the main Column's children
                    ],
                  ), // Close main Column
                ), // Close SliverToBoxAdapter
              ), // Close SliverPadding
              // GRID SLIVER
              _isLoading && _orders.isEmpty
                  ? SliverFillRemaining(
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.orange),
                      ),
                    )
                  : displayList.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(24.r),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.utensilsCrossed,
                                size: 40.sp,
                                color: Colors.orange.shade200,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'NO ACTIVE ORDERS',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              _activeFilter == 'All'
                                  ? 'Kitchen is quiet... Maybe the chef is taking a nap? 💤'
                                  : 'No orders in $_activeFilter stage.',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 16.0.w : 24.0.w,
                        0,
                        isMobile ? 16.0.w : 24.0.w,
                        isMobile ? 16.0.h : 24.0.h,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400.w,
                          mainAxisSpacing: 24.h,
                          crossAxisSpacing: 24.w,
                          childAspectRatio: isMobile ? 0.70 : 0.75,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final order = displayList[index];
                          if (order is! Map) return const SizedBox.shrink();
                          final status = order['status']?.toString() ?? 'NEW';

                          double total = 0;
                          final items = order['items'] ?? [];
                          if (items is List) {
                            for (var i in items) {
                              if (i is! Map) continue;
                              final itemData = i['item'];
                              final price =
                                  num.tryParse(
                                    ((itemData is Map
                                                ? itemData['branchPrice']
                                                : null) ??
                                            i['basePrice'] ??
                                            0)
                                        .toString(),
                                  ) ??
                                  0;
                              final qty =
                                  num.tryParse(
                                    (i['quantity'] ?? 1).toString(),
                                  ) ??
                                  1;
                              total += (price * qty);
                            }
                          }
                          final isPending = order['paymentStatus'] == 'PENDING';

                          return Container(
                            decoration: BoxDecoration(
                              color: isPending
                                  ? const Color(0xFFFEF2F2)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(40.r),
                              border: Border.all(
                                color: isPending
                                    ? Colors.red.shade100
                                    : Colors.grey.shade100,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(5),
                                  blurRadius: 10.r,
                                  offset: Offset(0, 4.h),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Card Header
                                Padding(
                                  padding: EdgeInsets.all(24.0.r),
                                  child: Stack(
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12.w,
                                                  vertical: 4.h,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: status == 'READY'
                                                      ? Colors.green.shade50
                                                      : status == 'ACCEPTED'
                                                      ? Colors.orange.shade50
                                                      : Colors.blue.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        20.r,
                                                      ),
                                                ),
                                                child: Text(
                                                  status == 'PREPARING'
                                                      ? 'COOKING'
                                                      : status,
                                                  style: TextStyle(
                                                    fontSize: 10.sp,
                                                    fontWeight: FontWeight.w900,
                                                    color: status == 'READY'
                                                        ? Colors.green
                                                        : status == 'ACCEPTED'
                                                        ? Colors.orange
                                                        : Colors.blue,
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.only(
                                                  right: 60.0.w,
                                                ),
                                                child: Text(
                                                  '#${(order['_id']?.toString() ?? '....').substring((order['_id']?.toString() ?? '....').length - 4).toUpperCase()}',
                                                  style: TextStyle(
                                                    fontSize: 10.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 16.h),
                                          Text(
                                            isFoodTruck
                                                ? (order['customerName']
                                                          ?.toString() ??
                                                      'Walk-in Guest')
                                                : 'Table ${order['tableNumber']?.toString() ?? 'NA'}',
                                            style: TextStyle(
                                              fontSize: 24.sp,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 8.h),
                                          Row(
                                            children: [
                                              Icon(
                                                LucideIcons.clock,
                                                size: 12.sp,
                                                color: Colors.grey,
                                              ),
                                              SizedBox(width: 6.w),
                                              Text(
                                                DateTime.tryParse(
                                                          order['createdAt'] ??
                                                              '',
                                                        )
                                                        ?.toLocal()
                                                        .toString()
                                                        .substring(11, 16) ??
                                                    'Time',
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Positioned(
                                        right: -10.w,
                                        top: -10.h,
                                        child: Row(
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                LucideIcons.user,
                                                size: 18.sp,
                                                color: Colors.grey,
                                              ),
                                              onPressed: () => setState(
                                                () => _viewDetails = order,
                                              ),
                                            ),
                                            if (!isFoodTruck &&
                                                _activeFilter != 'SERVED') ...[
                                              IconButton(
                                                icon: Icon(
                                                  LucideIcons.arrowRight,
                                                  size: 18.sp,
                                                  color: Colors.grey,
                                                ),
                                                onPressed: () => setState(() {
                                                  _shiftingOrder = order;
                                                  _newTableValue =
                                                      order['tableNumber']
                                                          ?.toString() ??
                                                      '';
                                                }),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Items List
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.all(24.r),
                                    decoration: BoxDecoration(
                                      color: isPending
                                          ? Colors.red.withAlpha(10)
                                          : Colors.grey.shade50,
                                      border: Border.symmetric(
                                        horizontal: BorderSide(
                                          color: isPending
                                              ? Colors.red.shade50
                                              : Colors.grey.shade100,
                                        ),
                                      ),
                                    ),
                                    child: ListView.builder(
                                      itemCount: (items is List)
                                          ? items.length
                                          : 0,
                                      itemBuilder: (ctx, iIdx) {
                                        final item = items[iIdx];
                                        if (item is! Map)
                                          return const SizedBox.shrink();
                                        final itemData = item['item'];
                                        final itemName =
                                            (itemData is Map
                                                ? itemData['branchName']
                                                : null) ??
                                            item['name'] ??
                                            '';
                                        final itemPrice =
                                            num.tryParse(
                                              ((itemData is Map
                                                          ? itemData['branchPrice']
                                                          : null) ??
                                                      item['basePrice'] ??
                                                      0)
                                                  .toString(),
                                            ) ??
                                            0;
                                        final qty =
                                            num.tryParse(
                                              (item['quantity'] ?? 1)
                                                  .toString(),
                                            ) ??
                                            1;
                                        final price = itemPrice * qty;

                                        return Padding(
                                          padding: EdgeInsets.only(
                                            bottom: 16.0.h,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 8.w,
                                                  vertical: 4.h,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        8.r,
                                                      ),
                                                  border: Border.all(
                                                    color: Colors.grey.shade200,
                                                  ),
                                                ),
                                                child: Text(
                                                  '${qty}x',
                                                  style: TextStyle(
                                                    fontSize: 10.sp,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 12.w),
                                              Expanded(
                                                child: Text(
                                                  itemName,
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '₹$price',
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                // Bottom Actions
                                Padding(
                                  padding: EdgeInsets.all(24.0.r),
                                  child: Column(
                                    children: [
                                      if (order['paymentStatus'] == 'PENDING' &&
                                          isFoodTruck) ...[
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12.w,
                                            vertical: 4.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(
                                              16.r,
                                            ),
                                          ),
                                          child: Text(
                                            'PAYMENT PENDING',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 9.sp,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 8.h),
                                      ],
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'TOTAL BILL',
                                            style: TextStyle(
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.grey,
                                              letterSpacing: 2.w,
                                            ),
                                          ),
                                          Text(
                                            '₹$total',
                                            style: TextStyle(
                                              fontSize: 24.sp,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_activeFilter != 'SERVED') ...[
                                        SizedBox(height: 16.h),
                                        Row(
                                          children: [
                                            if (status == 'NEW') ...[
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () => _cancelOrder(
                                                    order['_id'],
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.grey.shade100,
                                                    foregroundColor: Colors.red,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical: 20.h,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20.r,
                                                          ),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  child: Text(
                                                    'CANCEL',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 10.sp,
                                                      letterSpacing: 1.w,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 12.w),
                                            ],
                                            Expanded(
                                              flex: status == 'NEW' ? 2 : 1,
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  String next = status == 'NEW'
                                                      ? 'ACCEPTED'
                                                      : status == 'ACCEPTED'
                                                      ? 'PREPARING'
                                                      : status == 'PREPARING'
                                                      ? 'READY'
                                                      : 'SERVED';
                                                  if (isFoodTruck &&
                                                      next == 'SERVED' &&
                                                      order['paymentStatus'] ==
                                                          'PENDING') {
                                                    setState(() {
                                                      _paymentOrder = order;
                                                      _paymentModal = true;
                                                    });
                                                    return;
                                                  }
                                                  _updateStatus(order, next);
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      status == 'READY'
                                                      ? Colors.green
                                                      : status == 'ACCEPTED'
                                                      ? Colors.orange
                                                      : const Color(0xFF0F172A),
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 20.h,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20.r,
                                                        ),
                                                  ),
                                                ),
                                                child: Text(
                                                  _statusUpdating ==
                                                          order['_id']
                                                      ? 'WAIT...'
                                                      : status == 'NEW'
                                                      ? 'ACCEPT'
                                                      : status == 'ACCEPTED'
                                                      ? 'COOKING'
                                                      : status == 'PREPARING'
                                                      ? 'READY'
                                                      : 'SERVE',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.white,
                                                    fontSize: 10.sp,
                                                    letterSpacing: 1.w,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }, childCount: displayList.length),
                      ),
                    ),
            ],
          ),

          // Modals Overlay
          if (_shiftingOrder != null) _buildShiftModal(),
          if (_viewDetails != null) _buildDetailsModal(),
          if (_paymentModal) _buildPaymentModal(),
        ],
      ),
    );
  }

  Widget _buildShiftModal() {
    return Container(
      color: const Color(0xFF0F172A).withAlpha(150),
      alignment: Alignment.center,
      padding: EdgeInsets.all(24.r),
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: 400.w),
          padding: EdgeInsets.all(40.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(48.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SHIFT TABLE',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'FROM TABLE ${_shiftingOrder['tableNumber']}',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 2.w,
                ),
              ),
              SizedBox(height: 32.h),
              TextField(
                autofocus: true,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.w900),
                onChanged: (val) => setState(() => _newTableValue = val),
                decoration: InputDecoration(
                  hintText: '00',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 32.h),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => _shiftingOrder = null),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmTableShift,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 20.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: const Text(
                        'CONFIRM',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsModal() {
    return Container(
      color: const Color(0xFF0F172A).withAlpha(150),
      alignment: Alignment.center,
      padding: EdgeInsets.all(24.r),
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: 400.w),
          padding: EdgeInsets.all(40.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(48.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CUSTOMER INFO',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      LucideIcons.xCircle,
                      color: Colors.grey,
                      size: 24.sp,
                    ),
                    onPressed: () => setState(() => _viewDetails = null),
                  ),
                ],
              ),
              SizedBox(height: 32.h),
              Container(
                padding: EdgeInsets.all(24.r),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(32.r),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Icon(
                        LucideIcons.user,
                        color: Colors.orange,
                        size: 24.sp,
                      ),
                    ),
                    SizedBox(width: 20.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NAME',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                            letterSpacing: 2.w,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _viewDetails['customerName'] ?? 'Walk-in Guest',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              Container(
                padding: EdgeInsets.all(24.r),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(32.r),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Icon(
                        LucideIcons.phone,
                        color: Colors.orange,
                        size: 24.sp,
                      ),
                    ),
                    SizedBox(width: 20.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONTACT',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                            letterSpacing: 2.w,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _viewDetails['customerPhone'] ?? 'No Phone',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
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
                  onPressed: () => setState(() => _viewDetails = null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: const Text(
                    'CLOSE',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentModal() {
    return Container(
      color: const Color(0xFF0F172A).withAlpha(150),
      alignment: Alignment.center,
      padding: EdgeInsets.all(24.r),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 400.w,
          padding: EdgeInsets.all(40.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(48.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'COLLECT PAYMENT',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'SETTLE BILL BEFORE SERVING',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 2.w,
                ),
              ),
              SizedBox(height: 32.h),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _collectPayment('CASH'),
                      icon: Icon(LucideIcons.banknote, size: 20.sp),
                      label: const Text('CASH'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 24.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24.r),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _collectPayment('UPI'),
                      icon: Icon(LucideIcons.smartphone, size: 20.sp),
                      label: const Text('UPI'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 24.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              TextButton(
                onPressed: () => setState(() {
                  _paymentOrder = null;
                  _paymentModal = false;
                }),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
