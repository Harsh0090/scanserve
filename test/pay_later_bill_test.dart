import 'package:flutter_test/flutter_test.dart';
import 'package:ScanServe/src/utils/pay_later_bill.dart';

Map<String, dynamic> _order(double itemsTotal, {Map? item}) => {
      '_id': 'o1',
      'items': [
        {'basePrice': itemsTotal, 'quantity': 1, 'item': ?item},
      ],
    };

PickupBill _bill(double items, {LocalDiscount d = LocalDiscount.none, bool gst = true}) =>
    calculatePickupBill(_order(items), gstEnabled: gst, gstRate: 5, discount: d);

void main() {
  group('calculatePickupBill', () {
    test('GST is added before any discount', () {
      final b = _bill(1000);
      expect(b.total, 1050);
      expect(b.finalAmount, 1050);
      expect(b.discountAmount, 0);
      expect(b.error, isNull);
    });

    test('10% off the GST-inclusive total', () {
      final b = _bill(1000, d: const LocalDiscount(type: discountPercentage, value: '10'));
      expect(b.total, 1050);
      expect(b.discountAmount, 105);
      expect(b.finalAmount, 945);
    });

    test('flat ₹50 off', () {
      final b = _bill(1000, d: const LocalDiscount(type: discountFixed, value: '50'));
      expect(b.discountAmount, 50);
      expect(b.finalAmount, 1000);
    });

    test('over 100% or over the bill is an error and leaves the bill as is', () {
      final pct = _bill(1000, d: const LocalDiscount(type: discountPercentage, value: '150'));
      expect(pct.error, 'Cannot exceed 100%');
      expect(pct.finalAmount, 1050);
      final flat = _bill(1000, d: const LocalDiscount(type: discountFixed, value: '2000'));
      expect(flat.error, 'Cannot exceed bill amount');
      expect(flat.discountAmount, 0);
    });

    test('GST off', () {
      final b = _bill(1000, gst: false, d: const LocalDiscount(type: discountPercentage, value: '10'));
      expect(b.gstRate, 0);
      expect(b.total, 1000);
      expect(b.finalAmount, 900);
    });

    test('a type with no value, or an empty draft, is no discount', () {
      expect(_bill(1000, d: const LocalDiscount(type: discountPercentage)).finalAmount, 1050);
      expect(_bill(1000, d: const LocalDiscount(type: discountFixed, value: '0')).finalAmount, 1050);
    });

    test('populated menu branchPrice wins over basePrice; 0 falls back', () {
      expect(orderItemsSum(_order(100, item: {'branchPrice': 120})), 120);
      expect(orderItemsSum(_order(100, item: {'branchPrice': 0})), 100);
      expect(orderItemsSum(_order(100)), 100);
    });
  });

  group('LocalDiscount', () {
    test('round-trips through the website storage shape', () {
      const d = LocalDiscount(type: discountFixed, value: '50');
      final back = LocalDiscount.fromJson(d.toJson());
      expect(back.type, discountFixed);
      expect(back.value, '50');
      expect(LocalDiscount.fromJson({'type': 'BOGUS', 'value': '5'}).isEmpty, isTrue);
      expect(LocalDiscount.fromJson(null).isEmpty, isTrue);
    });
  });

  group('Pay Later', () {
    // Worked example from the plan: one customer, two orders.
    final orderA = {
      '_id': 'aaaa',
      'customerName': 'Rahul',
      'createdAt': '2026-10-26T14:15:00Z',
      'items': [
        {'basePrice': 1000, 'quantity': 1, 'item': 'id1'},
      ],
      'discount': {'type': 'PERCENTAGE', 'value': 10, 'amount': 105},
      'finalAmount': 945,
      'partialPayment': {'paidNow': 200, 'remaining': 745},
    };
    final orderB = {
      '_id': 'bbbb',
      'customerName': ' rahul',
      'createdAt': '2026-10-26T15:00:00Z',
      'items': [
        {'basePrice': 300, 'quantity': 1, 'item': 'id2'},
      ],
      'discount': {'type': 'NONE', 'value': 0, 'amount': 0},
      'finalAmount': 315,
      'partialPayment': {'paidNow': 0, 'remaining': 315},
    };

    test('groups names case- and space-insensitively and totals add up', () {
      final groups = groupPayLaterOrders([orderA, orderB]);
      expect(groups, hasLength(1));
      final g = groups.single;
      expect(g['customerName'], 'Rahul');
      expect(g['billBeforeDiscount'], 1365);
      expect(g['totalDiscount'], 105);
      expect(g['totalBill'], 1260);
      expect(g['totalPaid'], 200);
      expect(g['totalOwed'], 1060);
      final orders = g['orders'] as List;
      expect(orders.map((o) => o['_id']), ['bbbb', 'aaaa']); // newest first
      expect(orders.last['orderTotal'], 945);
    });

    test('100% discount keeps the order total at 0', () {
      expect(
        payLaterOrderTotal({
          'items': [
            {'basePrice': 500, 'quantity': 1},
          ],
          'discount': {'type': 'PERCENTAGE', 'value': 100, 'amount': 525},
          'finalAmount': 0,
        }),
        0,
      );
    });

    test('old orders with no discount and no finalAmount use the item sum', () {
      expect(
        payLaterOrderTotal({
          'items': [
            {'basePrice': 250, 'quantity': 2},
          ],
          'finalAmount': 0,
        }),
        500,
      );
    });

    test('blank names group as Guest', () {
      final g = groupPayLaterOrders([
        {'_id': 'x', 'customerName': '  ', 'items': []},
        {'_id': 'y', 'items': []},
      ]);
      expect(g.single['customerName'], 'Guest');
      expect((g.single['orders'] as List), hasLength(2));
    });
  });

  test('discountLabel', () {
    expect(discountLabel({'type': 'PERCENTAGE', 'value': 10}), '10% off');
    expect(discountLabel({'type': 'FIXED', 'value': 50}), 'Flat ₹50 off');
    expect(discountLabel({'type': 'NONE', 'value': 0}), '');
    expect(discountLabel(null), '');
  });

  test('inr uses Indian grouping and at most 2 decimals', () {
    expect(inr(1365), '1,365');
    expect(inr(126000), '1,26,000');
    expect(inr(12345678.5), '1,23,45,678.5');
    expect(inr(945.5), '945.5');
    expect(inr(744.999999), '745');
    expect(inr(0), '0');
    expect(inr(-105), '-105');
  });
}
