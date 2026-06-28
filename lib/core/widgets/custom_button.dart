import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum ButtonVariant { primary, accent, ghost, danger }

/// Yellow pill gradient button with spring-press, glow shadow, and idle pulse.
class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Gradient? gradient;
  final double height;
  final IconData? icon;
  final ButtonVariant variant;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.gradient,
    this.height = 56,
    this.icon,
    this.variant = ButtonVariant.accent,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnim;
  late Animation<double> _pulseAnim;
  DateTime? _lastTapped;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    // Idle pulse — gentle amber glow breathe
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.35, end: 0.65).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Gradient get _gradient {
    if (widget.gradient != null) return widget.gradient!;
    return switch (widget.variant) {
      ButtonVariant.accent => AppColors.accentGradient,
      ButtonVariant.primary => AppColors.primaryGradient,
      ButtonVariant.danger =>
        const LinearGradient(colors: [AppColors.danger, Color(0xFFCC0033)]),
      ButtonVariant.ghost =>
        const LinearGradient(colors: [Colors.transparent, Colors.transparent]),
    };
  }

  Color get _textColor => switch (widget.variant) {
        ButtonVariant.accent => AppColors.bgDark,
        ButtonVariant.ghost => AppColors.primary,
        _ => Colors.white,
      };

  Color get _glowColor => switch (widget.variant) {
        ButtonVariant.accent => AppColors.accent,
        ButtonVariant.danger => AppColors.danger,
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null && !widget.isLoading;
    final gradient = disabled
        ? const LinearGradient(colors: [Color(0xFF1B3A5C), Color(0xFF152E4A)])
        : _gradient;

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _pressController.forward();
      },
      onTapUp: (_) {
        _pressController.reverse(from: 1.0);
      },
      onTapCancel: () => _pressController.reverse(from: 1.0),
      onTap: widget.isLoading || disabled
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
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, _) => Container(
            height: widget.height,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(32),
              boxShadow: disabled
                  ? null
                  : [
                      BoxShadow(
                        color: _glowColor.withValues(
                            alpha: widget.variant == ButtonVariant.accent
                                ? _pulseAnim.value
                                : 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                        spreadRadius: -4,
                      ),
                    ],
            ),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _textColor,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: _textColor, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.text,
                          style: AppTextStyles.title(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _textColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
