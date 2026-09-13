import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ScanServe/src/services/kot_print_service.dart';
import 'package:ScanServe/src/services/bluetooth_printer_service.dart';

class MockHttpClientAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;
  dynamic responseData;
  int statusCode = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      responseData ?? '{"success": true}',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class MockBluetoothPrinterService extends BluetoothPrinterService {
  bool isPrintKOTCalled = false;
  bool isPrintBillCalled = false;
  bool hasConfigured = false;

  @override
  Future<bool> hasConfiguredPrinter() async => hasConfigured;

  @override
  Future<bool> printKOTDirect({
    required String orderId,
    required List<dynamic> items,
    bool isAddOn = false,
    String? tableNumber,
    String? customerName,
    String? restaurantName,
  }) async {
    isPrintKOTCalled = true;
    return true;
  }

  @override
  Future<bool> printBillDirect(Map<String, dynamic> bill) async {
    isPrintBillCalled = true;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KotPrintService Tests', () {
    late Dio dio;
    late MockHttpClientAdapter mockAdapter;
    late KotPrintService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      dio = Dio(BaseOptions(baseUrl: 'https://scanserve.in'));
      mockAdapter = MockHttpClientAdapter();
      dio.httpClientAdapter = mockAdapter;
      service = KotPrintService(dio: dio);
    });

    test('printKOT skips API call if all items have skipKitchen == true', () async {
      final items = [
        {'item': 'item1', 'quantity': 2, 'skipKitchen': true},
        {'item': 'item2', 'quantity': 1, 'skipKitchen': true},
      ];

      await service.printKOT(orderId: 'ord123', items: items, isAddOn: false);

      expect(mockAdapter.lastRequest, isNull);
    });

    test('printKOT filters out skipKitchen items and calls POST /api/print/kot', () async {
      mockAdapter.responseData = '{"success": true, "message": "KOT printed"}';

      final items = [
        {
          'item': {'_id': 'item1', 'branchName': 'Burger', 'branchPrice': 150},
          'quantity': 2,
          'skipKitchen': false,
        },
        {
          'item': {'_id': 'item2', 'branchName': 'Coke', 'branchPrice': 50},
          'quantity': 1,
          'skipKitchen': true,
        },
      ];

      await service.printKOT(orderId: 'ord123', items: items, isAddOn: true);

      expect(mockAdapter.lastRequest, isNotNull);
      expect(mockAdapter.lastRequest!.path, '/api/print/kot');
      expect(mockAdapter.lastRequest!.method, 'POST');

      final data = mockAdapter.lastRequest!.data as Map;
      expect(data['orderId'], 'ord123');
      expect(data['isAddOn'], true);
      expect(data['items'], hasLength(1));
      expect(data['items'][0]['item']['branchName'], 'Burger');
      expect(data['items'][0]['quantity'], 2);
    });

    test('printBill calls POST /api/print/bill', () async {
      mockAdapter.responseData = '{"success": true}';

      final bill = {
        'tableNumber': 'T-1',
        'total': 500,
        'items': [
          {'name': 'Pizza', 'quantity': 1, 'basePrice': 500}
        ]
      };

      await service.printBill(bill: bill);

      expect(mockAdapter.lastRequest, isNotNull);
      expect(mockAdapter.lastRequest!.path, '/api/print/bill');
      expect(mockAdapter.lastRequest!.method, 'POST');
      expect((mockAdapter.lastRequest!.data as Map)['bill']['tableNumber'], 'T-1');
    });

    test('getPrinters calls GET /api/print/printers and returns list', () async {
      mockAdapter.responseData = '''
      {
        "printers": [
          {"id": 101, "name": "CPENSUS Thermal 58mm"},
          {"id": 102, "name": "Kitchen POS-80"}
        ]
      }
      ''';

      final printers = await service.getPrinters();

      expect(mockAdapter.lastRequest, isNotNull);
      expect(mockAdapter.lastRequest!.path, '/api/print/printers');
      expect(mockAdapter.lastRequest!.method, 'GET');
      expect(printers, hasLength(2));
      expect(printers[0]['name'], 'CPENSUS Thermal 58mm');
      expect(printers[0]['id'], 101);
    });

    test('updatePrinterSettings calls PATCH /api/auth/update-printer-settings', () async {
      mockAdapter.responseData = '{"success": true}';

      await service.updatePrinterSettings(
        liveOrderKOT: true,
        autoPrintKOT: false,
        autoPrintBill: true,
        printNodePrinterId: 101,
      );

      expect(mockAdapter.lastRequest, isNotNull);
      expect(mockAdapter.lastRequest!.path, '/api/auth/update-printer-settings');
      expect(mockAdapter.lastRequest!.method, 'PATCH');

      final data = mockAdapter.lastRequest!.data as Map;
      expect(data['liveOrderKOT'], true);
      expect(data['autoPrintKOT'], false);
      expect(data['autoPrintBill'], true);
      expect(data['printNodePrinterId'], 101);
    });

    test('printKOT prints directly via Bluetooth when configured (zero 3rd party backend call)', () async {
      final mockBt = MockBluetoothPrinterService();
      mockBt.hasConfigured = true;
      final btService = KotPrintService(dio: dio, btService: mockBt);

      final items = [
        {
          'item': {'_id': 'item1', 'branchName': 'Biryani', 'branchPrice': 250},
          'quantity': 2,
          'skipKitchen': false,
        }
      ];

      await btService.printKOT(
        orderId: 'bt123',
        items: items,
        tableNumber: 'Table 5',
        customerName: 'Aman',
        restaurantName: 'The Spice House',
      );

      expect(mockBt.isPrintKOTCalled, isTrue);
      // Ensure backend API was NOT called because direct Bluetooth handled it!
      expect(mockAdapter.lastRequest, isNull);
    });

    test('printBill prints directly via Bluetooth when configured', () async {
      final mockBt = MockBluetoothPrinterService();
      mockBt.hasConfigured = true;
      final btService = KotPrintService(dio: dio, btService: mockBt);

      final bill = {
        'restaurantName': 'The Spice House',
        'tableNumber': 'Table 5',
        'items': [
          {'name': 'Biryani', 'quantity': 2, 'basePrice': 250}
        ],
        'total': 500,
      };

      await btService.printBill(bill: bill);

      expect(mockBt.isPrintBillCalled, isTrue);
      expect(mockAdapter.lastRequest, isNull);
    });
  });
}
