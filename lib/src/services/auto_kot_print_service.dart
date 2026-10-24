import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../app/context/AuthContext.dart';
import '../utils/apiConfig.dart';
import 'kot_print_service.dart';

/// Signature of the function that actually dispatches a KOT
/// (matches [KotPrintService.printKOT]).
typedef KotPrintFn = Future<void> Function({
  required String orderId,
  required List<dynamic> items,
  bool isAddOn,
  String? tableNumber,
  String? customerName,
  String? restaurantName,
});

/// Global Auto-KOT engine.
///
/// Mirrors the website's dashboard `layout.js`: a SINGLE socket listener that
/// lives in the dashboard shell (not on the Orders page), so live orders are
/// silently printed no matter which dashboard screen is open.
///
///   new_order       → prints the full order (kitchen items only)
///   order_modified  → prints ONLY the newly added items as an ADD-ON KOT
///
/// The Orders page no longer silent-prints; it only shows the
/// "PRINT KOT" prompt when autoPrintKOT is ON and liveOrderKOT is OFF.
class AutoKotPrintManager {
  final Map<String, dynamic>? Function() readUser;
  final KotPrintFn printKOT;

  /// Returns true when this device already printed the KOT itself
  /// (e.g. order placed via MenuModal) — see [locallyPrintedOrderIds].
  final bool Function(String key) isLocallyPrinted;

  /// Called when an auto-print fails (DashboardLayout surfaces a snackbar).
  void Function(String message)? onPrintError;

  /// Short wait before printing so a KOT printed locally by MenuModal
  /// (whose HTTP response may arrive after the socket event) is registered
  /// in [locallyPrintedOrderIds] first — prevents double printing.
  final Duration localPrintGrace;

  /// Same 25s debounce window the website uses for duplicate socket events.
  final Duration dedupeWindow;

  AutoKotPrintManager({
    required this.readUser,
    required this.printKOT,
    required this.isLocallyPrinted,
    this.onPrintError,
    this.localPrintGrace = const Duration(milliseconds: 1500),
    this.dedupeWindow = const Duration(seconds: 25),
  });

  /// Key used in [locallyPrintedOrderIds] by MenuModal when it prints
  /// add-on items for an existing order on this device.
  static String addOnLocalKey(String orderId) => 'addon:$orderId';

  // Deduplication tracker: prevents duplicate print triggers (25s window)
  final Set<String> _printKeys = {};
  // Orders this engine auto-printed as NEW — the Orders page checks this on
  // "Accept" so the same order is not printed a second time.
  final Map<String, DateTime> _autoPrintedOrders = {};
  // Table / customer info from new_order, reused for add-on tickets whose
  // socket payload may not carry them.
  final Map<String, Map<String, String?>> _orderMeta = {};

  IO.Socket? _socket;
  String? _restaurantId;

  String? get connectedRestaurantId => _restaurantId;

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  static Map userDataOf(Map? user) =>
      (user != null && user['data'] is Map) ? user['data'] as Map : (user ?? const {});

  static String? restaurantIdOf(Map? user) {
    if (user == null) return null;
    final data = user['data'] is Map ? user['data'] as Map : const {};
    final restaurant = user['restaurant'];
    final id = user['restaurantId'] ??
        data['restaurantId'] ??
        (restaurant is Map ? restaurant['_id'] : restaurant);
    final str = id?.toString();
    return (str == null || str.isEmpty) ? null : str;
  }

  /// Website rule: respect the order-level skipAutoPrint flag if set,
  /// otherwise fall back to the user's liveOrderKOT setting.
  static bool shouldAutoPrint(Map order, Map userData) {
    if (order['skipAutoPrint'] == true) return false;
    if (order['skipAutoPrint'] == false) return true;
    return userData['liveOrderKOT'] == true;
  }

  static bool _hasKitchenItems(List items) =>
      items.any((i) => i is Map && i['skipKitchen'] != true);

  static Map? _unwrap(dynamic data) {
    final order = (data is List && data.isNotEmpty) ? data[0] : data;
    return order is Map ? order : null;
  }

  /// True if this engine already auto-printed [orderId] as a new order.
  bool wasAutoPrinted(String orderId) => _autoPrintedOrders.containsKey(orderId);

  bool _claim(String printKey) {
    if (_printKeys.contains(printKey)) return false;
    _printKeys.add(printKey);
    Timer(dedupeWindow, () => _printKeys.remove(printKey));
    return true;
  }

  void _prune() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 12));
    _autoPrintedOrders.removeWhere((_, t) => t.isBefore(cutoff));
    if (_orderMeta.length > 500) _orderMeta.clear();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NEW ORDER HANDLER
  // ─────────────────────────────────────────────────────────────────────────
  void handleNewOrder(dynamic data) {
    final order = _unwrap(data);
    if (order == null) return;
    final orderId = order['_id']?.toString() ?? '';
    if (orderId.isEmpty) return;

    final tableNumber = (order['tableNumber'] ?? order['tableName'])?.toString();
    final customerName = order['customerName']?.toString();
    _orderMeta[orderId] = {'tableNumber': tableNumber, 'customerName': customerName};

    final status = order['status'];
    if (status == 'SERVED' || status == 'CANCELLED') return;

    final items = order['items'] is List ? List<dynamic>.from(order['items']) : <dynamic>[];
    if (items.isEmpty || !_hasKitchenItems(items)) return;

    if (!shouldAutoPrint(order, userDataOf(readUser()))) return;
    if (!_claim('$orderId-new')) return;

    Future.delayed(localPrintGrace, () async {
      if (isLocallyPrinted(orderId)) {
        debugPrint('⚙️ AutoKOT: $orderId already printed on this device, skipping.');
        return;
      }
      _autoPrintedOrders[orderId] = DateTime.now();
      _prune();
      await _execute(orderId, items, false, tableNumber, customerName);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADD-ON ITEMS (order_modified) HANDLER
  // ─────────────────────────────────────────────────────────────────────────
  void handleOrderModified(dynamic data) {
    final order = _unwrap(data);
    if (order == null || order['silent'] == true) return;
    final orderId = order['_id']?.toString() ?? '';
    if (orderId.isEmpty) return;

    final newItems = order['newItems'] is List ? List<dynamic>.from(order['newItems']) : <dynamic>[];
    if (newItems.isEmpty || !_hasKitchenItems(newItems)) return;

    if (!shouldAutoPrint(order, userDataOf(readUser()))) return;
    final printKey =
        '$orderId-addon-${newItems.length}-${order['updatedAt'] ?? DateTime.now().millisecondsSinceEpoch}';
    if (!_claim(printKey)) return;

    final meta = _orderMeta[orderId];
    final tableNumber =
        (order['tableNumber'] ?? order['tableName'] ?? meta?['tableNumber'])?.toString();
    final customerName = (order['customerName'] ?? meta?['customerName'])?.toString();

    Future.delayed(localPrintGrace, () async {
      if (isLocallyPrinted(addOnLocalKey(orderId))) {
        debugPrint('⚙️ AutoKOT: add-on for $orderId already printed on this device, skipping.');
        return;
      }
      // Prints ONLY the new add-on items
      await _execute(orderId, newItems, true, tableNumber, customerName);
    });
  }

  Future<void> _execute(
    String orderId,
    List<dynamic> items,
    bool isAddOn,
    String? tableNumber,
    String? customerName,
  ) async {
    try {
      final user = readUser();
      final restName = user?['restaurants']?[0]?['name'] ??
          user?['data']?['restaurants']?[0]?['name'] ??
          user?['name'];
      await printKOT(
        orderId: orderId,
        items: items,
        isAddOn: isAddOn,
        tableNumber: tableNumber,
        customerName: customerName,
        restaurantName: restName?.toString(),
      );
      debugPrint('🖨️ Auto-KOT printed successfully [${isAddOn ? "ADD-ON" : "NEW"}] for $orderId');
    } catch (e) {
      debugPrint('🖨️ KOT Auto-Print Error: $e');
      onPrintError?.call('KOT Print Error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOCKET
  // ─────────────────────────────────────────────────────────────────────────
  void connect(String restaurantId) {
    if (_socket != null && _restaurantId == restaurantId) return;
    disconnect();
    _restaurantId = restaurantId;

    _socket = IO.io(ApiConfig.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'forceNew': true, // independent from the Orders page connection
      'path': '/socket.io',
      'auth': {'restaurantId': restaurantId},
    });

    _socket?.onConnect((_) => debugPrint('✅ AutoKOT socket connected: ${_socket?.id}'));
    _socket?.onDisconnect((reason) => debugPrint('❌ AutoKOT socket disconnected: $reason'));
    _socket?.on('new_order', handleNewOrder);
    _socket?.on('order_modified', handleOrderModified);
  }

  void disconnect() {
    _socket?.off('new_order');
    _socket?.off('order_modified');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _restaurantId = null;
  }
}

/// App-wide singleton; connected/disconnected by DashboardLayout.
final autoKotPrintManagerProvider = Provider<AutoKotPrintManager>((ref) {
  final manager = AutoKotPrintManager(
    readUser: () => ref.read(authProvider).user,
    printKOT: ({
      required String orderId,
      required List<dynamic> items,
      bool isAddOn = false,
      String? tableNumber,
      String? customerName,
      String? restaurantName,
    }) =>
        ref.read(kotPrintServiceProvider).printKOT(
              orderId: orderId,
              items: items,
              isAddOn: isAddOn,
              tableNumber: tableNumber,
              customerName: customerName,
              restaurantName: restaurantName,
            ),
    isLocallyPrinted: (key) => ref.read(locallyPrintedOrderIds).contains(key),
  );
  ref.onDispose(manager.disconnect);
  return manager;
});
