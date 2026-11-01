import 'package:flutter_test/flutter_test.dart';
import 'package:ScanServe/src/services/auto_kot_print_service.dart';

class PrintCall {
  final String orderId;
  final List<dynamic> items;
  final bool isAddOn;
  final String? tableNumber;
  final bool bluetoothOnly;
  PrintCall(this.orderId, this.items, this.isAddOn, this.tableNumber,
      {this.bluetoothOnly = false});
}

void main() {
  late List<PrintCall> calls;
  late Map<String, dynamic> user;
  late Set<String> localPrinted;
  late AutoKotPrintManager manager;
  bool failPrint = false;
  String? lastError;
  // No thermal printer paired to this device unless a test says otherwise.
  bool localPrinterPaired = false;

  const grace = Duration(milliseconds: 20);

  setUp(() {
    calls = [];
    user = {'restaurantId': 'r1', 'liveOrderKOT': true};
    localPrinted = {};
    failPrint = false;
    lastError = null;
    localPrinterPaired = false;
    manager = AutoKotPrintManager(
      readUser: () => user,
      isLocallyPrinted: localPrinted.contains,
      hasLocalPrinter: () async => localPrinterPaired,
      localPrintGrace: grace,
      dedupeWindow: const Duration(milliseconds: 200),
      onPrintError: (m) => lastError = m,
      printKOT: ({
        required String orderId,
        required List<dynamic> items,
        bool isAddOn = false,
        String? tableNumber,
        String? customerName,
        String? restaurantName,
        bool bluetoothOnly = false,
      }) async {
        if (failPrint) throw Exception('printer offline');
        calls.add(PrintCall(orderId, items, isAddOn, tableNumber,
            bluetoothOnly: bluetoothOnly));
      },
    );
  });

  Future<void> settle() => Future.delayed(grace * 3);

  Map<String, dynamic> order({
    String id = 'o1',
    List<Map<String, dynamic>>? items,
    Object? skipAutoPrint,
    String status = 'PENDING',
  }) =>
      {
        '_id': id,
        'tableNumber': 'T5',
        'status': status,
        'items': items ?? [
          {'item': {'branchName': 'Paneer'}, 'quantity': 2},
          {'item': {'branchName': 'Coke'}, 'quantity': 1, 'skipKitchen': true},
        ],
        if (skipAutoPrint != null) 'skipAutoPrint': skipAutoPrint,
      };

  group('handleNewOrder', () {
    test('liveOrderKOT ON → silently prints full order', () async {
      manager.handleNewOrder(order());
      await settle();
      expect(calls, hasLength(1));
      expect(calls.single.isAddOn, isFalse);
      expect(calls.single.orderId, 'o1');
      expect(calls.single.tableNumber, 'T5');
      expect(manager.wasAutoPrinted('o1'), isTrue);
    });

    test('accepts socket payload wrapped in a list', () async {
      manager.handleNewOrder([order()]);
      await settle();
      expect(calls, hasLength(1));
    });

    test('liveOrderKOT OFF → no print', () async {
      user['liveOrderKOT'] = false;
      manager.handleNewOrder(order());
      await settle();
      expect(calls, isEmpty);
    });

    test('reads liveOrderKOT from nested user.data', () async {
      user = {'data': {'restaurantId': 'r1', 'liveOrderKOT': true}};
      manager.handleNewOrder(order());
      await settle();
      expect(calls, hasLength(1));
    });

    test('skipAutoPrint == true overrides liveOrderKOT ON', () async {
      manager.handleNewOrder(order(skipAutoPrint: true));
      await settle();
      expect(calls, isEmpty);
    });

    // Live Menu orders: the backend stamps every socket payload with
    // skipAutoPrint: true once it has run its own PrintNode job. That job
    // never reaches a thermal printer paired to this device, so the local
    // ticket must still print — Bluetooth-only, so the backend PrintNode job
    // is not triggered a second time.
    test('skipAutoPrint == true still prints locally when a printer is paired here', () async {
      localPrinterPaired = true;
      manager.handleNewOrder(order(skipAutoPrint: true));
      await settle();
      expect(calls, hasLength(1));
      expect(calls.single.bluetoothOnly, isTrue);
    });

    test('local copy is not printed when liveOrderKOT is OFF', () async {
      localPrinterPaired = true;
      user['liveOrderKOT'] = false;
      manager.handleNewOrder(order(skipAutoPrint: true));
      await settle();
      expect(calls, isEmpty);
    });

    test('local copy still excludes KDS-off items', () async {
      localPrinterPaired = true;
      manager.handleNewOrder(order(skipAutoPrint: true, items: [
        {'item': 'tea', 'quantity': 1, 'skipKitchen': true},
      ]));
      await settle();
      expect(calls, isEmpty);
    });

    test('normal auto-print is not flagged Bluetooth-only', () async {
      manager.handleNewOrder(order());
      await settle();
      expect(calls.single.bluetoothOnly, isFalse);
    });

    test('skipAutoPrint == false forces print even with liveOrderKOT OFF', () async {
      user['liveOrderKOT'] = false;
      manager.handleNewOrder(order(skipAutoPrint: false));
      await settle();
      expect(calls, hasLength(1));
    });

    test('order with only skipKitchen items is not printed', () async {
      manager.handleNewOrder(order(items: [
        {'item': 'water', 'quantity': 1, 'skipKitchen': true},
      ]));
      await settle();
      expect(calls, isEmpty);
    });

    test('duplicate new_order events print once', () async {
      manager.handleNewOrder(order());
      manager.handleNewOrder(order());
      await settle();
      manager.handleNewOrder(order());
      await settle();
      expect(calls, hasLength(1));
    });

    test('different orders each print', () async {
      manager.handleNewOrder(order(id: 'a'));
      manager.handleNewOrder(order(id: 'b'));
      await settle();
      expect(calls.map((c) => c.orderId), ['a', 'b']);
    });

    test('skips order already printed locally (MenuModal) even if registered after the socket event', () async {
      manager.handleNewOrder(order());
      // HTTP response of POST /api/orders arrives after the socket event
      localPrinted.add('o1');
      await settle();
      expect(calls, isEmpty);
      expect(manager.wasAutoPrinted('o1'), isFalse);
    });

    test('ignores SERVED / CANCELLED orders', () async {
      manager.handleNewOrder(order(id: 'x', status: 'SERVED'));
      manager.handleNewOrder(order(id: 'y', status: 'CANCELLED'));
      await settle();
      expect(calls, isEmpty);
    });

    test('ignores malformed payloads', () async {
      manager.handleNewOrder(null);
      manager.handleNewOrder('oops');
      manager.handleNewOrder({'items': []});
      manager.handleNewOrder(<dynamic>[]);
      await settle();
      expect(calls, isEmpty);
    });

    test('print failure is reported, not thrown', () async {
      failPrint = true;
      manager.handleNewOrder(order());
      await settle();
      expect(lastError, contains('printer offline'));
    });
  });

  group('handleOrderModified (add-on)', () {
    Map<String, dynamic> modified({
      List<Map<String, dynamic>>? newItems,
      Object? skipAutoPrint,
      bool silent = false,
      String updatedAt = '2026-10-24T10:00:00Z',
    }) =>
        {
          '_id': 'o1',
          'type': 'ITEM_ADDED',
          'updatedAt': updatedAt,
          'items': [
            {'item': {'branchName': 'Paneer'}, 'quantity': 2},
            {'item': {'branchName': 'Naan'}, 'quantity': 3},
          ],
          'newItems': newItems ?? [
            {'item': {'branchName': 'Naan'}, 'quantity': 3},
          ],
          if (skipAutoPrint != null) 'skipAutoPrint': skipAutoPrint,
          if (silent) 'silent': true,
        };

    test('prints ONLY the new items as ADD-ON', () async {
      manager.handleOrderModified(modified());
      await settle();
      expect(calls, hasLength(1));
      expect(calls.single.isAddOn, isTrue);
      expect(calls.single.items, hasLength(1));
      expect((calls.single.items.single as Map)['item']['branchName'], 'Naan');
    });

    test('reuses table number from the earlier new_order', () async {
      manager.handleNewOrder(order(skipAutoPrint: true)); // not printed, but meta cached
      manager.handleOrderModified(modified());
      await settle();
      expect(calls.single.tableNumber, 'T5');
    });

    test('silent modification is ignored', () async {
      manager.handleOrderModified(modified(silent: true));
      await settle();
      expect(calls, isEmpty);
    });

    test('no newItems (e.g. status change) → no print', () async {
      manager.handleOrderModified({'_id': 'o1', 'status': 'ACCEPTED'});
      await settle();
      expect(calls, isEmpty);
    });

    test('only skipKitchen add-ons → no print', () async {
      manager.handleOrderModified(modified(newItems: [
        {'item': 'coke', 'quantity': 1, 'skipKitchen': true},
      ]));
      await settle();
      expect(calls, isEmpty);
    });

    test('liveOrderKOT OFF → no print; skipAutoPrint false → print', () async {
      user['liveOrderKOT'] = false;
      manager.handleOrderModified(modified());
      await settle();
      expect(calls, isEmpty);
      manager.handleOrderModified(modified(skipAutoPrint: false, updatedAt: 'later'));
      await settle();
      expect(calls, hasLength(1));
    });

    test('duplicate event prints once; a later add-on prints again', () async {
      manager.handleOrderModified(modified());
      manager.handleOrderModified(modified());
      await settle();
      manager.handleOrderModified(modified(updatedAt: '2026-10-24T10:05:00Z'));
      await settle();
      expect(calls, hasLength(2));
    });

    test('skips add-on already printed on this device by MenuModal', () async {
      localPrinted.add(AutoKotPrintManager.addOnLocalKey('o1'));
      manager.handleOrderModified(modified());
      await settle();
      expect(calls, isEmpty);
    });
  });

  group('helpers', () {
    test('restaurantIdOf handles all session shapes', () {
      expect(AutoKotPrintManager.restaurantIdOf(null), isNull);
      expect(AutoKotPrintManager.restaurantIdOf({'restaurantId': 'a'}), 'a');
      expect(AutoKotPrintManager.restaurantIdOf({'data': {'restaurantId': 'b'}}), 'b');
      expect(AutoKotPrintManager.restaurantIdOf({'restaurant': {'_id': 'c'}}), 'c');
      expect(AutoKotPrintManager.restaurantIdOf({'restaurant': 'd'}), 'd');
      expect(AutoKotPrintManager.restaurantIdOf({'name': 'x'}), isNull);
    });
  });
}
