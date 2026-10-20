import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/weather_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/widgets/neu_feedback.dart';
import '../web_kit.dart';

/// Campus weather and the dispatch override.
///
/// The app's override form also has condition, temperature, wind and
/// message fields, but only the status is ever sent; this page offers what
/// the server actually takes — a status for two hours — and the way back to
/// live weather.
class WebAdminWeatherPage extends ConsumerStatefulWidget {
  const WebAdminWeatherPage({super.key});

  @override
  ConsumerState<WebAdminWeatherPage> createState() =>
      _WebAdminWeatherPageState();
}

class _WebAdminWeatherPageState extends ConsumerState<WebAdminWeatherPage> {
  static const _states = [
    (
      'safe',
      'Clear to fly',
      'Deliveries dispatch as normal.',
      Icons.wb_sunny_outlined,
      AppColors.success,
    ),
    (
      'caution',
      'Caution',
      'Flights run, with a weather surcharge and delays.',
      Icons.air_rounded,
      AppColors.warning,
    ),
    (
      'grounded',
      'Grounded',
      'No drone takes off; checkout is paused.',
      Icons.thunderstorm_outlined,
      AppColors.danger,
    ),
  ];

  late String _status = ref.read(weatherProvider).safetyStatus;
  bool _applying = false;
  bool _resuming = false;

  Future<void> _apply() async {
    setState(() => _applying = true);
    var ok = false;
    try {
      ok = await ref
          .read(weatherProvider.notifier)
          .setSimulatedWeather(_status, durationHours: 2.0);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _applying = false);
    final label = _states.firstWhere((s) => s.$1 == _status).$2;
    showNeuSnack(
      context,
      ok
          ? 'Override on: $label for the next 2 hours.'
          : 'The override could not be applied.',
      tone: ok ? NeuToneKind.success : NeuToneKind.error,
    );
  }

  Future<void> _resume() async {
    setState(() => _resuming = true);
    var ok = false;
    try {
      ok = await ref.read(weatherProvider.notifier).clearWeatherOverride();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _resuming = false;
      if (ok) _status = ref.read(weatherProvider).safetyStatus;
    });
    showNeuSnack(
      context,
      ok
          ? 'Back on live campus weather.'
          : 'Live weather could not be resumed.',
      tone: ok ? NeuToneKind.success : NeuToneKind.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(weatherProvider);
    final now =
        _states.where((s) => s.$1 == w.safetyStatus).firstOrNull ??
        _states.first;
    String n(double? v, String unit) =>
        v == null ? '—' : '${v.toStringAsFixed(1)} $unit';

    final current = WebPanel(
      depth: NeuDepth.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Without a reading the default status is not a fact about
              // the sky, so the icon stays neutral.
              Icon(
                w.id == null ? Icons.cloud_off_outlined : now.$4,
                size: 40,
                color: w.id == null
                    ? AppColors.textTertiary
                    : AppColors.readable(now.$5),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.id == null ? 'No reading yet' : now.$2,
                      style: WebText.display(26),
                    ),
                    Text(
                      w.condition ?? 'Waiting for the first reading',
                      style: WebText.body(size: 14.5),
                    ),
                  ],
                ),
              ),
              if (w.isOverrideActive)
                WebPill(
                  label: 'Override · ${w.overrideRemainingText}',
                  tone: AppColors.warning,
                )
              else
                const WebPill(label: 'Live', tone: AppColors.success),
            ],
          ),
          if ((w.message ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            WebWell(
              radius: 16,
              padding: const EdgeInsets.all(14),
              child: Text(
                w.message!,
                style: WebText.body(size: 14, color: AppColors.textPrimary),
              ),
            ),
          ],
          const SizedBox(height: 18),
          WebGrid(
            minTile: 150,
            gap: 14,
            children: [
              _Reading(
                'Temperature',
                n(w.temperature, '°C'),
                Icons.thermostat_rounded,
              ),
              _Reading('Wind', n(w.windSpeed, 'km/h'), Icons.air_rounded),
              _Reading('Gusts', n(w.windGusts, 'km/h'), Icons.storm_outlined),
              _Reading(
                'Rain',
                n(w.precipitation, 'mm'),
                Icons.water_drop_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Updated ${w.lastUpdatedText}${w.isDataStale ? ' — this reading is old' : ''}',
            style: WebText.body(size: 12.5, color: AppColors.textTertiary),
          ),
        ],
      ),
    );

    final override = WebPanel(
      title: 'Override for 2 hours',
      subtitle: 'Sets the dispatch status regardless of the live reading.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in _states) ...[
            _Option(
              selected: _status == s.$1,
              title: s.$2,
              detail: s.$3,
              icon: s.$4,
              tone: s.$5,
              onTap: () => setState(() => _status = s.$1),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 6),
          WebButton(
            label: 'Apply override',
            icon: Icons.check_rounded,
            expand: true,
            loading: _applying,
            onPressed: _resuming ? null : _apply,
          ),
          const SizedBox(height: 10),
          WebButton(
            label: 'Resume live weather',
            icon: Icons.sensors_rounded,
            kind: WebButtonKind.secondary,
            expand: true,
            loading: _resuming,
            onPressed: !w.isOverrideActive || _applying ? null : _resume,
          ),
        ],
      ),
    );

    return WebPage(
      title: 'Weather',
      subtitle: 'Whether drones can fly over campus right now.',
      onRefresh: () => ref.read(weatherProvider.notifier).loadWeatherSafety(),
      children: [
        WebSplit(
          main: current,
          side: override,
          sideWidth: 380,
          breakpoint: 1000,
        ),
      ],
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => WebWell(
    radius: 16,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AppColors.accentText),
        const SizedBox(height: 8),
        Text(value, style: WebText.numeric(size: 19)),
        Text(label, style: WebText.body(size: 12.5)),
      ],
    ),
  );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.selected,
    required this.title,
    required this.detail,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String detail;
  final IconData icon;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $detail',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? AppColors.surfaceSunken : AppColors.base,
              borderRadius: BorderRadius.circular(18),
              boxShadow: selected ? const [] : AppShadows.raised(),
              border: Border.all(
                color: selected ? AppColors.readable(tone) : Colors.transparent,
                width: 1.6,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.readable(tone)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: WebText.label(size: 14.5)),
                      Text(detail, style: WebText.body(size: 12.5)),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.readable(tone),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
