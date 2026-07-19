import 'dart:async';
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
import '../../core/services/supabase_service.dart';

// ---------------------------------------------------------------------------
// Display coordinates for the UCLM campus map image (normalized 0.0–1.0).
// These are visual positions only — do NOT derive from lat/lng.
// ---------------------------------------------------------------------------
Offset _displayOffset(String locationName, Size size) {
  final n = locationName.toLowerCase();
  double x, y;
  if (n.contains('old') || n.contains('main')) {
    x = 0.50;
    y = 0.43;
  } else if (n.contains('annex 1') || n.contains('annex1')) {
    x = 0.43;
    y = 0.49;
  } else if (n.contains('annex 2') || n.contains('annex2')) {
    x = 0.57;
    y = 0.49;
  } else if (n.contains('basic ed') || n.contains('basic education')) {
    x = 0.40;
    y = 0.58;
  } else if (n.contains('maritime')) {
    x = 0.60;
    y = 0.58;
  } else {
    x = 0.50;
    y = 0.45;
  }
  return Offset(x * size.width, y * size.height);
}

String _shortLabel(String name) {
  final n = name.toLowerCase();
  if (n.contains('old') || n.contains('main')) {
    return 'Old';
  }
  if (n.contains('annex 1') || n.contains('annex1')) {
    return 'Annex 1';
  }
  if (n.contains('annex 2') || n.contains('annex2')) {
    return 'Annex 2';
  }
  if (n.contains('basic ed') || n.contains('basic education')) {
    return 'Basic Ed';
  }
  if (n.contains('maritime')) {
    return 'Maritime';
  }
  return name;
}

// ---------------------------------------------------------------------------

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  Timer? _tickerTimer;

  List<Map<String, dynamic>> _locations = [];
  Map<String, dynamic>? _activeDeliveryRow;

  String _droneBatteryText = 'Drone not assigned yet';
  String _flightSpeed = '-- km/h';
  String _flightAltitude = '-- m';

  String? _tappedBuildingName;

  // Collapsible panel
  bool _panelExpanded = true;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _loadCampusLocations();
    _fetchActiveDeliveryRow();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _tickerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCampusLocations() async {
    if (!SupabaseService.isConfigured) return;
    try {
      final response = await SupabaseService.client
          .from('campus_locations')
          .select();
      if (mounted) {
        setState(() {
          _locations = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error loading campus locations: $e');
    }
  }

  Future<void> _fetchActiveDeliveryRow() async {
    if (!SupabaseService.isConfigured) return;
    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      final activeStatusNames = ['pending', 'assigning', 'in_transit'];

      final response = await SupabaseService.client
          .from('deliveries')
          .select('*, orders!inner(user_id)')
          .eq('orders.user_id', currentUser.id)
          .inFilter('status', activeStatusNames)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _activeDeliveryRow = response;
        });
        if (response != null) {
          _fetchTelemetryDetails(response['drone_id']?.toString());
        } else {
          _fetchTelemetryDetails(null);
        }
      }
    } catch (e) {
      debugPrint('Error fetching active delivery: $e');
    }
  }

  Future<void> _fetchTelemetryDetails(String? droneId) async {
    if (droneId == null) {
      if (mounted) {
        setState(() {
          _droneBatteryText = 'No telemetry records available.';
          _flightSpeed = '-- km/h';
          _flightAltitude = '-- m';
        });
      }
      return;
    }
    try {
      final drone = await SupabaseService.client
          .from('drones')
          .select('battery_level')
          .eq('id', droneId)
          .maybeSingle();
      if (drone != null && mounted) {
        final lvl = drone['battery_level'];
        setState(() {
          _droneBatteryText = lvl != null
              ? 'Drone Battery: $lvl%'
              : 'Drone Battery: Unknown';
        });
      }

      final tel = await SupabaseService.client
          .from('drone_telemetry')
          .select()
          .eq('drone_id', droneId)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (tel != null && mounted) {
        setState(() {
          if (tel['speed'] != null) {
            _flightSpeed = '${tel['speed']} km/h';
          }
          if (tel['altitude'] != null) {
            _flightAltitude = '${tel['altitude']} m';
          }
          if (tel['battery_level'] != null) {
            _droneBatteryText = 'Drone Battery: ${tel['battery_level']}%';
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _droneBatteryText = 'No telemetry records available.';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading drone telemetry: $e');
    }
  }

  Offset? _offsetForLocationId(String? id, Size size) {
    if (id == null || _locations.isEmpty) return null;
    final loc = _locations.firstWhere(
      (l) => l['id'].toString() == id,
      orElse: () => {},
    );
    if (loc.isEmpty) return null;
    return _displayOffset(loc['name']?.toString() ?? '', size);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<DeliveryModel>>(deliveryProvider, (previous, next) {
      if (previous != null) {
        for (final nextDel in next) {
          final prev = previous.firstWhere(
            (d) => d.id == nextDel.id,
            orElse: () => nextDel,
          );
          if (prev.status == DeliveryStatus.inTransit &&
              nextDel.status == DeliveryStatus.delivered) {
            context.go('/user/delivery/completed');
            break;
          }
        }
      }
      _fetchActiveDeliveryRow();
    });

    final deliveries = ref.watch(deliveryProvider);
    final active =
        (List<DeliveryModel>.from(deliveries)
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
            .where(
              (d) =>
                  d.status == DeliveryStatus.inTransit ||
                  d.status == DeliveryStatus.pending ||
                  d.status == DeliveryStatus.assigning,
            )
            .toList();
    final activeDelivery = active.isNotEmpty ? active.first : null;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.cardDark,
        onRefresh: () async {
          await ref
              .read(deliveryProvider.notifier)
              .loadDeliveriesFromSupabase();
          await _loadCampusLocations();
          await _fetchActiveDeliveryRow();
        },
        child: SizedBox.expand(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);

              // ---- compute delivery state ----
              Offset startOffset = Offset(
                0.50 * size.width,
                0.50 * size.height,
              );
              Offset endOffset = Offset(0.50 * size.width, 0.50 * size.height);
              Offset droneOffset = Offset(
                0.50 * size.width,
                0.43 * size.height,
              );

              double progress = 0.0;
              int remainingSeconds = 0;
              bool showDrone = false;
              bool showActiveRoute = false;
              bool showPlannedRoute = false;
              String statusLabel = 'No deliveries in progress.';
              String messageText = 'No active deliveries in progress.';

              final row = _activeDeliveryRow;
              final bool hasRoute =
                  row != null &&
                  row['pickup_location_id'] != null &&
                  row['dropoff_location_id'] != null;

              if (activeDelivery != null) {
                switch (activeDelivery.status) {
                  case DeliveryStatus.pending:
                    statusLabel = 'Awaiting Admin Approval';
                    messageText =
                        'Your delivery request is waiting for admin approval.';
                    progress = 0.0;
                    showPlannedRoute = hasRoute;
                    showDrone = false;
                    break;

                  case DeliveryStatus.assigning:
                    statusLabel = 'Assigning Drone';
                    messageText = 'Preparing drone for dispatch.';
                    progress = 0.0;
                    showPlannedRoute = hasRoute;
                    showDrone = false;
                    break;

                  case DeliveryStatus.inTransit:
                    showActiveRoute = hasRoute;
                    showDrone = hasRoute;
                    final startedAt = activeDelivery.deliveryStartedAt;
                    if (startedAt != null) {
                      final total = activeDelivery.estimatedDeliverySeconds;
                      final elapsed = DateTime.now()
                          .difference(startedAt)
                          .inSeconds;
                      progress = (elapsed / total).clamp(0.0, 1.0);
                      remainingSeconds = (total - elapsed).clamp(0, total);
                      if (remainingSeconds <= 0) {
                        statusLabel = 'Arrived at destination';
                        messageText = 'Your order has arrived! 🎉';
                        progress = 1.0;
                      } else {
                        final mm = (remainingSeconds ~/ 60).toString().padLeft(
                          2,
                          '0',
                        );
                        final ss = (remainingSeconds % 60).toString().padLeft(
                          2,
                          '0',
                        );
                        statusLabel = 'Arriving in $mm:$ss';
                        messageText =
                            'Drone is on its way to your destination.';
                      }
                    } else {
                      statusLabel = 'Waiting for dispatch';
                      messageText = 'Awaiting dispatch signal.';
                      showDrone = false;
                    }
                    break;

                  case DeliveryStatus.delivered:
                    statusLabel = 'Arrived at destination';
                    messageText = 'Your order has arrived! 🎉';
                    progress = 1.0;
                    showActiveRoute = hasRoute;
                    showDrone = hasRoute;
                    break;

                  case DeliveryStatus.cancelled:
                    statusLabel = 'Delivery Cancelled';
                    messageText = 'Your delivery request has been cancelled.';
                    break;
                }

                if (hasRoute) {
                  final pickup = _offsetForLocationId(
                    row['pickup_location_id']?.toString(),
                    size,
                  );
                  final dropoff = _offsetForLocationId(
                    row['dropoff_location_id']?.toString(),
                    size,
                  );
                  if (pickup != null && dropoff != null) {
                    startOffset = pickup;
                    endOffset = dropoff;
                    droneOffset = Offset(
                      startOffset.dx +
                          (endOffset.dx - startOffset.dx) * progress,
                      startOffset.dy +
                          (endOffset.dy - startOffset.dy) * progress,
                    );
                  }
                }
              }

              if (!showDrone) {
                // Park drone at Old Building when not in transit
                droneOffset = Offset(0.50 * size.width, 0.43 * size.height);
              }

              // ---- panel heights ----
              // ponytail: Position the panel exactly 16px above the bottom navigation bar.
              // MediaQuery.of(context).padding.bottom is set by the parent Scaffold to match the bottom nav height.
              final navOffset = MediaQuery.of(context).padding.bottom + 16.0;
              final collapsedH = 100.0;
              final expandedH = activeDelivery != null ? 360.0 : 120.0;
              final panelHeight = _panelExpanded ? expandedH : collapsedH;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // ── MAP (interactive) ──────────────────────────────────
                  Positioned.fill(
                    child: InteractiveViewer(
                      panEnabled: true,
                      scaleEnabled: true,
                      minScale: 1.0,
                      maxScale: 2.5,
                      boundaryMargin: const EdgeInsets.all(80),
                      child: Stack(
                        children: [
                          // background map image
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.88,
                              child: Image.asset(
                                'assets/images/uclm_map.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          // route line (drawn under markers)
                          if (activeDelivery != null &&
                              hasRoute &&
                              (showActiveRoute || showPlannedRoute))
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _RoutePainter(
                                  start: startOffset,
                                  end: endOffset,
                                  drone: droneOffset,
                                  progress: progress,
                                  radar: _radarController.value * 2 * math.pi,
                                  isPlanned: showPlannedRoute,
                                ),
                              ),
                            ),

                          // building markers
                          for (final loc in _locations) _buildMarker(loc, size),

                          // drone icon (only when flying)
                          if (showDrone)
                            Positioned(
                              left: droneOffset.dx - 28,
                              top: droneOffset.dy - 28,
                              child: _DroneWidget(
                                radar: _radarController.value,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── TOP HUD (fixed) ────────────────────────────────────
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          borderGradient: const LinearGradient(
                            colors: [
                              AppColors.accent,
                              AppColors.primary,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                          child: Row(
                            children: [
                              Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(
                                        alpha: 0.15,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.radar_rounded,
                                      color: AppColors.accent,
                                      size: 22,
                                    ),
                                  )
                                  .animate(onPlay: (c) => c.repeat())
                                  .shimmer(
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
                                    Text(
                                      'Prototype Telemetry Active',
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.success.withValues(
                                      alpha: 0.3,
                                    ),
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

                  // ── COLLAPSIBLE BOTTOM PANEL (fixed, always above bottom nav) ──
                  Positioned(
                    bottom: navOffset,
                    left: 0,
                    right: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // gradient fade above the card
                        IgnorePointer(
                          child: Container(
                            height: 60,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, AppColors.bgDark],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),

                        // card container
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeInOut,
                          height: panelHeight,
                          decoration: BoxDecoration(
                            color: AppColors.cardDark,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.25),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // drag handle / toggle button
                              GestureDetector(
                                onTap: () => setState(
                                  () => _panelExpanded = !_panelExpanded,
                                ),
                                behavior: HitTestBehavior.opaque,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 10),
                                      // pill
                                      Container(
                                        width: 36,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withValues(
                                            alpha: 0.5,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Icon(
                                        _panelExpanded
                                            ? Icons.keyboard_arrow_down_rounded
                                            : Icons.keyboard_arrow_up_rounded,
                                        color: AppColors.textSecondaryDark,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // panel content
                              Expanded(
                                child: SingleChildScrollView(
                                  physics: _panelExpanded
                                      ? const ClampingScrollPhysics()
                                      : const NeverScrollableScrollPhysics(),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      0,
                                      20,
                                      24,
                                    ),
                                    child: _panelExpanded
                                        ? activeDelivery == null
                                              ? _DockedCard(
                                                  statusLabel: statusLabel,
                                                  messageText: messageText,
                                                )
                                              : _ActiveCard(
                                                  delivery: activeDelivery,
                                                  progress: progress,
                                                  statusLabel: statusLabel,
                                                  droneBatteryText:
                                                      _droneBatteryText,
                                                  flightSpeed: _flightSpeed,
                                                  flightAltitude:
                                                      _flightAltitude,
                                                  hasDrone: showDrone,
                                                )
                                        : _CollapsedSummary(
                                            statusLabel: statusLabel,
                                            packageName:
                                                activeDelivery?.packageName ??
                                                '',
                                            route:
                                                activeDelivery
                                                    ?.deliveryAddress ??
                                                '',
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMarker(Map<String, dynamic> loc, Size size) {
    final name = loc['name']?.toString() ?? '';
    final offset = _displayOffset(name, size);
    final isTapped = _tappedBuildingName == name;

    return Positioned(
      left: offset.dx - 18,
      top: offset.dy - 32,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            setState(() => _tappedBuildingName = isTapped ? null : name),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isTapped)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgDark.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent, width: 1),
                ),
                child: Text(
                  _shortLabel(name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.bgDark.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.business_rounded,
                color: AppColors.accent,
                size: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Drone widget ─────────────────────────────────────────────────────────────

class _DroneWidget extends StatelessWidget {
  final double radar;
  const _DroneWidget({required this.radar});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 56 * radar,
            height: 56 * radar,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 1 - radar),
                width: 1.5,
              ),
            ),
          ),
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

// ── Panel sections ───────────────────────────────────────────────────────────

class _DockedCard extends StatelessWidget {
  final String statusLabel;
  final String messageText;
  const _DockedCard({required this.statusLabel, required this.messageText});

  @override
  Widget build(BuildContext context) {
    return Row(
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
                statusLabel,
                style: AppTextStyles.title(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                messageText,
                style: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CollapsedSummary extends StatelessWidget {
  final String statusLabel;
  final String packageName;
  final String route;
  const _CollapsedSummary({
    required this.statusLabel,
    required this.packageName,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.navigation_rounded, color: AppColors.accent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                packageName.isNotEmpty ? packageName : 'No active order',
                style: AppTextStyles.title(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                statusLabel,
                style: AppTextStyles.body(
                  fontSize: 11,
                  color: AppColors.accent,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (route.isNotEmpty)
                Text(
                  route,
                  style: AppTextStyles.body(
                    fontSize: 11,
                    color: AppColors.textSecondaryDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActiveCard extends StatelessWidget {
  final DeliveryModel delivery;
  final double progress;
  final String statusLabel;
  final String droneBatteryText;
  final String flightSpeed;
  final String flightAltitude;
  final bool hasDrone;

  const _ActiveCard({
    required this.delivery,
    required this.progress,
    required this.statusLabel,
    required this.droneBatteryText,
    required this.flightSpeed,
    required this.flightAltitude,
    required this.hasDrone,
  });

  Widget _metric(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: AppColors.textSecondaryDark),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value.replaceFirst('Drone Battery: ', ''),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toInt();
    return Column(
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
            Flexible(
              child: Text(
                statusLabel,
                style: AppTextStyles.title(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          delivery.packageName,
          style: AppTextStyles.title(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          'Route: ${delivery.deliveryAddress}',
          style: AppTextStyles.body(
            fontSize: 12,
            color: AppColors.textSecondaryDark,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        if (hasDrone) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metric(
                Icons.battery_charging_full_rounded,
                'Battery',
                droneBatteryText,
              ),
              _metric(Icons.speed_rounded, 'Speed', flightSpeed),
              _metric(Icons.height_rounded, 'Altitude', flightAltitude),
            ],
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            droneBatteryText,
            style: AppTextStyles.body(
              fontSize: 12,
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
        const SizedBox(height: 16),
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
              '$pct%',
              style: AppTextStyles.title(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.borderDark,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 14),
        GradientButton(
          text: 'View Telemetry Logs',
          height: 42,
          onPressed: () =>
              context.push('/user/track/details?id=${delivery.id}'),
          icon: Icons.analytics_outlined,
        ),
      ],
    );
  }
}

// ── Route painter ─────────────────────────────────────────────────────────────

class _RoutePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Offset drone;
  final double progress;
  final double radar;
  final bool isPlanned;

  const _RoutePainter({
    required this.start,
    required this.end,
    required this.drone,
    required this.progress,
    required this.radar,
    required this.isPlanned,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isPlanned) {
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.30)
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      return;
    }

    // Blue glow underlay
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.35)
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Blue inner line
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.60)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    final totalDist = (end - start).distance;
    final activeDist = totalDist * progress;

    if (totalDist > 0) {
      final vec = (end - start) / totalDist;
      const dashW = 6.0;
      const dashSpace = 6.0;

      void drawDashes(Paint paint) {
        double d = 0;
        while (d < activeDist) {
          final s = start + vec * d;
          d += dashW;
          final e = start + vec * math.min(d, activeDist);
          canvas.drawLine(s, e, paint);
          d += dashSpace;
        }
      }

      drawDashes(
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.40)
          ..strokeWidth = 8.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );

      drawDashes(
        Paint()
          ..color = AppColors.accent
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    // Radar sweep around drone
    canvas.drawCircle(
      drone,
      140,
      Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          colors: [
            Colors.transparent,
            AppColors.accent.withValues(alpha: 0.15),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: GradientRotation(radar),
        ).createShader(Rect.fromCircle(center: drone, radius: 140)),
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) =>
      old.progress != progress ||
      old.radar != radar ||
      old.drone != drone ||
      old.isPlanned != isPlanned;
}
