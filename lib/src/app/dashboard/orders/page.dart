import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../utils/apiClient.dart';
import '../../../utils/apiConfig.dart';
import '../../context/AuthContext.dart';
import '../../components/MenuModal.dart';
import '../../../services/kot_print_service.dart';

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
  String _activeFilter = 'All';
  String _searchQuery = '';
  bool _isLoading = false;

  // SERVED period filter
  String _servedDateFilter = 'all';
  String _customStart = '';
  String _customEnd = '';

  // Track newly added items for "New" badge
  final Map<String, List<String>> _newlyAddedItems = {};

  // Pay Later partial amounts and state
  final Map<String, TextEditingController> _partialAmounts = {};
  String? _partialCollectingCustomer;

  TextEditingController _getPartialController(String customerName) {
    if (!_partialAmounts.containsKey(customerName)) {
      _partialAmounts[customerName] = TextEditingController();
    }
    return _partialAmounts[customerName]!;
  }

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
  final Set<String> _pendingCheckoutIds = {};
  final Set<String> _processedEvents = {};
  final Set<String> _shownPromptKeys = {};

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
    for (var ctrl in _partialAmounts.values) {
      ctrl.dispose();
    }
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

    if (mounted) {
      setState(() {
        _activeFilter = 'All';
      });
    }

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

      final orderId = newOrder['_id']?.toString() ?? '';
      final eventKey = "$orderId-${newOrder['type'] ?? 'base'}-${newOrder['updatedAt'] ?? newOrder['createdAt']}";

      // Socket event deduplication with 10s auto-cleanup
      if (_processedEvents.contains(eventKey)) return;
      _processedEvents.add(eventKey);
      Future.delayed(const Duration(seconds: 10), () => _processedEvents.remove(eventKey));

      final user = ref.read(authProvider).user;
      final userData = (user != null && user['data'] is Map) ? user['data'] : (user ?? {});
      final bool liveOrderKOT = userData['liveOrderKOT'] == true;
      final bool autoPrintKOT = userData['autoPrintKOT'] == true;

      setState(() {
        final idx = _orders.indexWhere((o) => o is Map && o['_id'].toString() == orderId);
        if (idx != -1) {
          if (newOrder['type'] == 'ITEM_ADDED') {
            final newItems = newOrder['newItems'];
            if (newItems is List && newItems.isNotEmpty) {
              final newIds = newItems
                  .map((i) => (i is Map ? (i['item'] is Map ? i['item']['_id'] : i['item']) : i).toString())
                  .toList();
              _newlyAddedItems[orderId] = [
                ...(_newlyAddedItems[orderId] ?? []),
                ...newIds,
              ];

              // TRIGGER 2: Add-on items added to existing order
              // if user.autoPrintKOT == true AND user.liveOrderKOT == false:
              //     showKOTPrompt(order: existingOrder, items: socketData.newItems, isAddOn: true)
              // Note: when liveOrderKOT is true, backend handles this automatically
              if (autoPrintKOT && !liveOrderKOT) {
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
              if (newOrder['lastAddedItems'] != null)
                'lastAddedItems': newOrder['lastAddedItems'],
            };
          } else {
            _orders[idx] = {..._orders[idx] as Map, ...newOrder};
          }
        } else {
          // TRIGGER 1: New order arrives via socket (not already in local list)
          final status = newOrder['status'];
          if ((status == 'SERVED' || status == 'CANCELLED') && !_pendingCheckoutIds.contains(orderId)) {
            return;
          }

          final items = (newOrder['items'] is List) ? List<dynamic>.from(newOrder['items']) : <dynamic>[];
          if (liveOrderKOT) {
            // Skip if this order was already printed locally (e.g. placed via MenuModal)
            final alreadyPrinted = ref.read(locallyPrintedOrderIds).contains(orderId);
            if (!alreadyPrinted) {
              _silentPrintKOT(newOrder, items, false);
            } else {
              debugPrint('⚙️ Socket new_order: skipping duplicate print for $orderId (already printed locally)');
            }
          } else if (autoPrintKOT) {
            final alreadyPrinted = ref.read(locallyPrintedOrderIds).contains(orderId);
            if (!alreadyPrinted) {
              _showKOTToast(newOrder, items, false);
            }
          }

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
    // Step 1: Filter out skipKitchen items
    final kitchenItems = itemsToShow
        .where((i) => i is Map && i['skipKitchen'] != true)
        .toList();
    if (kitchenItems.isEmpty) return; // Nothing to print

    final orderId = order['_id']?.toString() ?? '';
    final promptKey = "kot-$orderId-${isAddOn ? 'addon' : 'new'}-${kitchenItems.length}";
    if (_shownPromptKeys.contains(promptKey)) return;
    _shownPromptKeys.add(promptKey);
    Future.delayed(const Duration(seconds: 15), () => _shownPromptKeys.remove(promptKey));

    final title = isAddOn ? "Add-on Order" : "New Order";
    final table = order['tableNumber'] ?? order['customerName'] ?? "NA";

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
                    '$title — Table $table',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${kitchenItems.length} items to print',
                    style: const TextStyle(fontSize: 11),
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
            // TRIGGER 4: User taps "PRINT KOT" button
            _printKOT(order, itemsToShow, isAddOn);
          },
        ),
        duration: const Duration(seconds: 15),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _silentPrintKOT(dynamic order, List<dynamic> items, bool isAddOn) async {
    try {
      final orderId = (order is Map ? order['_id'] : order)?.toString() ?? '';
      final tableNumber = (order is Map ? order['tableNumber'] ?? order['tableName'] : null)?.toString();
      final customerName = (order is Map ? order['customerName'] : null)?.toString();
      final user = ref.read(authProvider).user;
      final restName = user?['restaurants']?[0]?['name'] ?? user?['data']?['restaurants']?[0]?['name'] ?? user?['name'];

      final kotService = ref.read(kotPrintServiceProvider);
      await kotService.printKOT(
        orderId: orderId,
        items: items,
        isAddOn: isAddOn,
        tableNumber: tableNumber,
        customerName: customerName,
        restaurantName: restName?.toString(),
      );
    } catch (e) {
      debugPrint("❌ Silent KOT print failed: $e");
    }
  }

  Future<void> _printKOT(dynamic order, List<dynamic> itemsToShow, bool isAddOn) async {
    try {
      final orderId = (order is Map ? order['_id'] : order)?.toString() ?? '';
      final tableNumber = (order is Map ? order['tableNumber'] ?? order['tableName'] : null)?.toString();
      final customerName = (order is Map ? order['customerName'] : null)?.toString();
      final user = ref.read(authProvider).user;
      final restName = user?['restaurants']?[0]?['name'] ?? user?['data']?['restaurants']?[0]?['name'] ?? user?['name'];

      final kotService = ref.read(kotPrintServiceProvider);
      await kotService.printKOT(
        orderId: orderId,
        items: itemsToShow,
        isAddOn: isAddOn,
        tableNumber: tableNumber,
        customerName: customerName,
        restaurantName: restName?.toString(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KOT sent to printer ✓'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('KOT Print Failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final data = await apiFetch('/api/admin/orders/live');
      if (mounted && data is List) {
        setState(() {
          final pendingOrders = _orders
              .where((o) =>
                  o is Map &&
                  _pendingCheckoutIds.contains(o['_id'].toString()))
              .toList();

          final newOrders = List<dynamic>.from(data);
          for (var po in pendingOrders) {
            final exists = newOrders.any((o) =>
                o is Map && o['_id'].toString() == po['_id'].toString());
            if (!exists) {
              newOrders.add(po);
            }
          }
          _orders = newOrders;
        });
      }
    } catch (e) {
      debugPrint("Live Orders Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchServedOrders([String dateFilter = 'all', String? start, String? end]) async {
    setState(() => _isLoading = true);
    try {
      String url = '/api/orders/served';
      final List<String> params = [];
      if (dateFilter != 'all') params.add('dateFilter=$dateFilter');
      if (dateFilter == 'custom' && start != null && end != null && start.isNotEmpty && end.isNotEmpty) {
        params.add('startDate=$start');
        params.add('endDate=$end');
      }
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }
      final data = await apiFetch(url);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch pay later orders: $e')),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Split payment collected',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      setState(() {
        _pendingCheckoutIds.add(order['_id'].toString());
        _splitTarget = null;
      });
      await _fetchOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _splitLoading = false);
    }
  }

  Future<void> _handleCollectEarly(dynamic order, String method) async {
    try {
      setState(() => _paymentUpdating = '${order['_id']}-$method');
      await apiFetch(
        '/api/orders/collect-early',
        method: 'POST',
        data: {'orderId': order['_id'], 'paymentMethod': method},
      );
      if (mounted) {
        setState(() {
          _pendingCheckoutIds.add(order['_id'].toString());
        });
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

  Future<void> _handleCollectAndServe(dynamic order, String method) async {
    try {
      setState(() => _paymentUpdating = '${order['_id']}-$method');
      await apiFetch(
        '/api/admin/orders/${order['_id']}/status',
        method: 'PATCH',
        data: {'status': 'SERVED'},
      );
      await apiFetch(
        '/api/admin/orders/collect-payment',
        method: 'PATCH',
        data: {'orderId': order['_id'], 'paymentMethod': method},
      );
      final autoPrintBill = ref.read(authProvider).user?['autoPrintBill'] == true ||
          ref.read(authProvider).user?['data']?['autoPrintBill'] == true;
      if (autoPrintBill) {
        _printOrderBill(order);
      }
      setState(() {
        _orders.removeWhere((o) => o['_id'].toString() == order['_id'].toString());
      });
      await _fetchOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
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
      final authState = ref.read(authProvider);
      final isRestaurant = authState.user?['businessType'] == "RESTAURANT" || authState.user?['data']?['businessType'] == "RESTAURANT";
      if (mounted && !isRestaurant) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark pay later: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    if (filter == 'SERVED') {
      _fetchServedOrders(
        _servedDateFilter,
        _customStart.isNotEmpty ? _customStart : null,
        _customEnd.isNotEmpty ? _customEnd : null,
      );
    } else if (filter == 'PAY_LATER') {
      _fetchPayLaterOrders();
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    final isArchived = _payLaterOrders.any((o) => o is Map && o['_id']?.toString() == orderId) ||
        _servedOrders.any((o) => o is Map && o['_id']?.toString() == orderId);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isArchived ? 'Delete this order?' : 'Cancel Order?',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp),
        ),
        content: Text(
          isArchived
              ? "This order will be removed from sales records permanently."
              : "This action cannot be undone.",
          style: TextStyle(fontSize: 14.sp),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isArchived ? 'Keep Order' : 'No, keep it',
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
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            ),
            child: Text(
              isArchived ? 'Yes, Delete' : 'Yes, cancel it!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await apiFetch('/api/admin/orders/$orderId/cancel', method: 'PATCH');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArchived ? 'Order deleted!' : 'Order Cancelled!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _orders.removeWhere((o) => o is Map && o['_id']?.toString() == orderId);
          _servedOrders.removeWhere((o) => o is Map && o['_id']?.toString() == orderId);
          _payLaterOrders.removeWhere((o) => o is Map && o['_id']?.toString() == orderId);
        });
      }
      _fetchOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Table Shifted!')));
      }
      setState(() {
        _shiftingOrder = null;
        _newTableValue = "";
      });
      _fetchOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _collectPayment(String method) async {
    if (_paymentOrder == null) return;
    try {
      await apiFetch(
        '/api/orders/collect-early',
        method: 'POST',
        data: {'orderId': _paymentOrder['_id'], 'paymentMethod': method},
      );
      setState(() {
        _pendingCheckoutIds.add(_paymentOrder['_id'].toString());
        _paymentModal = false;
        _paymentOrder = null;
      });
      _fetchOrders();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment Collected!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(dynamic order, String nextStatus) async {
    try {
      setState(() => _statusUpdating = order['_id']);
      final result = await apiFetch(
        '/api/admin/orders/${order['_id']}/status',
        method: 'PATCH',
        data: {'status': nextStatus},
      );
      if (mounted) {
        setState(() {
          _newlyAddedItems.remove(order['_id']?.toString());
        });
      }
      if (nextStatus == 'ACCEPTED') {
        // TRIGGER 3: Admin Accepts Order (Status -> ACCEPTED)
        final updatedOrder = (result is Map && result['order'] != null)
            ? result['order']
            : (result is Map ? result : order);
        final user = ref.read(authProvider).user;
        final userData = (user != null && user['data'] is Map) ? user['data'] : (user ?? {});
        final bool liveOrderKOT = userData['liveOrderKOT'] == true;
        final bool autoPrintKOT = userData['autoPrintKOT'] == true;

        final items = (updatedOrder['items'] is List)
            ? List<dynamic>.from(updatedOrder['items'])
            : ((order is Map && order['items'] is List)
                ? List<dynamic>.from(order['items'])
                : <dynamic>[]);

        if (liveOrderKOT) {
          _silentPrintKOT(updatedOrder, items, false);
        } else if (autoPrintKOT) {
          _showKOTToast(updatedOrder, items, false);
        }
      } else if (nextStatus == 'SERVED') {
        _printOrderBill(order);
        setState(() {
          _pendingCheckoutIds.remove(order['_id'].toString());
        });
      }
      await _fetchOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _statusUpdating = null);
    }
  }

  Future<void> _printOrderBill(dynamic order) async {
    final orderId = order['_id']?.toString();
    if (orderId == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fetching bill...'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.blueGrey,
        ),
      );
    }

    try {
      // Step 1: Fetch bill data from backend
      final data = await apiFetch('/api/admin/orders/$orderId/bill-preview', method: 'GET');

      if (data == null || data['bill'] == null) {
        throw Exception('Invalid bill response from server');
      }

      final bill = Map<String, dynamic>.from(data['bill'] as Map);

      // Step 2: Route through KotPrintService (Bluetooth → backend fallback)
      final kotService = ref.read(kotPrintServiceProvider);
      await kotService.printBill(bill: bill);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Bill sent to printer'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Printer Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  List<Map<String, dynamic>> _getGroupedPayLaterOrders() {
    final Map<String, Map<String, dynamic>> groups = {};
    for (var order in _payLaterOrders) {
      if (order is! Map) continue;
      final rawName = (order['customerName'] ?? 'Guest').toString();
      final key = rawName.trim().toLowerCase();

      if (!groups.containsKey(key)) {
        groups[key] = {
          'customerName': rawName.trim(),
          'orders': <dynamic>[],
          'totalOwed': 0.0,
          'totalPaid': 0.0,
          'totalBill': 0.0,
        };
      }

      double orderTotal = 0.0;
      final items = order['items'];
      if (items is List) {
        for (var i in items) {
          if (i is! Map) continue;
          final itemData = i['item'];
          final price = num.tryParse(((itemData is Map ? itemData['branchPrice'] : null) ?? i['basePrice'] ?? 0).toString()) ?? 0;
          final qty = num.tryParse((i['quantity'] ?? 1).toString()) ?? 1;
          orderTotal += (price * qty);
        }
      }

      final partialPayment = order['partialPayment'];
      final num paidNow = (partialPayment is Map && partialPayment['paidNow'] != null)
          ? (num.tryParse(partialPayment['paidNow'].toString()) ?? 0)
          : 0;
      final bool hasPartial = paidNow > 0;
      final double owedForThisOrder = hasPartial
          ? (num.tryParse((partialPayment['remaining'] ?? orderTotal).toString())?.toDouble() ?? orderTotal)
          : orderTotal;
      final double paidForThisOrder = hasPartial ? paidNow.toDouble() : 0.0;

      (groups[key]!['orders'] as List<dynamic>).add({
        ...order,
        'orderTotal': orderTotal,
      });
      groups[key]!['totalBill'] = (groups[key]!['totalBill'] as double) + orderTotal;
      groups[key]!['totalPaid'] = (groups[key]!['totalPaid'] as double) + paidForThisOrder;
      groups[key]!['totalOwed'] = (groups[key]!['totalOwed'] as double) + owedForThisOrder;
    }

    final list = groups.values.toList();
    for (var g in list) {
      final ords = g['orders'] as List<dynamic>;
      ords.sort((a, b) {
        final dateA = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      return list.where((g) {
        final name = (g['customerName'] ?? '').toString().toLowerCase();
        if (name.contains(q)) return true;
        final ords = g['orders'] as List<dynamic>;
        return ords.any((o) {
          final id = (o['_id'] ?? '').toString().toLowerCase();
          return id.length >= 4 && id.substring(id.length - 4).contains(q);
        });
      }).toList();
    }

    return list;
  }

  Future<void> _handleCollectPartialPayLater(Map<String, dynamic> group, String method) async {
    final customerName = group['customerName']?.toString() ?? '';
    final ctrl = _getPartialController(customerName);
    final amount = num.tryParse(ctrl.text.trim()) ?? 0;
    final double totalOwed = (group['totalOwed'] as num?)?.toDouble() ?? 0.0;

    if (amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (amount > totalOwed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Amount cannot exceed ₹${totalOwed.toInt()} owed'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    try {
      setState(() => _partialCollectingCustomer = customerName);
      await apiFetch(
        '/api/admin/orders/pay-later/collect-partial',
        method: 'PATCH',
        data: {
          'customerName': customerName,
          'amount': amount,
          'paymentMethod': method,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('₹$amount collected via $method ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
      ctrl.clear();
      await _fetchPayLaterOrders();
      await _fetchOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to collect partial payment: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _partialCollectingCustomer = null);
    }
  }

  Future<void> _handleSettleAllPayLater(Map<String, dynamic> group, String method) async {
    final orders = List<dynamic>.from(group['orders'] ?? []);
    for (var order in orders) {
      if (order is Map) {
        await _clearPayLaterPayment(order, method);
      }
    }
    await _fetchPayLaterOrders();
    await _fetchOrders();
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

  Widget _buildPaymentButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isSplit = false,
    bool isLoading = false,
  }) {
    final bgColor = isSplit ? Colors.purple.shade50 : Colors.grey.shade50;
    final fgColor = isSplit ? Colors.purple.shade700 : Colors.grey.shade700;
    final borderColor = isSplit ? Colors.purple.shade200 : Colors.grey.shade200;

    return Expanded(
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          side: BorderSide(color: borderColor, width: 1.r),
          padding: EdgeInsets.symmetric(vertical: 14.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 12.r,
                height: 12.r,
                child: CircularProgressIndicator(
                  strokeWidth: 2.r,
                  valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                ),
              )
            else ...[
              Icon(icon, size: 14.sp),
              SizedBox(width: 4.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5.w,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  String _formatTime(dynamic dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr.toString())?.toLocal();
    if (dt == null) return '';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  String _formatDateTime(dynamic dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr.toString())?.toLocal();
    if (dt == null) return '';
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEPT', 'OCT', 'NOV', 'DEC'];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day $month • $hour:$minute $amPm';
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color border;
    Color text;
    String label;

    switch (status) {
      case 'NEW':
        bg = const Color(0xFFEFF6FF);
        border = const Color(0xFFBFDBFE);
        text = const Color(0xFF2563EB);
        label = 'NEW';
        break;
      case 'ACCEPTED':
        bg = const Color(0xFFEEF2FF);
        border = const Color(0xFFC7D2FE);
        text = const Color(0xFF4F46E5);
        label = 'ACCEPTED';
        break;
      case 'PREPARING':
        bg = const Color(0xFFFFF7ED);
        border = const Color(0xFFFED7AA);
        text = const Color(0xFFEA580C);
        label = 'COOKING';
        break;
      case 'READY':
        bg = const Color(0xFFFAF5FF);
        border = const Color(0xFFE9D5FF);
        text = const Color(0xFF9333EA);
        label = 'READY';
        break;
      case 'SERVED':
        bg = const Color(0xFFF0FDF4);
        border = const Color(0xFFDCFCE7);
        text = const Color(0xFF16A34A);
        label = 'SERVED';
        break;
      default:
        bg = const Color(0xFFEFF6FF);
        border = const Color(0xFFBFDBFE);
        text = const Color(0xFF2563EB);
        label = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.checkCircle2, size: 10.sp, color: text),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5.sp,
              fontWeight: FontWeight.w900,
              color: text,
              letterSpacing: 0.5.w,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemRow(dynamic order, dynamic item, bool isPayLaterOrder) {
    if (item is! Map) return const SizedBox.shrink();
    final itemData = item['item'];
    final itemName = (itemData is Map ? itemData['branchName'] : null) ?? item['name'] ?? '';
    final itemPrice = num.tryParse(((itemData is Map ? itemData['branchPrice'] : null) ?? item['basePrice'] ?? 0).toString()) ?? 0;
    final qty = num.tryParse((item['quantity'] ?? 1).toString()) ?? 1;
    final price = itemPrice * qty;

    final orderId = order['_id']?.toString() ?? '';
    final itemId = (itemData is Map ? itemData['_id'] : item['_id'])?.toString();
    final isNewItem = _newlyAddedItems[orderId]?.contains(itemId) == true;

    final canRemove = order['status'] != 'SERVED' &&
        order['status'] != 'CANCELLED' &&
        order['paymentStatus'] != 'PAID' &&
        !isPayLaterOrder &&
        _activeFilter != 'SERVED';

    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            '${qty}x',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  itemName.toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF334155),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isNewItem) ...[
                SizedBox(width: 4.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    'NEW',
                    style: TextStyle(
                      fontSize: 7.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          '₹${price.toInt()}',
          style: TextStyle(
            fontSize: 10.5.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF94A3B8),
          ),
        ),
        if (canRemove) ...[
          SizedBox(width: 6.w),
          InkWell(
            onTap: () {
              _removeItemFromOrder(order['_id'].toString(), item['_id'].toString()).then((res) {
                setState(() {
                  final updatedOrder = (res is Map && res['order'] != null) ? res['order'] : res;
                  final idx = _orders.indexWhere((o) => o is Map && o['_id'].toString() == order['_id'].toString());
                  if (idx != -1) {
                    if (res is Map && res['cancelled'] == true) {
                      _orders.removeAt(idx);
                    } else {
                      _orders[idx] = {
                        ..._orders[idx] as Map,
                        'items': updatedOrder['items'],
                        'estimatedTotal': updatedOrder['estimatedTotal'],
                        'subTotal': updatedOrder['subTotal'],
                      };
                    }
                  }
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item removed')),
                  );
                }
              }).catchError((err) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $err')),
                  );
                }
              });
            },
            borderRadius: BorderRadius.circular(10.r),
            child: Container(
              width: 16.r,
              height: 16.r,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.x,
                size: 9.sp,
                color: Colors.red.shade400,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCardActionButtons(
    dynamic order,
    String status,
    bool isReady,
    bool isFullyServed,
    bool isPayLaterOrder,
    bool isRestaurant,
  ) {
    if (isReady && !isPayLaterOrder && _activeFilter != 'SERVED') {
      return Column(
        children: [
          Row(
            children: [
              _buildPaymentButton(
                icon: Icons.payments_outlined,
                label: 'CASH',
                onPressed: () => isRestaurant
                    ? _handleCollectAndServe(order, 'CASH')
                    : _handleCollectEarly(order, 'CASH'),
                isLoading: _paymentUpdating == '${order['_id']}-CASH',
              ),
              SizedBox(width: 6.w),
              _buildPaymentButton(
                icon: Icons.qr_code_scanner,
                label: 'UPI',
                onPressed: () => isRestaurant
                    ? _handleCollectAndServe(order, 'UPI')
                    : _handleCollectEarly(order, 'UPI'),
                isLoading: _paymentUpdating == '${order['_id']}-UPI',
              ),
              SizedBox(width: 6.w),
              _buildPaymentButton(
                icon: Icons.credit_card,
                label: 'CARD',
                onPressed: () => isRestaurant
                    ? _handleCollectAndServe(order, 'CARD')
                    : _handleCollectEarly(order, 'CARD'),
                isLoading: _paymentUpdating == '${order['_id']}-CARD',
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _initiatePayLater(order),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFFBEB),
                    foregroundColor: const Color(0xFFD97706),
                    side: const BorderSide(color: Color(0xFFFDE68A)),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    _payLaterUpdating == order['_id'] ? '...' : 'Pay Later',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 10.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _splitTarget = order),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFFAF5FF),
                    foregroundColor: const Color(0xFF9333EA),
                    side: const BorderSide(color: Color(0xFFE9D5FF)),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    'Split',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 10.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (!isReady && !isFullyServed && !isPayLaterOrder && _activeFilter != 'SERVED') {
      final String nextStatus = status == 'NEW'
          ? 'ACCEPTED'
          : status == 'ACCEPTED'
              ? 'PREPARING'
              : 'READY';
      final String buttonText = status == 'NEW'
          ? 'ACCEPT'
          : status == 'ACCEPTED'
              ? 'COOKING'
              : 'READY';
      final Color buttonBg = status == 'ACCEPTED'
          ? const Color(0xFFF97316)
          : const Color(0xFF0F172A);

      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _statusUpdating == order['_id']
              ? null
              : () => _updateStatus(order, nextStatus),
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonBg,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
            elevation: 0,
          ),
          child: Text(
            _statusUpdating == order['_id'] ? '...' : buttonText,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 11.sp,
              letterSpacing: 1.w,
            ),
          ),
        ),
      );
    }

    if (isFullyServed) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFDCFCE7)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✓ SERVED & PAID',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF16A34A),
                      letterSpacing: 1.w,
                    ),
                  ),
                  if (order['paymentMethod'] != null && order['paymentMethod'].toString().isNotEmpty)
                    Text(
                      'via ${order['paymentMethod']}',
                      style: TextStyle(
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4ADE80),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(LucideIcons.printer, size: 16.sp, color: const Color(0xFF16A34A)),
              onPressed: () => _printOrderBill(order),
              tooltip: 'Reprint Bill',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    if (isPayLaterOrder) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COLLECT PAYMENT',
            style: TextStyle(
              fontSize: 8.sp,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFD97706),
              letterSpacing: 1.w,
            ),
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _clearPayLaterPayment(order, 'CASH'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade50,
                    foregroundColor: Colors.amber.shade700,
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      side: BorderSide(color: Colors.amber.shade200),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _paymentUpdating == '${order['_id']}-CASH' ? '...' : 'CASH',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9.sp),
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _clearPayLaterPayment(order, 'UPI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade50,
                    foregroundColor: Colors.amber.shade700,
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      side: BorderSide(color: Colors.amber.shade200),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _paymentUpdating == '${order['_id']}-UPI' ? '...' : 'UPI',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9.sp),
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _clearPayLaterPayment(order, 'CARD'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade50,
                    foregroundColor: Colors.amber.shade700,
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      side: BorderSide(color: Colors.amber.shade200),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _paymentUpdating == '${order['_id']}-CARD' ? '...' : 'CARD',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9.sp),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildServedDateFilterBar() {
    final dateOptions = [
      {'key': 'all', 'label': 'All Time'},
      {'key': 'today', 'label': 'Today'},
      {'key': 'yesterday', 'label': 'Yesterday'},
      {'key': 'week', 'label': 'This Week'},
      {'key': 'custom', 'label': 'Custom'},
    ];

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'PERIOD',
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF94A3B8),
                letterSpacing: 1.w,
              ),
            ),
            SizedBox(width: 12.w),
            ...dateOptions.map((opt) {
              final isSelected = _servedDateFilter == opt['key'];
              return Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: InkWell(
                  onTap: () {
                    setState(() => _servedDateFilter = opt['key']!);
                    if (opt['key'] != 'custom') {
                      _fetchServedOrders(opt['key']!);
                    }
                  },
                  borderRadius: BorderRadius.circular(20.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      opt['label']!,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (_servedDateFilter == 'custom') ...[
              SizedBox(width: 8.w),
              OutlinedButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(now.year + 1),
                  );
                  if (picked != null) {
                    setState(() {
                      _customStart = picked.start.toIso8601String().substring(0, 10);
                      _customEnd = picked.end.toIso8601String().substring(0, 10);
                    });
                    _fetchServedOrders('custom', _customStart, _customEnd);
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  _customStart.isNotEmpty && _customEnd.isNotEmpty
                      ? '$_customStart to $_customEnd'
                      : 'Pick Dates',
                  style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, dynamic order, dynamic authState) {
    final status = (order['status']?.toString() ?? 'NEW').toUpperCase();
    const isRestaurant = true;
    final isPayLaterOrder = order['paymentStatus'] == 'PAY_LATER';
    final isReady = status == 'READY';
    final isFullyServed = status == 'SERVED' && !isPayLaterOrder;

    double total = 0;
    final items = order['items'] ?? [];
    if (items is List) {
      for (var i in items) {
        if (i is! Map) continue;
        final itemData = i['item'];
        final price = num.tryParse(((itemData is Map ? itemData['branchPrice'] : null) ?? i['basePrice'] ?? 0).toString()) ?? 0;
        final qty = num.tryParse((i['quantity'] ?? 1).toString()) ?? 1;
        total += (price * qty);
      }
    }

    final Color stripeColor = status == 'NEW'
        ? const Color(0xFF60A5FA)
        : status == 'ACCEPTED'
            ? const Color(0xFF818CF8)
            : status == 'PREPARING'
                ? const Color(0xFFFB923C)
                : status == 'READY'
                    ? const Color(0xFFC084FC)
                    : const Color(0xFF4ADE80);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isPayLaterOrder ? Colors.amber.shade200 : const Color(0xFFE2E8F0),
          width: 1.r,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Top Stripe Bar (4px height)
          Container(
            height: 4.h,
            width: double.infinity,
            color: stripeColor,
          ),

          // 2. Card Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildStatusBadge(status),
                        if (isPayLaterOrder) ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Text(
                              'PAY LATER',
                              style: TextStyle(
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _viewDetails = order),
                          borderRadius: BorderRadius.circular(8.r),
                          child: Padding(
                            padding: EdgeInsets.all(4.r),
                            child: Icon(
                              LucideIcons.user,
                              size: 15.sp,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        if (!isFullyServed && !isPayLaterOrder && _activeFilter != 'SERVED') ...[
                          SizedBox(width: 4.w),
                          InkWell(
                            onTap: () => setState(() {
                              _shiftingOrder = order;
                              _newTableValue = order['tableNumber']?.toString() ?? '';
                            }),
                            borderRadius: BorderRadius.circular(8.r),
                            child: Padding(
                              padding: EdgeInsets.all(4.r),
                              child: Icon(
                                LucideIcons.moveRight,
                                size: 15.sp,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                        SizedBox(width: 4.w),
                        InkWell(
                          onTap: () => _cancelOrder(order['_id'].toString()),
                          borderRadius: BorderRadius.circular(8.r),
                          child: Padding(
                            padding: EdgeInsets.all(4.r),
                            child: Icon(
                              LucideIcons.trash2,
                              size: 15.sp,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                if (!isPayLaterOrder)
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                      children: [
                        TextSpan(
                          text: 'TABLE ${order['tableNumber'] ?? 'NA'}',
                        ),
                        if (order['tableAreaLabel'] != null && order['tableAreaLabel'].toString().isNotEmpty)
                          TextSpan(
                            text: ' (${order['tableAreaLabel']})',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  Text(
                    (order['customerName'] ?? 'Guest').toString(),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(
                      LucideIcons.clock,
                      size: 11.sp,
                      color: const Color(0xFF94A3B8),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      _formatTime(order['createdAt']),
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Items List
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: Color(0xFFF1F5F9),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 150.h),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (items is List)
                          for (int iIdx = 0; iIdx < items.length; iIdx++) ...[
                            _buildOrderItemRow(order, items[iIdx], isPayLaterOrder),
                            if (iIdx < items.length - 1) SizedBox(height: 6.h),
                          ],
                      ],
                    ),
                  ),
                ),
                if (!isFullyServed && !isPayLaterOrder && !isReady && _activeFilter != 'SERVED') ...[
                  SizedBox(height: 8.h),
                  CustomPaint(
                    painter: DashedRectPainter(
                      color: const Color(0xFFCBD5E1),
                      strokeWidth: 1.r,
                      gap: 4.w,
                      borderRadius: 12.r,
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _appendTarget = {
                            'currentOrderId': order['_id'],
                            'customerName': order['customerName'] ?? 'Table ${order['tableNumber'] ?? 'Guest'}',
                          };
                        });
                        _scaffoldKey.currentState?.openEndDrawer();
                      },
                      borderRadius: BorderRadius.circular(12.r),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.plus,
                              size: 12.sp,
                              color: const Color(0xFF94A3B8),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              '+ ADD ITEMS',
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF94A3B8),
                                letterSpacing: 1.w,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 4. Card Footer
          Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 2.w,
                      ),
                    ),
                    Text(
                      '₹${total.toInt()}',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                _buildCardActionButtons(order, status, isReady, isFullyServed, isPayLaterOrder, isRestaurant),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayLaterCustomerCard(BuildContext context, Map<String, dynamic> group) {
    final customerName = (group['customerName'] ?? 'Guest').toString();
    final double totalBill = (group['totalBill'] as num?)?.toDouble() ?? 0.0;
    final double totalPaid = (group['totalPaid'] as num?)?.toDouble() ?? 0.0;
    final double totalOwed = (group['totalOwed'] as num?)?.toDouble() ?? 0.0;
    final List<dynamic> orders = (group['orders'] is List) ? group['orders'] as List : [];
    final ctrl = _getPartialController(customerName);
    final isCollecting = _partialCollectingCustomer == customerName;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: const Color(0xFFFDE68A), // amber-200
          width: 1.5.r,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header: Avatar + Customer Name + Orders Count + Pay Later Badge
          Padding(
            padding: EdgeInsets.all(14.r),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38.r,
                      height: 38.r,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7), // amber-100
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        customerName.isNotEmpty ? customerName[0].toUpperCase() : 'G',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFD97706), // amber-600
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${orders.length} order${orders.length > 1 ? "s" : ""}',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB), // amber-50
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: const Color(0xFFFDE68A)), // amber-200
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.alertCircle,
                        size: 11.sp,
                        color: const Color(0xFFD97706),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'PAY LATER',
                        style: TextStyle(
                          fontSize: 8.5.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFD97706),
                          letterSpacing: 0.5.w,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Orders list (slate-50 background)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border.symmetric(
                horizontal: BorderSide(color: Color(0xFFF1F5F9)),
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 160.h),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int ordIdx = 0; ordIdx < orders.length; ordIdx++) ...[
                      Builder(builder: (ctx) {
                        final order = orders[ordIdx];
                        final orderId = (order['_id'] ?? '').toString();
                        final last4 = orderId.length >= 4
                            ? orderId.substring(orderId.length - 4).toUpperCase()
                            : orderId.toUpperCase();
                        final orderItems = (order['items'] is List) ? order['items'] as List : [];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDateTime(order['createdAt']),
                                  style: TextStyle(
                                    fontSize: 8.5.sp,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF94A3B8),
                                    letterSpacing: 0.5.w,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '#$last4',
                                      style: TextStyle(
                                        fontSize: 8.5.sp,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    SizedBox(width: 6.w),
                                    InkWell(
                                      onTap: () => _cancelOrder(orderId),
                                      borderRadius: BorderRadius.circular(6.r),
                                      child: Padding(
                                        padding: EdgeInsets.all(2.r),
                                        child: Icon(
                                          LucideIcons.trash2,
                                          size: 12.sp,
                                          color: const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            for (var item in orderItems) ...[
                              Builder(builder: (ctx) {
                                final itemData = item is Map ? item['item'] : null;
                                final itemName = (itemData is Map ? itemData['branchName'] : null) ?? (item is Map ? item['name'] : '') ?? '';
                                final itemPrice = num.tryParse(((itemData is Map ? itemData['branchPrice'] : null) ?? (item is Map ? item['basePrice'] : null) ?? 0).toString()) ?? 0;
                                final qty = num.tryParse(((item is Map ? item['quantity'] : null) ?? 1).toString()) ?? 1;
                                final price = itemPrice * qty;

                                return Padding(
                                  padding: EdgeInsets.only(bottom: 4.h),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(6.r),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          '${qty}x',
                                          style: TextStyle(
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 6.w),
                                      Expanded(
                                        child: Text(
                                          itemName.toString().toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF334155),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '₹${price.toInt()}',
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            if (ordIdx < orders.length - 1)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 6.h),
                                child: Divider(height: 1.h, color: const Color(0xFFE2E8F0)),
                              ),
                          ],
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 3. Card Footer: Total Bill + Already Paid/Still Owes + Collect Partial + Settle All
          Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL BILL',
                      style: TextStyle(
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFCBD5E1),
                        letterSpacing: 2.w,
                      ),
                    ),
                    Text(
                      '₹${totalBill.toInt()}',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),

                if (totalPaid > 0) ...[
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB), // amber-50
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: const Color(0xFFFEF3C7)), // amber-100
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ALREADY PAID',
                              style: TextStyle(
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF16A34A),
                                letterSpacing: 0.5.w,
                              ),
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              '₹${totalPaid.toInt()}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'STILL OWES',
                              style: TextStyle(
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFD97706),
                                letterSpacing: 0.5.w,
                              ),
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              '₹${totalOwed.toInt()}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 10.h),

                // Collect Partial Payment Container
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: const Color(0xFFFEF3C7),
                      width: 1.5.r,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COLLECT PARTIAL PAYMENT',
                        style: TextStyle(
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 1.w,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: TextField(
                          controller: ctrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Up to ₹${totalOwed.toInt()}',
                            hintStyle: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF94A3B8),
                            ),
                            prefixIcon: Icon(
                              Icons.currency_rupee,
                              size: 13.sp,
                              color: const Color(0xFF94A3B8),
                            ),
                            prefixIconConstraints: BoxConstraints(minWidth: 28.w),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
                            isDense: true,
                          ),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: ['CASH', 'UPI', 'CARD'].map((m) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 2.w),
                              child: ElevatedButton(
                                onPressed: isCollecting ? null : () => _handleCollectPartialPayLater(group, m),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(vertical: 7.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                                child: Text(
                                  isCollecting ? '...' : m,
                                  style: TextStyle(
                                    fontSize: 8.5.sp,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5.w,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 10.h),

                // Settle All Pick Method
                Text(
                  'SETTLE ALL — PICK METHOD',
                  style: TextStyle(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFD97706),
                    letterSpacing: 1.w,
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: ['CASH', 'UPI', 'CARD'].map((m) {
                    final isBusy = _paymentUpdating != null;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2.w),
                        child: OutlinedButton(
                          onPressed: isBusy ? null : () => _handleSettleAllPayLater(group, m),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFFBEB),
                            foregroundColor: const Color(0xFFB45309),
                            side: const BorderSide(color: Color(0xFFFDE68A)),
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: 9.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          child: Text(
                            m,
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5.w,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final rawUser = authState.user;
    final rawUserData = (rawUser != null && rawUser['data'] is Map) ? rawUser['data'] : (rawUser ?? {});
    final bool isFoodTruck = (rawUserData['businessType'] ?? rawUser?['businessType'] ?? '') == 'FOOD_TRUCK';

    // Reactive: If user just loaded, initialize data
    if (authState.user != null && _socket == null && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initRoleAndData();
      });
    }

    final isMobile = 1.sw < 768;

    if (_activeFilter == 'LIVE') {
      _activeFilter = 'All';
    }

    final String activeTab = (isFoodTruck && _activeFilter == 'All') ? 'LIVE' : _activeFilter;
    final bool isServedTab = activeTab == 'SERVED';
    final bool isPayLaterTab = activeTab == 'PAY_LATER';
    final bool isLiveTab = activeTab == 'LIVE' || activeTab == 'All';
    
    final List<Map<String, dynamic>> groupedPayLater = isPayLaterTab ? _getGroupedPayLaterOrders() : [];

    List<dynamic> displayList;
    if (_activeFilter == 'SERVED') {
      displayList = _servedOrders;
    } else if (_activeFilter == 'PAY_LATER') {
      displayList = _payLaterOrders;
    } else if (_activeFilter == 'All') {
      displayList = _orders
          .where((o) =>
              o is Map &&
              o['status'] != 'CANCELLED' &&
              (o['status'] != 'SERVED' ||
                  _pendingCheckoutIds.contains(o['_id'].toString())) &&
              o['paymentStatus'] != 'PAY_LATER')
          .toList();
    } else {
      displayList = _orders
          .where((o) =>
              o is Map &&
              o['status'] != 'CANCELLED' &&
              o['status'] == _activeFilter &&
              o['paymentStatus'] != 'PAY_LATER')
          .toList();
    }

    displayList = displayList
        .where((o) => o is Map && o['status'] != 'CANCELLED')
        .toList();

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      displayList = displayList.where((o) {
        if (o is! Map) return false;
        final name = (o['customerName'] ?? '').toString().toLowerCase();
        final table = (o['tableNumber'] ?? '').toString().toLowerCase();
        final id = (o['_id'] ?? '').toString().toLowerCase();
        return name.contains(q) ||
            table.contains(q) ||
            (id.length >= 4 && id.substring(id.length - 4).contains(q));
      }).toList();
    }

    // Food truck live list — all non-cancelled live orders (includes served-but-paid)
    List<dynamic> foodTruckLiveList = _orders
        .where((o) => o is Map && o['status'] != 'CANCELLED')
        .toList();
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      foodTruckLiveList = foodTruckLiveList.where((o) {
        if (o is! Map) return false;
        final name = (o['customerName'] ?? '').toString().toLowerCase();
        final id = (o['_id'] ?? '').toString().toLowerCase();
        return name.contains(q) ||
            (id.length >= 4 && id.substring(id.length - 4).contains(q));
      }).toList();
    }

    final filters = isFoodTruck 
      ? ["LIVE", "SERVED", "PAY_LATER"]
      : [
          "All",
          "NEW",
          "ACCEPTED",
          "PREPARING",
          "READY",
          "SERVED",
          "PAY_LATER"
        ];
    
    
    final List<dynamic> currentList = isPayLaterTab 
        ? groupedPayLater 
        : (isLiveTab && isFoodTruck) 
            ? foodTruckLiveList 
            : displayList;

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
              final orderId = newOrder['_id'];
              final exists = _orders.any((o) => o is Map && o['_id'].toString() == orderId.toString());
              if (!exists) {
                _orders.insert(0, newOrder);
              }
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
                                  width: 10.r,
                                  height: 10.r,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF97316),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 24.sp,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF0F172A),
                                    ),
                                    children: const [
                                      TextSpan(text: 'LIVE '),
                                      TextSpan(
                                        text: 'ORDERS',
                                        style: TextStyle(
                                          color: Color(0xFFEA580C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(
                                    LucideIcons.externalLink,
                                    color: const Color(0xFFEA580C),
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
                                color: const Color(0xFF64748B),
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
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: TextField(
                                      onChanged: (val) =>
                                          setState(() => _searchQuery = val),
                                      decoration: InputDecoration(
                                        hintText: 'Search name or table...',
                                        hintStyle: TextStyle(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 13.sp,
                                        ),
                                        prefixIcon: Icon(
                                          LucideIcons.search,
                                          size: 18.sp,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 14.h,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
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
                                      width: 10.r,
                                      height: 10.r,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF97316),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 28.sp,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF0F172A),
                                        ),
                                        children: const [
                                          TextSpan(text: 'LIVE '),
                                          TextSpan(
                                            text: 'ORDERS',
                                            style: TextStyle(
                                              color: Color(0xFFEA580C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'KITCHEN COMMAND CENTER',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF64748B),
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
                                    foregroundColor: const Color(0xFFEA580C),
                                  ),
                                ),
                                SizedBox(width: 16.w),
                                Container(
                                  width: 250.w,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: TextField(
                                    onChanged: (val) =>
                                        setState(() => _searchQuery = val),
                                    decoration: InputDecoration(
                                      hintText: 'Search name or table...',
                                      hintStyle: TextStyle(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 13.sp,
                                      ),
                                      prefixIcon: Icon(
                                        LucideIcons.search,
                                        size: 18.sp,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 14.h,
                                      ),
                                    ),
                                  ),
                                ),
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
                            ),
                          ],
                        ),
                      SizedBox(height: 24.h),

                      // FILTERS
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: filters.map((f) {
                            final isActive = activeTab == f;
                            final int count;
                            if (f == "LIVE") {
                              count = foodTruckLiveList.length;
                            } else if (f == "All") {
                              count = _orders.where((o) =>
                                  o is Map &&
                                  o['status'] != 'CANCELLED' &&
                                  (o['status'] != 'SERVED' || _pendingCheckoutIds.contains(o['_id'].toString())) &&
                                  o['paymentStatus'] != 'PAY_LATER').length;
                            } else if (f == "SERVED") {
                              count = _servedOrders.length;
                            } else if (f == "PAY_LATER") {
                              count = _payLaterOrders.length;
                            } else {
                              count = _orders.where((o) =>
                                  o is Map &&
                                  o['status'] != 'CANCELLED' &&
                                  o['status'] == f &&
                                  o['paymentStatus'] != 'PAY_LATER').length;
                            }

                            final String label = f == "All"
                                ? "ALL"
                                : f == "PREPARING"
                                    ? "COOKING"
                                    : f == "PAY_LATER"
                                        ? "PAY LATER"
                                        : f;

                            final isPayLater = f == "PAY_LATER";
                            final Color bgColor = isActive
                                ? (isPayLater ? const Color(0xFFFBBF24) : const Color(0xFF0F172A))
                                : Colors.white;
                            final Color borderColor = isActive
                                ? (isPayLater ? const Color(0xFFFBBF24) : const Color(0xFF0F172A))
                                : const Color(0xFFE2E8F0);
                            final Color textColor = isActive
                                ? (isPayLater ? const Color(0xFF0F172A) : Colors.white)
                                : const Color(0xFF94A3B8);
                            final Color badgeBg = isActive
                                ? (isPayLater ? const Color(0xFFD97706) : const Color(0xFFF97316))
                                : const Color(0xFFF1F5F9);
                            final Color badgeText = isActive
                                ? Colors.white
                                : const Color(0xFF64748B);

                            return Padding(
                              padding: EdgeInsets.only(right: 8.0.w),
                              child: InkWell(
                                onTap: () => _onFilterChanged(f),
                                borderRadius: BorderRadius.circular(24.r),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 18.w,
                                    vertical: 9.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(24.r),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5.w,
                                          color: textColor,
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6.w,
                                          vertical: 2.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: badgeBg,
                                          borderRadius: BorderRadius.circular(6.r),
                                        ),
                                        child: Text(
                                          '$count',
                                          style: TextStyle(
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.w900,
                                            color: badgeText,
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
                      SizedBox(height: 16.h),

                      // SERVED PERIOD FILTER BAR
                      if (isServedTab) ...[
                        _buildServedDateFilterBar(),
                      ],

                      // TOP SELLING ITEMS
                      if (isServedTab && topSelling.isNotEmpty)
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

                      // PAY LATER PENDING BANNER
                      if (isPayLaterTab && _payLaterOrders.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(top: 16.h, bottom: 8.h),
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.alertCircle,
                                size: 18.sp,
                                color: const Color(0xFFD97706),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  '${_payLaterOrders.length} ORDER${_payLaterOrders.length > 1 ? "S" : ""} PENDING PAYMENT — COLLECT WHEN CUSTOMER RETURNS',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFB45309),
                                    letterSpacing: 0.5.w,
                                  ),
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
                  : currentList.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(24.r),
                              decoration: BoxDecoration(
                                color: isPayLaterTab ? const Color(0xFFFFFBEB) : Colors.orange.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPayLaterTab ? LucideIcons.alertCircle : LucideIcons.utensilsCrossed,
                                size: 40.sp,
                                color: isPayLaterTab ? const Color(0xFFFDE68A) : Colors.orange.shade200,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              isPayLaterTab
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
                              isPayLaterTab
                                  ? 'All customers are settled up! 🎉'
                                  : (activeTab == 'All' || activeTab == 'LIVE')
                                  ? 'Kitchen is quiet... Maybe the chef is taking a nap? 💤'
                                  : 'No orders in $activeTab stage.',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: isPayLaterTab ? const Color(0xFF94A3B8) : Colors.grey,
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
                      sliver: isMobile
                          ? SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  if (isPayLaterTab) {
                                    return Padding(
                                      padding: EdgeInsets.only(bottom: 24.h),
                                      child: _buildPayLaterCustomerCard(context, groupedPayLater[index]),
                                    );
                                  }
                                  final order = currentList[index];
                                  if (order is! Map) return const SizedBox.shrink();
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 24.h),
                                    child: isFoodTruck
                                        ? _buildFoodTruckOrderCard(context, order)
                                        : _buildOrderCard(context, order, authState),
                                  );
                                },
                                childCount: currentList.length,
                              ),
                            )
                          : SliverGrid(
                              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 420.w,
                                mainAxisSpacing: 24.h,
                                crossAxisSpacing: 24.w,
                                childAspectRatio: isPayLaterTab ? 0.54 : (isFoodTruck ? 0.82 : 0.70),
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  if (isPayLaterTab) {
                                    return _buildPayLaterCustomerCard(context, groupedPayLater[index]);
                                  }
                                  final order = currentList[index];
                                  if (order is! Map) return const SizedBox.shrink();
                                  return isFoodTruck
                                      ? _buildFoodTruckOrderCard(context, order)
                                      : _buildOrderCard(context, order, authState);
                                },
                                childCount: currentList.length,
                              ),
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

  // ─────────────────────────────────────────────────────────────
  // FOOD TRUCK CARD HELPERS
  // ─────────────────────────────────────────────────────────────

  Widget _buildFoodTruckItemRow(dynamic order, dynamic item) {
    if (item is! Map) return const SizedBox.shrink();
    final itemData = item['item'];
    final itemName = (itemData is Map ? itemData['branchName'] : null) ?? item['name'] ?? '';
    final itemPrice = num.tryParse(((itemData is Map ? itemData['branchPrice'] : null) ?? item['basePrice'] ?? 0).toString()) ?? 0;
    final qty = num.tryParse((item['quantity'] ?? 1).toString()) ?? 1;
    final price = itemPrice * qty;

    final canRemove = order['status'] != 'SERVED' &&
        order['status'] != 'CANCELLED' &&
        order['paymentStatus'] != 'PAID' &&
        _activeFilter != 'SERVED';

    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            '${qty}x',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            itemName.toString().toUpperCase(),
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF334155),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '₹${price.toInt()}',
          style: TextStyle(
            fontSize: 10.5.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF94A3B8),
          ),
        ),
        if (canRemove) ...[
          SizedBox(width: 6.w),
          InkWell(
            onTap: () {
              _removeItemFromOrder(
                order['_id'].toString(),
                item['_id'].toString(),
              ).then((res) {
                setState(() {
                  final updatedOrder = (res is Map && res['order'] != null) ? res['order'] : res;
                  final idx = _orders.indexWhere(
                    (o) => o is Map && o['_id'].toString() == order['_id'].toString(),
                  );
                  if (idx != -1) {
                    if (res is Map && res['cancelled'] == true) {
                      _orders.removeAt(idx);
                    } else {
                      _orders[idx] = {
                        ..._orders[idx] as Map,
                        'items': updatedOrder['items'],
                        'estimatedTotal': updatedOrder['estimatedTotal'],
                        'subTotal': updatedOrder['subTotal'],
                      };
                    }
                  }
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item removed')),
                  );
                }
              }).catchError((err) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $err')),
                  );
                }
              });
            },
            borderRadius: BorderRadius.circular(10.r),
            child: Container(
              width: 16.r,
              height: 16.r,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.x,
                size: 9.sp,
                color: Colors.red.shade400,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFoodTruckOrderCard(BuildContext context, dynamic order) {
    final status = (order['status']?.toString() ?? 'NEW').toUpperCase();
    final isPaid = order['paymentStatus'] == 'PAID';
    final isPayLaterOrder = order['paymentStatus'] == 'PAY_LATER';
    final isServed = status == 'SERVED' && !isPayLaterOrder;

    double total = 0;
    final items = order['items'] ?? [];
    if (items is List) {
      for (var i in items) {
        if (i is! Map) continue;
        final itemData = i['item'];
        final price = num.tryParse(
              ((itemData is Map ? itemData['branchPrice'] : null) ?? i['basePrice'] ?? 0).toString(),
            ) ??
            0;
        final qty = num.tryParse((i['quantity'] ?? 1).toString()) ?? 1;
        total += (price * qty);
      }
    }

    final orderId = order['_id']?.toString() ?? '';
    final last4 = orderId.length >= 4
        ? orderId.substring(orderId.length - 4).toUpperCase()
        : orderId.toUpperCase();

    final Color stripeColor = status == 'NEW'
        ? const Color(0xFF60A5FA)
        : status == 'ACCEPTED'
            ? const Color(0xFF818CF8)
            : status == 'PREPARING'
                ? const Color(0xFFFB923C)
                : status == 'READY'
                    ? const Color(0xFFC084FC)
                    : const Color(0xFF4ADE80);

    return Opacity(
      opacity: isServed && isPaid ? 0.65 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isPayLaterOrder
                ? Colors.amber.shade200
                : isServed
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFE2E8F0),
            width: 1.r,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 10.r,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Top stripe ──
            Container(height: 4.h, width: double.infinity, color: stripeColor),

            // ── Header ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildStatusBadge(status),
                          if (isPayLaterOrder) ...[
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                'PAY LATER',
                                style: TextStyle(
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          // Order ID badge
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              '#$last4',
                              style: TextStyle(
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.w,
                              ),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          InkWell(
                            onTap: () => setState(() => _viewDetails = order),
                            borderRadius: BorderRadius.circular(8.r),
                            child: Padding(
                              padding: EdgeInsets.all(4.r),
                              child: Icon(
                                LucideIcons.user,
                                size: 15.sp,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          InkWell(
                            onTap: () => _cancelOrder(orderId),
                            borderRadius: BorderRadius.circular(8.r),
                            child: Padding(
                              padding: EdgeInsets.all(4.r),
                              child: Icon(
                                LucideIcons.trash2,
                                size: 15.sp,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    (order['customerName'] ?? 'Guest').toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(LucideIcons.clock, size: 11.sp, color: const Color(0xFF94A3B8)),
                      SizedBox(width: 4.w),
                      Text(
                        _formatTime(order['createdAt']),
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Items List ──
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border.symmetric(
                  horizontal: BorderSide(color: Color(0xFFF1F5F9)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 150.h),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (items is List)
                            for (int iIdx = 0; iIdx < items.length; iIdx++) ...[
                              _buildFoodTruckItemRow(order, items[iIdx]),
                              if (iIdx < items.length - 1) SizedBox(height: 6.h),
                            ],
                        ],
                      ),
                    ),
                  ),
                  // Add Items button (hidden when served/paid)
                  if (!isServed && !isPaid) ...[
                    SizedBox(height: 8.h),
                    CustomPaint(
                      painter: DashedRectPainter(
                        color: const Color(0xFFCBD5E1),
                        strokeWidth: 1.r,
                        gap: 4.w,
                        borderRadius: 12.r,
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _appendTarget = {
                              'currentOrderId': order['_id'],
                              'customerName': order['customerName'] ?? 'Guest',
                            };
                          });
                          _scaffoldKey.currentState?.openEndDrawer();
                        },
                        borderRadius: BorderRadius.circular(12.r),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.plus, size: 12.sp, color: const Color(0xFF94A3B8)),
                              SizedBox(width: 4.w),
                              Text(
                                '+ ADD ITEMS',
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF94A3B8),
                                  letterSpacing: 1.w,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Footer ──
            Padding(
              padding: EdgeInsets.all(14.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL',
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 2.w,
                        ),
                      ),
                      Text(
                        '₹${total.toInt()}',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),

                  // ── Already Paid badge + Checkout (food truck: shown in live orders when paid but not yet served) ──
                  if (isPaid && !isServed) ...[
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFFDCFCE7)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '✓ PAID',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF16A34A),
                                  letterSpacing: 1.w,
                                ),
                              ),
                              if (order['paymentMethod'] != null &&
                                  order['paymentMethod'].toString().isNotEmpty)
                                Text(
                                  'via ${order['paymentMethod']}',
                                  style: TextStyle(
                                    fontSize: 8.5.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF4ADE80),
                                  ),
                                ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: _statusUpdating == order['_id']
                                ? null
                                : () => _updateStatus(order, 'SERVED'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 8.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _statusUpdating == order['_id'] ? '...' : 'CHECKOUT',
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5.w,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8.h),
                  ],

                  // ── Served & Fully Done ──
                  if (isServed && isPaid) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFFDCFCE7)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '✓ SERVED & PAID',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF16A34A),
                                    letterSpacing: 1.w,
                                  ),
                                ),
                                if (order['paymentMethod'] != null &&
                                    order['paymentMethod'].toString().isNotEmpty)
                                  Text(
                                    'via ${order['paymentMethod']}',
                                    style: TextStyle(
                                      fontSize: 8.5.sp,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF4ADE80),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              LucideIcons.printer,
                              size: 16.sp,
                              color: const Color(0xFF16A34A),
                            ),
                            onPressed: () => _printOrderBill(order),
                            tooltip: 'Reprint Bill',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Pay Later: Collect Payment buttons ──
                  if (isPayLaterOrder) ...[
                    Text(
                      'COLLECT PAYMENT',
                      style: TextStyle(
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFD97706),
                        letterSpacing: 1.w,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _clearPayLaterPayment(order, 'CASH'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade50,
                              foregroundColor: Colors.amber.shade700,
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                side: BorderSide(color: Colors.amber.shade200),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _paymentUpdating == '${order['_id']}-CASH' ? '...' : 'CASH',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9.sp),
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _clearPayLaterPayment(order, 'UPI'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade50,
                              foregroundColor: Colors.amber.shade700,
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                side: BorderSide(color: Colors.amber.shade200),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _paymentUpdating == '${order['_id']}-UPI' ? '...' : 'UPI',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9.sp),
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _clearPayLaterPayment(order, 'CARD'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade50,
                              foregroundColor: Colors.amber.shade700,
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                side: BorderSide(color: Colors.amber.shade200),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _paymentUpdating == '${order['_id']}-CARD' ? '...' : 'CARD',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9.sp),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // ── Collect Payment (active, unpaid orders) ──
                  if (!isPaid && !isServed && !isPayLaterOrder) ...[
                    Text(
                      'COLLECT PAYMENT',
                      style: TextStyle(
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFF97316),
                        letterSpacing: 1.w,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: ['CASH', 'UPI', 'CARD'].map((method) {
                        final isLoading = _paymentUpdating == '${order['_id']}-$method';
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2.w),
                            child: OutlinedButton(
                              onPressed: _paymentUpdating != null
                                  ? null
                                  : () => _handleCollectEarly(order, method),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFF8FAFC),
                                foregroundColor: const Color(0xFF334155),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                padding: EdgeInsets.symmetric(vertical: 10.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                              ),
                              child: isLoading
                                  ? SizedBox(
                                      width: 12.r,
                                      height: 12.r,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF334155)),
                                      ),
                                    )
                                  : Text(
                                      method,
                                      style: TextStyle(
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5.w,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 6.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => setState(() => _splitTarget = order),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFFAF5FF),
                          foregroundColor: const Color(0xFF9333EA),
                          side: const BorderSide(color: Color(0xFFE9D5FF)),
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        child: Text(
                          '✂  SPLIT',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _payLaterUpdating == order['_id']
                                ? null
                                : () => _initiatePayLater(order),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFFBEB),
                              foregroundColor: const Color(0xFFD97706),
                              side: const BorderSide(color: Color(0xFFFDE68A)),
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            child: Text(
                              _payLaterUpdating == order['_id'] ? '...' : 'PAY LATER',
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _cancelOrder(orderId),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFF1F2),
                              foregroundColor: const Color(0xFFEF4444),
                              side: const BorderSide(color: Color(0xFFFECACA)),
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            child: Text(
                              'CANCEL',
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w900,
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
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MODALS
  // ─────────────────────────────────────────────────────────────

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
    final existingNames = _payLaterOrders
        .map((o) => (o is Map ? o['customerName']?.toString() : null))
        .where((n) => n != null && n.trim().isNotEmpty)
        .map((n) => n!.trim())
        .toSet()
        .toList();

    return PayLaterModalWidget(
      order: _payLaterTarget['order'],
      defaultName: _payLaterTarget['defaultName'],
      existingNames: existingNames,
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
  final List<String> existingNames;
  final Function(String, num, num?) onConfirm;
  final VoidCallback onCancel;

  const PayLaterModalWidget({
    super.key,
    required this.order,
    required this.defaultName,
    this.existingNames = const [],
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<PayLaterModalWidget> createState() => _PayLaterModalWidgetState();
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
              if (_nameCtrl.text.trim().isNotEmpty && widget.existingNames.isNotEmpty) ...[
                Builder(builder: (ctx) {
                  final query = _nameCtrl.text.trim().toLowerCase();
                  final matches = widget.existingNames
                      .where((n) => n.toLowerCase().contains(query) && n.toLowerCase() != query)
                      .take(4)
                      .toList();
                  if (matches.isEmpty) return const SizedBox.shrink();

                  return Container(
                    margin: EdgeInsets.only(top: 8.h),
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EXISTING CUSTOMERS',
                          style: TextStyle(
                            fontSize: 8.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFD97706),
                            letterSpacing: 1.w,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Wrap(
                          spacing: 6.w,
                          runSpacing: 6.h,
                          children: matches.map((m) {
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _nameCtrl.text = m;
                                });
                              },
                              borderRadius: BorderRadius.circular(10.r),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 16.r,
                                      height: 16.r,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFEF3C7),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        m[0].toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 8.sp,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 5.w),
                                    Text(
                                      m,
                                      style: TextStyle(
                                        fontSize: 10.5.sp,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }),
              ],
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
    super.key,
    required this.order,
    required this.isLoading,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<SplitPaymentModalWidget> createState() =>
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

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double borderRadius;

  DashedRectPainter({
    this.color = Colors.grey,
    this.strokeWidth = 1.0,
    this.gap = 5.0,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = Path();
    double distance = 0.0;

    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        final len = gap;
        if (distance + len > pathMetric.length) {
          dashPath.addPath(
            pathMetric.extractPath(distance, pathMetric.length),
            Offset.zero,
          );
        } else {
          dashPath.addPath(
            pathMetric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len * 2;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
