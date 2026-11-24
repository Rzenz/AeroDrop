import 'package:aerodrop/core/models/support_report_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Test Case ID: CASE-045', () {
    test(
      'Test Case Description: Admin resolves the open report "Drone landed at the wrong building" | '
      'Expected Result: The report is listed as an open Drone & Delivery Issue, and once resolved it reads Resolved',
      () {
        SupportReportModel report(String status) => SupportReportModel(
          id: '5f0e2b1c-0000-4000-a000-000000000000',
          userId: 'maria',
          subject: 'Drone landed at the wrong building',
          message: 'My order was dropped at Annex 2 instead of the Maritime Building.',
          category: 'delivery_issue',
          status: status,
          createdAt: DateTime(2026, 11, 17, 15, 51),
        );

        final open = report('open');
        expect(open.categoryLabel, 'Drone & Delivery Issue');
        expect(open.isResolved, isFalse);
        expect(open.statusLabel, 'Open');

        final resolved = report('resolved');
        expect(resolved.isResolved, isTrue);
        expect(resolved.statusLabel, 'Resolved');
      },
    );
  });
}
