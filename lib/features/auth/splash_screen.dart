import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
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
                      // Custom SVG Drone Illustration
                      AnimatedBuilder(
                        animation: _scanController,
                        builder: (context, _) {
                          return SizedBox(
                            width: graphicSize * 0.4,
                            height: graphicSize * 0.4,
                            child: CustomPaint(
                              size: Size(graphicSize * 0.4, graphicSize * 0.4),
                              painter: _DroneSvgPainter(animationValue: _scanController.value),
                            ),
                          );
                        },
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

class _DroneSvgPainter extends CustomPainter {
  final double animationValue;

  _DroneSvgPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    
    // Scale factor to map 0..400 coordinate space to the actual size
    double s(double val) => val * w / 400.0;

    // Paints
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s(12.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final accentPaint = Paint()
      ..color = const Color(0xFF4F46E5) // Indigo from SVG
      ..style = PaintingStyle.stroke
      ..strokeWidth = s(12.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final propellerPaint = Paint()
      ..color = const Color(0xFF4F46E5) // Indigo from SVG
      ..style = PaintingStyle.stroke
      ..strokeWidth = s(12.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. Left Motor Mount
    final path1 = Path()
      ..moveTo(s(94.65), s(91.35))
      ..lineTo(s(94.65), s(109.12))
      ..cubicTo(s(86.41), s(113.1), s(76.89), s(116.58), s(64.91), s(119.01))
      ..lineTo(s(64.91), s(91.35))
      ..cubicTo(s(64.91), s(83.14), s(71.57), s(76.48), s(79.78), s(76.48))
      ..cubicTo(s(83.88), s(76.48), s(87.6), s(78.14), s(90.29), s(80.83))
      ..cubicTo(s(92.98), s(83.52), s(94.65), s(87.23), s(94.65), s(91.35))
      ..close();
    canvas.drawPath(path1, linePaint);

    // 2. Left Motor Shaft
    canvas.drawLine(Offset(s(79.783), s(76.478)), Offset(s(79.783), s(50.0)), linePaint);

    // 3. Right Motor Mount
    final path2 = Path()
      ..moveTo(s(322.99), s(91.35))
      ..lineTo(s(322.99), s(115.94))
      ..cubicTo(s(310.96), s(112.3), s(301.68), s(107.52), s(293.25), s(102.44))
      ..lineTo(s(293.25), s(91.35))
      ..cubicTo(s(293.25), s(83.14), s(299.91), s(76.48), s(308.12), s(76.48))
      ..cubicTo(s(312.22), s(76.48), s(315.94), s(78.14), s(318.63), s(80.83))
      ..cubicTo(s(321.32), s(83.52), s(323.0), s(87.23), s(323.0), s(91.35))
      ..close();
    canvas.drawPath(path2, linePaint);

    // 4. Right Motor Shaft
    canvas.drawLine(Offset(s(308.12), s(76.478)), Offset(s(308.12), s(50.0)), linePaint);

    // 5. Lower body structure
    final path3 = Path()
      ..moveTo(s(271.217), s(155.102))
      ..lineTo(s(271.217), s(166.283))
      ..cubicTo(s(271.217), s(175.228), s(263.966), s(182.479), s(255.021), s(182.479))
      ..lineTo(s(144.979), s(182.479))
      ..cubicTo(s(136.034), s(182.479), s(128.783), s(175.228), s(128.783), s(166.283))
      ..lineTo(s(128.783), s(155.102));
    canvas.drawPath(path3, linePaint);

    // 6. Drone Main Aerodynamic Body
    final path4 = Path()
      ..moveTo(s(335.381), s(119.043))
      ..cubicTo(s(277.58), s(107.355), s(277.13), s(71.466), s(200.149), s(71.421))
      ..cubicTo(s(123.168), s(71.466), s(122.719), s(107.355), s(64.919), s(119.043))
      ..cubicTo(s(56.392), s(120.767), s(50.222), s(128.201), s(50.222), s(136.901))
      ..cubicTo(s(50.222), s(146.953), s(58.371), s(155.102), s(68.423), s(155.102))
      ..lineTo(s(332.022), s(155.102))
      ..cubicTo(s(342.074), s(155.102), s(350.223), s(146.953), s(350.223), s(136.901))
      ..cubicTo(s(350.223), s(128.201), s(344.053), s(120.767), s(335.381), s(119.043))
      ..close();
    canvas.drawPath(path4, linePaint);

    // 7. Center eye/camera
    canvas.drawCircle(Offset(s(200.0), s(113.261)), s(20.935), linePaint);

    // 8. Left Leg
    final path5 = Path()
      ..moveTo(s(94.297), s(155.102))
      ..lineTo(s(75.116), s(198.574))
      ..cubicTo(s(68.707), s(213.099), s(71.547), s(230.043), s(82.341), s(241.685))
      ..lineTo(s(110.731), s(272.304));
    canvas.drawPath(path5, linePaint);

    // 9. Right Leg
    final path6 = Path()
      ..moveTo(s(305.703), s(155.102))
      ..lineTo(s(324.884), s(198.574))
      ..cubicTo(s(331.293), s(213.099), s(328.453), s(230.043), s(317.659), s(241.685))
      ..lineTo(s(289.269), s(272.304));
    canvas.drawPath(path6, linePaint);

    // 10. Secondary/Back Box Part
    final path7 = Path()
      ..moveTo(s(174.735), s(220.319))
      ..lineTo(s(273.395), s(220.319))
      ..cubicTo(s(281.961), s(220.319), s(288.905), s(227.263), s(288.905), s(235.829))
      ..lineTo(s(288.905), s(334.489))
      ..cubicTo(s(288.905), s(343.055), s(281.961), s(350.0), s(273.395), s(350.0))
      ..lineTo(s(174.735), s(350.0));
    canvas.drawPath(path7, linePaint);

    // 11. Main Cargo Box
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s(111.225), s(220.319), s(129.681), s(129.681)),
        Radius.circular(s(15.51)),
      ),
      linePaint,
    );

    // 12. Box Latch/Ribbon (Indigo in SVG)
    final path8 = Path()
      ..moveTo(s(159.289), s(220.319))
      ..lineTo(s(192.841), s(220.319))
      ..lineTo(s(192.841), s(260.106))
      ..cubicTo(s(192.841), s(264.987), s(188.878), s(268.95), s(183.997), s(268.95))
      ..lineTo(s(168.132), s(268.95))
      ..cubicTo(s(163.251), s(268.95), s(159.289), s(264.987), s(159.289), s(260.106))
      ..close();
    canvas.drawPath(path8, accentPaint);

    // 13. Spinning Propellers (Indigo in SVG)
    final double propellerRotation = animationValue * 8 * math.pi; // Fast spin

    // Left Propeller
    canvas.save();
    canvas.translate(s(79.783), s(50.0));
    canvas.rotate(propellerRotation);
    canvas.drawLine(
      Offset(-s(41.957), 0),
      Offset(s(41.957), 0),
      propellerPaint,
    );
    canvas.restore();

    // Right Propeller
    canvas.save();
    canvas.translate(s(308.12), s(50.0));
    canvas.rotate(propellerRotation);
    canvas.drawLine(
      Offset(-s(41.957), 0),
      Offset(s(41.957), 0),
      propellerPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DroneSvgPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
