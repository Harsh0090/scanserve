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
  List<dynamic> _payLaterOrders = [];
  String _activeFilter = 'LIVE';
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
  dynamic _payLaterTarget;
  dynamic _splitTarget;
  bool _splitLoading = false;
  String? _payLaterUpdating;
  String? _paymentUpdating;
  Map<String, dynamic>? _appendTarget;

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
    await _fetchPayLaterOrders();
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

    void upsertOrder(dynamic data) {
      if (!mounted) return;
      final newOrder = (data is List && data.isNotEmpty) ? data[0] : data;
      if (newOrder is! Map) return;

      setState(() {
        final orderId = newOrder['_id'];
        final idx = _orders.indexWhere((o) => o is Map && o['_id'] == orderId);
        if (idx != -1) {
          if (newOrder['type'] == 'ITEM_ADDED') {
            final newItems = newOrder['newItems'];
            if (newItems is List && newItems.isNotEmpty) {
              final autoPrintKOT =
                  ref.read(authProvider).user?['autoPrintKOT'] == true;
              if (autoPrintKOT) {
                _showKOTToast(_orders[idx], newItems, true);
              }
            }
            _orders[idx] = {
              ..._orders[idx] as Map,
              'items': newOrder['items'] ?? _orders[idx]['items'],
              'estimatedTotal':
                  newOrder['estimatedTotal'] ?? _orders[idx]['estimatedTotal'],
              'subTotal': newOrder['subTotal'] ?? _orders[idx]['subTotal'],
              'updatedAt': newOrder['updatedAt'],
            };
          } else {
            _orders[idx] = {..._orders[idx] as Map, ...newOrder};
          }
        } else {
          _showKOTToast(newOrder, newOrder['items'] ?? [], false);
          _orders.insert(0, newOrder);
        }
      });
    }

    _socket?.on('new_order', upsertOrder);
    _socket?.on('order_status_changed', upsertOrder);
    _socket?.on('order_modified', upsertOrder);
    _socket?.on('order_updated', upsertOrder);

    _socket?.on('order_cancelled', (data) {
      if (!mounted) return;
      final orderId = data is Map ? data['orderId'] : null;
      if (orderId != null) {
        setState(() {
          _orders.removeWhere(
            (o) => o is Map && o['_id'].toString() == orderId.toString(),
          );
        });
      }
    });
  }

  void _showKOTToast(dynamic order, List<dynamic> itemsToShow, bool isAddOn) {
    if (!mounted) return;
    final kitchenItems = itemsToShow
        .where((i) => i is Map && i['skipKitchen'] != true)
        .toList();
    if (kitchenItems.isEmpty) return;

    final title = isAddOn ? "Add-on Order" : "New Order";
    final table = order['tableNumber'] ?? order['customerName'] ?? "NA";

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('🧾 ', style: TextStyle(fontSize: 20)),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$title - $table',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${kitchenItems.length} items to print',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'PRINT KOT',
          textColor: Colors.orange,
          onPressed: () {
            // printKOT logic here
            _printKOT(order, itemsToShow, isAddOn);
          },
        ),
        duration: const Duration(seconds: 15),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _printKOT(dynamic order, List<dynamic> itemsToShow, bool isAddOn) {
    debugPrint("Print KOT logic placeholder for order: ${order['_id']}");
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

  Future<void> _fetchPayLaterOrders() async {
    try {
      final data = await apiFetch('/api/admin/orders/pay-later');
      if (mounted && data is Map && data['orders'] != null) {
        setState(
          () => _payLaterOrders = data['orders'] is List ? data['orders'] : [],
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch pay later orders: $e')),
        );
    }
  }

  Future<void> _clearPayLaterPayment(dynamic order, String method) async {
    try {
      setState(() => _paymentUpdating = '${order['_id']}-$method');
      await apiFetch(
        '/api/admin/orders/${order['_id']}/clear-pay-later',
        method: 'PATCH',
        data: {'paymentMethod': method},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment collected via $method',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      setState(() {
        _orders.removeWhere((o) => o is Map && o['_id'] == order['_id']);
        _payLaterOrders.removeWhere(
          (o) => o is Map && o['_id'] == order['_id'],
        );
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _paymentUpdating = null);
    }
  }

  Future<void> _handleSplitPayment(
    dynamic order,
    List<Map<String, dynamic>> payments,
  ) async {
    try {
      setState(() => _splitLoading = true);
      await apiFetch(
        '/api/orders/split-payment',
        method: 'POST',
        data: {'orderId': order['_id'], 'payments': payments},
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Split payment collected',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      setState(() => _splitTarget = null);
      await _fetchOrders();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _splitLoading = false);
    }
  }

  Future<void> _handleCollectEarly(dynamic order, String method) async {
    try {
      setState(() => _paymentUpdating = '${order['_id']}-$method');
      await apiFetch(
        '/api/admin/orders/collect-payment',
        method: 'PATCH',
        data: {'orderId': order['_id'], 'paymentMethod': method},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment collected via $method ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _fetchOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _paymentUpdating = null);
    }
  }

  Future<void> _handlePayLater(
    dynamic order,
    String customerName,
    num paidNow,
    num? remaining,
  ) async {
    try {
      setState(() => _payLaterUpdating = order['_id']);
      final res = await apiFetch(
        '/api/admin/orders/${order['_id']}/pay-later',
        method: 'PATCH',
        data: {
          'customerName': customerName,
          'paidNow': paidNow,
          'remaining': remaining,
        },
      );
      final updatedOrder = (res is Map && res['order'] != null)
          ? res['order']
          : res;
      setState(() {
        final idx = _orders.indexWhere(
          (o) => o is Map && o['_id'] == order['_id'],
        );
        if (idx != -1) {
          _orders[idx] = {
            ..._orders[idx] as Map,
            'customerName': updatedOrder['customerName'] ?? customerName,
            'paymentStatus': 'PAY_LATER',
            'status': 'SERVED',
          };
        }
      });
      await _fetchPayLaterOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              paidNow > 0
                  ? '₹$paidNow collected, ₹$remaining pending for $customerName'
                  : 'Pay Later saved for $customerName',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      setState(() => _payLaterTarget = null);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark pay later: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _payLaterUpdating = null);
    }
  }

  void _initiatePayLater(dynamic order) {
    setState(() {
      _payLaterTarget = {
        'order': order,
        'defaultName': order['customerName'] ?? '',
      };
    });
  }

  Future<dynamic> _removeItemFromOrder(String orderId, String itemId) async {
    return await apiFetch(
      '/api/admin/orders/$orderId/remove-item',
      method: 'PATCH',
      data: {'itemId': itemId},
    );
  }

  void _onFilterChanged(String filter) {
    setState(() => _activeFilter = filter);
    if (filter == 'SERVED' && _servedOrders.isEmpty) {
      _fetchServedOrders();
    } else if (filter == 'PAY_LATER' && _payLaterOrders.isEmpty) {
      _fetchPayLaterOrders();
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
        : _activeFilter == 'PAY_LATER'
        ? _payLaterOrders
        : _activeFilter == 'LIVE'
        ? _orders
              .where((o) => o is Map && o['status'] != 'SERVED' && o['paymentStatus'] != 'PAY_LATER')
              .toList()
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

    final filters = [
      "LIVE",
      "SERVED",
      "PAY_LATER",
    ];
    final topSelling = _getTopSelling();

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: MenuModal(
        onClose: () {
          _scaffoldKey.currentState?.closeEndDrawer();
          setState(() => _appendTarget = null);
        },
        sendAppendOrder: _appendTarget,
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
                                    onPressed: () {
                                      setState(() => _appendTarget = null);
                                      _scaffoldKey.currentState?.openEndDrawer();
                                    },
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
                                    onPressed: () {
                                      setState(() => _appendTarget = null);
                                      _scaffoldKey.currentState?.openEndDrawer();
                                    },
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
                            final count = f == "LIVE"
                                ? _orders
                                      .where(
                                        (o) =>
                                            o is Map &&
                                            o['status'] != 'CANCELLED' &&
                                            o['status'] != 'SERVED' &&
                                            o['paymentStatus'] != 'PAY_LATER',
                                      )
                                      .length
                                : f == "SERVED"
                                ? _servedOrders.length
                                : f == "PAY_LATER"
                                ? _payLaterOrders.length
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
                                        f == "PREPARING"
                                            ? "COOKING"
                                            : f == "PAY_LATER"
                                            ? "PAY LATER"
                                            : f,
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

                      if (_activeFilter == 'PAY_LATER')
                        Container(
                          margin: EdgeInsets.only(top: 24.h),
                          padding: EdgeInsets.all(24.r),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFF7ED), Color(0xFFFFF1F2)],
                            ),
                            borderRadius: BorderRadius.circular(32.r),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12.r),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.receipt_long,
                                  color: Colors.orange,
                                  size: 24.sp,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PAY LATER ORDERS',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      'Orders marked for payment collection later.',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
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
                              _activeFilter == 'PAY_LATER'
                                  ? 'NO PAY LATER ORDERS'
                                  : 'NO ACTIVE ORDERS',
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
                                  : _activeFilter == 'PAY_LATER'
                                  ? 'No pending pay later orders.'
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
                          childAspectRatio: isMobile ? 0.65 : 0.70,
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
                                                  color: status == 'PREPARING'
                                                      ? Colors.purple.shade50
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
                                                      : status == 'PAY_LATER'
                                                      ? 'PAY LATER'
                                                      : status,
                                                  style: TextStyle(
                                                    fontSize: 10.sp,
                                                    fontWeight: FontWeight.w900,
                                                    color: status == 'PREPARING'
                                                        ? Colors.purple
                                                        : status == 'ACCEPTED'
                                                        ? Colors.orange
                                                        : Colors.blue,
                                                  ),
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  if (order['paymentStatus'] ==
                                                      'PAY_LATER')
                                                    Container(
                                                      margin: EdgeInsets.only(
                                                        right: 8.w,
                                                      ),
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 6.w,
                                                            vertical: 2.h,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors
                                                            .orange
                                                            .shade50,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12.r,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors
                                                              .orange
                                                              .shade200,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        'PAY LATER',
                                                        style: TextStyle(
                                                          fontSize: 8.sp,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: Colors
                                                              .orange
                                                              .shade700,
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
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                                ],
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
                                    padding: EdgeInsets.symmetric(horizontal: 24.r, vertical: 12.r),
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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Flexible(
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: (items is List) ? items.length : 0,
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
                                              if (_activeFilter != 'SERVED' &&
                                                  status != 'READY' &&
                                                  status != 'SERVED' &&
                                                  (items is List &&
                                                      items.length > 1)) ...[
                                                SizedBox(width: 4.w),
                                                InkWell(
                                                  onTap: () {
                                                    final itemId =
                                                        item['_id'] ??
                                                        item['item']?['_id'];
                                                    if (itemId != null) {
                                                      _removeItemFromOrder(
                                                        order['_id'],
                                                        itemId,
                                                      );
                                                    }
                                                  },
                                                  child: Container(
                                                    padding: EdgeInsets.all(
                                                      4.r,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4.r,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      Icons.close,
                                                      size: 14.sp,
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Builder(
                                    builder: (context) {
                                      bool isServed = order['status'] == 'SERVED' && order['paymentStatus'] != 'PAY_LATER';
                                      if (!isServed && order['paymentStatus'] != 'PAY_LATER' && _activeFilter != 'SERVED') {
                                        return Padding(
                                          padding: EdgeInsets.only(top: 8.h),
                                          child: OutlinedButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                _appendTarget = {
                                                  'currentOrderId': order['_id'],
                                                  'customerName': order['customerName'] ?? 'Table ${order['tableNumber'] ?? 'Guest'}'
                                                };
                                              });
                                              _scaffoldKey.currentState?.openEndDrawer();
                                            },
                                            icon: Icon(LucideIcons.plus, size: 10.sp),
                                            label: Text(
                                              'ADD ITEMS',
                                              style: TextStyle(
                                                fontSize: 8.sp,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.grey.shade400,
                                                letterSpacing: 1.w,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding: EdgeInsets.symmetric(vertical: 8.h),
                                              side: BorderSide(color: Colors.grey.shade200, width: 1.r),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12.r),
                                              ),
                                              foregroundColor: Colors.grey.shade400,
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Bottom Actions
                          Builder(
                                  builder: (context) {
                                    bool isPaid = order['paymentMethod'] != null && order['paymentMethod'].toString().isNotEmpty;
                                    bool isServed = order['status'] == 'SERVED' && order['paymentStatus'] != 'PAY_LATER';
                                    
                                    return Padding(
                                      padding: EdgeInsets.all(24.0.r),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // TOTAL BILL section
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'TOTAL',
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.grey.shade400,
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
                                          SizedBox(height: 16.h),
                                          
                                          // PAY_LATER breakdown info (if applicable)
                                          if (order['paymentStatus'] == 'PAY_LATER' && order['paidAmount'] != null && (num.tryParse(order['paidAmount'].toString()) ?? 0) > 0) ...[
                                            Container(
                                              padding: EdgeInsets.all(12.r),
                                              margin: EdgeInsets.only(bottom: 16.h),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade50,
                                                borderRadius: BorderRadius.circular(16.r),
                                              ),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text('PAID NOW', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.green)),
                                                      Text('₹${order['paidAmount']}', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: Colors.green)),
                                                    ],
                                                  ),
                                                  Divider(height: 16.h, color: Colors.orange.shade200),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text('REMAINING', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: Colors.orange.shade700)),
                                                      Text('₹${order['remainingAmount']}', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: Colors.orange.shade700)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],

                                          // STATE 1: PAY_LATER tab collection
                                          if (_activeFilter == 'PAY_LATER') ...[
                                            Text(
                                              'COLLECT PAYMENT',
                                              style: TextStyle(
                                                fontSize: 9.sp,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.orange.shade600,
                                                letterSpacing: 2.w,
                                              ),
                                            ),
                                            SizedBox(height: 12.h),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton(
                                                    onPressed: () => _clearPayLaterPayment(order, 'CASH'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.amber.shade50,
                                                      foregroundColor: Colors.amber.shade700,
                                                      padding: EdgeInsets.symmetric(vertical: 14.h),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r), side: BorderSide(color: Colors.amber.shade200)),
                                                      elevation: 0,
                                                    ),
                                                    child: Text(_paymentUpdating == '${order['_id']}-CASH' ? '...' : 'CASH', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10.sp, letterSpacing: 1.w)),
                                                  ),
                                                ),
                                                SizedBox(width: 8.w),
                                                Expanded(
                                                  child: ElevatedButton(
                                                    onPressed: () => _clearPayLaterPayment(order, 'UPI'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.amber.shade50,
                                                      foregroundColor: Colors.amber.shade700,
                                                      padding: EdgeInsets.symmetric(vertical: 14.h),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r), side: BorderSide(color: Colors.amber.shade200)),
                                                      elevation: 0,
                                                    ),
                                                    child: Text(_paymentUpdating == '${order['_id']}-UPI' ? '...' : 'UPI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10.sp, letterSpacing: 1.w)),
                                                  ),
                                                ),
                                                SizedBox(width: 8.w),
                                                Expanded(
                                                  child: ElevatedButton(
                                                    onPressed: () => _clearPayLaterPayment(order, 'CARD'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.amber.shade50,
                                                      foregroundColor: Colors.amber.shade700,
                                                      padding: EdgeInsets.symmetric(vertical: 14.h),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r), side: BorderSide(color: Colors.amber.shade200)),
                                                      elevation: 0,
                                                    ),
                                                    child: Text(_paymentUpdating == '${order['_id']}-CARD' ? '...' : 'CARD', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10.sp, letterSpacing: 1.w)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ]
                                          // STATE 2: PAID STATE (Image 2)
                                          else if (isPaid && !isServed) ...[
                                            Row(
                                              children: [
                                                Expanded(
                                                  flex: 1,
                                                  child: Container(
                                                    padding: EdgeInsets.symmetric(vertical: 16.h),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.shade50,
                                                      borderRadius: BorderRadius.horizontal(left: Radius.circular(20.r)),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        '✓ PAID VIA ${order['paymentMethod']}',
                                                        style: TextStyle(
                                                          fontSize: 10.sp,
                                                          fontWeight: FontWeight.w900,
                                                          color: Colors.green.shade700,
                                                          letterSpacing: 1.w,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 1,
                                                  child: ElevatedButton(
                                                    onPressed: () => _updateStatus(order, 'SERVED'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF10B981), // Emerald 500
                                                      padding: EdgeInsets.symmetric(vertical: 16.h),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.horizontal(right: Radius.circular(20.r)),
                                                      ),
                                                      elevation: 0,
                                                    ),
                                                    child: Text(
                                                      _statusUpdating == order['_id'] ? 'WAIT...' : 'CHECKOUT',
                                                      style: TextStyle(
                                                        fontSize: 10.sp,
                                                        fontWeight: FontWeight.w900,
                                                        color: Colors.white,
                                                        letterSpacing: 1.w,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ]
                                          // STATE 3: UNPAID STATE (Image 1)
                                          else if (!isPaid && !isServed) ...[
                                            Text(
                                              'COLLECT PAYMENT',
                                              style: TextStyle(
                                                fontSize: 9.sp,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.orange.shade600,
                                                letterSpacing: 2.w,
                                              ),
                                            ),
                                            SizedBox(height: 12.h),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton(
                                                    onPressed: () => _handleCollectEarly(order, 'CASH'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.grey.shade100,
                                                      foregroundColor: const Color(0xFF0F172A),
                                                      padding: EdgeInsets.symmetric(vertical: 14.h),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                                      elevation: 0,
                                                    ),
                                                    child: Text(_paymentUpdating == '${order['_id']}-CASH' ? '...' : 'CASH', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10.sp, letterSpacing: 1.w)),
                                                  ),
                                                ),
                                                SizedBox(width: 8.w),
                                                Expanded(
                                                  child: ElevatedButton(
                                                    onPressed: () => _handleCollectEarly(order, 'UPI'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.grey.shade100,
                                                      foregroundColor: const Color(0xFF0F172A),
                                                      padding: EdgeInsets.symmetric(vertical: 14.h),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                                      elevation: 0,
                                                    ),
                                                    child: Text(_paymentUpdating == '${order['_id']}-UPI' ? '...' : 'UPI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10.sp, letterSpacing: 1.w)),
                                                  ),
                                                ),
                                                SizedBox(width: 8.w),
                                                Expanded(
                                                  child: ElevatedButton(
                                                    onPressed: () => _handleCollectEarly(order, 'CARD'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.grey.shade100,
                                                      foregroundColor: const Color(0xFF0F172A),
                                                      padding: EdgeInsets.symmetric(vertical: 14.h),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                                      elevation: 0,
                                                    ),
                                                    child: Text(_paymentUpdating == '${order['_id']}-CARD' ? '...' : 'CARD', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10.sp, letterSpacing: 1.w)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 8.h),
                                            ElevatedButton(
                                              onPressed: () => setState(() => _splitTarget = order),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.purple.shade50,
                                                foregroundColor: Colors.purple.shade600,
                                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12.r),
                                                  side: BorderSide(color: Colors.purple.shade100),
                                                ),
                                                elevation: 0,
                                              ),
                                              child: Text(
                                                '✂ SPLIT',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 10.sp,
                                                  letterSpacing: 1.w,
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: 8.h),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton(
                                                    onPressed: () => _initiatePayLater(order),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.amber.shade50,
                                                      foregroundColor: Colors.amber.shade700,
                                                      padding: EdgeInsets.symmetric(vertical: 14.h),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(12.r),
                                                        side: BorderSide(color: Colors.amber.shade200),
                                                      ),
                                                      elevation: 0,
                                                    ),
                                                    child: Text(
                                                      _payLaterUpdating == order['_id'] ? '...' : 'PAY LATER',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 10.sp,
                                                        letterSpacing: 1.w,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 8.w),
                                                Expanded(
                                                  child: ElevatedButton(
                                                    onPressed: () => _cancelOrder(order['_id']),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red.shade50,
                                                      foregroundColor: Colors.red.shade600,
                                                      padding: EdgeInsets.symmetric(vertical: 14.h),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(12.r),
                                                        side: BorderSide(color: Colors.red.shade100),
                                                      ),
                                                      elevation: 0,
                                                    ),
                                                    child: Text(
                                                      'CANCEL',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w900,
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
                                    );
                                  },
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
          if (_payLaterTarget != null) _buildPayLaterModal(),
          if (_splitTarget != null) _buildSplitPaymentModal(),
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

  Widget _buildPayLaterModal() {
    return PayLaterModalWidget(
      order: _payLaterTarget['order'],
      defaultName: _payLaterTarget['defaultName'],
      onConfirm: (name, paidNow, remaining) {
        _handlePayLater(_payLaterTarget['order'], name, paidNow, remaining);
      },
      onCancel: () => setState(() => _payLaterTarget = null),
    );
  }

  Widget _buildSplitPaymentModal() {
    return SplitPaymentModalWidget(
      order: _splitTarget,
      isLoading: _splitLoading,
      onConfirm: (payments) {
        _handleSplitPayment(_splitTarget, payments);
      },
      onCancel: () => setState(() => _splitTarget = null),
    );
  }
}

class PayLaterModalWidget extends StatefulWidget {
  final dynamic order;
  final String defaultName;
  final Function(String, num, num?) onConfirm;
  final VoidCallback onCancel;

  const PayLaterModalWidget({
    Key? key,
    required this.order,
    required this.defaultName,
    required this.onConfirm,
    required this.onCancel,
  }) : super(key: key);

  @override
  _PayLaterModalWidgetState createState() => _PayLaterModalWidgetState();
}

class _PayLaterModalWidgetState extends State<PayLaterModalWidget> {
  late TextEditingController _nameCtrl;
  late TextEditingController _paidCtrl;
  bool _partialMode = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.defaultName);
    _paidCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    num orderTotal = 0;
    if (widget.order['items'] is List) {
      for (var i in widget.order['items']) {
        final price =
            num.tryParse(
              ((i['item'] is Map ? i['item']['branchPrice'] : null) ??
                      i['basePrice'] ??
                      0)
                  .toString(),
            ) ??
            0;
        final qty = num.tryParse((i['quantity'] ?? 1).toString()) ?? 1;
        orderTotal += (price * qty);
      }
    }

    final paidNowVal = num.tryParse(_paidCtrl.text) ?? 0;
    final remaining = (orderTotal > 0 && paidNowVal > 0)
        ? (orderTotal - paidNowVal)
        : null;

    final isConfirmDisabled =
        _nameCtrl.text.trim().isEmpty ||
        (_partialMode && paidNowVal > 0 && paidNowVal >= orderTotal);

    return Container(
      color: const Color(0xFF0F172A).withAlpha(150),
      alignment: Alignment.center,
      padding: EdgeInsets.all(24.r),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 400.w,
          padding: EdgeInsets.all(32.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(48.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.alertCircle,
                    color: Colors.orange,
                    size: 28.sp,
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'PAY LATER',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Enter customer name to track this order',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.w,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                onChanged: (v) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Customer name...',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.all(20.r),
                ),
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 16.h),
              if (orderTotal > 0)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _partialMode = !_partialMode;
                        _paidCtrl.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _partialMode
                          ? Colors.orange.shade50
                          : Colors.grey.shade50,
                      foregroundColor: _partialMode
                          ? Colors.orange
                          : Colors.grey,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                    ),
                    child: Text(
                      _partialMode
                          ? 'Partial payment ON'
                          : 'Paid something now? (optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11.sp,
                      ),
                    ),
                  ),
                ),
              if (_partialMode) ...[
                SizedBox(height: 16.h),
                TextField(
                  controller: _paidCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.currency_rupee,
                      color: Colors.grey,
                    ),
                    hintText: 'Amount paid now...',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24.r),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.all(20.r),
                  ),
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (paidNowVal > 0) ...[
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL BILL',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '₹$orderTotal',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PAID NOW',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              '- ₹$paidNowVal',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 24.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'REMAINING',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.orange,
                              ),
                            ),
                            Text(
                              '₹$remaining',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onCancel,
                      child: Text(
                        'CANCEL',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.sp,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isConfirmDisabled
                          ? null
                          : () {
                              widget.onConfirm(
                                _nameCtrl.text.trim(),
                                _partialMode ? paidNowVal : 0,
                                _partialMode && paidNowVal > 0
                                    ? remaining
                                    : orderTotal,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 20.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: Text(
                        'CONFIRM',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11.sp,
                        ),
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
}

class SplitPaymentModalWidget extends StatefulWidget {
  final dynamic order;
  final bool isLoading;
  final Function(List<Map<String, dynamic>>) onConfirm;
  final VoidCallback onCancel;

  const SplitPaymentModalWidget({
    Key? key,
    required this.order,
    required this.isLoading,
    required this.onConfirm,
    required this.onCancel,
  }) : super(key: key);

  @override
  _SplitPaymentModalWidgetState createState() =>
      _SplitPaymentModalWidgetState();
}

class _SplitPaymentModalWidgetState extends State<SplitPaymentModalWidget> {
  String _method1 = "CASH";
  String _method2 = "UPI";
  final TextEditingController _amt1Ctrl = TextEditingController();

  final List<String> methods = ["CASH", "UPI", "CARD"];

  @override
  void dispose() {
    _amt1Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    num orderTotal = 0;
    if (widget.order['items'] is List) {
      for (var i in widget.order['items']) {
        final price =
            num.tryParse(
              ((i['item'] is Map ? i['item']['branchPrice'] : null) ??
                      i['basePrice'] ??
                      0)
                  .toString(),
            ) ??
            0;
        final qty = num.tryParse((i['quantity'] ?? 1).toString()) ?? 1;
        orderTotal += (price * qty);
      }
    }

    final amt1 = num.tryParse(_amt1Ctrl.text) ?? 0;
    final amt2 = _amt1Ctrl.text.isNotEmpty
        ? (orderTotal - amt1 > 0 ? orderTotal - amt1 : 0)
        : 0;

    final isValid = _method1 != _method2 && amt1 > 0 && amt1 < orderTotal;

    return Container(
      color: const Color(0xFF0F172A).withAlpha(150),
      alignment: Alignment.center,
      padding: EdgeInsets.all(24.r),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 400.w,
          padding: EdgeInsets.all(32.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(48.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.currency_rupee, color: Colors.purple, size: 28.sp),
                  SizedBox(width: 12.w),
                  Text(
                    'SPLIT PAYMENT',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Total: ₹$orderTotal',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.w,
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'FIRST PAYMENT METHOD',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey,
                    letterSpacing: 1.w,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                children: methods
                    .map(
                      (m) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _method1 = m;
                                if (m == _method2) {
                                  _method2 = methods.firstWhere(
                                    (x) => x != m && x != _method1,
                                    orElse: () =>
                                        methods.firstWhere((x) => x != m),
                                  );
                                }
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _method1 == m
                                  ? Colors.purple.shade50
                                  : Colors.grey.shade50,
                              foregroundColor: _method1 == m
                                  ? Colors.purple
                                  : Colors.grey,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                side: BorderSide(
                                  color: _method1 == m
                                      ? Colors.purple.shade200
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                            child: Text(
                              m,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 10.sp,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: _amt1Ctrl,
                keyboardType: TextInputType.number,
                onChanged: (v) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.currency_rupee,
                    color: Colors.grey,
                  ),
                  hintText: 'Amount paid by $_method1...',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.all(20.r),
                ),
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 24.h),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SECOND PAYMENT METHOD',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey,
                    letterSpacing: 1.w,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                children: methods
                    .where((m) => m != _method1)
                    .map(
                      (m) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: ElevatedButton(
                            onPressed: () => setState(() => _method2 = m),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _method2 == m
                                  ? Colors.purple.shade50
                                  : Colors.grey.shade50,
                              foregroundColor: _method2 == m
                                  ? Colors.purple
                                  : Colors.grey,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                side: BorderSide(
                                  color: _method2 == m
                                      ? Colors.purple.shade200
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                            child: Text(
                              m,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 10.sp,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: 24.h),

              if (isValid)
                Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _method1,
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '₹$amt1',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _method2,
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '₹$amt2',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 24.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            '₹$orderTotal ✓',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onCancel,
                      child: Text(
                        'CANCEL',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.sp,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (!isValid || widget.isLoading)
                          ? null
                          : () {
                              widget.onConfirm([
                                {'method': _method1, 'amount': amt1},
                                {'method': _method2, 'amount': amt2},
                              ]);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 20.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: Text(
                        widget.isLoading ? 'PROCESSING...' : 'CONFIRM SPLIT',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11.sp,
                        ),
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
}
