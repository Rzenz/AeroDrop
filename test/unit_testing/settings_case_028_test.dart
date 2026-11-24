import 'package:aerodrop/core/providers/settings_provider.dart';
import 'package:aerodrop/core/widgets/spring_switch.dart';
import 'package:aerodrop/features/profile/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_helpers.dart';

void main() {
  group('Test Case ID: CASE-028', () {
    testWidgets(
      'Test Case Description: User switches off Dark appearance in Settings | '
      'Expected Result: The app changes to the light theme and remembers the choice',
      (tester) async {
        await pumpScreen(tester, const SettingsPage());
        final container = ProviderScope.containerOf(tester.element(find.byType(SettingsPage)));
        expect(container.read(themeModeProvider), ThemeMode.dark);

        await tester.tap(find.byType(SpringSwitch).first);
        await tester.pump(const Duration(seconds: 1));

        expect(container.read(themeModeProvider), ThemeMode.light);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('theme_mode'), ThemeMode.light.index);
      },
    );
  });
}
