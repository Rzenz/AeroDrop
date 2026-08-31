import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'neu_back_button.dart';

/// The shared screen header.
///
/// Transparent by design — it sits directly on the canvas so the only things
/// with depth are the back button and any action, which is what the eye should
/// find first.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.showBackButton = true,
    this.onBackPressed,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 68 : 78);

  @override
  Widget build(BuildContext context) {
    final canPop =
        showBackButton && (onBackPressed != null || Navigator.canPop(context));

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            if (canPop) ...[
              NeuBackButton(onPressed: onBackPressed),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading(fontSize: 20),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTextStyles.caption(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: AppSpacing.xs),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
