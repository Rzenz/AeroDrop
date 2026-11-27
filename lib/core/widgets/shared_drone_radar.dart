import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_radii.dart';
import '../models/delivery_model.dart';
import '../models/flight_phase.dart';
import '../models/drone_model.dart';
import '../models/telemetry_model.dart';
import '../providers/telemetry_provider.dart';
import '../providers/drone_provider.dart';
import '../providers/delivery_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/neu_card.dart';
import 'campus_markers.dart';

/// Reusable authoritative Drone Radar widget for Customer, Vendor, and Admin.
/// Displays live OpenStreetMap campus map (with offline fallback to static asset),
/// two-leg route trajectory (Base -> Vendor -> Dropoff), animated drone radar ping,
/// and authoritative telemetry metrics.
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
  late final MapController _mapController;
  Timer? _staleCheckTimer;
  Timer? _livePollTimer;

  bool _userHasPanned = false;
  bool _isOfflineFallback = false;
  int _tileErrorCount = 0;
  bool _isMapReady = false;
  LatLng? _lastFollowedLatLng;

  // Until _loadBaseHubLocation() reads BASE-HUB; the database is the source of truth.
  (double, double) _baseHubCoords = (10.3253829, 123.9537052);

  /// The campus_locations rows, read in build from campusLocationsProvider.
  /// Every name and coordinate the radar draws comes from here.
  List<CampusLocation> _locations = const [];

  static const _campusCenter = LatLng(10.3255, 123.9539);
  static final _campusBounds = LatLngBounds(
    const LatLng(10.3210, 123.9480),
    const LatLng(10.3300, 123.9600),
  );

  /// Where each campus location sits on the OFFLINE schematic, keyed by
  /// location_code. Layout only: the schematic is a stylised drawing, not a
  /// projection, so these cannot be computed from coordinates. Names and
  /// coordinates come from campus_locations (campusLocationsProvider), so a
  /// building moved in the database moves on the live map with no code
  /// change. A code missing here still draws on the live map; it just has no
  /// place on the schematic.
  static const _schematicLayout = <String, Offset>{
    'MAIN': Offset(0.50, 0.43),
    'ANNEX-2': Offset(0.57, 0.49),
    'BASIC-ED': Offset(0.40, 0.58),
    'MARITIME': Offset(0.60, 0.58),
    // Below BASIC-ED, clear of its marker down to a 320 px wide phone.
    kTestDropCode: Offset(0.44, 0.76),
  };

  /// A row whose position is known: the model reads a missing one as 0, 0.
  static bool _hasPosition(CampusLocation l) =>
      l.latitude != 0 || l.longitude != 0;

  CampusLocation? _rowByCode(String code) {
    for (final l in _locations) {
      if (l.locationCode.toUpperCase() == code && _hasPosition(l)) return l;
    }
    return null;
  }

  /// The campus location a delivery names, matched against the rows: by code
  /// or exact name first, then by one name containing the other.
  CampusLocation? _rowFor(String? nameOrCode) {
    final q = nameOrCode?.trim().toLowerCase() ?? '';
    if (q.isEmpty) return null;
    final rows = _locations.where(
      (l) => _hasPosition(l) && !isHubLocationCode(l.locationCode, l.name),
    );
    for (final l in rows) {
      if (l.locationCode.toLowerCase() == q || l.name.toLowerCase() == q) {
        return l;
      }
    }
    for (final l in rows) {
      final name = l.name.toLowerCase();
      if (name.isNotEmpty && (name.contains(q) || q.contains(name))) return l;
    }
    return null;
  }

  /// The hub: its row when loaded, else what _loadBaseHubLocation() read.
  (double, double) get _hubCoords {
    final row = _rowByCode('BASE-HUB');
    return row != null ? (row.latitude, row.longitude) : _baseHubCoords;
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadBaseHubLocation();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    final isDelivered = widget.delivery?.status == DeliveryStatus.delivered;
    if (!isDelivered) {
      _radarController.repeat();
    }
    _staleCheckTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkStaleDrone(),
    );
    _livePollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final d = widget.delivery;
        if (d != null) {
          try {
            ref
                .read(deliveryTelemetryProvider(d.id).notifier)
                .loadLatestTelemetry();
          } catch (_) {}
        }
        try {
          ref.read(fleetTelemetryProvider.notifier).loadFleetTelemetry();
          ref.read(droneProvider.notifier).loadDronesFromSupabase();
        } catch (_) {}
      });
    });
  }

  void _loadBaseHubLocation() async {
    if (!SupabaseService.isConfigured) return;
    try {
      final res = await SupabaseService.client
          .from('campus_locations')
          .select('latitude, longitude')
          .eq('location_code', 'BASE-HUB')
          .maybeSingle();
      if (res != null && mounted) {
        final lat = (res['latitude'] as num?)?.toDouble();
        final lng = (res['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _baseHubCoords = (lat, lng);
            });
          });
        }
      }
    } catch (_) {}
  }

  void _checkStaleDrone() async {
    if (!mounted || !SupabaseService.isConfigured) return;
    try {
      final drones = ref.read(droneProvider);
      final returningDrone = drones
          .where((d) => d.status == DroneStatus.returning)
          .firstOrNull;
      // Without the drone's real id there is nothing to recover: skip rather
      // than call the RPC with an id that does not exist.
      if (returningDrone != null && returningDrone.dbId.isNotEmpty) {
        final res = await SupabaseService.client.rpc(
          'recover_stale_returning_drone',
          params: {'p_drone_id': returningDrone.dbId},
        );
        if (res != null && (res as Map)['recovered'] == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(droneProvider.notifier).loadDronesFromSupabase();
          });
        }
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant SharedDroneRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isDelivered = widget.delivery?.status == DeliveryStatus.delivered;
      final drones = ref.read(droneProvider);
      final isReturning = drones.any((d) => d.status == DroneStatus.returning);
      if (isDelivered && !isReturning) {
        if (_radarController.isAnimating) {
          _radarController.stop();
        }
      } else {
        if (!_radarController.isAnimating) {
          _radarController.repeat();
        }
      }
    });
  }

  @override
  void dispose() {
    _isMapReady = false;
    _staleCheckTimer?.cancel();
    _livePollTimer?.cancel();
    _radarController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  (double, double) _coordinatesForBuilding(String? nameOrCode) {
    if (nameOrCode == null || nameOrCode.isEmpty) {
      return (10.325210, 123.953201);
    }
    final query = nameOrCode.toLowerCase();
    if (query.contains('hub') || query.contains('base')) {
      return _hubCoords;
    }
    final row = _rowFor(nameOrCode);
    if (row != null) return (row.latitude, row.longitude);
    // LAST RESORT, before the rows have loaded: stale copies of
    // campus_locations (positions as of migration 43).
    // Before the building names: none of them should claim the test point.
    if (query.contains('test drop') || query.contains('test-drop')) {
      return (10.3256272, 123.9539688);
    }
    if (query.contains('annex 2') ||
        query.contains('annex2') ||
        query.contains('annex-2')) {
      return (10.325633, 123.953770);
    }
    if (query.contains('basic')) {
      return (10.325133, 123.953853);
    }
    if (query.contains('maritime')) {
      return (10.3261650, 123.9543871);
    }
    if (query.contains('main') || query.contains('old')) {
      return (10.325210, 123.953201);
    }
    return (10.325210, 123.953201);
  }

  /// Places a real coordinate on the offline schematic, which is a diagram
  /// rather than a map: positions are interpolated between two buildings the
  /// schematic already places (Main and Maritime), then kept on the canvas.
  /// Approximate by nature; the online map shows the true position.
  Offset _offsetForCoordinates((double, double) coords, Size size) {
    final a = _rowByCode('MAIN');
    final b = _rowByCode('MARITIME');
    final pa = _schematicLayout['MAIN']!;
    final pb = _schematicLayout['MARITIME']!;
    // Without both rows there is nothing to interpolate between
    if (a == null || b == null) {
      return Offset(pa.dx * size.width, pa.dy * size.height);
    }
    double lerp(double g0, double g1, double p0, double p1, double value) {
      if (g1 == g0) return p0;
      return (p0 + (value - g0) / (g1 - g0) * (p1 - p0)).clamp(0.06, 0.94);
    }

    return Offset(
      lerp(a.longitude, b.longitude, pa.dx, pb.dx, coords.$2) * size.width,
      lerp(a.latitude, b.latitude, pa.dy, pb.dy, coords.$1) * size.height,
    );
  }

  LatLng _latLngForBuilding(String? nameOrCode) {
    final (lat, lng) = _coordinatesForBuilding(nameOrCode);
    return LatLng(lat, lng);
  }

  Offset _offsetForBuilding(String? nameOrCode, Size size) {
    if (nameOrCode == null || nameOrCode.isEmpty) {
      return Offset(0.50 * size.width, 0.43 * size.height);
    }
    final query = nameOrCode.toLowerCase();
    if (query.contains('hub') || query.contains('base')) {
      return Offset(0.50 * size.width, 0.33 * size.height);
    }
    final layout = _schematicLayout[_rowFor(nameOrCode)?.locationCode];
    if (layout != null) {
      return Offset(layout.dx * size.width, layout.dy * size.height);
    }
    for (final entry in _schematicLayout.entries) {
      final code = entry.key.toLowerCase();
      if (code == query || query.contains(code)) {
        return Offset(
          entry.value.dx * size.width,
          entry.value.dy * size.height,
        );
      }
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

  void _handleTileError() {
    _tileErrorCount++;
    if (_tileErrorCount >= 3 && !_isOfflineFallback) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isOfflineFallback) return;
        setState(() {
          _isOfflineFallback = true;
        });
      });
    }
  }

  void _retryOnlineMap() {
    if (!mounted) return;
    setState(() {
      _isOfflineFallback = false;
      _tileErrorCount = 0;
      _userHasPanned = false;
      _lastFollowedLatLng = null;
    });
  }

  void _followDroneIfNeeded(LatLng droneLatLng) {
    if (!_isMapReady || _userHasPanned || _isOfflineFallback) return;
    if (_lastFollowedLatLng != null &&
        (_lastFollowedLatLng!.latitude - droneLatLng.latitude).abs() <
            0.00001 &&
        (_lastFollowedLatLng!.longitude - droneLatLng.longitude).abs() <
            0.00001) {
      return;
    }
    _lastFollowedLatLng = droneLatLng;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isMapReady || _userHasPanned || _isOfflineFallback) {
        return;
      }
      try {
        final zoom = _mapController.camera.zoom;
        _mapController.move(droneLatLng, zoom);
      } catch (_) {}
    });
  }

  LatLng _calculateDroneLatLng({
    required LatLng startLatLng,
    required LatLng endLatLng,
    required double legProgress,
    required TelemetryModel? telemetry,
    required bool isDelivered,
    required bool isReturning,
    required bool isStandby,
  }) {
    if (telemetry != null &&
        telemetry.latitude != 0.0 &&
        telemetry.longitude != 0.0) {
      return LatLng(telemetry.latitude, telemetry.longitude);
    }

    if (isDelivered && !isReturning) {
      return endLatLng;
    }

    if (isStandby) {
      return LatLng(_baseHubCoords.$1, _baseHubCoords.$2);
    }

    final lat =
        startLatLng.latitude +
        (endLatLng.latitude - startLatLng.latitude) * legProgress;
    final lng =
        startLatLng.longitude +
        (endLatLng.longitude - startLatLng.longitude) * legProgress;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    // The rows every building name and coordinate below comes from
    _locations = ref.watch(campusLocationsProvider).asData?.value ?? const [];
    final d = widget.delivery;
    final telemetry = d != null
        ? _safeWatchTelemetry(ref, d.id)
        : ref.watch(fleetTelemetryProvider);
    final dronesList = ref.watch(droneProvider);
    final fallbackDrone = dronesList.firstOrNull;
    final droneDbStatus = fallbackDrone?.status;

    final hubOffsetRatio = const Offset(0.50, 0.33); // Drone Hub at top center

    // With no delivery given (the fleet view), a returning drone is matched to
    // the delivery its telemetry belongs to, so a shuttle between trips is
    // still recognised as one
    final allDeliveries = ref.watch(deliveryProvider);
    final droneReturning = droneDbStatus != null
        ? droneDbStatus == DroneStatus.returning
        : telemetry?.eventType == 'returning_to_base';
    final DeliveryModel? activeOrRecentDel =
        d ??
        (droneReturning && telemetry?.deliveryId != null
            ? allDeliveries
                  .where((del) => del.id == telemetry!.deliveryId)
                  .firstOrNull
            : null);

    // One phase drives every label below, and the tracking header too
    final phase = resolveFlightPhase(
      delivery: activeOrRecentDel,
      droneStatus: droneDbStatus,
      telemetryEvent: telemetry?.eventType,
    );
    final bool returningToVendor = phase == FlightPhase.returningToVendor;
    final bool atVendor = phase == FlightPhase.atVendor;
    final bool isReturning =
        returningToVendor || phase == FlightPhase.returningToBase;
    final bool isAssigning = atVendor || phase == FlightPhase.headingToPickup;
    final bool isInTransit = phase == FlightPhase.delivering;
    final bool isDelivered = d?.status == DeliveryStatus.delivered;
    final bool isStandby = phase == FlightPhase.standby;
    final String loadLabel = activeOrRecentDel != null
        ? nextLoadLabel(activeOrRecentDel)
        : '';

    final String pickupName =
        activeOrRecentDel?.pickupLocationName ?? 'Vendor Shop';
    final String dropoffName =
        activeOrRecentDel?.dropoffLocationName ??
        activeOrRecentDel?.deliveryAddress ??
        'Campus';
    // A drop-off the customer pinned on the map: its coordinates come from
    // the delivery row, never from matching a name. Its label is free text
    // ("by the main gate") and must not be matched against buildings either.
    final pinCoords = activeOrRecentDel?.customDropoffCoords;
    final String dropoffMatchName = pinCoords != null ? '' : dropoffName;
    final String? pinLabel = activeOrRecentDel?.customDropoffLabel;

    // Compute live return progress from coordinates or telemetry
    double returnProgressCalc = 0.0;
    if (isReturning) {
      if (telemetry != null &&
          telemetry.latitude != 0.0 &&
          telemetry.longitude != 0.0) {
        final originCoords =
            pinCoords ??
            activeOrRecentDel?.dropoffLocationCoords ??
            _coordinatesForBuilding(dropoffName);
        final targetCoords = returningToVendor
            ? (activeOrRecentDel?.pickupLocationCoords ??
                  _coordinatesForBuilding(pickupName))
            : _hubCoords;
        final baseLat = targetCoords.$1;
        final baseLng = targetCoords.$2;
        final originLat = originCoords.$1;
        final originLng = originCoords.$2;

        final distTotal = math.sqrt(
          math.pow(baseLat - originLat, 2) + math.pow(baseLng - originLng, 2),
        );
        final distTraveled = math.sqrt(
          math.pow(telemetry.latitude - originLat, 2) +
              math.pow(telemetry.longitude - originLng, 2),
        );

        if (distTotal > 0.00001) {
          returnProgressCalc = (distTraveled / distTotal).clamp(0.0, 1.0);
        }
      }
      if (telemetry?.progress != null && telemetry!.progress > 0) {
        returnProgressCalc = math.max(
          returnProgressCalc,
          telemetry.progress.clamp(0.0, 1.0),
        );
      }
    }

    final legProgress = isReturning
        ? returnProgressCalc
        : isDelivered
        ? 1.0
        : (isStandby
              ? 0.0
              : (telemetry?.progress != null && telemetry!.progress > 0
                    ? telemetry.progress.clamp(0.0, 1.0)
                    : (activeOrRecentDel != null
                          ? activeOrRecentDel.progress.clamp(0.0, 1.0)
                          : 0.0)));

    final String dbStatusLabel = switch (droneDbStatus) {
      DroneStatus.available => 'Available',
      DroneStatus.assigned => 'Assigned',
      DroneStatus.busy => 'Busy',
      DroneStatus.charging => 'Charging',
      DroneStatus.maintenance => 'Maintenance',
      DroneStatus.offline => 'Offline',
      // Never "to Base" while the delivery still owes a trip
      DroneStatus.returning =>
        (activeOrRecentDel?.returnLegHeadsToVendor ?? false)
            ? 'Returning to Vendor'
            : 'Returning to Base',
      null => 'Available',
    };

    // Status formatting
    final String statusBadgeText = switch (phase) {
      FlightPhase.returningToVendor => 'Returning to Vendor',
      FlightPhase.returningToBase => 'Returning to Base',
      FlightPhase.atVendor => 'At Vendor',
      FlightPhase.headingToPickup => 'Heading to Pickup',
      FlightPhase.delivering => 'In Flight / In Transit',
      FlightPhase.delivered => 'Delivered',
      FlightPhase.standby => '$dbStatusLabel — At Base',
    };

    // Only the final leg home is the warning colour. A shuttle back to the
    // vendor, or a wait there, is still mid-delivery: in-flight blue.
    // Drives the badge, route lines, drone marker and progress readout.
    final Color statusColor = switch (phase) {
      FlightPhase.returningToBase => AppColors.warning,
      FlightPhase.returningToVendor => AppColors.accent,
      FlightPhase.atVendor => AppColors.accent,
      FlightPhase.headingToPickup => AppColors.primaryLight,
      FlightPhase.delivering => AppColors.accent,
      FlightPhase.delivered => AppColors.success,
      FlightPhase.standby => AppColors.accent,
    };

    final String droneCodeDisplay =
        telemetry?.droneCode ??
        (d != null && d.droneId != null && d.droneId!.isNotEmpty
            ? d.droneId!
            : (fallbackDrone?.id ?? '—'));

    final String legDescription = returningToVendor
        ? (legProgress >= 1.0
              ? 'Back at $pickupName • Collecting $loadLabel'
              : 'Drone $droneCodeDisplay returning to $pickupName • '
                    'Collecting $loadLabel')
        : atVendor
        ? 'At $pickupName • Collecting $loadLabel'
        : isReturning
        ? (legProgress >= 1.0
              ? 'Arrived at Campus Drone Hub Base'
              : 'Drone $droneCodeDisplay returning to Base Hub')
        : isAssigning
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

    // Real-world LatLng references
    final hubLatLng = LatLng(_hubCoords.$1, _hubCoords.$2);
    // The delivery's own pickup and drop-off rows first; names only as a
    // fallback
    final pickupRow = activeOrRecentDel?.pickupLocationCoords;
    final dropoffRow = activeOrRecentDel?.dropoffLocationCoords;
    final vendorLatLng = pickupRow != null
        ? LatLng(pickupRow.$1, pickupRow.$2)
        : _latLngForBuilding(pickupName);
    final customerLatLng = pinCoords != null
        ? LatLng(pinCoords.$1, pinCoords.$2)
        : dropoffRow != null
        ? LatLng(dropoffRow.$1, dropoffRow.$2)
        : _latLngForBuilding(dropoffName);

    LatLng startLatLng;
    LatLng endLatLng;
    if (isReturning) {
      startLatLng = customerLatLng;
      endLatLng = returningToVendor ? vendorLatLng : hubLatLng;
    } else if (isAssigning) {
      startLatLng = hubLatLng;
      endLatLng = vendorLatLng;
    } else if (isInTransit) {
      startLatLng = vendorLatLng;
      endLatLng = customerLatLng;
    } else if (isDelivered) {
      startLatLng = vendorLatLng;
      endLatLng = customerLatLng;
    } else {
      startLatLng = hubLatLng;
      endLatLng = hubLatLng;
    }

    final droneLatLng = _calculateDroneLatLng(
      startLatLng: startLatLng,
      endLatLng: endLatLng,
      legProgress: legProgress,
      telemetry: telemetry,
      isDelivered: isDelivered,
      isReturning: isReturning,
      isStandby: isStandby,
    );

    if (!isStandby && (!isDelivered || isReturning)) {
      _followDroneIfNeeded(droneLatLng);
    }

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
                                widget.title ??
                                    (isStandby
                                        ? 'Campus Drone Radar'
                                        : 'Live Drone Radar'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              if (isInTransit &&
                                  (activeOrRecentDel?.packageWeight ?? 0) > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.accent.withValues(
                                        alpha: 0.5,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.inventory_2_outlined,
                                        size: 11,
                                        color: AppColors.accent,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Payload: ${activeOrRecentDel!.packageWeight.toStringAsFixed(2)} kg',
                                        style: AppTextStyles.caption(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    ],
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
              // FlutterMap must not be built inside a LayoutBuilder: it calls
              // setState and fires map callbacks during layout, which breaks
              // the relayout boundary. Only the offline canvas needs a size.
              Expanded(
                child: _isOfflineFallback
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final size = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );

                          return _buildOfflineMapCanvas(
                            size: size,
                            hubOffsetRatio: hubOffsetRatio,
                            pickupName: pickupName,
                            dropoffName: dropoffMatchName,
                            pinPoint: pinCoords == null
                                ? null
                                : _offsetForCoordinates(pinCoords, size),
                            pinLabel: pinLabel,
                            isReturning: isReturning,
                            returningToVendor: returningToVendor,
                            isAssigning: isAssigning,
                            isInTransit: isInTransit,
                            isDelivered: isDelivered,
                            isStandby: isStandby,
                            legProgress: legProgress,
                            statusColor: statusColor,
                          );
                        },
                      )
                    : _buildOnlineMapCanvas(
                        hubLatLng: hubLatLng,
                        vendorLatLng: vendorLatLng,
                        customerLatLng: customerLatLng,
                        startLatLng: startLatLng,
                        endLatLng: endLatLng,
                        droneLatLng: droneLatLng,
                        pickupName: pickupName,
                        dropoffName: dropoffMatchName,
                        pinLatLng: pinCoords == null ? null : customerLatLng,
                        pinLabel: pinLabel,
                        isReturning: isReturning,
                        isAssigning: isAssigning,
                        isInTransit: isInTransit,
                        isDelivered: isDelivered,
                        isStandby: isStandby,
                        statusColor: statusColor,
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
                      value: (!isReturning && (isDelivered || isStandby))
                          ? '0.0 m/s'
                          : (telemetry?.speed != null
                                ? '${telemetry!.speed!.toStringAsFixed(1)} m/s'
                                : ((d?.currentSpeed ?? 0) > 0
                                      ? '${d!.currentSpeed!.toStringAsFixed(1)} m/s'
                                      : (isReturning ? '5.0 m/s' : '—'))),
                      color: AppColors.info,
                    ),
                    _buildTelemetryItem(
                      icon: Icons.alt_route_rounded,
                      label: isReturning
                          ? (returningToVendor
                                ? 'Return to Vendor'
                                : 'Return Progress')
                          : atVendor
                          ? 'At Vendor'
                          : (isStandby
                                ? 'Status'
                                : (isAssigning
                                      ? 'Pickup Progress'
                                      : 'Delivery Progress')),
                      value: atVendor
                          ? 'Collecting $loadLabel'
                          : (isStandby && !isReturning)
                          ? dbStatusLabel
                          : '${(legProgress * 100).round()}%',
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

  /// Real OpenStreetMap canvas using flutter_map
  Widget _buildOnlineMapCanvas({
    required LatLng hubLatLng,
    required LatLng vendorLatLng,
    required LatLng customerLatLng,
    required LatLng startLatLng,
    required LatLng endLatLng,
    required LatLng droneLatLng,
    required String pickupName,
    required String dropoffName,
    LatLng? pinLatLng,
    String? pinLabel,
    required bool isReturning,
    required bool isAssigning,
    required bool isInTransit,
    required bool isDelivered,
    required bool isStandby,
    required Color statusColor,
  }) {
    final polylines = <Polyline>[];

    if (!isStandby) {
      // 1. Mission Circuit (Hub -> Vendor -> Customer -> Hub) in subtle dotted line
      polylines.add(
        Polyline(
          points: [hubLatLng, vendorLatLng, customerLatLng, hubLatLng],
          color: Colors.white.withValues(alpha: 0.18),
          strokeWidth: 2.0,
          pattern: StrokePattern.dotted(),
        ),
      );

      // 2. Active Leg Remaining (start to end) in dashed line
      polylines.add(
        Polyline(
          points: [startLatLng, endLatLng],
          color: statusColor.withValues(alpha: 0.45),
          strokeWidth: 3.0,
          pattern: StrokePattern.dashed(segments: const [6, 4]),
        ),
      );

      // 3. Traveled Line (start to drone) in solid accent line
      polylines.add(
        Polyline(
          points: [startLatLng, droneLatLng],
          color: statusColor,
          strokeWidth: 3.8,
        ),
      );
    }

    final markers = <Marker>[];

    // Campus landmark markers: every campus_locations row with a position,
    // except the hub, which has its own marker below
    for (final loc in _locations.where(
      (l) => _hasPosition(l) && !isHubLocationCode(l.locationCode, l.name),
    )) {
      final locName = loc.name;
      final locCode = loc.locationCode;
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

      markers.add(
        Marker(
          point: LatLng(loc.latitude, loc.longitude),
          width: 64,
          height: 56,
          alignment: Alignment.center,
          child: CampusMarkerPill(
            code: locCode,
            color: markerColor,
            isPickup: isPickup,
            isDropoff: isDropoff,
            isTestPoint: locCode == kTestDropCode,
          ),
        ),
      );
    }

    // The customer's pinned drop-off, when the order has one
    if (pinLatLng != null && !isStandby) {
      markers.add(
        Marker(
          point: pinLatLng,
          width: 120,
          height: 60,
          alignment: Alignment.center,
          child: _buildPinMarker(pinLabel),
        ),
      );
    }

    // BASE HUB Marker
    markers.add(
      Marker(
        point: hubLatLng,
        width: 68,
        height: 56,
        alignment: Alignment.center,
        child: const HubMarker(),
      ),
    );

    // Live Drone Marker with Pulsing Radar
    markers.add(
      Marker(
        point: droneLatLng,
        width: 56,
        height: 56,
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _radarController,
          builder: (context, child) {
            return _buildDroneMarker(
              radarVal: _radarController.value,
              color: statusColor,
              isDelivered: isDelivered && !isReturning,
            );
          },
        ),
      ),
    );

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _campusCenter,
            initialZoom: 17.8,
            minZoom: 16.0,
            maxZoom: 20.0,
            cameraConstraint: CameraConstraint.contain(bounds: _campusBounds),
            onMapReady: () {
              if (!mounted) return;
              _isMapReady = true;
              if (!isStandby && (!isDelivered || isReturning)) {
                _followDroneIfNeeded(droneLatLng);
              }
            },
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture && !_userHasPanned) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || _userHasPanned) return;
                  setState(() {
                    _userHasPanned = true;
                  });
                });
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'ph.edu.uclm.aerodrop',
              maxNativeZoom: 19,
              errorTileCallback: (tile, error, stackTrace) {
                _handleTileError();
              },
            ),
            // Subtle dark overlay to match AeroDrop's sleek aesthetic while keeping streets and buildings legible
            IgnorePointer(
              child: Container(color: Colors.black.withValues(alpha: 0.24)),
            ),
            PolylineLayer(polylines: polylines),
            MarkerLayer(markers: markers),
            const SimpleAttributionWidget(
              source: Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 9, color: Colors.white70),
              ),
              alignment: Alignment.bottomRight,
            ),
          ],
        ),

        // Recenter / Follow Drone button (shows when user panned)
        if (_userHasPanned)
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () {
                if (!mounted) return;
                setState(() {
                  _userHasPanned = false;
                  _lastFollowedLatLng = null;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || !_isMapReady || _isOfflineFallback) return;
                  try {
                    _mapController.move(droneLatLng, 17.8);
                  } catch (_) {}
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardDark2.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.7),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.my_location_rounded,
                      size: 13,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Follow Drone',
                      style: AppTextStyles.caption(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Offline map canvas fallback using assets/images/uclm_map.png
  Widget _buildOfflineMapCanvas({
    required Size size,
    required Offset hubOffsetRatio,
    required String pickupName,
    required String dropoffName,
    Offset? pinPoint,
    String? pinLabel,
    required bool isReturning,
    bool returningToVendor = false,
    required bool isAssigning,
    required bool isInTransit,
    required bool isDelivered,
    required bool isStandby,
    required double legProgress,
    required Color statusColor,
  }) {
    final hubPoint = Offset(
      hubOffsetRatio.dx * size.width,
      hubOffsetRatio.dy * size.height,
    );
    final vendorPoint = _offsetForBuilding(pickupName, size);
    final customerPoint = pinPoint ?? _offsetForBuilding(dropoffName, size);

    Offset startPoint;
    Offset endPoint;
    Offset dronePoint;

    if (isReturning) {
      startPoint = customerPoint;
      endPoint = returningToVendor ? vendorPoint : hubPoint;
      dronePoint = Offset(
        startPoint.dx + (endPoint.dx - startPoint.dx) * legProgress,
        startPoint.dy + (endPoint.dy - startPoint.dy) * legProgress,
      );
    } else if (isAssigning) {
      startPoint = hubPoint;
      endPoint = vendorPoint;
      dronePoint = Offset(
        startPoint.dx + (endPoint.dx - startPoint.dx) * legProgress,
        startPoint.dy + (endPoint.dy - startPoint.dy) * legProgress,
      );
    } else if (isInTransit) {
      startPoint = vendorPoint;
      endPoint = customerPoint;
      dronePoint = Offset(
        startPoint.dx + (endPoint.dx - startPoint.dx) * legProgress,
        startPoint.dy + (endPoint.dy - startPoint.dy) * legProgress,
      );
    } else if (isDelivered) {
      startPoint = vendorPoint;
      endPoint = customerPoint;
      dronePoint = customerPoint;
    } else {
      startPoint = hubPoint;
      endPoint = hubPoint;
      dronePoint = hubPoint;
    }

    return Stack(
      children: [
        // Map Background Image
        Positioned.fill(
          child: Opacity(
            opacity: 0.88,
            child: Image.asset('assets/images/uclm_map.png', fit: BoxFit.cover),
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
                    radarAngle: _radarController.value * 2 * math.pi,
                    accentColor: statusColor,
                  ),
                );
              },
            ),
          ),

        // Campus landmark markers: rows that have a place on the schematic
        for (final loc in _locations)
          if (_schematicLayout[loc.locationCode] case final at?)
            _buildCampusMarker(loc, at, size, pickupName, dropoffName),

        // The customer's pinned drop-off, when the order has one
        if (pinPoint != null && !isStandby)
          Positioned(
            left: pinPoint.dx - 60,
            top: pinPoint.dy - 12,
            width: 120,
            child: _buildPinMarker(pinLabel),
          ),

        // Hub Marker
        Positioned(
          left: hubPoint.dx - 16,
          top: hubPoint.dy - 16,
          child: const HubMarker(),
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
                isDelivered: isDelivered && !isReturning,
              );
            },
          ),
        ),

        // Offline map indicator badge with retry capability
        Positioned(
          top: 10,
          left: 10,
          child: GestureDetector(
            onTap: _retryOnlineMap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.85),
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 4),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 12,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Offline map',
                    style: AppTextStyles.caption(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.refresh_rounded,
                    size: 11,
                    color: AppColors.warning,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The customer's pinned drop-off. Same pill family as the building
  /// markers, but a flag in the success colour with a white ring, so it reads
  /// as a chosen spot rather than a known building. Labelled with the
  /// customer's own words when they gave any.
  Widget _buildPinMarker(String? label) {
    final text = (label == null || label.trim().isEmpty) ? 'PIN' : label.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.95),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.45),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            Icons.flag_rounded,
            size: 12,
            color: AppColors.bgDark,
            semanticLabel: 'Pinned drop-off',
          ),
        ),
        const SizedBox(height: 2),
        Container(
          constraints: const BoxConstraints(maxWidth: 116),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCampusMarker(
    CampusLocation loc,
    Offset at,
    Size size,
    String pickupName,
    String dropoffName,
  ) {
    final x = at.dx * size.width;
    final y = at.dy * size.height;
    final locName = loc.name;
    final locCode = loc.locationCode;

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
      child: CampusMarkerPill(
        code: locCode,
        color: markerColor,
        isPickup: isPickup,
        isDropoff: isDropoff,
        isTestPoint: locCode == kTestDropCode,
      ),
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
                color: color.withValues(
                  alpha: (1.0 - radarVal).clamp(0.0, 1.0),
                ),
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
