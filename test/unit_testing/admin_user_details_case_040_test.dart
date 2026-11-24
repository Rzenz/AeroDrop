import 'package:aerodrop/core/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Test Case ID: CASE-040', () {
    test(
      'Test Case Description: Admin opens the Account Details of customer Paolo Reyes | '
      'Expected Result: Details show his email, phone, role USER and account status active; a suspended account is no longer active',
      () {
        final row = {
          'id': 'paolo',
          'email': 'paolo.reyes@uclm.edu.ph',
          'full_name': 'Paolo Reyes',
          'phone_number': '+639171234567',
          'role': 'user',
          'account_status': 'active',
          'created_at': '2026-10-09T08:00:00Z',
        };
        final paolo = AeroDropUser.fromMap(row);
        expect(paolo.fullName, 'Paolo Reyes');
        expect(paolo.email, 'paolo.reyes@uclm.edu.ph');
        expect(paolo.phoneNumber, '+639171234567');
        expect(paolo.role, 'user');
        expect(paolo.accountStatus, 'active');

        final suspended = AeroDropUser.fromMap({...row, 'account_status': 'suspended'});
        expect(suspended.accountStatus, 'suspended');
      },
    );
  });
}
