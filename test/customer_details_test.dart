import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ScanServe/src/app/components/customer_details.dart';
import 'package:ScanServe/src/utils/apiClient.dart';

/// Answers GET /api/orders/customers/suggest without the network.
class FakeSuggestApi extends Interceptor {
  final List<String> queries = [];
  bool fail = false;
  List<Map<String, dynamic>> rows = [];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    queries.add(options.queryParameters['q'].toString());
    if (fail) {
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options,
          statusCode: 401,
          data: {'message': 'Not authenticated'},
        ),
      ));
      return;
    }
    handler.resolve(Response(requestOptions: options, statusCode: 200, data: rows));
  }
}

void main() {
  late FakeSuggestApi api;

  setUp(() {
    api = FakeSuggestApi()
      ..rows = [
        {'name': 'Harsh Kumawat', 'phone': '9876543210', 'orderCount': 7},
        {'name': 'Harshit', 'phone': null, 'orderCount': 2},
      ];
    dioClient.interceptors.add(api);
  });

  tearDown(() => dioClient.interceptors.remove(api));

  group('order helpers', () {
    test('realCustomerName hides empty and placeholder names', () {
      expect(realCustomerName({'customerName': ' Harsh '}), 'Harsh');
      expect(realCustomerName({'customerName': 'Guest'}), isNull);
      expect(realCustomerName({'customerName': 'NA'}), isNull);
      expect(realCustomerName({'customerName': ''}), isNull);
      expect(realCustomerName({'customerName': null}), isNull);
      expect(realCustomerName(null), isNull);
    });

    test('isPickupOrder is true only without a table number', () {
      expect(isPickupOrder({'tableNumber': null}), isTrue);
      expect(isPickupOrder({'tableNumber': ''}), isTrue);
      expect(isPickupOrder({}), isTrue);
      expect(isPickupOrder({'tableNumber': '5'}), isFalse);
      expect(isPickupOrder({'tableNumber': 5}), isFalse);
    });

    test('orTextFallback treats null and empty alike', () {
      expect(orTextFallback(null, 'Guest'), 'Guest');
      expect(orTextFallback('  ', 'Guest'), 'Guest');
      expect(orTextFallback('Rahul', 'Guest'), 'Rahul');
    });

    test('CustomerSuggestion.fromJson maps a missing phone to null', () {
      final c = CustomerSuggestion.fromJson({'name': 'A', 'phone': '', 'orderCount': 3});
      expect(c.phone, isNull);
      expect(c.orderCount, 3);
    });
  });

  group('CustomerSuggestController', () {
    testWidgets('one character sends no request', (tester) async {
      final c = CustomerSuggestController();
      c.onQueryChanged('h');
      await tester.pump(const Duration(milliseconds: 400));
      expect(api.queries, isEmpty);
      expect(c.items, isEmpty);
      c.dispose();
    });

    testWidgets('fast typing sends one trimmed request after 250 ms', (tester) async {
      final c = CustomerSuggestController();
      for (final q in ['ha', 'har', 'hars', 'harsh ']) {
        c.onQueryChanged(q);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(api.queries, isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      expect(api.queries, ['harsh']);
      expect(c.items.map((e) => e.name), ['Harsh Kumawat', 'Harshit']);
      c.dispose();
    });

    testWidgets('a failed request clears the list without throwing', (tester) async {
      final c = CustomerSuggestController();
      c.onQueryChanged('ha');
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.items, hasLength(2));

      api.fail = true;
      c.onQueryChanged('har');
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.items, isEmpty);
      c.dispose();
    });

    testWidgets('going back under 2 characters clears the list', (tester) async {
      final c = CustomerSuggestController();
      c.onQueryChanged('ha');
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.items, isNotEmpty);
      c.onQueryChanged('h');
      expect(c.items, isEmpty);
      c.dispose();
    });
  });

  group('CustomerSuggestField', () {
    late List<CustomerSuggestion> picks;

    /// Pumps the field and types "har" so the dropdown opens.
    Future<void> pumpField(WidgetTester tester, TextEditingController ctrl) async {
      picks = [];
      await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(402, 885),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: CustomerSuggestField(
                controller: ctrl,
                onSelected: (c) {
                  picks.add(c);
                  ctrl.text = c.name;
                },
              ),
            ),
          ),
        ),
      ));
      await tester.enterText(find.byType(TextField), 'har');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
    }

    testWidgets('shows rows with phone and order count, and a tap picks one', (tester) async {
      final ctrl = TextEditingController();
      await pumpField(tester, ctrl);

      expect(find.text('HARSH KUMAWAT'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('7 orders'), findsOneWidget);
      expect(find.text('2 orders'), findsOneWidget);

      await tester.tap(find.text('HARSH KUMAWAT'));
      await tester.pump();
      expect(picks.single.name, 'Harsh Kumawat');
      expect(picks.single.phone, '9876543210');
      expect(ctrl.text, 'Harsh Kumawat');
      expect(find.text('7 orders'), findsNothing);
      // The pick sets the text programmatically: no extra request.
      await tester.pump(const Duration(milliseconds: 300));
      expect(api.queries, ['har']);
      ctrl.dispose();
    });

    testWidgets('dropdown hides when the request fails', (tester) async {
      final ctrl = TextEditingController();
      await pumpField(tester, ctrl);
      expect(find.text('7 orders'), findsOneWidget);

      api.fail = true;
      await tester.enterText(find.byType(TextField), 'harsh');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('7 orders'), findsNothing);
      ctrl.dispose();
    });
  });
}
