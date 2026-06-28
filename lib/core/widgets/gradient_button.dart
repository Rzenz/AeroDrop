import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double height;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 56,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;
  DateTime? _lastTapped;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
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
    final isDisabled = widget.onPressed == null && !widget.isLoading;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        return Center(
          child: GestureDetector(
            onTapDown: (_) {
              if (!isDisabled && !widget.isLoading) {
                HapticFeedback.lightImpact();
                _pressController.forward();
              }
            },
            onTapUp: (_) {
              if (!isDisabled && !widget.isLoading) {
                _pressController.reverse();
              }
            },
            onTapCancel: () {
              if (!isDisabled && !widget.isLoading) {
                _pressController.reverse();
              }
            },
            onTap: (isDisabled || widget.isLoading)
                ? null
                : () {
                    final now = DateTime.now();
                    if (_lastTapped != null &&
                        now.difference(_lastTapped!) <
                            const Duration(milliseconds: 500)) {
                      return;
                    }
                    _lastTapped = now;
                    widget.onPressed?.call();
                  },
            child: ScaleTransition(
              scale: _scaleAnim,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.fastOutSlowIn,
                height: widget.height,
                // ponytail: ensure we never pass double.infinity to AnimatedContainer's width
                // to prevent Tween from interpolating with infinity and producing NaN.
                width: widget.isLoading
                    ? widget.height
                    : (maxWidth.isFinite ? maxWidth : MediaQuery.sizeOf(context).width - 48.0),
                decoration: BoxDecoration(
                  gradient: isDisabled
                      ? const LinearGradient(
                          colors: [Color(0xFF2C3B52), Color(0xFF1A2332)],
                        )
                      : AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  boxShadow: isDisabled
                      ? null
                      : [
                          BoxShadow(
                            // ponytail: static alpha replaces infinite _pulseController.
                            // Upgrade path: restore pulse if UX team requests it, but
                            // use VisibilityDetector to pause when off-screen.
                            color: AppColors.accent.withValues(
                              alpha: widget.isLoading ? 0.2 : 0.4,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                            spreadRadius: 1,
                          ),
                        ],
                ),
                alignment: Alignment.center,
                child: widget.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.bgDark),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: AppColors.bgDark, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              widget.text,
                              style: AppTextStyles.title(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.bgDark,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
