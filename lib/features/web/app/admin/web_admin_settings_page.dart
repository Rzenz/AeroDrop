import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../web_kit.dart';

/// The administrator's settings — the ones that are kept.
///
/// The app's admin settings also show switches for telemetry, auto-assign
/// and maintenance alerts, a payload slider, and "Recalibrate" / "Reset all
/// sessions" buttons; none of those is saved or sent anywhere, so they are
/// not offered here.
class WebAdminSettingsPage extends ConsumerWidget {
  const WebAdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final lowBattery = ref.watch(lowBatteryAlertsProvider);

    Widget row(IconData icon, String title, String detail, Widget trailing) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 21, color: AppColors.accentText),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: WebText.label(size: 14.5)),
                    Text(detail, style: WebText.body(size: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing,
            ],
          ),
        );

    return WebPage(
      title: 'Settings',
      subtitle: 'How the console looks and what it warns you about.',
      maxWidth: 860,
      children: [
        WebPanel(
          title: 'Alerts',
          child: row(
            Icons.battery_alert_outlined,
            'Low battery warnings',
            'Flag any drone under 10% on the dashboard and the fleet page.',
            WebTabs(
              labels: const ['On', 'Off'],
              selected: lowBattery ? 0 : 1,
              onSelected: (i) =>
                  ref.read(lowBatteryAlertsProvider.notifier).setAlerts(i == 0),
            ),
          ),
        ),
        WebPanel(
          title: 'Appearance',
          child: row(
            Icons.contrast_rounded,
            'Theme',
            'Dark is the AeroDrop default.',
            WebTabs(
              labels: const ['Light', 'Dark', 'System'],
              selected: switch (mode) {
                ThemeMode.light => 0,
                ThemeMode.dark => 1,
                ThemeMode.system => 2,
              },
              onSelected: (i) => ref
                  .read(themeModeProvider.notifier)
                  .setTheme(
                    const [
                      ThemeMode.light,
                      ThemeMode.dark,
                      ThemeMode.system,
                    ][i],
                  ),
            ),
          ),
        ),
        WebPanel(
          title: 'Operations',
          child: Column(
            children: [
              row(
                Icons.wb_sunny_outlined,
                'Campus weather',
                'Override the dispatch status, or return to live weather.',
                WebButton(
                  label: 'Open',
                  kind: WebButtonKind.secondary,
                  dense: true,
                  onPressed: () => context.go('/admin/weather'),
                ),
              ),
              row(
                Icons.lock_reset_rounded,
                'Your password',
                'Change the password you sign in with.',
                WebButton(
                  label: 'Change',
                  kind: WebButtonKind.secondary,
                  dense: true,
                  onPressed: () => context.push('/shared/change-password'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
