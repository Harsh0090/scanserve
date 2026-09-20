import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/apiClient.dart';

import 'bluetooth_printer_service.dart';

/// Single item within a KOT order
class OrderItem {
  final dynamic item; // String _id or Map with {_id, branchName, branchPrice}
  final int quantity;
  final bool skipKitchen;
  final num? basePrice;
  final String? name;

  OrderItem({
    required this.item,
    required this.quantity,
    this.skipKitchen = false,
    this.basePrice,
    this.name,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      item: json['item'],
      quantity: (json['quantity'] is num) ? (json['quantity'] as num).toInt() : 1,
      skipKitchen: json['skipKitchen'] == true,
      basePrice: json['basePrice'] is num ? json['basePrice'] as num : null,
      name: json['name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item': item,
      'quantity': quantity,
      'skipKitchen': skipKitchen,
      if (basePrice != null) 'basePrice': basePrice,
      if (name != null) 'name': name,
    };
  }
}

/// Service handling KOT printing, Bill printing, and Printer Settings
class KotPrintService {
  final Dio _dio;
  final BluetoothPrinterService _btService;

  KotPrintService({Dio? dio, BluetoothPrinterService? btService})
      : _dio = dio ?? dioClient,
        _btService = btService ?? BluetoothPrinterService();

  /// Core print function for Kitchen Order Ticket
  ///
  /// Filters out items where [skipKitchen == true]. If no kitchen items remain,
  /// returns early without calling any print service.
  ///
  /// Checks for configured Bluetooth printer first (direct zero-dependency print).
  /// If no Bluetooth printer is configured or direct print fails, falls back
  /// seamlessly to backend PrintNode API.
  Future<void> printKOT({
    required String orderId,
    required List<dynamic> items,
    bool isAddOn = false,
    String? tableNumber,
    String? customerName,
    String? restaurantName,
  }) async {
    // Step 1: Normalize items and filter out skipKitchen == true
    final List<Map<String, dynamic>> kitchenItems = [];

    for (final raw in items) {
      if (raw is OrderItem) {
        if (!raw.skipKitchen) {
          kitchenItems.add(raw.toJson());
        }
      } else if (raw is Map<String, dynamic>) {
        if (raw['skipKitchen'] != true) {
          kitchenItems.add(Map<String, dynamic>.from(raw));
        }
      } else if (raw is Map) {
        if (raw['skipKitchen'] != true) {
          kitchenItems.add(Map<String, dynamic>.from(raw));
        }
      }
    }

    if (kitchenItems.isEmpty) {
      debugPrint("ℹ️ KotPrintService: No kitchen items to print (all skipped or empty).");
      return; // Nothing to print
    }

    // Step 2: Try Direct Bluetooth Thermal Print first
    final hasBt = await _btService.hasConfiguredPrinter();
    if (hasBt) {
      debugPrint("🖨️ KotPrintService: Attempting Direct Bluetooth KOT print for order $orderId...");
      try {
        final btSuccess = await _btService.printKOTDirect(
          orderId: orderId,
          items: kitchenItems,
          isAddOn: isAddOn,
          tableNumber: tableNumber,
          customerName: customerName,
          restaurantName: restaurantName,
        );
        if (btSuccess) {
          debugPrint("✅ KotPrintService: Direct Bluetooth KOT printed successfully.");
          return;
        } else {
          debugPrint("⚠️ KotPrintService: Direct Bluetooth print unsuccessful, falling back to backend...");
        }
      } catch (e) {
        debugPrint("⚠️ KotPrintService: Bluetooth print error ($e), falling back to backend...");
      }
    }

    debugPrint(
      "🖨️ KotPrintService: Sending KOT print to backend for order $orderId (${kitchenItems.length} items, isAddOn: $isAddOn)...",
    );

    // Step 3: Call backend API (PrintNode fallback)
    try {
      final response = await _dio.post(
        '/api/print/kot',
        data: {
          'orderId': orderId,
          'isAddOn': isAddOn,
          'items': kitchenItems,
        },
      );

      if (response.statusCode != 200) {
        final message = (response.data is Map)
            ? response.data['message'] ?? 'KOT print failed'
            : 'KOT print failed';
        throw Exception(message);
      }

      debugPrint("✅ KotPrintService: Backend KOT printed successfully.");
    } on DioException catch (e) {
      final serverMsg = e.response?.data is Map
          ? e.response?.data['message']
          : null;
      throw Exception(serverMsg ?? e.message ?? 'KOT print failed');
    } catch (e) {
      debugPrint("❌ KotPrintService Error: $e");
      rethrow;
    }
  }

  /// Print customer receipt/bill
  Future<void> printBill({required Map<String, dynamic> bill}) async {
    // Try Direct Bluetooth Print first
    final hasBt = await _btService.hasConfiguredPrinter();
    if (hasBt) {
      try {
        final btSuccess = await _btService.printBillDirect(bill);
        if (btSuccess) {
          debugPrint("✅ KotPrintService: Direct Bluetooth Bill printed successfully.");
          return;
        }
      } catch (e) {
        debugPrint("⚠️ Direct Bluetooth bill print error ($e), falling back to backend...");
      }
    }

    try {
      final response = await _dio.post(
        '/api/print/bill',
        data: {'bill': bill},
      );

      if (response.statusCode != 200) {
        final message = (response.data is Map)
            ? response.data['message'] ?? 'Bill print failed'
            : 'Bill print failed';
        throw Exception(message);
      }

      debugPrint("✅ KotPrintService: Bill printed successfully via backend.");
    } on DioException catch (e) {
      final serverMsg = e.response?.data is Map
          ? e.response?.data['message']
          : null;
      throw Exception(serverMsg ?? e.message ?? 'Bill print failed');
    } catch (e) {
      debugPrint("❌ KotPrintService Bill Error: $e");
      rethrow;
    }
  }

  /// Fetch list of printers available in PrintNode
  Future<List<Map<String, dynamic>>> getPrinters() async {
    try {
      final response = await _dio.get('/api/print/printers');
      if (response.statusCode == 200 && response.data is Map) {
        final rawPrinters = response.data['printers'];
        if (rawPrinters is List) {
          return rawPrinters
              .map((p) => (p is Map) ? Map<String, dynamic>.from(p) : <String, dynamic>{})
              .toList();
        }
      }
      return [];
    } on DioException catch (e) {
      final serverMsg = e.response?.data is Map ? e.response?.data['message'] : null;
      throw Exception(serverMsg ?? e.message ?? 'Failed to list printers');
    } catch (e) {
      debugPrint("❌ KotPrintService getPrinters Error: $e");
      rethrow;
    }
  }

  /// Save printer settings to user account
  Future<void> updatePrinterSettings({
    bool? autoPrintKOT,
    bool? autoPrintBill,
    bool? liveOrderKOT,
    String? printerName,
    int? printNodePrinterId,
  }) async {
    final Map<String, dynamic> data = {};
    if (autoPrintKOT != null) data['autoPrintKOT'] = autoPrintKOT;
    if (autoPrintBill != null) data['autoPrintBill'] = autoPrintBill;
    if (liveOrderKOT != null) data['liveOrderKOT'] = liveOrderKOT;
    if (printerName != null) data['printerName'] = printerName;
    if (printNodePrinterId != null) {
      data['printNodePrinterId'] = printNodePrinterId;
    }

    try {
      final response = await _dio.patch(
        '/api/auth/update-printer-settings',
        data: data,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        final message = (response.data is Map)
            ? response.data['message'] ?? 'Failed to update printer settings'
            : 'Failed to update printer settings';
        throw Exception(message);
      }

      debugPrint("✅ KotPrintService: Printer settings updated.");
    } on DioException catch (e) {
      final serverMsg = e.response?.data is Map ? e.response?.data['message'] : null;
      throw Exception(serverMsg ?? e.message ?? 'Failed to update printer settings');
    } catch (e) {
      debugPrint("❌ KotPrintService updatePrinterSettings Error: $e");
      rethrow;
    }
  }
}

/// Riverpod Provider for KotPrintService
final kotPrintServiceProvider = Provider<KotPrintService>((ref) {
  final btService = ref.watch(bluetoothPrinterServiceProvider);
  return KotPrintService(btService: btService);
});

/// Tracks order IDs that were already printed locally by this client.
/// The socket handler checks this set to avoid printing a KOT twice when
/// the backend echoes back a new_order event for an order the user just placed.
final locallyPrintedOrderIds = StateProvider<Set<String>>((ref) => {});
