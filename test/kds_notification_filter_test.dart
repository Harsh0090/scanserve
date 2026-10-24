import 'package:flutter_test/flutter_test.dart';
import 'package:ScanServe/src/services/kds_notification_filter.dart';

void main() {
  Map<String, dynamic> item(String name, {bool skip = false, String? addedAt, String? lastAddedAt}) => {
        'name': name,
        'quantity': 1,
        'skipKitchen': skip,
        if (addedAt != null) 'addedAt': addedAt,
        if (lastAddedAt != null) 'lastAddedAt': lastAddedAt,
      };

  group('NEW order', () {
    test('rings when at least one item has KDS on', () {
      final order = {'items': [item('Paneer'), item('Coke', skip: true)]};
      expect(KdsNotificationFilter.shouldNotify(order, 'NEW'), isTrue);
    });

    test('silent when every item has KDS off', () {
      final order = {'items': [item('Coke', skip: true), item('Water', skip: true)]};
      expect(KdsNotificationFilter.shouldNotify(order, 'NEW'), isFalse);
    });

    test('missing skipKitchen counts as KDS on', () {
      final order = {'items': [{'name': 'Old item', 'quantity': 1}]};
      expect(KdsNotificationFilter.shouldNotify(order, 'NEW'), isTrue);
    });
  });

  group('UPDATE (items added)', () {
    const t0 = '2026-10-24T10:00:00.000Z';
    const t1 = '2026-10-24T10:20:00.000Z';
    const t1b = '2026-10-24T10:20:00.040Z';

    test('silent when only KDS-off items were added', () {
      final order = {'items': [item('Paneer', addedAt: t0), item('Coke', skip: true, addedAt: t1)]};
      expect(KdsNotificationFilter.shouldNotify(order, 'UPDATE'), isFalse);
    });

    test('rings when a KDS-on item was added', () {
      final order = {
        'items': [item('Coke', skip: true, addedAt: t0), item('Naan', addedAt: t1), item('Water', skip: true, addedAt: t1b)],
      };
      expect(KdsNotificationFilter.shouldNotify(order, 'UPDATE'), isTrue);
    });

    test('quantity bump on an existing KDS-on line rings', () {
      final order = {'items': [item('Paneer', addedAt: t0, lastAddedAt: t1), item('Coke', skip: true, addedAt: t0)]};
      expect(KdsNotificationFilter.shouldNotify(order, 'UPDATE'), isTrue);
    });

    test('quantity bump on an existing KDS-off line is silent', () {
      final order = {'items': [item('Paneer', addedAt: t0), item('Coke', skip: true, addedAt: t0, lastAddedAt: t1)]};
      expect(KdsNotificationFilter.shouldNotify(order, 'UPDATE'), isFalse);
    });

    test('prefers explicit newItems / silent when present', () {
      expect(
        KdsNotificationFilter.shouldNotify({'items': [item('Paneer')], 'newItems': [item('Coke', skip: true)]}, 'UPDATE'),
        isFalse,
      );
      expect(KdsNotificationFilter.shouldNotify({'items': [item('Paneer')], 'silent': true}, 'UPDATE'), isFalse);
    });

    test('no timestamps → falls back to whole order', () {
      expect(KdsNotificationFilter.shouldNotify({'items': [item('Paneer'), item('Coke', skip: true)]}, 'UPDATE'), isTrue);
    });
  });

  test('READY follows the whole-order rule', () {
    expect(KdsNotificationFilter.shouldNotify({'items': [item('Coke', skip: true)]}, 'READY'), isFalse);
    expect(KdsNotificationFilter.shouldNotify({'items': [item('Paneer')]}, 'READY'), isTrue);
  });

  test('fails open when the order is unknown or malformed', () {
    expect(KdsNotificationFilter.shouldNotify(null, 'NEW'), isTrue);
    expect(KdsNotificationFilter.shouldNotify({'items': []}, 'NEW'), isTrue);
    expect(KdsNotificationFilter.shouldNotify({'items': 'oops'}, 'UPDATE'), isTrue);
  });
}
