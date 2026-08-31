import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'neu_button.dart';
import 'neu_surface.dart';

/// The shared empty / nothing-here state.
///
/// The icon sits in a debossed circular well — an empty state literally is a
/// hollow, and the inset treatment says so without needing an illustration.
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.subtitle,
    this.lottiePath,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? lottiePath;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lottiePath != null)
              SizedBox(
                width: 160,
                height: 160,
                child: Lottie.asset(lottiePath!, repeat: true),
              )
            else
              NeuSurface(
                style: NeuStyle.inset,
                depth: NeuDepth.medium,
                width: 92,
                height: 92,
                alignment: Alignment.center,
                borderRadius: BorderRadius.circular(46),
                color: AppColors.surfaceSunken,
                child: Icon(
                  icon ?? Icons.inbox_rounded,
                  size: 38,
                  color: AppColors.textTertiary,
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              style: AppTextStyles.heading(fontSize: 19),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: AppTextStyles.body(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              NeuButton(
                text: actionLabel!,
                onPressed: onAction,
                expand: false,
                height: 48,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The error twin of [EmptyStateWidget]. Distinguished by a danger-tinted icon
/// and a retry action, so "broken" never gets confused with "empty".
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            NeuSurface(
              style: NeuStyle.inset,
              depth: NeuDepth.medium,
              width: 92,
              height: 92,
              alignment: Alignment.center,
              borderRadius: BorderRadius.circular(46),
              color: AppColors.surfaceSunken,
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 38,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              style: AppTextStyles.heading(fontSize: 19),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: AppTextStyles.body(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              NeuButton(
                text: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
                expand: false,
                height: 48,
                variant: NeuButtonVariant.neutral,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
