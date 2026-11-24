import 'package:aerodrop/features/admin/no_fly_zone_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-046', () {
    testWidgets(
      'Test Case Description: Admin opens New Zone and taps Save Zone without a zone name or reason | '
      'Expected Result: The zone is not saved and the New Restricted Zone form stays open',
      (tester) async {
        await pumpScreen(tester, const NoFlyZonePage(), size: const Size(600, 1200));
        expect(find.text('No no-fly zones configured.'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('New Restricted Zone'), findsOneWidget);

        await tester.tap(find.text('Save Zone'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('New Restricted Zone'), findsOneWidget);
        expect(find.text('No no-fly zones configured.'), findsOneWidget);
      },
    );
  });
}
