import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../web_breakpoints.dart';
import '../../web_tokens.dart';
import '../../widgets/web_motion.dart';

/// The three weather states and what each does to dispatch.
///
/// Set as a table, because that is what it is: three states, one behaviour
/// each, enforced in one function. The previous pass made it three tinted
/// cards, which spent a full colour wash on what is really three rows of a
/// lookup.
///
/// Colour appears here and nowhere else on the page besides the accent, and
/// it is load-bearing: these are the same three tokens the app paints its
/// weather banner with, so learning them here means reading the app correctly
/// on day one. Each state gets a short bar rather than a tinted card — enough
/// to carry the code without turning the row into a status card.
class WeatherSection extends StatelessWidget {
  const WeatherSection({super.key});

  static const _states = <_WeatherRow>[
    _WeatherRow(
      'Safe',
      AppColors.success,
      'Clear conditions',
      'Drones dispatch normally, at full cruise speed.',
    ),
    _WeatherRow(
      'Caution',
      AppColors.warning,
      'Strong winds',
      'Flights still go, but slower and with a wider battery margin. '
          'Deliveries take longer.',
    ),
    _WeatherRow(
      'Grounded',
      AppColors.danger,
      'Unsafe to fly',
      'Dispatch is blocked outright. Anything already airborne finishes its '
          'run; nothing new leaves the hub.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);

    return WebContentFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // This heading is weighted differently from the run section's: a
          // statement on the left with its explanation set beside it rather
          // than beneath. A page where every section opens with the same
          // marker-title-body stack reads as one long strip.
          RevealOnScroll(
            child: brk.isExpanded
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 58,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weather',
                              style: WebType.meta(color: WebInk.accent),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'The sky decides, not the schedule.',
                              style: WebType.title(brk),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                      Expanded(
                        flex: 42,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'An administrator sets the current condition from '
                            'the admin console. The dispatch function reads '
                            'it before every single flight.',
                            style: WebType.body(),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weather',
                        style: WebType.meta(color: WebInk.accent),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'The sky decides, not the schedule.',
                        style: WebType.title(brk),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'An administrator sets the current condition. The '
                        'dispatch function reads it before every flight.',
                        style: WebType.body(),
                      ),
                    ],
                  ),
          ),
          SizedBox(height: brk.isCompact ? 44 : 64),
          const WebRule(),
          for (var i = 0; i < _states.length; i++)
            RevealOnScroll(
              delay: WebMotion.stagger * i,
              child: Column(
                children: [_WeatherRowTile(_states[i]), const WebRule()],
              ),
            ),
        ],
      ),
    );
  }
}

class _WeatherRow {
  const _WeatherRow(this.label, this.tone, this.condition, this.effect);

  final String label;
  final Color tone;
  final String condition;
  final String effect;
}

class _WeatherRowTile extends StatelessWidget {
  const _WeatherRowTile(this.row);
  final _WeatherRow row;

  // The semantic tones are tuned for the app's dark canvas, and this page's
  // canvas is darker still, so they are used as-is: the lowest, danger, is
  // 5.6:1 on WebInk.canvas.

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);

    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 3, height: 20, color: row.tone),
        const SizedBox(width: 14),
        Flexible(
          child: Text(row.label, style: WebType.entry(brk, color: row.tone)),
        ),
      ],
    );

    final condition = Text(
      row.condition,
      style: WebType.body(
        color: WebInk.text,
      ).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
    );

    final effect = Text(row.effect, style: WebType.body());

    return Padding(
      padding: EdgeInsets.symmetric(vertical: brk.isCompact ? 26 : 34),
      child: brk.isExpanded
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 26, child: label),
                const SizedBox(width: 32),
                Expanded(flex: 24, child: condition),
                const SizedBox(width: 32),
                Expanded(
                  flex: 50,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: effect,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(left: 17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [condition, const SizedBox(height: 7), effect],
                  ),
                ),
              ],
            ),
    );
  }
}
