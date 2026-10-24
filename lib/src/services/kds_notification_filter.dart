import 'dart:async';
import 'dart:developer';
import '../utils/apiClient.dart';

/// Decides whether an order push should ring, based on each item's KDS
/// toggle (Menu Manager → "KDS On" / "No KDS", stored as `skipKitchen`).
///
/// Mirrors the website's dashboard/layout.js rules:
///   NEW            → ring only if the order has at least one kitchen item
///   UPDATE         → ring only if the newly added items include a kitchen item
///                    (website: `order_modified.silent`)
///   READY / others → ring only if the order has at least one kitchen item
///
/// FCM pushes only carry `orderId` + `type`, so the order is looked up in
/// /api/admin/orders/live. If the lookup fails or the order isn't found we
/// ring anyway — a missed order is worse than an extra alert.
class KdsNotificationFilter {
  KdsNotificationFilter._();

  /// Items stamped within this window of the newest stamp belong to the
  /// same "add items" request (backend sets them in one loop).
  static const Duration batchWindow = Duration(seconds: 5);

  static bool isKitchenItem(dynamic item) =>
      item is Map && item['skipKitchen'] != true;

  static bool hasKitchenItems(List items) => items.any(isKitchenItem);

  static DateTime? _stampOf(dynamic item) {
    if (item is! Map) return null;
    final added = DateTime.tryParse(item['addedAt']?.toString() ?? '');
    final more = DateTime.tryParse(item['lastAddedAt']?.toString() ?? '');
    if (added == null) return more;
    if (more == null) return added;
    return more.isAfter(added) ? more : added;
  }

  /// Items from the most recent add-items request: new lines (`addedAt`)
  /// and existing lines whose quantity was bumped (`lastAddedAt`).
  static List latestBatch(List items) {
    DateTime? newest;
    for (final i in items) {
      final t = _stampOf(i);
      if (t != null && (newest == null || t.isAfter(newest))) newest = t;
    }
    if (newest == null) return items;
    final cutoff = newest.subtract(batchWindow);
    return items.where((i) {
      final t = _stampOf(i);
      return t != null && !t.isBefore(cutoff);
    }).toList();
  }

  /// Pure decision for an already-fetched [order]. Null order → ring.
  static bool shouldNotify(Map? order, String type) {
    if (order == null) return true;
    if (order['silent'] == true) return false;
    final items = order['items'];
    if (items is! List || items.isEmpty) return true;

    if (type == 'UPDATE') {
      final newItems = order['newItems'];
      return hasKitchenItems(newItems is List ? newItems : latestBatch(items));
    }
    return hasKitchenItems(items);
  }

  /// Fetches the order and applies [shouldNotify]. Safe to call from the FCM
  /// background isolate.
  static Future<bool> shouldNotifyForPush(String orderId, String type) async {
    if (orderId.isEmpty) return true;
    try {
      await initCookies();
      final res = await apiFetch('/api/admin/orders/live')
          .timeout(const Duration(seconds: 5));
      final orders = res is Map ? res['orders'] : null;
      if (orders is! List) return true;
      final order = orders.cast<dynamic>().firstWhere(
            (o) => o is Map && o['_id']?.toString() == orderId,
            orElse: () => null,
          );
      final ring = shouldNotify(order as Map?, type);
      log('KDS filter: order=$orderId type=$type found=${order != null} ring=$ring');
      return ring;
    } catch (e) {
      log('KDS filter: lookup failed, ringing anyway -> $e');
      return true;
    }
  }
}
