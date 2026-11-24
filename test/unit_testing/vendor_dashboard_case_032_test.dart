import 'package:aerodrop/core/models/order_model.dart';
import 'package:aerodrop/features/vendor/vendor_dashboard_screen.dart';
import 'package:flutter_test/flutter_test.dart';

OrderModel _order(String id, DateTime when, String status, double total) => OrderModel(
  id: id,
  userId: 'paolo',
  vendorId: 'kape',
  orderStatus: status,
  dropoffLocationId: 'main',
  totalAmount: total,
  createdAt: when,
  items: const [],
);

void main() {
  group('Test Case ID: CASE-032', () {
    test(
      'Test Case Description: Kape Kanto opens the vendor dashboard after a week of orders | '
      'Expected Result: Sales, Last 7 Days adds up delivered orders per day and leaves out cancelled and older orders',
      () {
        final now = DateTime(2026, 11, 17, 20);
        final orders = [
          _order('a', DateTime(2026, 11, 17, 9), 'delivered', 143.19), // today
          _order('b', DateTime(2026, 11, 17, 11), 'delivered', 108.19), // today
          _order('c', DateTime(2026, 11, 16, 10), 'delivered', 193.19), // yesterday
          _order('d', DateTime(2026, 11, 14, 12), 'cancelled', 153.19), // cancelled: not a sale
          _order('e', DateTime(2026, 11, 11, 12), 'delivered', 158.19), // 6 days ago
          _order('f', DateTime(2026, 11, 9, 12), 'delivered', 999.00), // 8 days ago: outside the week
        ];

        final days = lastSevenDaysSales(orders, now);

        expect(days.length, 7);
        expect(days[6], closeTo(251.38, 0.001)); // today
        expect(days[5], closeTo(193.19, 0.001)); // yesterday
        expect(days[3], 0); // the cancelled order's day
        expect(days[0], closeTo(158.19, 0.001)); // 6 days ago
        expect(days.reduce((a, b) => a + b), closeTo(602.76, 0.001));
      },
    );
  });
}
