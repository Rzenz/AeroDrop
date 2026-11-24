import 'package:aerodrop/core/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _pan(String role, String vendorStatus) => {
  'id': 'pan',
  'email': 'pandemandaue@uclm.edu.ph',
  'full_name': 'Elena Bautista',
  'phone_number': '+639171234567',
  'role': role,
  'vendor_status': vendorStatus,
  'business_name': 'Pan de Mandaue',
};

void main() {
  group('Test Case ID: CASE-039', () {
    test(
      'Test Case Description: Admin approves the pending vendor application of Pan de Mandaue | '
      'Expected Result: Before approval the account is a pending applicant (no store access); after approval it is an active vendor',
      () {
        final before = AeroDropUser.fromMap(_pan('user', 'pending'));
        expect(before.isPendingVendor, isTrue);
        expect(before.isVendor, isFalse);
        expect(before.businessName, 'Pan de Mandaue');

        // Approval stores role 'vendor' and vendor_status 'active'.
        final after = AeroDropUser.fromMap(_pan('vendor', 'active'));
        expect(after.isPendingVendor, isFalse);
        expect(after.isVendor, isTrue);
      },
    );
  });
}
