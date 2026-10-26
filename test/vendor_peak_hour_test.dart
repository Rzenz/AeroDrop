import 'package:flutter_test/flutter_test.dart';
import 'package:aerodrop/core/models/order_model.dart';
import 'package:aerodrop/features/vendor/vendor_dashboard_screen.dart';

OrderModel _on(DateTime when, String status, double amount) => OrderModel(
  id: 'o${when.millisecondsSinceEpoch}$status',
  userId: 'u',
  vendorId: 'v',
  orderStatus: status,
  dropoffLocationId: 'l',
  totalAmount: amount,
  createdAt: when,
  items: const [],
);

OrderModel _at(int hour, [int minute = 0]) => OrderModel(
  id: 'o$hour$minute',
  userId: 'u',
  vendorId: 'v',
  orderStatus: 'delivered',
  dropoffLocationId: 'l',
  totalAmount: 100,
  // Local time, so the expected hour does not depend on the test machine
  createdAt: DateTime(2026, 10, 26, hour, minute),
  items: const [],
);

void main() {
  group('peakOrderingWindow', () {
    test('needs at least $peakHourMinimumOrders orders', () {
      final nine = [for (var i = 0; i < 9; i++) _at(12, i)];
      expect(peakOrderingWindow(nine), isNull);
      expect(peakOrderingWindow([...nine, _at(12, 30)]), isNotNull);
    });

    test('finds the busiest hour as a one-hour window', () {
      final orders = [
        for (var i = 0; i < 4; i++) _at(12, i * 10), // 12:00–13:00 ×4
        for (var i = 0; i < 3; i++) _at(9, i * 10),
        for (var i = 0; i < 3; i++) _at(18, i * 10),
      ];
      expect(peakOrderingWindow(orders), '12:00 PM – 1:00 PM');
    });

    test('formats midnight, morning and the hour before midnight', () {
      expect(
        peakOrderingWindow([for (var i = 0; i < 10; i++) _at(0, i)]),
        '12:00 AM – 1:00 AM',
      );
      expect(
        peakOrderingWindow([for (var i = 0; i < 10; i++) _at(11, i)]),
        '11:00 AM – 12:00 PM',
      );
      expect(
        peakOrderingWindow([for (var i = 0; i < 10; i++) _at(23, i)]),
        '11:00 PM – 12:00 AM',
      );
    });

    test('a tie goes to the earlier hour', () {
      final orders = [
        for (var i = 0; i < 5; i++) _at(15, i),
        for (var i = 0; i < 5; i++) _at(10, i),
      ];
      expect(peakOrderingWindow(orders), '10:00 AM – 11:00 AM');
    });
  });

  group('lastSevenDaysSales', () {
    final now = DateTime(2026, 10, 26, 15); // a Monday afternoon

    test('buckets the last seven local days, today last', () {
      final sales = lastSevenDaysSales([
        _on(DateTime(2026, 10, 26, 9), 'delivered', 100), // today
        _on(DateTime(2026, 10, 25, 23, 59), 'delivered', 40), // yesterday
        _on(DateTime(2026, 10, 20, 0, 1), 'delivered', 7), // 6 days ago
      ], now);
      expect(sales, [7.0, 0.0, 0.0, 0.0, 0.0, 40.0, 100.0]);
    });

    test('leaves out older weeks and undelivered orders', () {
      final sales = lastSevenDaysSales([
        _on(DateTime(2026, 10, 19, 12), 'delivered', 999), // a week ago Monday
        _on(DateTime(2026, 9, 28, 12), 'delivered', 999), // last month
        _on(DateTime(2026, 10, 26, 10), 'pending', 999),
        _on(DateTime(2026, 10, 26, 11), 'cancelled', 999),
      ], now);
      expect(sales.every((v) => v == 0), isTrue);
    });
  });
}
