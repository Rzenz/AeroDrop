import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/providers/drone_provider.dart';
import '../../core/models/delivery_model.dart';

class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key});

  ({double lat, double lng}) _parseCoordinates(String coords) {
    try {
      final parts = coords.split(',');
      if (parts.length != 2) return (lat: 10.3157, lng: 123.8854);
      final latPart = parts[0].replaceAll(RegExp(r'[^0-9.-]'), '').trim();
      final lngPart = parts[1].replaceAll(RegExp(r'[^0-9.-]'), '').trim();
      double lat = double.tryParse(latPart) ?? 10.3157;
      double lng = double.tryParse(lngPart) ?? 123.8854;
      if (parts[0].contains('S')) lat = -lat;
      if (parts[1].contains('W')) lng = -lng;
      return (lat: lat, lng: lng);
    } catch (_) {
      return (lat: 10.3157, lng: 123.8854);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveries = ref.watch(deliveryProvider);
    final drones = ref.watch(droneProvider);
    final active = deliveries.where((d) => d.status == DeliveryStatus.inTransit).toList();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // Map area
          Positioned.fill(
            child: CustomPaint(
              painter: _DarkMapPainter(),
            ),
          ),

          // Drone positions
          ...drones.map((drone) {
            final parsed = _parseCoordinates(drone.currentCoordinates);
            final w = MediaQuery.of(context).size.width;
            final h = MediaQuery.of(context).size.height;

            // Map UCLM area lat [10.28, 10.35] and lng [123.85, 123.92]
            const latMin = 10.28;
            const latMax = 10.35;
            const lngMin = 123.85;
            const lngMax = 123.92;

            final pctX = (parsed.lng - lngMin) / (lngMax - lngMin);
            final pctY = (latMax - parsed.lat) / (latMax - latMin);

            final x = pctX.clamp(0.1, 0.9) * w;
            final y = pctY.clamp(0.2, 0.8) * h;

            return Positioned(
              left: x - 20,
              top: y - 20,
              child: _DroneMarker(drone.batteryLevel).animate(
                onPlay: (c) => c.repeat(),
              ).scale(
                duration: 1200.ms,
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.1, 1.1),
                curve: Curves.easeInOut,
              ).then().scale(
                duration: 1200.ms,
                begin: const Offset(1.1, 1.1),
                end: const Offset(1.0, 1.0),
                curve: Curves.easeInOut,
              ),
            );
          }),

          // Top header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
                      child: const Icon(Icons.my_location_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text('Live Fleet Tracker',
                        style: AppTextStyles.title(
                            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                                color: AppColors.success, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text('${drones.length} active',
                              style: const TextStyle(
                                  color: AppColors.success, fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: -0.1),
            ),
          ),

          // Bottom info sheet
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, AppColors.bgDark, AppColors.bgDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 120),
              child: active.isEmpty
                  ? GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const Icon(Icons.flight_land_rounded,
                              color: AppColors.textSecondaryDark),
                          const SizedBox(width: 12),
                          Text('No active deliveries',
                              style: AppTextStyles.body(
                                  fontSize: 14, color: AppColors.textSecondaryDark)),
                        ],
                      ),
                    )
                  : _ActiveDeliveryCard(delivery: active.first),
            ).animate().slideY(begin: 0.15, delay: 200.ms).fadeIn(delay: 200.ms),
          ),
        ],
      ),
    );
  }
}

class _DroneMarker extends StatelessWidget {
  final double battery;
  const _DroneMarker(this.battery);

  @override
  Widget build(BuildContext context) {
    final color = battery > 50
        ? AppColors.success
        : battery > 20
            ? AppColors.warning
            : AppColors.danger;
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
          ),
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, AppColors.primary]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)],
            ),
            child: const Icon(Icons.flight_rounded, color: Colors.white, size: 10),
          ),
        ],
      ),
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  final DeliveryModel delivery;
  const _ActiveDeliveryCard({required this.delivery});

  @override
  Widget build(BuildContext context) {
    final address = delivery.deliveryAddress;
    String pickup = 'Main Gate';
    String dropoff = address;
    if (address.startsWith('From ') && address.contains(' to ')) {
      pickup = address.substring(5, address.indexOf(' to '));
      dropoff = address.substring(address.indexOf(' to ') + 4);
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Package In Transit',
                        style: AppTextStyles.title(
                            fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(delivery.id.substring(0, 8).toUpperCase(),
                        style: AppTextStyles.body(
                            fontSize: 11, color: AppColors.textSecondaryDark)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('LIVE',
                    style: TextStyle(
                        color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _InfoChip(Icons.location_on_rounded, pickup,
                  AppColors.warning)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded,
                    color: AppColors.textSecondaryDark, size: 16),
              ),
              Expanded(child: _InfoChip(Icons.flag_rounded, dropoff,
                  AppColors.success)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoChip(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                style: const TextStyle(fontSize: 10, color: Colors.white70),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _DarkMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Base — deep dark map background
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFF0A0F1E));

    final gridPaint = Paint()
      ..color = const Color(0xFF1A2240)
      ..strokeWidth = 1;

    // Vertical grid lines
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    // Horizontal grid lines
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Road-like lines
    final roadPaint = Paint()
      ..color = const Color(0xFF1E2C50)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
        Offset(0, size.height * 0.35),
        Offset(size.width, size.height * 0.45),
        roadPaint);
    canvas.drawLine(
        Offset(size.width * 0.3, 0),
        Offset(size.width * 0.45, size.height),
        roadPaint);
    canvas.drawLine(
        Offset(0, size.height * 0.65),
        Offset(size.width, size.height * 0.6),
        roadPaint);

    // Glowing waypoints
    final glowPaint = Paint()
      ..color = const Color(0xFF6C63FF).withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.4), 40, glowPaint);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.6), 40, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _DarkMapPainter oldDelegate) => false;
}
