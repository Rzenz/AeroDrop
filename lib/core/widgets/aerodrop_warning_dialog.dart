import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'neu_button.dart';
import 'neu_surface.dart';

/// Shared warning / advisory dialog.
///
/// The illustrative icon sits in a debossed well tinted by its own colour, so
/// severity is legible before the text is read.
void showAeroDropWarningDialog({
  required BuildContext context,
  required String title,
  required String message,
  required IconData icon,
  required Color iconColor,
  required IconData centerIcon,
  required Color centerIconColor,
}) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.base,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.brXl),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      title: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(title, style: AppTextStyles.heading(fontSize: 18)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: AppTextStyles.body(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: NeuSurface(
              style: NeuStyle.inset,
              depth: NeuDepth.medium,
              width: 76,
              height: 76,
              alignment: Alignment.center,
              borderRadius: BorderRadius.circular(38),
              color: Color.alphaBlend(
                centerIconColor.withValues(alpha: 0.12),
                AppColors.surfaceSunken,
              ),
              child: Icon(centerIcon, color: centerIconColor, size: 34),
            ),
          ),
        ],
      ),
      actions: [
        NeuButton(
          text: 'OK',
          height: 46,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );
}
