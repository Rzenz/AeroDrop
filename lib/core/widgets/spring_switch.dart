import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import 'neu_surface.dart';

/// The app's toggle.
///
/// An inset track with a raised thumb — the physical reading of a switch. The
/// track also tints on when active, so the state is not carried by thumb
/// position alone.
class SpringSwitch extends StatelessWidget {
  const SpringSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = AppColors.primary,
    this.enabled = true,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final bool enabled;
  final String? semanticLabel;

  static const double _w = 52;
  static const double _h = 30;
  static const double _thumb = 22;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onChanged(!value);
              }
            : null,
        // Keep the 44pt target even though the switch itself is 30pt tall.
        child: SizedBox(
          width: _w,
          height: 44,
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.45,
              child: NeuSurface(
                style: NeuStyle.inset,
                depth: NeuDepth.flat,
                width: _w,
                height: _h,
                borderRadius: AppRadii.brPill,
                color: value
                    ? Color.alphaBlend(
                        activeColor.withValues(alpha: 0.30),
                        AppColors.surfaceSunken,
                      )
                    : AppColors.surfaceSunken,
                child: AnimatedAlign(
                  duration: AppMotion.normal,
                  curve: AppMotion.spring,
                  alignment: value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      width: _thumb,
                      height: _thumb,
                      decoration: BoxDecoration(
                        color: value ? activeColor : AppColors.base,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.raised(NeuDepth.flat),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
