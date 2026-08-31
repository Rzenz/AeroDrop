import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_shadows.dart';

/// The cart action that sits in the centre of the nav dock.
///
/// Accent-filled and haloed: it is the only element in the dock that is not
/// navigation, so it deliberately breaks the dock's monochrome to read as an
/// action rather than a fifth tab.
class AeroDropFloatingActionButton extends StatefulWidget {
  const AeroDropFloatingActionButton({
    super.key,
    required this.onPressed,
    this.icon = Icons.shopping_cart_rounded,
    this.badgeCount = 0,
    this.size = 56,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final int badgeCount;
  final double size;

  @override
  State<AeroDropFloatingActionButton> createState() =>
      _AeroDropFloatingActionButtonState();
}

class _AeroDropFloatingActionButtonState
    extends State<AeroDropFloatingActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    Widget fab = AnimatedScale(
      scale: _pressed ? 0.9 : 1.0,
      duration: AppMotion.instant,
      curve: AppMotion.standard,
      child: Container(
        width: s,
        height: s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accentFill,
          shape: BoxShape.circle,
          boxShadow: _pressed
              ? null
              : [
                  ...AppShadows.raised(NeuDepth.medium),
                  ...AppShadows.glow(AppColors.accentFill, alpha: 0.30),
                ],
        ),
        child: Icon(widget.icon, color: AppColors.onAccentFill, size: s * 0.42),
      ),
    );

    if (widget.badgeCount > 0) {
      fab = Stack(
        clipBehavior: Clip.none,
        children: [
          fab,
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.base, width: 2),
              ),
              child: Center(
                child: Text(
                  widget.badgeCount > 99 ? '99+' : '${widget.badgeCount}',
                  style: AppTextStyles.label(
                    fontSize: 10,
                    // White, not the theme's text colour. The badge sits on a
                    // saturated danger fill in both themes, and on the light
                    // canvas `textPrimary` is near-black — unreadable there.
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      label: 'Cart',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: Hero(tag: 'aerodrop_request_delivery_fab', child: fab),
      ),
    );
  }
}
