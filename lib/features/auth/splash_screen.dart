import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _rotateController;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _navigationTimer = Timer(const Duration(milliseconds: 3600), () {
      if (mounted) {
        context.go('/onboarding');
      }
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _rotateController.dispose();
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 680;
    final graphicSize = isSmallScreen ? 180.0 : 240.0;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // Background: Deep navy with radial blue glow
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.25),
                  radius: 0.85,
                  colors: [
                    Color(0xFF0F2B48),
                    AppColors.bgDark,
                  ],
                ),
              ),
            ),
          ),

          // Ambient yellow bottom glow
          Positioned(
            bottom: -120,
            left: size.width * 0.15,
            right: size.width * 0.15,
            child: Container(
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.18),
                    blurRadius: 120,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // Drone graphic with rotating ring
                SizedBox(
                  width: graphicSize,
                  height: graphicSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer rotating dashed ring
                      AnimatedBuilder(
                        animation: _rotateController,
                        builder: (_, _) => Transform.rotate(
                          angle: _rotateController.value * 2 * math.pi,
                          child: CustomPaint(
                            size: Size(graphicSize, graphicSize),
                            painter: _DashedRingPainter(
                              color: AppColors.accent.withValues(alpha: 0.45),
                              radius: graphicSize / 2 - 5,
                              dashCount: 24,
                            ),
                          ),
                        ),
                      ),
                      // Inner blue ring
                      Container(
                        width: graphicSize * 0.75,
                        height: graphicSize * 0.75,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                      ),
                      // Scan line sweep
                      AnimatedBuilder(
                        animation: _scanController,
                        builder: (_, _) => Opacity(
                          opacity: (1 - _scanController.value).clamp(0.0, 0.75),
                          child: Container(
                            width: graphicSize * 0.7,
                            height: graphicSize * 0.7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                startAngle: 0,
                                endAngle: _scanController.value * 2 * math.pi,
                                colors: [
                                  Colors.transparent,
                                  AppColors.primary.withValues(alpha: 0.35),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Drone Lottie
                      SizedBox(
                        width: graphicSize * 0.55,
                        height: graphicSize * 0.55,
                        child: Lottie.asset(
                          'assets/lottie/drone_fly.json',
                          repeat: true,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .scale(
                      duration: 800.ms,
                      curve: Curves.elasticOut,
                      begin: const Offset(0.4, 0.4),
                    )
                    .fadeIn(duration: 500.ms),

                const SizedBox(height: 52),

                // Wordmark — yellow typewriter reveal
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.accentGradient.createShader(bounds),
                  blendMode: BlendMode.srcIn,
                  child: AnimatedTextKit(
                    totalRepeatCount: 1,
                    isRepeatingAnimation: false,
                    animatedTexts: [
                      TypewriterAnimatedText(
                        'AERODROP',
                        textStyle: AppTextStyles.display(
                          fontSize: 44,
                          letterSpacing: 10,
                        ),
                        speed: const Duration(milliseconds: 90),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 600.ms),

                const SizedBox(height: 12),

                Text(
                  'UCLM DRONE DELIVERY SYSTEM',
                  style: AppTextStyles.label(
                    fontSize: 11,
                    color: AppColors.textSecondaryDark,
                    letterSpacing: 3,
                  ),
                ).animate().fadeIn(delay: 1100.ms),

                const Spacer(flex: 3),

                // Progress indicator at the bottom
                Padding(
                  padding: const EdgeInsets.fromLTRB(60, 0, 60, 48),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const SizedBox(
                          height: 4,
                          child: LinearProgressIndicator(
                            backgroundColor: AppColors.borderDark,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Initializing drone fleet...',
                        style: AppTextStyles.body(
                          fontSize: 12,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 1300.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  final Color color;
  final double radius;
  final int dashCount;

  _DashedRingPainter({
    required this.color,
    required this.radius,
    required this.dashCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final angleStep = (2 * math.pi) / dashCount;
    final dashLength = angleStep * 0.45;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * angleStep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashLength,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter old) => false;
}
