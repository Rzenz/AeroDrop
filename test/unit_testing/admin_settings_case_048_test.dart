import 'package:aerodrop/core/providers/settings_provider.dart';
import 'package:aerodrop/features/admin/admin_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fakes.dart';
import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-048', () {
    testWidgets(
      'Test Case Description: Admin turns off Live Drone Telemetry in System Settings | '
      'Expected Result: The Live Drone Telemetry switch changes from on to off',
      (tester) async {
        await pumpScreen(
          tester,
          const AdminSettingsScreen(),
          overrides: [lowBatteryAlertsProvider.overrideWith((ref) => FakeLowBattery())],
          size: const Size(600, 1600),
        );
        final telemetry = find.widgetWithText(SwitchListTile, 'Live Drone Telemetry');
        expect(tester.widget<SwitchListTile>(telemetry).value, isTrue);

        await tester.tap(telemetry);
        await tester.pump(const Duration(seconds: 1));

        expect(tester.widget<SwitchListTile>(telemetry).value, isFalse);
      },
    );
  });
}
