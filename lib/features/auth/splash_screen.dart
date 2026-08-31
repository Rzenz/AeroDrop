import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/neu_input.dart';

/// The launch screen.
///
/// One animation controller drives everything: the progress bar, the stage
/// label and the entrance. The previous version ran five simultaneous infinite
/// controllers behind a radar sweep and two glow layers, which cost a repaint
/// every frame to say the same thing a progress bar already says.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;

  /// Shown in sequence as the bar fills. Kept short and plain — a launch
  /// screen reports what it is doing, it does not perform.
  static const _stages = [
    'Connecting to the fleet',
    'Checking campus airspace',
    'Loading your deliveries',
    'Ready for takeoff',
  ];

  int _stage = 0;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _progress.addListener(() {
      final next = (_progress.value * _stages.length).floor().clamp(
        0,
        _stages.length - 1,
      );
      if (next != _stage) {
        setState(() => _stage = next);
        HapticFeedback.selectionClick();
      }
    });

    _progress.forward().then((_) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      context.go('/onboarding');
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 680;
    final markSize = compact ? 104.0 : 124.0;

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.pageGutter(context),
          ),
          child: Column(
            children: [
              const Spacer(flex: 3),
              _BrandMark(size: markSize),
              SizedBox(height: compact ? AppSpacing.xl : AppSpacing.xxl),
              Text(
                'AeroDrop',
                style: AppTextStyles.display(fontSize: compact ? 34 : 40),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'UCLM Drone Delivery System',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(flex: 4),
              _ProgressBlock(progress: _progress, label: _stages[_stage]),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// The app mark, scaled up for the launch screen.
///
/// Static, with a single settle-in scale. A logo that spins forever reads as a
/// page that has not finished loading.
class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.88, end: 1),
      duration: AppMotion.slow,
      curve: AppMotion.enter,
      builder: (context, t, child) => Transform.scale(
        scale: t,
        child: Opacity(opacity: t.clamp(0, 1), child: child),
      ),
      child: BrandMark(size: size),
    );
  }
}

/// Stage label, percentage and the fill bar.
class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.progress, required this.label});

  final Animation<double> progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppMotion.fast,
                  child: Text(
                    label,
                    key: ValueKey(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${(progress.value * 100).round()}%',
                style: AppTextStyles.numeric(
                  fontSize: 13,
                  color: AppColors.accentText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          NeuProgressBar(
            value: progress.value,
            height: 7,
            semanticLabel: 'Startup progress',
          ),
        ],
      ),
    );
  }
}
