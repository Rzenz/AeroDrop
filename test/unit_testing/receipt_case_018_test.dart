import 'package:aerodrop/core/services/delivery_fee_calculator.dart';
import 'package:aerodrop/features/orders/receipt_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Test Case ID: CASE-018', () {
    testWidgets(
      'Test Case Description: Customer opens the official receipt of a delivered UCLM Canteen order | '
      'Expected Result: Receipt lists Chicken Adobo Rice and Turon, the P23.19 delivery fee and TOTAL PAID P148.19',
      (tester) async {
        tester.view.physicalSize = const Size(600, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final receipt = ReceiptData(
          orderRef: '9664dc58-82f5-41a8-0000-000000000000',
          vendorName: 'UCLM Canteen',
          customerName: 'Maria Santos',
          lines: const [
            ReceiptLine(name: 'Chicken Adobo Rice', quantity: 1, unitPrice: 95.0),
            ReceiptLine(name: 'Turon (2 pcs)', quantity: 1, unitPrice: 30.0),
          ],
          subtotal: 125.0,
          deliveryFee: 23.19,
          feeBreakdown: DeliveryFeeBreakdown(baseFee: 15, distanceKm: 0, distanceFee: 0, weightKg: 0.54, weightFee: 5.4, weatherFee: 0, totalFee: 23.19, breakdownText: ''),
          total: 148.19,
          paymentLabel: 'GCash',
          placedAt: DateTime(2026, 11, 17, 8, 49),
          dropoffName: 'UCLM Maritime Building',
          orderStatus: 'Delivered',
        );

        await tester.pumpWidget(MaterialApp(home: ReceiptScreen(data: receipt)));
        await tester.pumpAndSettle();

        expect(find.text('CHICKEN ADOBO RICE'), findsOneWidget);
        expect(find.text('TURON (2 PCS)'), findsOneWidget);
        expect(find.text('₱23.19'), findsWidgets);
        expect(find.text('TOTAL PAID'), findsOneWidget);
        expect(find.text('₱148.19'), findsWidgets);
      },
    );
  });
}
