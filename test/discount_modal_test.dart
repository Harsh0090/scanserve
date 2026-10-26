import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ScanServe/src/app/dashboard/orders/page.dart';
import 'package:ScanServe/src/utils/pay_later_bill.dart';

/// ₹1,000 of items, GST 5% → bill ₹1,050.
final _order = {
  '_id': 'o1',
  'items': [
    {'basePrice': 1000, 'quantity': 1},
  ],
};

void main() {
  LocalDiscount? applied;
  bool removed = false;

  Future<void> pumpModal(WidgetTester tester, {LocalDiscount initial = LocalDiscount.none}) async {
    applied = null;
    removed = false;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(402, 885),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: DiscountModalWidget(
            initial: initial,
            billFor: (d) => calculatePickupBill(_order, gstEnabled: true, gstRate: 5, discount: d),
            onApply: (d) => applied = d,
            onRemove: () => removed = true,
          ),
        ),
      ),
    ));
  }

  ElevatedButton applyButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'APPLY'));

  testWidgets('a 10% chip previews Bill / Discount / Payable and applies', (tester) async {
    await pumpModal(tester);
    expect(find.text('BILL: ₹1,050 (INCL. GST 5%)'), findsOneWidget);

    await tester.tap(find.text('% OFF'));
    await tester.pump();
    await tester.tap(find.text('10%'));
    await tester.pump();

    expect(find.text('- ₹105'), findsOneWidget);
    expect(find.text('₹945'), findsOneWidget);
    await tester.tap(find.text('APPLY'));
    expect(applied?.type, discountPercentage);
    expect(applied?.value, '10');
  });

  testWidgets('over 100% shows the error and disables Apply', (tester) async {
    await pumpModal(tester);
    await tester.tap(find.text('% OFF'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '150');
    await tester.pump();

    expect(find.text('Cannot exceed 100%'), findsOneWidget);
    expect(applyButton(tester).onPressed, isNull);
  });

  testWidgets('switching type clears the value; Remove reports removal', (tester) async {
    await pumpModal(tester, initial: const LocalDiscount(type: discountFixed, value: '50'));
    expect(find.text('- ₹50'), findsOneWidget);

    await tester.tap(find.text('% OFF'));
    await tester.pump();
    expect(find.text('- ₹0'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);

    await tester.tap(find.text('REMOVE'));
    expect(removed, isTrue);
    expect(applied, isNull);
  });

  testWidgets('the field rejects minus signs and letters', (tester) async {
    await pumpModal(tester);
    await tester.tap(find.text('₹ OFF'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '-5a');
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });
}
