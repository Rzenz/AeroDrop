import 'package:aerodrop/core/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _pan(String vendorStatus) => {
  'id': 'pan',
  'email': 'pandemandaue@uclm.edu.ph',
  'full_name': 'Elena Bautista',
  'phone_number': '+639171234567',
  'role': 'user',
  'vendor_status': vendorStatus,
  'business_name': 'Pan de Mandaue',
};

void main() {
  group('Test Case ID: CASE-117', () {
    test(
      'Test Case Description: Admin rejects the pending vendor application of Pan de Mandaue | '
      'Expected Result: The applicant is no longer pending and does not get store access',
      () {
        final before = AeroDropUser.fromMap(_pan('pending'));
        expect(before.isPendingVendor, isTrue);
        // Rejection stores vendor_status 'rejected' and leaves the role as 'user'.
        final after = AeroDropUser.fromMap(_pan('rejected'));
        expect(after.isPendingVendor, isFalse);
        expect(after.isVendor, isFalse);
        expect(after.businessName, 'Pan de Mandaue');
      },
    );
  });
}
