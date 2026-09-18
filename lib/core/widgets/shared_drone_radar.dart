import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_radii.dart';
import '../models/delivery_model.dart';
import '../models/drone_model.dart';
import '../models/telemetry_model.dart';
import '../providers/telemetry_provider.dart';
import '../providers/drone_provider.dart';
import '../widgets/neu_card.dart';

/// Reusable authoritative Drone Radar widget for Customer, Vendor, and Admin.
/// Displays live campus map, two-leg route trajectory (Base -> Vendor -> Dropoff),
/// animated drone radar ping, and authoritative telemetry metrics.
class SharedDroneRadar extends ConsumerStatefulWidget {
  final DeliveryModel? delivery;
  final bool isCompact;
  final VoidCallback? onTapDetails;
  final String? title;

  const SharedDroneRadar({
    super.key,
    this.delivery,
    this.isCompact = false,
    this.onTapDetails,
    this.title,
  });

  @override
  ConsumerState<SharedDroneRadar> createState() => _SharedDroneRadarState();
}

class _SharedDroneRadarState extends ConsumerState<SharedDroneRadar>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  static const _campusLocations = [
    {'name': 'Old Building (Main)', 'code': 'MAIN', 'x': 0.50, 'y': 0.43},
    {'name': 'Annex 1 Building', 'code': 'ANNEX-1', 'x': 0.43, 'y': 0.49},
    {'name': 'Annex 2 Building', 'code': 'ANNEX-2', 'x': 0.57, 'y': 0.49},
    {
      'name': 'Basic Education Building',
      'code': 'BASIC-ED',
      'x': 0.40,
      'y': 0.58,
    },
    {'name': 'Maritime Building', 'code': 'MARITIME', 'x': 0.60, 'y': 0.58},
  ];

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    final isDelivered = widget.delivery?.status == DeliveryStatus.delivered;
    if (!isDelivered) {
      _radarController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SharedDroneRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isDelivered = widget.delivery?.status == DeliveryStatus.delivered;
    if (isDelivered) {
      if (_radarController.isAnimating) {
        _radarController.stop();
      }
    } else {
      if (!_radarController.isAnimating) {
        _radarController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  Offset _offsetForBuilding(String? nameOrCode, Size size) {
    if (nameOrCode == null || nameOrCode.isEmpty) {
      return Offset(0.50 * size.width, 0.43 * size.height);
    }
    final query = nameOrCode.toLowerCase();
    for (final loc in _campusLocations) {
      final locName = (loc['name'] as String).toLowerCase();
      final locCode = (loc['code'] as String).toLowerCase();
      if (locCode == query ||
          locName.contains(query) ||
          query.contains(locCode)) {
        return Offset(
          (loc['x'] as double) * size.width,
          (loc['y'] as double) * size.height,
        );
      }
    }
    if (query.contains('annex 1') || query.contains('annex1')) {
      return Offset(0.43 * size.width, 0.49 * size.height);
    }
    if (query.contains('annex 2') || query.contains('annex2')) {
      return Offset(0.57 * size.width, 0.49 * size.height);
    }
    if (query.contains('basic')) {
      return Offset(0.40 * size.width, 0.58 * size.height);
    }
    if (query.contains('maritime')) {
      return Offset(0.60 * size.width, 0.58 * size.height);
    }
    return Offset(0.50 * size.width, 0.43 * size.height);
  }

  TelemetryModel? _safeWatchTelemetry(WidgetRef ref, String deliveryId) {
    try {
      return ref.watch(deliveryTelemetryProvider(deliveryId)) ??
          ref.watch(fleetTelemetryProvider);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.delivery;
    final telemetry = d != null ? _safeWatchTelemetry(ref, d.id) : null;

    final bool isAssigning = d?.status == DeliveryStatus.assigning;
    final bool isInTransit = d?.status == DeliveryStatus.inTransit;
    final bool isDelivered = d?.status == DeliveryStatus.delivered;
    final bool isStandby = d == null || (!isAssigning && !isInTransit && !isDelivered);

    final hubOffsetRatio = const Offset(0.50, 0.33); // Drone Hub at top center

    final legProgress = isDelivered
        ? 1.0
        : (isStandby
            ? 0.0
            : (telemetry?.progress != null && telemetry!.progress > 0
                ? telemetry.progress.clamp(0.0, 1.0)
                : d.progress.clamp(0.0, 1.0)));

    // ponytail: derive standby label from actual drones.status, not hardcoded
    final dronesList = ref.watch(droneProvider);
    final fallbackDrone = dronesList.firstOrNull;
    final droneDbStatus = fallbackDrone?.status;
    final String dbStatusLabel = switch (droneDbStatus) {
      DroneStatus.available => 'Available',
      DroneStatus.assigned => 'Assigned',
      DroneStatus.busy => 'Busy',
      DroneStatus.charging => 'Charging',
      DroneStatus.maintenance => 'Maintenance',
      DroneStatus.offline => 'Offline',
      null => 'Available',
    };

    // Status formatting
    final String statusBadgeText = isAssigning
        ? 'Heading to Pickup'
        : isInTransit
        ? 'In Flight / In Transit'
        : isDelivered
        ? 'Delivered'
        : '$dbStatusLabel — At Base';

    final Color statusColor = isAssigning
        ? AppColors.primaryLight
        : isInTransit
        ? AppColors.accent
        : isDelivered
        ? AppColors.success
        : AppColors.accent;

    final String pickupName = d?.pickupLocationName ?? 'Vendor Shop';
    final String dropoffName = d?.dropoffLocationName ?? d?.deliveryAddress ?? 'Campus';

    final String droneCodeDisplay = telemetry?.droneCode ??
        (d != null && d.droneId != null && d.droneId!.isNotEmpty
            ? d.droneId!
            : (fallbackDrone?.id ?? '—'));

    final String legDescription = isAssigning
        ? (legProgress >= 1.0
              ? 'Package Picked Up • Switching to Delivery'
              : 'Drone $droneCodeDisplay flying to $pickupName for pickup')
        : isInTransit
        ? (legProgress >= 1.0
              ? 'Arrived at Dropoff Point'
              : 'Drone $droneCodeDisplay flying to $dropoffName')
        : isDelivered
        ? 'Order successfully delivered to $dropoffName'
        : 'Stationed at Campus Drone Hub • Ready for dispatch';

    final height = widget.isCompact ? 330.0 : 420.0;

    return NeuCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Container(
          height: height,
          color: AppColors.cardDark,
          child: Column(
            children: [
              // Header bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardDark2,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.radar_rounded,
                        color: statusColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                widget.title ?? (isStandby ? 'Campus Drone Radar' : 'Live Drone Radar'),
                                style: AppTextStyles.subHead(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  statusBadgeText,
                                  style: AppTextStyles.caption(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            legDescription,
                            style: AppTextStyles.caption(
                              fontSize: 11,
                              color: AppColors.textSecondaryDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (widget.onTapDetails != null)
                      IconButton(
                        icon: const Icon(
                          Icons.open_in_new_rounded,
                          size: 18,
                          color: AppColors.textSecondaryDark,
                        ),
                        tooltip: 'View Details',
                        onPressed: widget.onTapDetails,
                      ),
                  ],
                ),
              ),

              // Interactive map canvas
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );

                    final hubPoint = Offset(
                      hubOffsetRatio.dx * size.width,
                      hubOffsetRatio.dy * size.height,
                    );
                    final vendorPoint = _offsetForBuilding(pickupName, size);
                    final customerPoint = _offsetForBuilding(dropoffName, size);

                    Offset startPoint;
                    Offset endPoint;
                    Offset dronePoint;

                    if (isAssigning) {
                      // Leg 1: Hub -> Vendor
                      startPoint = hubPoint;
                      endPoint = vendorPoint;
                      dronePoint = Offset(
                        startPoint.dx +
                            (endPoint.dx - startPoint.dx) * legProgress,
                        startPoint.dy +
                            (endPoint.dy - startPoint.dy) * legProgress,
                      );
                    } else if (isInTransit) {
                      // Leg 2: Vendor -> Customer
                      startPoint = vendorPoint;
                      endPoint = customerPoint;
                      dronePoint = Offset(
                        startPoint.dx +
                            (endPoint.dx - startPoint.dx) * legProgress,
                        startPoint.dy +
                            (endPoint.dy - startPoint.dy) * legProgress,
                      );
                    } else if (isDelivered) {
                      startPoint = vendorPoint;
                      endPoint = customerPoint;
                      dronePoint = customerPoint;
                    } else {
                      // Standby state: drone stationed at Campus Hub base
                      startPoint = hubPoint;
                      endPoint = hubPoint;
                      dronePoint = hubPoint;
                    }

                    return Stack(
                      children: [
                        // Map Background Image
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.85,
                            child: Image.asset(
                              'assets/images/uclm_map.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        // Route line painter (drawn when flight active/delivered)
                        if (!isStandby)
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _radarController,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: _RadarRoutePainter(
                                    start: startPoint,
                                    end: endPoint,
                                    drone: dronePoint,
                                    isAssigning: isAssigning,
                                    radarAngle:
                                        _radarController.value * 2 * math.pi,
                                    accentColor: statusColor,
                                  ),
                                );
                              },
                            ),
                          ),

                        // Campus Landmark Markers
                        for (final loc in _campusLocations)
                          _buildCampusMarker(
                            loc,
                            size,
                            pickupName,
                            dropoffName,
                          ),

                        // Hub Marker
                        Positioned(
                          left: hubPoint.dx - 16,
                          top: hubPoint.dy - 16,
                          child: _buildHubMarker(),
                        ),

                        // Drone Icon with Pulsing Radar
                        Positioned(
                          left: dronePoint.dx - 22,
                          top: dronePoint.dy - 22,
                          child: AnimatedBuilder(
                            animation: _radarController,
                            builder: (context, child) {
                              return _buildDroneMarker(
                                radarVal: _radarController.value,
                                color: statusColor,
                                isDelivered: isDelivered,
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Bottom live telemetry bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardDark2,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTelemetryItem(
                      icon: Icons.flight_takeoff_rounded,
                      label: 'Drone',
                      value: droneCodeDisplay,
                      color: AppColors.accent,
                    ),
                    _buildTelemetryItem(
                      icon: Icons.battery_charging_full_rounded,
                      label: 'Battery',
                      value: telemetry?.batteryLevel != null
                          ? '${telemetry!.batteryLevel!.round()}%'
                          : (d?.batteryLevel != null
                              ? '${d!.batteryLevel!.round()}%'
                              : (fallbackDrone?.batteryLevel != null
                                  ? '${fallbackDrone!.batteryLevel.round()}%'
                                  : '—')),
                      color: AppColors.success,
                    ),
                    _buildTelemetryItem(
                      icon: Icons.speed_rounded,
                      label: 'Speed',
                      value: isDelivered || isStandby
                          ? '0.0 km/h'
                          : (telemetry?.speed != null
                              ? '${telemetry!.speed!.toStringAsFixed(1)} km/h'
                              : ((d.currentSpeed ?? 0) > 0
                                  ? '${d.currentSpeed!.toStringAsFixed(1)} km/h'
                                  : '—')),
                      color: AppColors.info,
                    ),
                    _buildTelemetryItem(
                      icon: Icons.alt_route_rounded,
                      label: isStandby
                          ? 'Status'
                          : (isAssigning
                              ? 'Pickup Progress'
                              : 'Delivery Progress'),
                      value: isStandby ? dbStatusLabel : '${(legProgress * 100).round()}%',
                      color: statusColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampusMarker(
    Map<String, dynamic> loc,
    Size size,
    String pickupName,
    String dropoffName,
  ) {
    final x = (loc['x'] as double) * size.width;
    final y = (loc['y'] as double) * size.height;
    final locName = loc['name'] as String;
    final locCode = loc['code'] as String;

    final isPickup =
        pickupName.toLowerCase().contains(locCode.toLowerCase()) ||
        pickupName.toLowerCase().contains(locName.toLowerCase());
    final isDropoff =
        dropoffName.toLowerCase().contains(locCode.toLowerCase()) ||
        dropoffName.toLowerCase().contains(locName.toLowerCase());

    final markerColor = isPickup
        ? AppColors.primaryLight
        : isDropoff
        ? AppColors.accent
        : Colors.white70;

    return Positioned(
      left: x - 12,
      top: y - 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: markerColor.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: markerColor.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              isPickup
                  ? Icons.storefront_rounded
                  : isDropoff
                  ? Icons.location_on_rounded
                  : Icons.apartment_rounded,
              size: 12,
              color: AppColors.bgDark,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              locCode,
              style: AppTextStyles.caption(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: markerColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHubMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.warning.withValues(alpha: 0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.hub_rounded,
            size: 14,
            color: AppColors.bgDark,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'BASE HUB',
            style: AppTextStyles.caption(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: AppColors.warning,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDroneMarker({
    required double radarVal,
    required Color color,
    bool isDelivered = false,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse ring (only active when not delivered)
        if (!isDelivered && radarVal > 0)
          Container(
            width: 44 * radarVal,
            height: 44 * radarVal,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: (1.0 - radarVal).clamp(0.0, 1.0)),
                width: 1.5,
              ),
            ),
          ),
        // Central icon badge
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            isDelivered ? Icons.check_circle_rounded : Icons.navigation_rounded,
            size: 16,
            color: AppColors.bgDark,
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.caption(
                fontSize: 9,
                color: AppColors.textSecondaryDark,
              ),
            ),
            Text(
              value,
              style: AppTextStyles.caption(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RadarRoutePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Offset drone;
  final bool isAssigning;
  final double radarAngle;
  final Color accentColor;

  _RadarRoutePainter({
    required this.start,
    required this.end,
    required this.drone,
    required this.isAssigning,
    required this.radarAngle,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Planned route path
    final routePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.4)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, routePaint);

    // Traveled path
    final traveledPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, drone, traveledPaint);

    // Radar scan arc around drone
    final radarPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(drone, 24, radarPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarRoutePainter oldDelegate) {
    return oldDelegate.drone != drone ||
        oldDelegate.radarAngle != radarAngle ||
        oldDelegate.accentColor != accentColor;
  }
}
