import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ScanServe/src/services/firebase_messaging_service.dart';
import 'package:ScanServe/src/services/order_alarm_service.dart';
import 'package:ScanServe/src/utils/apiClient.dart';

/// End-to-end: FCM push → FirebaseMessagingService.showNotificationInternal →
/// KDS filter (real apiFetch, faked HTTP) → OrderAlarmService (faked plugin).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> alarmCalls;
  late List<String> requests;
  Object? liveOrders; // response body, or an Exception to simulate failure

  setUpAll(() async {
    final tmp = await Directory.systemTemp.createTemp('kds_push_test');
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => tmp.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_foreground_task/methods'),
      (call) async {
        alarmCalls.add(call.method);
        // Report "running" once started so the plugin's state check completes.
        return call.method == 'isRunningService' ? alarmCalls.contains('startService') : null;
      },
    );
    OrderAlarmService.init(); // main.dart does this at startup
    dioClient.interceptors.insert(
      0,
      InterceptorsWrapper(onRequest: (options, handler) {
        requests.add('${options.method} ${options.path}');
        if (liveOrders is Exception) {
          return handler.reject(DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 500, data: {'message': 'boom'}),
          ));
        }
        handler.resolve(Response(requestOptions: options, statusCode: 200, data: liveOrders));
      }),
    );
  });

  setUp(() {
    alarmCalls = [];
    requests = [];
    liveOrders = null;
  });

  Map<String, dynamic> item(String name, {bool skip = false, String addedAt = '2026-10-24T10:00:00.000Z', String? lastAddedAt}) => {
        'name': name,
        'quantity': 1,
        'skipKitchen': skip,
        'addedAt': addedAt,
        if (lastAddedAt != null) 'lastAddedAt': lastAddedAt,
      };

  void serve(List<Map<String, dynamic>> items, {String id = 'o1'}) => liveOrders = {
        'count': 1,
        'orders': [
          {'_id': id, 'status': 'PENDING', 'items': items},
        ],
      };

  Future<bool> push(String type, {String orderId = 'o1'}) async {
    await FirebaseMessagingService().showNotificationInternal(RemoteMessage(
      data: {'orderId': orderId, 'type': type},
      notification: const RemoteNotification(title: 'Order', body: '₹100 • 🪑 Table 5'),
    ));
    return alarmCalls.contains('startService');
  }

  group('NEW order push', () {
    test('all items KDS off → no alarm', () async {
      serve([item('Coke', skip: true), item('Water', skip: true)]);
      expect(await push('NEW'), isFalse);
      expect(requests, ['GET /api/admin/orders/live']);
    });

    test('one item KDS on → alarm rings', () async {
      serve([item('Paneer'), item('Coke', skip: true)]);
      expect(await push('NEW'), isTrue);
    });
  });

  group('UPDATE (items added) push', () {
    const later = '2026-10-24T10:30:00.000Z';

    test('only KDS-off items added → no alarm', () async {
      serve([item('Paneer'), item('Coke', skip: true, addedAt: later)]);
      expect(await push('UPDATE'), isFalse);
    });

    test('KDS-on item added → alarm rings', () async {
      serve([item('Coke', skip: true), item('Naan', addedAt: later)]);
      expect(await push('UPDATE'), isTrue);
    });

    test('more quantity of a KDS-on item → alarm rings', () async {
      serve([item('Paneer', lastAddedAt: later), item('Coke', skip: true)]);
      expect(await push('UPDATE'), isTrue);
    });
  });

  group('fails open', () {
    test('API error → alarm still rings', () async {
      liveOrders = Exception('server down');
      expect(await push('NEW'), isTrue);
    });

    test('order not in live list → alarm still rings', () async {
      serve([item('Coke', skip: true)], id: 'someone-else');
      expect(await push('NEW'), isTrue);
    });
  });
}
