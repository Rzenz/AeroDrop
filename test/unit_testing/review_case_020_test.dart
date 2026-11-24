import 'package:aerodrop/core/models/order_model.dart';
import 'package:aerodrop/features/orders/widgets/order_review_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-020', () {
    testWidgets(
      'Test Case Description: Customer taps Submit Review on a delivered UCLM Canteen order without giving any star rating | '
      "Expected Result: Review is not submitted and 'Please select at least a store or product rating.' is shown",
      (tester) async {
        final order = OrderModel(
          id: '9664dc58-0000-4000-a000-000000000000',
          userId: 'maria',
          vendorId: 'canteen',
          vendorName: 'UCLM Canteen',
          orderStatus: 'delivered',
          dropoffLocationId: 'maritime',
          totalAmount: 148.19,
          createdAt: DateTime(2026, 11, 17, 8),
          items: [
            OrderItemModel(productId: 'adobo', productName: 'Chicken Adobo Rice', quantity: 1, unitPrice: 95),
            OrderItemModel(productId: 'turon', productName: 'Turon (2 pcs)', quantity: 1, unitPrice: 30),
          ],
        );

        await pumpScreen(
          tester,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => OrderReviewDialog.show(context, order: order),
                child: const Text('Rate'),
              ),
            ),
          ),
          size: const Size(390, 1200),
        );
        await tester.tap(find.text('Rate'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Rate Your Order'), findsOneWidget);
        await tapButton(tester, 'Submit Review');

        expect(find.text('Please select at least a store or product rating.'), findsOneWidget);
        expect(find.text('Rate Your Order'), findsOneWidget); // dialog stays open
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });
}
