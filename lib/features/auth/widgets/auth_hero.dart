import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/entrance.dart';

/// The header shared by sign-in and registration.
///
/// The mark hovers above a landing pad — two plates in perspective, the same
/// shape a drone actually sets down on. It exists because both screens needed
/// the same thing and were each drawing their own lockup: sign-in had a small
/// mark beside a wordmark, registration had a 42pt display title with the mark
/// pushed to the far right. Neither looked like the other.
class AuthHero extends StatelessWidget {
  const AuthHero({
    super.key,
    required this.progress,
    required this.title,
    this.subtitle,
    this.compact = false,
  });

  final Animation<double> progress;

  /// What this screen is for, in a few words. Carries the product name so the
  /// user can see which app they are signing in to.
  final String title;

  final String? subtitle;

  /// Trims the pad and the type for short screens and long forms.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mark = compact ? 56.0 : 66.0;

    return Column(
      children: [
        Entrance(
          progress: progress,
          start: 0.0,
          rise: 10,
          child: _LandingPad(markSize: mark, progress: progress),
        ),
        SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
        Entrance(
          progress: progress,
          start: 0.14,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.display(fontSize: compact ? 25 : 29),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Entrance(
            progress: progress,
            start: 0.20,
            // Both screens rewrite this line while the user is looking at it —
            // sign-in when the vendor door is flipped, registration when the
            // account kind changes. Swapping the text outright reads as a
            // glitch; crossing it over reads as an answer to the tap.
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              switchInCurve: AppMotion.enter,
              switchOutCurve: AppMotion.exit,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  alignment: Alignment.topCenter,
                  sizeFactor: animation,
                  child: child,
                ),
              ),
              child: Text(
                subtitle!,
                key: ValueKey(subtitle),
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Two plates in perspective with the app mark floating over them.
class _LandingPad extends StatelessWidget {
  const _LandingPad({required this.markSize, required this.progress});

  final double markSize;
  final Animation<double> progress;

  /// Flattens the rotated squares into plates seen from a low angle. Any less
  /// and they read as diamonds; any more and they read as lines.
  static const _tilt = 0.46;

  @override
  Widget build(BuildContext context) {
    final lift = CurvedAnimation(
      parent: progress,
      curve: const Interval(0, 0.45, curve: Curves.easeOutCubic),
    );

    return SizedBox(
      height: markSize * 2.1,
      child: AnimatedBuilder(
        animation: lift,
        builder: (context, child) {
          final t = lift.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // The glow the mark casts onto the pad. Sits behind both plates
              // so it reads as light falling, not as a ring around the mark.
              Opacity(
                opacity: t * 0.9,
                child: Container(
                  width: markSize * 2.4,
                  height: markSize * 2.4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.26),
                        AppColors.accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              _plate(size: markSize * 1.62, dy: markSize * 0.52, t: t, i: 1),
              _plate(size: markSize * 1.34, dy: markSize * 0.30, t: t, i: 0),

              // The mark settles onto the pad rather than appearing on it.
              Transform.translate(
                offset: Offset(0, -markSize * 0.16 - (1 - t) * 12),
                child: Transform.scale(scale: 0.86 + 0.14 * t, child: child),
              ),
            ],
          );
        },
        child: BrandMark(size: markSize),
      ),
    );
  }

  /// One plate. [i] is its depth in the stack — further plates start lower and
  /// arrive slightly later, which is what gives the pad its sense of layers.
  Widget _plate({
    required double size,
    required double dy,
    required double t,
    required int i,
  }) {
    final local = ((t - i * 0.12) / 0.88).clamp(0.0, 1.0);

    return Transform.translate(
      offset: Offset(0, dy + (1 - local) * 10),
      child: Transform.scale(
        scaleY: _tilt,
        child: Transform.rotate(
          angle: math.pi / 4,
          child: Opacity(
            opacity: local,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: AppRadii.brXl,
                color: AppColors.surfaceRaised.withValues(alpha: 0.55),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.18 - i * 0.06),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
