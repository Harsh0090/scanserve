import 'dart:math' as math;

/// Bill, discount and Pay Later money rules from the Live Orders screen,
/// ported from the website's getPickupBill() and groupedPayLaterOrders.
///
/// A discount lives only on this device until the order is paid or moved to
/// Pay Later, under the same key the website uses in localStorage:
/// `liveOrdersPaymentState:<restaurantId>` → `pickupDiscounts`,
/// shaped `{ orderId: { type, value } }`.

const String discountNone = 'NONE';
const String discountPercentage = 'PERCENTAGE';
const String discountFixed = 'FIXED';

/// Same rounding as the website and backend: JS `+x.toFixed(2)`.
double fix2(num v) => double.parse(v.toStringAsFixed(2));

double numOf(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

/// Rupee amount with Indian digit grouping and at most 2 decimals:
/// 1,26,000 · 1,365 · 945.5
String inr(num v) {
  final rounded = fix2(v);
  final parts = rounded.abs().toStringAsFixed(2).split('.');
  var whole = parts[0];
  final decimals = parts[1].replaceFirst(RegExp(r'0+$'), '');
  if (whole.length > 3) {
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    whole = '${groups.join(',')},$last3';
  }
  return '${rounded < 0 ? '-' : ''}$whole${decimals.isEmpty ? '' : '.$decimals'}';
}

String _discountTypeOf(dynamic type) {
  final t = type?.toString();
  return (t == discountPercentage || t == discountFixed) ? t! : discountNone;
}

/// A discount typed on this device, not yet saved on the order.
class LocalDiscount {
  final String type;
  final String value; // raw field text, as the website keeps it

  const LocalDiscount({this.type = discountNone, this.value = ''});

  static const none = LocalDiscount();

  double get numeric => double.tryParse(value) ?? 0;

  /// Nothing to apply: no type picked, or no positive value typed.
  bool get isEmpty => type == discountNone || numeric <= 0;

  Map<String, dynamic> toJson() => {'type': type, 'value': value};

  factory LocalDiscount.fromJson(dynamic json) {
    if (json is! Map) return none;
    return LocalDiscount(
      type: _discountTypeOf(json['type']),
      value: json['value']?.toString() ?? '',
    );
  }
}

class PickupBill {
  final double subTotal;
  final double gstRate;
  final double total; // GST-inclusive, before discount: the API's billTotal
  final double discountAmount;
  final double finalAmount;
  final String? error;

  const PickupBill({
    required this.subTotal,
    required this.gstRate,
    required this.total,
    this.discountAmount = 0,
    required this.finalAmount,
    this.error,
  });
}

/// Unit price of an order line: the menu branchPrice when the item is
/// populated (live orders) and above 0, otherwise the line's basePrice.
double lineUnitPrice(dynamic line) {
  if (line is! Map) return 0;
  final itemData = line['item'];
  final branchPrice = itemData is Map ? numOf(itemData['branchPrice']) : 0.0;
  return branchPrice > 0 ? branchPrice : numOf(line['basePrice']);
}

double orderItemsSum(dynamic order) {
  final items = order is Map ? order['items'] : null;
  if (items is! List) return 0;
  double sum = 0;
  for (final line in items) {
    if (line is! Map) continue;
    sum += lineUnitPrice(line) * (num.tryParse((line['quantity'] ?? 1).toString()) ?? 1);
  }
  return sum;
}

/// Website getPickupBill(): GST first, then the discount on the
/// GST-inclusive total. The backend recomputes the discount from billTotal.
PickupBill calculatePickupBill(
  dynamic order, {
  required bool gstEnabled,
  required num gstRate,
  LocalDiscount discount = LocalDiscount.none,
}) {
  final subTotal = orderItemsSum(order);
  final rate = gstEnabled ? gstRate.toDouble() : 0.0;
  final total = fix2(subTotal + subTotal * rate / 100);
  final value = discount.numeric;

  PickupBill base({String? error}) => PickupBill(
      subTotal: subTotal, gstRate: rate, total: total, finalAmount: total, error: error);
  PickupBill discounted(double amount) => PickupBill(
      subTotal: subTotal,
      gstRate: rate,
      total: total,
      discountAmount: amount,
      finalAmount: fix2(total - amount));

  if (discount.isEmpty) return base();
  if (discount.type == discountPercentage) {
    if (value > 100) return base(error: 'Cannot exceed 100%');
    return discounted(fix2(total * value / 100));
  }
  if (value > total) return base(error: 'Cannot exceed bill amount');
  return discounted(fix2(value));
}

/// The discount the backend saved on an order: `{type, value, amount}`.
String orderDiscountType(dynamic order) =>
    _discountTypeOf(order is Map && order['discount'] is Map ? order['discount']['type'] : null);

double orderDiscountAmount(dynamic order) =>
    order is Map && order['discount'] is Map ? numOf(order['discount']['amount']) : 0;

/// "10% off" / "Flat ₹50 off"
String discountLabel(dynamic discount) {
  if (discount is! Map) return '';
  final value = numOf(discount['value']);
  switch (_discountTypeOf(discount['type'])) {
    case discountPercentage:
      return '${inr(value)}% off';
    case discountFixed:
      return 'Flat ₹${inr(value)} off';
    default:
      return '';
  }
}

/// Payable of a Pay Later order. Uses finalAmount whenever a discount
/// exists, so a 100% discount stays 0; old and game orders have no
/// finalAmount and fall back to the item sum.
double payLaterOrderTotal(dynamic order) {
  final finalAmount = order is Map ? numOf(order['finalAmount']) : 0.0;
  if (orderDiscountType(order) != discountNone) return finalAmount;
  return finalAmount > 0 ? finalAmount : orderItemsSum(order);
}

/// Website groupedPayLaterOrders: one group per customer name (trimmed,
/// case-insensitive), in first-seen order, newest order first inside.
/// Each order gets its `orderTotal`; each group carries totalBill (net of
/// discount), totalPaid, totalOwed, totalDiscount and billBeforeDiscount.
List<Map<String, dynamic>> groupPayLaterOrders(List<dynamic> payLaterOrders) {
  final groups = <String, Map<String, dynamic>>{};
  for (final order in payLaterOrders) {
    if (order is! Map) continue;
    final name = order['customerName']?.toString().trim() ?? '';
    final rawName = name.isEmpty ? 'Guest' : name;
    final group = groups.putIfAbsent(rawName.toLowerCase(), () => {
          'customerName': rawName,
          'orders': <dynamic>[],
          'totalBill': 0.0,
          'totalPaid': 0.0,
          'totalOwed': 0.0,
          'totalDiscount': 0.0,
          'billBeforeDiscount': 0.0,
        });

    final orderTotal = payLaterOrderTotal(order);
    final partial = order['partialPayment'];
    final paid = partial is Map ? numOf(partial['paidNow']) : 0.0;
    final discount = orderDiscountAmount(order);

    (group['orders'] as List).add({...order, 'orderTotal': orderTotal});
    group['totalBill'] += orderTotal;
    group['totalPaid'] += paid;
    group['totalOwed'] += math.max(0.0, orderTotal - paid);
    group['totalDiscount'] += discount;
    group['billBeforeDiscount'] += orderTotal + discount;
  }

  DateTime createdAt(dynamic o) =>
      DateTime.tryParse(o['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

  for (final group in groups.values) {
    (group['orders'] as List).sort((a, b) => createdAt(b).compareTo(createdAt(a)));
    for (final key in ['totalBill', 'totalPaid', 'totalOwed', 'totalDiscount', 'billBeforeDiscount']) {
      group[key] = fix2(group[key] as double);
    }
  }
  return groups.values.toList();
}
