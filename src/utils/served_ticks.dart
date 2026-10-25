import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// "Served to the table" ticks from the Live Orders screen.
///
/// Ticks live only on this device, under the same key the website uses in
/// localStorage: `liveOrdersPaymentState:<restaurantId>` → `servedItems`,
/// shaped `{ orderId: { rowKey: tickedQty } }`.
String servedStorageKey(String restaurantId) =>
    'liveOrdersPaymentState:$restaurantId';

/// Robust recovery of restaurantId from the different session shapes.
String? restaurantIdOf(dynamic user) {
  if (user is! Map) return null;
  final data = user['data'];
  final restaurant = user['restaurant'];
  final id = user['restaurantId'] ??
      (data is Map ? data['restaurantId'] : null) ??
      (restaurant is Map ? restaurant['_id'] : restaurant);
  return id?.toString();
}

String lineIdOf(dynamic item) {
  if (item is! Map) return '';
  final itemData = item['item'];
  return (item['_id'] ??
          (itemData is Map ? itemData['_id'] : null) ??
          (itemData is Map ? itemData['branchName'] : null) ??
          item['name'] ??
          '')
      .toString();
}

num qtyOf(dynamic item) =>
    (item is Map ? num.tryParse((item['quantity'] ?? 1).toString()) : null) ?? 1;

/// One display row of an order item: an item added in several rounds
/// (addHistory) is shown as one row per round, like the website.
class ItemRound {
  final String key;
  final num qty;
  final dynamic at;
  final int index;
  final bool isRound;
  final bool isLast;

  const ItemRound({
    required this.key,
    required this.qty,
    required this.at,
    required this.index,
    required this.isRound,
    required this.isLast,
  });
}

/// Website getItemRounds(): an item that was added in several rounds
/// (addHistory has more than one entry) is shown as one row per round.
/// Round 0 keeps the plain line id as its tick key, so a tick made before
/// the add-on survives.
List<ItemRound> getItemRounds(dynamic item) {
  final lineId = lineIdOf(item);
  final history = item is Map ? item['addHistory'] : null;
  if (history is List && history.length > 1) {
    return [
      for (int i = 0; i < history.length; i++)
        ItemRound(
          key: i == 0 ? lineId : '$lineId:$i',
          qty: (history[i] is Map ? num.tryParse('${history[i]['qty']}') : null) ?? 0,
          at: history[i] is Map ? history[i]['at'] : null,
          index: i,
          isRound: true,
          isLast: i == history.length - 1,
        ),
    ];
  }
  return [
    ItemRound(
      key: lineId,
      qty: qtyOf(item),
      at: history is List && history.isNotEmpty && history[0] is Map
          ? history[0]['at']
          : null,
      index: 0,
      isRound: false,
      isLast: true,
    ),
  ];
}

/// A row counts as ticked only while ticked qty >= the row's qty (website).
bool isRoundServed(
  Map<String, Map<String, num>> served,
  String orderId,
  ItemRound r,
) =>
    (served[orderId]?[r.key] ?? 0) >= r.qty;

/// True when the order has at least one row and every row (every add-on
/// round included) is ticked. A newly added round starts unticked, so the
/// order stops being fully served as soon as something is added.
bool isOrderFullyServed(dynamic order, Map<String, Map<String, num>> served) {
  if (order is! Map) return false;
  final orderId = order['_id']?.toString() ?? '';
  final items = order['items'];
  if (orderId.isEmpty || items is! List) return false;
  int rows = 0;
  for (final item in items) {
    if (item is! Map) continue;
    for (final r in getItemRounds(item)) {
      rows++;
      if (!isRoundServed(served, orderId, r)) return false;
    }
  }
  return rows > 0;
}

/// Reads the ticks saved by the Live Orders screen.
Future<Map<String, Map<String, num>>> loadServedItems(String restaurantId) async {
  final parsed = <String, Map<String, num>>{};
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(servedStorageKey(restaurantId));
    final saved = raw != null ? jsonDecode(raw) : null;
    final servedRaw = saved is Map ? saved['servedItems'] : null;
    if (servedRaw is Map) {
      servedRaw.forEach((orderId, lines) {
        if (lines is! Map) return;
        final orderMap = <String, num>{};
        lines.forEach((lineId, qty) {
          final q = num.tryParse(qty.toString());
          if (q != null) orderMap[lineId.toString()] = q;
        });
        if (orderMap.isNotEmpty) parsed[orderId.toString()] = orderMap;
      });
    }
  } catch (_) {
    // Missing or unreadable state simply means nothing is ticked.
  }
  return parsed;
}
