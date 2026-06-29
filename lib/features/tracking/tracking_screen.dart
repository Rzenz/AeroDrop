import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/models/delivery_model.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _flightProgressController;

  // UCLM campus bounds for coordinate mapping
  static const double latMin = 10.3250;
  static const double latMax = 10.3310;
  static const double lngMin = 123.9480;
  static const double lngMax = 123.9540;

  // Hub coordinates (start)
  static const double hubLat = 10.3276;
  static const double hubLng = 123.9507;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _flightProgressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
    // ponytail: removed _simulationTimer that called setState((){}) every 1s
    // for no data change. The two AnimationControllers already drive repaints.
  }

  @override
  void dispose() {
    _radarController.dispose();
    _flightProgressController.dispose();
    super.dispose();
  }

  ({double lat, double lng}) _parseCoordinates(String coords) {
    try {
      final parts = coords.split(',');
      if (parts.length != 2) return (lat: hubLat, lng: hubLng);
      final latPart = parts[0].replaceAll(RegExp(r'[^0-9.-]'), '').trim();
      final lngPart = parts[1].replaceAll(RegExp(r'[^0-9.-]'), '').trim();
      double lat = double.tryParse(latPart) ?? hubLat;
      double lng = double.tryParse(lngPart) ?? hubLng;
      if (parts[0].contains('S')) lat = -lat;
      if (parts[1].contains('W')) lng = -lng;
      return (lat: lat, lng: lng);
    } catch (_) {
      return (lat: hubLat, lng: hubLng);
    }
  }

  Offset _mapCoordsToOffset(double lat, double lng, Size size) {
    final pctX = (lng - lngMin) / (lngMax - lngMin);
    final pctY = (latMax - lat) / (latMax - latMin);
    return Offset(
      pctX.clamp(0.1, 0.9) * size.width,
      pctY.clamp(0.2, 0.8) * size.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<DeliveryModel>>(deliveryProvider, (previous, next) {
      if (previous != null) {
        for (final nextDel in next) {
          final prevDel = previous.firstWhere((d) => d.id == nextDel.id, orElse: () => nextDel);
          if (prevDel.status == DeliveryStatus.inTransit && nextDel.status == DeliveryStatus.delivered) {
            context.go('/user/delivery/completed');
            break;
          }
        }
      }
    });

    final deliveries = ref.watch(deliveryProvider);
    final activeDeliveries = deliveries
        .where((d) => d.status == DeliveryStatus.inTransit)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);

          double targetLat = 10.3265;
          double targetLng = 123.9515;

          if (activeDeliveries.isNotEmpty) {
            final activeDel = activeDeliveries.first;
            final parsedTarget = _parseCoordinates(activeDel.deliveryAddress);
            targetLat = parsedTarget.lat;
            targetLng = parsedTarget.lng;
            if (targetLat == hubLat && targetLng == hubLng) {
              if (activeDel.deliveryAddress.toLowerCase().contains('library')) {
                targetLat = 10.3288;
                targetLng = 123.9525;
              } else if (activeDel.deliveryAddress.toLowerCase().contains('gate')) {
                targetLat = 10.3258;
                targetLng = 123.9495;
              } else {
                targetLat = 10.3265;
                targetLng = 123.9515;
              }
            }
          }

          final double progress = _flightProgressController.value;
          final double currentLat = hubLat + (targetLat - hubLat) * progress;
          final double currentLng = hubLng + (targetLng - hubLng) * progress;

          final startOffset = _mapCoordsToOffset(hubLat, hubLng, size);
          final endOffset = _mapCoordsToOffset(targetLat, targetLng, size);
          final droneOffset = _mapCoordsToOffset(currentLat, currentLng, size);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Real Map Background centered on UCLM Campus
              Positioned.fill(
                child: Opacity(
                  opacity: 0.85, // Slightly dimmed to keep the overlay HUD highly readable
                  child: Image.asset(
                    'assets/images/uclm_map.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // Vector Map Painter (Now paints overlay path and radar on top of the real map)
              Positioned.fill(
                child: CustomPaint(
                  painter: _VectorMapPainter(
                    startPoint: startOffset,
                    endPoint: endOffset,
                    dronePoint: droneOffset,
                    flightProgress: progress,
                    radarAngle: _radarController.value * 2 * math.pi,
                  ),
                ),
              ),

              // Drone Marker
              Positioned(
                left: droneOffset.dx - 28,
                top: droneOffset.dy - 28,
                child: _DroneMarkerWidget(
                  radarValue: _radarController.value,
                ),
              ),

              // Start/End Landmarks
              Positioned(
                left: startOffset.dx - 12,
                top: startOffset.dy - 12,
                child: const _LandmarkPin(
                  icon: Icons.business_rounded,
                  color: AppColors.primaryLight,
                ),
              ),

              Positioned(
                left: endOffset.dx - 12,
                top: endOffset.dy - 12,
                child: _LandmarkPin(
                  icon: Icons.flag_rounded,
                  color: AppColors.accent,
                ),
              ),

              // Top Telemetry HUD Overlay
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      borderRadius: BorderRadius.circular(24),
                      borderGradient: const LinearGradient(
                        colors: [AppColors.accent, AppColors.primary, Colors.transparent],
                        stops: [0.0, 0.5, 1.0],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.radar_rounded,
                              color: AppColors.accent,
                              size: 22,
                            ),
                          ).animate(onPlay: (c) => c.repeat()).shimmer(
                                duration: 2000.ms,
                                color: Colors.white24,
                              ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Telemetry Link Active',
                                  style: AppTextStyles.title(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Lat: ${currentLat.toStringAsFixed(5)} • Lng: ${currentLng.toStringAsFixed(5)}',
                                  style: AppTextStyles.body(
                                    fontSize: 11,
                                    color: AppColors.textSecondaryDark,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.success.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'ONLINE',
                              style: AppTextStyles.label(
                                fontSize: 10,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn().slideY(begin: -0.1, end: 0),

              // Bottom Detail Panel
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.bgDark,
                        AppColors.bgDark,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.25, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 110),
                  child: activeDeliveries.isEmpty
                      ? GlassCard(
                          padding: const EdgeInsets.all(22),
                          borderRadius: BorderRadius.circular(24),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.flight_land_rounded,
                                  color: AppColors.textSecondaryDark,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'No Deliveries in Progress',
                                      style: AppTextStyles.title(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Fleet is currently docked at UCLM Hub',
                                      style: AppTextStyles.body(
                                        fontSize: 12,
                                        color: AppColors.textSecondaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : _ActiveTrackingCard(
                          delivery: activeDeliveries.first,
                          progress: progress,
                        ),
                ),
              ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0),
            ],
          );
        },
      ),
    );
  }
}

class _DroneMarkerWidget extends StatelessWidget {
  final double radarValue;

  const _DroneMarkerWidget({required this.radarValue});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing radar ring
          Container(
            width: 56 * radarValue,
            height: 56 * radarValue,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 1 - radarValue),
                width: 1.5,
              ),
            ),
          ),
          // Inner core glow
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.accentGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.navigation_rounded,
              color: AppColors.bgDark,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandmarkPin extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _LandmarkPin({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: color,
        size: 14,
      ),
    );
  }
}

class _ActiveTrackingCard extends StatelessWidget {
  final DeliveryModel delivery;
  final double progress;

  const _ActiveTrackingCard({
    required this.delivery,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).toInt();

    return GlassCard(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(26),
      borderGradient: const LinearGradient(
        colors: [AppColors.accent, AppColors.primary, Colors.transparent],
        stops: [0.0, 0.5, 1.0],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'FLIGHT # ${delivery.id.substring(0, 5).toUpperCase()}',
                  style: AppTextStyles.label(
                    fontSize: 10,
                    color: AppColors.bgDark,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'ETA: ${delivery.eta}',
                style: AppTextStyles.title(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            delivery.packageName,
            style: AppTextStyles.title(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Destination: ${delivery.deliveryAddress}',
            style: AppTextStyles.body(
              fontSize: 13,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transit Progress',
                style: AppTextStyles.body(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              Text(
                '$percentage%',
                style: AppTextStyles.title(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.borderDark,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),
          // Gradient Button for Full Telemetry Details
          GradientButton(
            text: 'View Telemetry Logs',
            height: 44,
            onPressed: () => context.push('/user/track/details?id=${delivery.id}'),
            icon: Icons.analytics_outlined,
          ),
        ],
      ),
    );
  }
}

class _VectorMapPainter extends CustomPainter {
  final Offset startPoint;
  final Offset endPoint;
  final Offset dronePoint;
  final double flightProgress;
  final double radarAngle;

  const _VectorMapPainter({
    required this.startPoint,
    required this.endPoint,
    required this.dronePoint,
    required this.flightProgress,
    required this.radarAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Only paint the path and radar sweep. The background map is now rendered by the Image.network underneath.

    final pathPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.15)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(startPoint, endPoint, pathPaint);

    final activePathPaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double dashWidth = 6.0;
    final double dashSpace = 6.0;
    double distance = 0.0;
    final double totalDistance = (endPoint - startPoint).distance;
    final double activeDistance = totalDistance * flightProgress;

    final Offset vector = (endPoint - startPoint) / totalDistance;

    while (distance < activeDistance) {
      final Offset startDash = startPoint + vector * distance;
      distance += dashWidth;
      final Offset endDash = startPoint + vector * math.min(distance, activeDistance);
      canvas.drawLine(startDash, endDash, activePathPaint);
      distance += dashSpace;
    }

    final radarPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: [
          Colors.transparent,
          AppColors.accent.withValues(alpha: 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(radarAngle),
      ).createShader(
        Rect.fromCircle(center: dronePoint, radius: 140),
      );

    canvas.drawCircle(dronePoint, 140, radarPaint);
  }

  @override
  bool shouldRepaint(covariant _VectorMapPainter oldDelegate) {
    return oldDelegate.flightProgress != flightProgress ||
        oldDelegate.radarAngle != radarAngle ||
        oldDelegate.dronePoint != dronePoint;
  }
}
