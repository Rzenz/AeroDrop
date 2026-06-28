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
          final size = isSmallScreen ? 180.0 : 250.0;
          return Center(
            child: AnimatedBuilder(
              animation: animController,
              builder: (context, child) {
                // Subtle floating up-and-down effect
                final floatOffset = Offset(0, -10 * math.sin(animController.value * 2 * math.pi));
                return Transform.translate(
                  offset: floatOffset,
                  child: child,
                );
              },
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Drone Body Glow Shadow
                    Container(
                      width: size * 0.4,
                      height: size * 0.4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    // Drone Arms (X-Shape) - Ultra Minimalist Thin Lines
                    Transform.rotate(
                      angle: math.pi / 4,
                      child: Container(
                        width: size * 0.72,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Transform.rotate(
                      angle: -math.pi / 4,
                      child: Container(
                        width: size * 0.72,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Drone Propeller Motors (4 corners)
                    ...List.generate(4, (index) {
                      final angle = (index * 90 + 45) * math.pi / 180;
                      final dist = size * 0.36;
                      final x = dist * math.cos(angle);
                      final y = dist * math.sin(angle);
                      return Positioned(
                        left: (size / 2) + x - (size * 0.125),
                        top: (size / 2) + y - (size * 0.125),
                        child: _PropellerWidget(
                          size: size * 0.25,
                        ),
                      );
                    }),
                    // Central Drone Body - Minimalist Glassmorphic Circle
                    Container(
                      width: size * 0.35,
                      height: size * 0.35,
                      decoration: BoxDecoration(
                        color: const Color(0xFF101926),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.radar_rounded,
                        color: Colors.white70,
                        size: 32,
                      ),
                    ),
                    // Camera Lens Accent (Gold Dot)
                    Positioned(
                      bottom: size * 0.36,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
