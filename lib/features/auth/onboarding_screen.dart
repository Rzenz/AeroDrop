import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ScaleEffect;
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _radarAnimController;

  @override
  void initState() {
    super.initState();
    _radarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _radarAnimController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 680;
    final isLast = _currentPage == 2;

    final List<_SlideData> slides = [
      _SlideData(
        title: 'Fast Campus\nDeliveries',
        description:
            'Request drone deliveries across UCLM Campus instantly. Send documents, food, or electronics directly to study halls and buildings.',
        gradientBegin: Alignment.topLeft,
        gradientEnd: Alignment.bottomRight,
        colors: [const Color(0xFF0D1B2A), const Color(0xFF1565C0)],
        illustrationBuilder: (context, animController) {
          return Center(
            child: _DroneAndTruckIllustration(
              animController: animController,
              size: isSmallScreen ? 180.0 : 240.0,
            ),
          );
        },
      ),
      _SlideData(
        title: 'Live Fleet\nTracking',
        description:
            'Watch your package fly. Track drone coordinates, altitude, and ETA in real-time using our interactive flight radar.',
        gradientBegin: Alignment.topRight,
        gradientEnd: Alignment.bottomLeft,
        colors: [const Color(0xFF0D1B2A), const Color(0xFF00838F)],
        illustrationBuilder: (context, animController) {
          return _RadarIllustration(
            animController: animController,
            size: isSmallScreen ? 160.0 : 220.0,
          );
        },
      ),
      _SlideData(
        title: 'Cashless\nPayments',
        description:
            'Pay using Cash, GCash, or major cards directly at checkout. Completely secure and hassle-free.',
        gradientBegin: Alignment.bottomCenter,
        gradientEnd: Alignment.topCenter,
        colors: [const Color(0xFF0D1B2A), const Color(0xFF00796B)],
        illustrationBuilder: (context, animController) {
          final size = isSmallScreen ? 170.0 : 230.0;
          return Center(
            child: AnimatedBuilder(
              animation: animController,
              builder: (context, child) {
                // Subtle floating up-and-down effect using the slide animation controller
                final floatOffset = Offset(0, -8 * math.sin(animController.value * 2 * math.pi));
                return Transform.translate(
                  offset: floatOffset,
                  child: Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // perspective
                      ..rotateY(0.08) // subtle 3D tilt
                      ..rotateX(0.04),
                    alignment: Alignment.center,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: size * 1.1,
                height: size * 0.7,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Card Chip
                        Container(
                          width: 32,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD600), Color(0xFFFFCA28)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // Contactless icon
                        const Icon(
                          Icons.wifi_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ],
                    ),
                    const Text(
                      '••••  ••••  ••••  8842',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CARDHOLDER',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              'AERODROP MEMBER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.credit_card_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ];

    final currentSlide = slides[_currentPage];

    return Scaffold(
      body: Stack(
        children: [
          // Background PageView for full-bleed gradient transitions
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: currentSlide.gradientBegin,
                  end: currentSlide.gradientEnd,
                  colors: currentSlide.colors,
                ),
              ),
            ),
          ),

          // Content PageView
          SafeArea(
            child: Column(
              children: [
                // Top Skip Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: AnimatedOpacity(
                      opacity: isLast ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: isLast,
                        child: TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context.go('/login');
                          },
                          child: Text(
                            'Skip',
                            style: AppTextStyles.subHead(
                              fontSize: 15,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Illustration & Text Slider
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: slides.length,
                    itemBuilder: (context, index) {
                      final slide = slides[index];
                      return Column(
                        children: [
                          // Top 55% space for Illustration
                          Expanded(
                            flex: 11,
                            child: slide.illustrationBuilder(context, _radarAnimController)
                                .animate(key: ValueKey('illust_$index'))
                                .scale(duration: 600.ms, curve: Curves.elasticOut)
                                .fadeIn(duration: 400.ms),
                          ),
                          // Bottom space for Title & Description
                          Expanded(
                            flex: 9,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      slide.title,
                                      style: AppTextStyles.display(
                                        fontSize: isSmallScreen ? 26 : 34,
                                        letterSpacing: -0.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    )
                                        .animate(key: ValueKey('title_$index'))
                                        .fadeIn(duration: 400.ms)
                                        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                                    const SizedBox(height: 12),
                                    Text(
                                      slide.description,
                                      style: AppTextStyles.body(
                                        fontSize: isSmallScreen ? 13.5 : 15,
                                        color: AppColors.textSecondaryDark,
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    )
                                        .animate(key: ValueKey('desc_$index'))
                                        .fadeIn(delay: 150.ms, duration: 400.ms)
                                        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Bottom Controls Area
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, isSmallScreen ? 16 : 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Smooth Page Indicator with scale effect
                      SmoothPageIndicator(
                        controller: _pageController,
                        count: slides.length,
                        effect: const ScaleEffect(
                          dotColor: AppColors.borderDark,
                          activeDotColor: AppColors.accent,
                          dotHeight: 8,
                          dotWidth: 8,
                          scale: 1.6,
                          spacing: 12,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 20 : 36),
                      // Gradient Button CTA
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GradientButton(
                          text: isLast ? 'Get Started' : 'Next',
                          onPressed: _next,
                          icon: isLast
                              ? Icons.rocket_launch_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideData {
  final String title;
  final String description;
  final Alignment gradientBegin;
  final Alignment gradientEnd;
  final List<Color> colors;
  final Widget Function(BuildContext, AnimationController) illustrationBuilder;

  _SlideData({
    required this.title,
    required this.description,
    required this.gradientBegin,
    required this.gradientEnd,
    required this.colors,
    required this.illustrationBuilder,
  });
}

class _RadarIllustration extends StatelessWidget {
  final AnimationController animController;
  final double size;

  const _RadarIllustration({
    required this.animController,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer rotating ring
            AnimatedBuilder(
              animation: animController,
              builder: (_, _) => Transform.rotate(
                angle: animController.value * 2 * math.pi,
                child: CustomPaint(
                  size: Size(size, size),
                  painter: _DashedCirclePainter(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    radius: size / 2 - 10,
                    dashCount: 16,
                  ),
                ),
              ),
            ),
            // Middle ring
            Container(
              width: size * 0.68,
              height: size * 0.68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
            ),
            // Scan Sweep
            AnimatedBuilder(
              animation: animController,
              builder: (_, _) => Opacity(
                opacity: (1 - animController.value).clamp(0.1, 0.65),
                child: Container(
                  width: size * 0.66,
                  height: size * 0.66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      startAngle: 0,
                      endAngle: animController.value * 2 * math.pi,
                      colors: [
                        Colors.transparent,
                        AppColors.accent.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Core pulsing dot
            Container(
              width: size * 0.1,
              height: size * 0.1,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.accentGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double radius;
  final int dashCount;

  _DashedCirclePainter({
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
    final dashLength = angleStep * 0.4;

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
  bool shouldRepaint(covariant _DashedCirclePainter old) => false;
}

class _PropellerWidget extends StatefulWidget {
  final double size;

  const _PropellerWidget({
    required this.size,
  });

  @override
  State<_PropellerWidget> createState() => _PropellerWidgetState();
}

class _PropellerWidgetState extends State<_PropellerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _spinController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _spinController.value * 2 * math.pi,
          child: child,
        );
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Motor Hub
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.white30,
                shape: BoxShape.circle,
              ),
            ),
            // Blades
            Container(
              width: widget.size,
              height: 1.2,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DroneAndTruckIllustration extends StatelessWidget {
  final AnimationController animController;
  final double size;

  const _DroneAndTruckIllustration({
    required this.animController,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: animController,
        builder: (context, child) {
          // Floating hovering animation
          final floatOffset = Offset(0, -12 * math.sin(animController.value * 2 * math.pi));
          return Transform.translate(
            offset: floatOffset,
            child: CustomPaint(
              size: Size(size, size),
              painter: _DroneSvgPainter(animationValue: animController.value),
            ),
          );
        },
      ),
    );
  }
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
    // <path d="M94.65,91.35v17.77c-8.24,3.98-17.76,7.46-29.74,9.89v-27.66c0-8.21,6.66-14.87,14.87-14.87,4.1,0,7.82,1.66,10.51,4.36,2.69,2.69,4.36,6.4,4.36,10.51Z"/>
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
    // <line x1="79.783" y1="76.478" x2="79.783" y2="50"/>
    canvas.drawLine(Offset(s(79.783), s(76.478)), Offset(s(79.783), s(50.0)), linePaint);

    // 3. Right Motor Mount
    // <path d="M322.99,91.35v24.59c-12.03-3.64-21.31-8.42-29.74-13.5v-11.09c0-8.21,6.66-14.87,14.87-14.87,4.1,0,7.82,1.66,10.51,4.36,2.69,2.69,4.36,6.4,4.36,10.51Z"/>
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
    // <line x1="308.12" y1="76.478" x2="308.12" y2="50"/>
    canvas.drawLine(Offset(s(308.12), s(76.478)), Offset(s(308.12), s(50.0)), linePaint);

    // 5. Lower body structure
    // <path d="M271.217,155.102v11.181c0,8.945-7.251,16.196-16.196,16.196h-110.043c-8.945,0-16.196-7.251-16.196-16.196v-11.181"/>
    final path3 = Path()
      ..moveTo(s(271.217), s(155.102))
      ..lineTo(s(271.217), s(166.283))
      ..cubicTo(s(271.217), s(175.228), s(263.966), s(182.479), s(255.021), s(182.479))
      ..lineTo(s(144.979), s(182.479))
      ..cubicTo(s(136.034), s(182.479), s(128.783), s(175.228), s(128.783), s(166.283))
      ..lineTo(s(128.783), s(155.102));
    canvas.drawPath(path3, linePaint);

    // 6. Drone Main Aerodynamic Body
    // <path d="M335.381,119.043c-57.801-11.688-58.25-47.577-135.231-47.622h0c-.024-.001-.048,0-.072,0s-.048,0-.072,0h0c-76.981.047-77.43,35.935-135.231,47.623-8.527,1.724-14.696,9.158-14.696,17.858h0c0,10.052,8.149,18.201,18.2,18.201h263.599c10.052,0,18.201-8.149,18.201-18.201h0c0-8.7-6.169-16.134-14.696-17.858Z"/>
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
    // <circle cx="200" cy="113.261" r="20.935"/>
    canvas.drawCircle(Offset(s(200.0), s(113.261)), s(20.935), linePaint);

    // 8. Left Leg
    // <path d="M94.297,155.102l-19.181,43.472c-6.409,14.525-3.569,31.469,7.225,43.111l28.39,30.619"/>
    final path5 = Path()
      ..moveTo(s(94.297), s(155.102))
      ..lineTo(s(75.116), s(198.574))
      ..cubicTo(s(68.707), s(213.099), s(71.547), s(230.043), s(82.341), s(241.685))
      ..lineTo(s(110.731), s(272.304));
    canvas.drawPath(path5, linePaint);

    // 9. Right Leg
    // <path d="M305.703,155.102l19.181,43.472c6.409,14.525,3.569,31.469-7.225,43.111l-28.39,30.619"/>
    final path6 = Path()
      ..moveTo(s(305.703), s(155.102))
      ..lineTo(s(324.884), s(198.574))
      ..cubicTo(s(331.293), s(213.099), s(328.453), s(230.043), s(317.659), s(241.685))
      ..lineTo(s(289.269), s(272.304));
    canvas.drawPath(path6, linePaint);

    // 10. Secondary/Back Box Part
    // <path d="M174.735,220.319h98.66c8.566,0,15.51,6.944,15.51,15.51v98.66c0,8.566-6.944,15.51-15.51,15.51h-98.66"
    final path7 = Path()
      ..moveTo(s(174.735), s(220.319))
      ..lineTo(s(273.395), s(220.319))
      ..cubicTo(s(281.961), s(220.319), s(288.905), s(227.263), s(288.905), s(235.829))
      ..lineTo(s(288.905), s(334.489))
      ..cubicTo(s(288.905), s(343.055), s(281.961), s(350.0), s(273.395), s(350.0))
      ..lineTo(s(174.735), s(350.0));
    canvas.drawPath(path7, linePaint);

    // 11. Main Cargo Box
    // <rect x="111.225" y="220.319" width="129.681" height="129.681" rx="15.51" ry="15.51"/>
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s(111.225), s(220.319), s(129.681), s(129.681)),
        Radius.circular(s(15.51)),
      ),
      linePaint,
    );

    // 12. Box Latch/Ribbon (Indigo in SVG)
    // <path d="M159.289,220.319h33.552v39.787c0,4.881-3.963,8.843-8.843,8.843h-15.865c-4.881,0-8.843-3.963-8.843-8.843v-39.787h0Z"/>
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
