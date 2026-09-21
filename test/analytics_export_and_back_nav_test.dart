import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerodrop/core/services/analytics_export_service.dart';
import 'package:aerodrop/core/widgets/neu_back_button.dart';
import 'package:aerodrop/core/widgets/custom_app_bar.dart';

void main() {
  group('Analytics Export Service Tests', () {
    test('Date range factory helpers compute expected ranges', () {
      final now = DateTime.now();

      // Today
      final todayRange = AnalyticsDateRange.today();
      expect(todayRange.preset, DateRangePreset.today);
      expect(todayRange.startDate.year, now.year);
      expect(todayRange.startDate.month, now.month);
      expect(todayRange.startDate.day, now.day);
      expect(todayRange.startDate.hour, 0);
      expect(todayRange.startDate.minute, 0);
      expect(todayRange.endDate.hour, 23);
      expect(todayRange.endDate.minute, 59);

      // Last 7 days
      final last7DaysRange = AnalyticsDateRange.last7Days();
      expect(last7DaysRange.preset, DateRangePreset.last7Days);
      expect(last7DaysRange.endDate.day, now.day);
      expect(last7DaysRange.startDate.isBefore(last7DaysRange.endDate), isTrue);

      // Last 30 days
      final last30DaysRange = AnalyticsDateRange.last30Days();
      expect(last30DaysRange.preset, DateRangePreset.last30Days);
      expect(last30DaysRange.startDate.isBefore(last30DaysRange.endDate), isTrue);
      expect(last30DaysRange.endDate.difference(last30DaysRange.startDate).inDays >= 29, isTrue);

      // This month
      final thisMonthRange = AnalyticsDateRange.thisMonth();
      expect(thisMonthRange.preset, DateRangePreset.thisMonth);
      expect(thisMonthRange.startDate.day, 1);
      expect(thisMonthRange.startDate.month, now.month);
      expect(thisMonthRange.startDate.year, now.year);
    });

    test('Customer name anonymization unit tests', () {
      expect(AnalyticsExportService.anonymizeCustomerName('Juan Dela Cruz'), 'Juan D.');
      expect(AnalyticsExportService.anonymizeCustomerName('Maria Clara'), 'Maria C.');
      expect(AnalyticsExportService.anonymizeCustomerName('Madonna'), 'Madonna');
      expect(AnalyticsExportService.anonymizeCustomerName(''), 'Customer');
      expect(AnalyticsExportService.anonymizeCustomerName(null), 'Customer');
      expect(AnalyticsExportService.anonymizeCustomerName('   Alice    Smith   '), 'Alice S.');
    });

    test('CSV generation includes UTF-8 BOM, anonymized names, KPI sections, and currency', () {
      final dateRange = AnalyticsDateRange.custom(
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 21),
      );

      final sampleData = AnalyticsReportData(
        dateRange: dateRange,
        generatedAt: DateTime(2026, 9, 21, 12, 0),
        totalOrders: 3,
        deliveredOrders: 2,
        cancelledOrders: 1,
        cancelledByCustomer: 0,
        cancelledByVendor: 0,
        cancelledByWeather: 1,
        cancelledOther: 0,
        totalRevenue: 520.0,
        refundedAmount: 150.0,
        avgDeliveryTimeMinutes: 8.5,
        deliveriesCompleted: 2,
        weatherStatusCounts: {'safe': 10, 'caution': 2, 'grounded': 1},
        vendors: [
          const VendorAnalyticsItem(
            vendorId: 'v1',
            storeName: 'Aero Cafe',
            orderCount: 2,
            deliveredCount: 2,
            revenue: 370.0,
            averageRating: 4.8,
            reviewCount: 15,
          ),
        ],
        dailyStats: [
          DailyAnalyticsItem(
            dateString: '2026-09-20',
            date: DateTime(2026, 9, 20),
            orderCount: 3,
            deliveredCount: 2,
            revenue: 520.0,
          ),
        ],
        paymentSplit: [
          const PaymentSplitItem(
            methodLabel: 'GCash',
            rawMethod: 'gcash_simulated',
            count: 2,
            totalAmount: 400.0,
          ),
          const PaymentSplitItem(
            methodLabel: 'Credit/Debit Card',
            rawMethod: 'card_simulated',
            count: 1,
            totalAmount: 270.0,
          ),
        ],
        orders: [
          OrderExportItem(
            shortId: 'A1B2C3D4',
            fullId: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
            createdAt: DateTime(2026, 9, 20, 10, 30),
            storeName: 'Aero Cafe',
            customerAnonymized: AnalyticsExportService.anonymizeCustomerName('Juan Dela Cruz'),
            status: 'Delivered',
            paymentMethod: 'GCash',
            paymentStatus: 'paid',
            totalAmount: 250.0,
            deliveryDurationMinutes: 7.2,
          ),
          OrderExportItem(
            shortId: 'B2C3D4E5',
            fullId: 'b2c3d4e5-f6a7-8901-bcde-f12345678901',
            createdAt: DateTime(2026, 9, 20, 11, 15),
            storeName: 'Aero Cafe',
            customerAnonymized: AnalyticsExportService.anonymizeCustomerName('Maria Clara'),
            status: 'Delivered',
            paymentMethod: 'Credit/Debit Card',
            paymentStatus: 'paid',
            totalAmount: 270.0,
            deliveryDurationMinutes: 9.8,
          ),
          OrderExportItem(
            shortId: 'C3D4E5F6',
            fullId: 'c3d4e5f6-a7b8-9012-cdef-123456789012',
            createdAt: DateTime(2026, 9, 20, 12, 00),
            storeName: 'Tech Store',
            customerAnonymized: AnalyticsExportService.anonymizeCustomerName('Madonna'),
            status: 'Cancelled',
            paymentMethod: 'GCash',
            paymentStatus: 'refunded',
            totalAmount: 150.0,
            cancellationReason: 'weather_grounded',
            deliveryDurationMinutes: null,
          ),
        ],
      );

      // Verify CSV Output
      final csvBytes = AnalyticsExportService.generateCsv(sampleData);
      // Check UTF-8 BOM
      expect(csvBytes[0], 0xEF);
      expect(csvBytes[1], 0xBB);
      expect(csvBytes[2], 0xBF);

      final csvContent = utf8.decode(csvBytes);
      // Anonymized names should be present
      expect(csvContent.contains('Juan D.'), isTrue);
      expect(csvContent.contains('Maria C.'), isTrue);
      expect(csvContent.contains('Madonna'), isTrue);
      // Full surnames should NOT appear
      expect(csvContent.contains('Juan Dela Cruz'), isFalse);
      expect(csvContent.contains('Maria Clara'), isFalse);

      // Verify sections and Peso symbols
      expect(csvContent.contains('AERODROP ANALYTICS REPORT'), isTrue);
      expect(csvContent.contains('EXECUTIVE SUMMARY'), isTrue);
      expect(csvContent.contains('VENDOR BREAKDOWN'), isTrue);
      expect(csvContent.contains('PAYMENT METHOD SPLIT'), isTrue);
      expect(csvContent.contains('DAILY DISPATCH VOLUME'), isTrue);
      expect(csvContent.contains('DETAILED ORDER LIST'), isTrue);
      expect(csvContent.contains('₱520.00'), isTrue);
      expect(csvContent.contains('₱150.00'), isTrue);
      expect(csvContent.contains('8.5 mins'), isTrue);
    });
  });

  group('Back Navigation & Widget Tests', () {
    testWidgets('NeuBackButton renders with default and custom fallbackRoute', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NeuBackButton(fallbackRoute: '/admin'),
          ),
        ),
      );

      expect(find.byType(NeuBackButton), findsOneWidget);
      expect(find.byIcon(NeuBackButton.glyph), findsOneWidget);
    });

    testWidgets('CustomAppBar displays NeuBackButton by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: CustomAppBar(
              title: 'Test App Bar',
              showBackButton: true,
              fallbackRoute: '/vendor',
            ),
          ),
        ),
      );

      expect(find.text('Test App Bar'), findsOneWidget);
      expect(find.byType(NeuBackButton), findsOneWidget);
    });
  });
}
