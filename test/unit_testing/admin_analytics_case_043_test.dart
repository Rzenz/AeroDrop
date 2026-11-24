import 'package:aerodrop/core/services/analytics_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Test Case ID: CASE-043', () {
    test(
      'Test Case Description: Admin exports the Performance Analytics report | '
      'Expected Result: Customer names are shortened for privacy (Maria Santos to "Maria S."), and payments, statuses and amounts use readable labels',
      () {
        expect(AnalyticsExportService.anonymizeCustomerName('Maria Santos'), 'Maria S.');
        expect(AnalyticsExportService.anonymizeCustomerName('Juan Dela Cruz'), 'Juan D.');
        expect(AnalyticsExportService.anonymizeCustomerName(null), 'Customer');

        expect(AnalyticsExportService.formatPaymentMethod('gcash_simulated'), 'GCash');
        expect(AnalyticsExportService.formatPaymentMethod('card_simulated'), 'Credit/Debit Card');
        expect(AnalyticsExportService.formatOrderStatus('in_transit'), 'In Transit');
        expect(AnalyticsExportService.formatCurrency(3065.04), '₱3065.04');
      },
    );
  });
}
