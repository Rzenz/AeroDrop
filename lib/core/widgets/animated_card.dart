import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AnimatedCard extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? child; // If custom child is provided, use it instead of title/subtitle
  final VoidCallback? onTap;
  final double scaleFactor;
  final Gradient? borderGradient;

  const AnimatedCard({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.child,
    this.onTap,
    this.scaleFactor = 0.98, // Scale down 2% on press
    this.borderGradient,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  DateTime? _lastTapped;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    final borderGrad = widget.borderGradient ??
        LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.35),
            AppColors.accent.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    Widget innerContent;
    if (widget.child != null) {
      innerContent = widget.child!;
    } else {
      innerContent = Row(
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.title != null)
                  Text(
                    widget.title!,
                    style: AppTextStyles.title(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle!,
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: 12),
            widget.trailing!,
          ] else if (widget.onTap != null) ...[
            const SizedBox(width: 12),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryDark,
              size: 20,
            ),
          ],
        ],
      );
    }

    Widget card = CustomPaint(
      painter: _GradientBorderPainter(
        radius: radius,
        strokeWidth: 1.5,
        gradient: borderGrad,
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: radius,
        ),
        child: innerContent,
      ),
    );

    if (widget.onTap != null) {
      card = GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _pressController.forward();
        },
        onTapUp: (_) {
          _pressController.reverse();
          final now = DateTime.now();
          if (_lastTapped != null &&
              now.difference(_lastTapped!) <
                  const Duration(milliseconds: 500)) {
            return;
          }
          _lastTapped = now;
          widget.onTap!();
        },
        onTapCancel: () => _pressController.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: card,
        ),
      );
    }

    // Staggered entrance animation
    return card
        .animate()
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .slideY(begin: 0.1, end: 0.0, duration: 400.ms, curve: Curves.easeOut);
  }
}

class _GradientBorderPainter extends CustomPainter {
  final BorderRadius radius;
  final double strokeWidth;
  final Gradient gradient;

  _GradientBorderPainter({
    required this.radius,
    required this.strokeWidth,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final rrect = radius.toRRect(rect);

    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..shader = gradient.createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gradient != gradient;
  }
}
