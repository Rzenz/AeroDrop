import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? action;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const CustomAppBar({
    super.key,
    required this.title,
    this.action,
    this.showBackButton = true,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = showBackButton && (onBackPressed != null || Navigator.canPop(context));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: NavigationToolbar(
          leading: canPop
              ? Center(
                  child: GestureDetector(
                    onTap: onBackPressed ?? () {
                      HapticFeedback.lightImpact();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        // fallback if popped out of go_router stack
                        Navigator.maybePop(context);
                      }
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.cardDark.withValues(alpha: 0.6),
                        border: Border.all(
                          color: AppColors.borderDark,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
          middle: Text(
            title,
            style: AppTextStyles.heading(fontSize: 22),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: action != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Center(child: action!),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(68);
}
