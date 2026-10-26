import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/staggered_list.dart';
import '../../core/widgets/shared_drone_radar.dart';
import '../../core/providers/delivery_provider.dart';
import '../../core/providers/drone_provider.dart';
import '../../core/models/flight_phase.dart';
import '../../core/models/telemetry_model.dart';
import '../../core/providers/order_provider.dart';
import '../orders/widgets/order_chat_entry.dart';
import '../../core/providers/telemetry_provider.dart';
import '../../core/models/delivery_model.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/drone_flight_calculator.dart';

class TrackingDetailsPage extends ConsumerStatefulWidget {
  final String deliveryId;
  const TrackingDetailsPage({super.key, required this.deliveryId});

  @override
  ConsumerState<TrackingDetailsPage> createState() =>
      _TrackingDetailsPageState();
}

class _TrackingDetailsPageState extends ConsumerState<TrackingDetailsPage> {
  String _pickupName = '—';
  String _dropoffName = '—';
  String _droneBatteryText = '—';
  String _droneName = '—';
  String _flightSpeed = '—';
  String _flightAltitude = '—';
  String _signalStrengthText = '—';
  String _headingText = '—';

  DeliveryModel? _fetchedDelivery;
  RealtimeChannel? _delChannel;
  RealtimeChannel? _telChannel;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _fetchDetails();
      _setupRealtime();
    });
  }

  @override
  void dispose() {
    _delChannel?.unsubscribe();
    _telChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    if (!SupabaseService.isConfigured) return;
    try {
      _delChannel = SupabaseService.client
          .channel('tracking_details_del:${widget.deliveryId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'deliveries',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: widget.deliveryId,
            ),
            callback: (_) {
              if (mounted) _fetchDetails();
            },
          )
          .subscribe();

      _telChannel = SupabaseService.client
          .channel('tracking_details_tel:${widget.deliveryId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'drone_telemetry',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'delivery_id',
              value: widget.deliveryId,
            ),
            callback: (payload) {
              if (!mounted) return;
              final rec = payload.newRecord;
              setState(() {
                final speed = rec['speed'];
                final alt = rec['altitude'];
                final battery = rec['battery_level'];
                final signal = rec['signal_strength'];
                final heading = rec['heading'];

                if (speed != null) _flightSpeed = '$speed km/h';
                if (alt != null) _flightAltitude = '$alt m';
                if (battery != null) _droneBatteryText = '$battery%';
                if (signal != null) _signalStrengthText = '$signal%';
                if (heading != null) _headingText = '$heading°';
              });
              _fetchDetails();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime subscription error in tracking details: $e');
    }
  }

  Future<void> _fetchDetails() async {
    if (!SupabaseService.isConfigured) return;
    if (!mounted) return;

    try {
      // 1. Fetch latest delivery details from deliveries table
      final delResponse = await SupabaseService.client
          .from('deliveries')
          .select()
          .eq('id', widget.deliveryId)
          .maybeSingle();

      if (delResponse != null) {
        final data = Map<String, dynamic>.from(delResponse);

        // Convert map to DeliveryModel status
        final rawStatus = data['status']?.toString().toLowerCase();
        final isComplete = rawStatus == 'delivered';
        final status = isComplete
            ? DeliveryStatus.delivered
            : (rawStatus == 'intransit' || rawStatus == 'in_transit')
            ? DeliveryStatus.inTransit
            : rawStatus == 'assigning'
            ? DeliveryStatus.assigning
            : rawStatus == 'cancelled'
            ? DeliveryStatus.cancelled
            : DeliveryStatus.pending;

        // Single authoritative source of truth: deliveries.progress
        final double rawProgress =
            (data['progress'] as num?)?.toDouble() ?? 0.0;
        final double progress = status == DeliveryStatus.delivered
            ? 1.0
            : rawProgress.clamp(0.0, 1.0);

        // ETA helper
        String etaStr = data['eta']?.toString() ?? 'TBD';
        if (status == DeliveryStatus.delivered) {
          etaStr = '0 mins';
        } else if (status == DeliveryStatus.inTransit) {
          final totalSecs =
              (data['estimated_delivery_seconds'] as num?)?.toDouble() ?? 60.0;
          final remaining = DroneFlightCalculator.calculateRemainingSeconds(
            progress: progress,
            totalDurationSeconds: totalSecs,
          );
          etaStr = DroneFlightCalculator.formatEta(remaining);
        } else if (status == DeliveryStatus.assigning) {
          etaStr = 'En route to vendor';
        }

        final model = DeliveryModel(
          id: data['id'].toString(),
          senderName: data['sender_name']?.toString() ?? 'Unknown Sender',
          recipientName:
              data['recipient_name']?.toString() ?? 'Unknown Recipient',
          recipientPhone: data['recipient_phone']?.toString() ?? '',
          deliveryAddress: data['delivery_address']?.toString() ?? '',
          packageName: data['package_name']?.toString() ?? 'AeroDrop Package',
          packageWeight: (data['package_weight'] as num?)?.toDouble() ?? 0.0,
          packageType: data['package_type']?.toString() ?? 'Other',
          status: status,
          droneId: data['drone_id']?.toString() ?? 'DRN-001',
          eta: etaStr,
          createdAt: data['created_at'] != null
              ? DateTime.tryParse(data['created_at'].toString()) ??
                    DateTime.now()
              : DateTime.now(),
          progress: progress,
          estimatedDistanceKm: data['estimated_distance_km'] != null
              ? (data['estimated_distance_km'] as num).toDouble()
              : null,
          paymentAmount: data['payment_amount'] != null
              ? (data['payment_amount'] as num).toDouble()
              : null,
          deliveryStartedAt: data['delivery_started_at'] != null
              ? DateTime.tryParse(data['delivery_started_at'].toString())
              : null,
          estimatedDeliverySeconds:
              (data['estimated_delivery_seconds'] as num?)?.toInt() ?? 60,
          deliveredAt: data['delivery_completed_at'] != null
              ? DateTime.tryParse(data['delivery_completed_at'].toString())
              : null,
          tripsRequired: (data['trips_required'] as num?)?.toInt() ?? 1,
          tripsCompleted: (data['trips_completed'] as num?)?.toInt() ?? 0,
          orderId: data['order_id']?.toString(),
        );

        if (mounted) {
          setState(() {
            _fetchedDelivery = model;
          });
        }

        // 2. Fetch locations
        final pickupId = data['pickup_location_id'];
        final dropoffId = data['dropoff_location_id'];
        if (pickupId != null) {
          final p = await SupabaseService.client
              .from('campus_locations')
              .select('name')
              .eq('id', pickupId)
              .maybeSingle();
          if (p != null && mounted) {
            setState(() {
              _pickupName =
                  p['name']?.toString() ?? 'Pickup location unavailable';
            });
          }
        }

        if (dropoffId != null) {
          final d = await SupabaseService.client
              .from('campus_locations')
              .select('name')
              .eq('id', dropoffId)
              .maybeSingle();
          if (d != null && mounted) {
            setState(() {
              _dropoffName =
                  d['name']?.toString() ?? 'Drop-off location unavailable';
            });
          }
        }

        // 3. Fetch Drone details
        final droneId = data['drone_id'];
        if (droneId != null) {
          final drone = await SupabaseService.client
              .from('drones')
              .select('drone_name, drone_code, battery_level')
              .eq('id', droneId)
              .maybeSingle();
          if (drone != null && mounted) {
            setState(() {
              _droneName =
                  drone['drone_name']?.toString() ??
                  drone['drone_code']?.toString() ??
                  'DRN-001';
              final lvl = drone['battery_level'];
              if (lvl != null) {
                _droneBatteryText = '$lvl%';
              }
            });
          }

          // 4. Fetch latest telemetry
          final tel = await SupabaseService.client
              .from('drone_telemetry')
              .select()
              .eq('drone_id', droneId)
              .order('recorded_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (tel != null && mounted) {
            setState(() {
              final speed = tel['speed'];
              final alt = tel['altitude'];
              final battery = tel['battery_level'];
              final signal = tel['signal_strength'];
              final heading = tel['heading'];

              if (speed != null) {
                _flightSpeed = '$speed km/h';
              } else if (status == DeliveryStatus.delivered) {
                _flightSpeed = '0 km/h';
              }
              if (alt != null) {
                _flightAltitude = '$alt m';
              } else if (status == DeliveryStatus.delivered) {
                _flightAltitude = '0 m';
              }
              if (battery != null) {
                _droneBatteryText = '$battery%';
              }
              if (signal != null) {
                _signalStrengthText = '$signal%';
              }
              if (heading != null) {
                _headingText = '$heading°';
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error in _fetchDetails: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveries = ref.watch(deliveryProvider);
    final providerDelivery = deliveries
        .where((d) => d.id == widget.deliveryId)
        .firstOrNull;

    final baseDelivery = providerDelivery ?? _fetchedDelivery;
    final status = baseDelivery?.status ?? DeliveryStatus.pending;
    final progress = (status == DeliveryStatus.delivered)
        ? 1.0
        : (baseDelivery?.progress ?? 0.0).clamp(0.0, 1.0);

    final double? parsedBattery = double.tryParse(
      _droneBatteryText.replaceAll('%', '').trim(),
    );
    final double? parsedSpeed = double.tryParse(
      _flightSpeed.replaceAll('km/h', '').trim(),
    );
    final double? parsedAlt = double.tryParse(
      _flightAltitude.replaceAll('m', '').trim(),
    );

    final activeDelivery =
        (baseDelivery ??
                DeliveryModel(
                  id: widget.deliveryId,
                  senderName: '',
                  recipientName: '',
                  recipientPhone: '',
                  deliveryAddress: '',
                  packageName: 'AeroDrop Package',
                  packageWeight: 0,
                  packageType: 'Package',
                  status: status,
                  eta: 'TBD',
                  createdAt: DateTime.now(),
                  progress: progress,
                ))
            .copyWith(
              status: status,
              progress: progress,
              pickupLocationName:
                  baseDelivery?.pickupLocationName ?? _pickupName,
              dropoffLocationName:
                  baseDelivery?.dropoffLocationName ?? _dropoffName,
              batteryLevel:
                  baseDelivery?.batteryLevel ??
                  parsedBattery ??
                  (status == DeliveryStatus.delivered ? 88.0 : 96.0),
              currentSpeed:
                  baseDelivery?.currentSpeed ??
                  parsedSpeed ??
                  (status == DeliveryStatus.delivered ? 0.0 : 18.0),
              currentAltitude:
                  baseDelivery?.currentAltitude ??
                  parsedAlt ??
                  (status == DeliveryStatus.delivered ? 0.0 : 25.0),
            );

    final isDelivered = activeDelivery.status == DeliveryStatus.delivered;
    final isAssigning = activeDelivery.status == DeliveryStatus.assigning;

    // Same inputs and resolver as the radar below, so the header and the
    // radar's badge always describe the same moment
    TelemetryModel? telemetry;
    try {
      telemetry =
          ref.watch(deliveryTelemetryProvider(widget.deliveryId)) ??
          ref.watch(fleetTelemetryProvider);
    } catch (_) {
      telemetry = null;
    }
    final phase = resolveFlightPhase(
      delivery: activeDelivery,
      droneStatus: ref.watch(droneProvider).firstOrNull?.status,
      telemetryEvent: telemetry?.eventType,
    );
    final loadLabel = nextLoadLabel(activeDelivery).toUpperCase();

    final radarTitle = switch (phase) {
      FlightPhase.headingToPickup => 'HEADING TO PICKUP',
      FlightPhase.atVendor => 'AT VENDOR · COLLECTING $loadLabel',
      FlightPhase.delivering => 'DRONE EN ROUTE',
      FlightPhase.returningToVendor =>
        'RETURNING TO VENDOR · COLLECTING $loadLabel',
      FlightPhase.returningToBase =>
        isDelivered ? 'DELIVERED · RETURNING TO BASE' : 'RETURNING TO BASE',
      FlightPhase.delivered => 'DELIVERED',
      FlightPhase.standby =>
        isDelivered
            ? 'DELIVERED'
            : (isAssigning ? 'HEADING TO PICKUP' : 'DRONE EN ROUTE'),
    };

    // Between trips deliveries.progress is reset for the next load, so the
    // card shows how many loads have arrived instead of a stalled 0% / 100%
    final betweenTrips =
        phase == FlightPhase.returningToVendor || phase == FlightPhase.atVendor;
    final progressPercent = (activeDelivery.progress * 100).round();
    final progressBadge = betweenTrips
        ? 'Loads: ${activeDelivery.tripsCompleted} of ${activeDelivery.tripsRequired}'
        : 'Progress: $progressPercent%';
    final progressValue = betweenTrips
        ? activeDelivery.tripsCompleted / activeDelivery.tripsRequired
        : activeDelivery.progress;

    // Chat with the other party, kept in the app bar so it stays reachable
    // while the map is in view. Same conditions as the order details button.
    final routePath = GoRouterState.of(context).uri.path;
    final isVendor = routePath.startsWith('/vendor');
    final chatOrderId = activeDelivery.orderId;
    final chatOrder = chatOrderId == null || chatOrderId.isEmpty
        ? null
        : (isVendor
                  ? ref.watch(vendorOrdersProvider).orders
                  : ref.watch(orderProvider).orders)
              .where((o) => o.id == chatOrderId)
              .firstOrNull;
    final showChat =
        chatOrder != null &&
        chatOrder.vendorId.isNotEmpty &&
        !chatOrder.chatAwaitingPayment;

    return Scaffold(
      backgroundColor: AppColors.base,
      appBar: CustomAppBar(
        title: isDelivered ? 'Delivery Completed' : 'Live Flight Tracking',
        subtitle:
            'ID: ${widget.deliveryId.length > 8 ? widget.deliveryId.substring(0, 8).toUpperCase() : widget.deliveryId}',
        action: showChat
            ? OrderChatAction(orderId: chatOrder.id, isVendor: isVendor)
            : null,
      ),
      body: Container(
        decoration: BoxDecoration(color: AppColors.base),
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.base,
            onRefresh: () async {
              await ref
                  .read(deliveryProvider.notifier)
                  .loadDeliveriesFromSupabase();
              await _fetchDetails();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: StaggeredColumn(
                  delayMs: 60,
                  children: [
                    const SizedBox(height: 12),

                    // Simulated Drone Radar / Campus Map
                    SharedDroneRadar(
                      delivery: activeDelivery,
                      isCompact: false,
                      title: radarTitle,
                    ),
                    const SizedBox(height: 16),

                    // ETA / Arrival Status Card
                    NeuCard(
                      padding: const EdgeInsets.all(20),
                      accent: isDelivered
                          ? AppColors.success
                          : AppColors.primary,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  (isDelivered
                                          ? AppColors.success
                                          : AppColors.primary)
                                      .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isDelivered
                                  ? Icons.check_circle_rounded
                                  : Icons.timer_rounded,
                              color: isDelivered
                                  ? AppColors.success
                                  : AppColors.primaryLight,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isDelivered
                                      ? 'Delivery Status'
                                      : 'Estimated Arrival Time',
                                  style: AppTextStyles.body(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isDelivered
                                      ? 'Order Delivered Successfully 🎉'
                                      : activeDelivery.status ==
                                            DeliveryStatus.cancelled
                                      ? 'Cancelled'
                                      : isAssigning
                                      ? 'En Route to Pickup'
                                      : '${activeDelivery.eta} remaining',
                                  style: AppTextStyles.title(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDelivered
                                        ? AppColors.success
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Live Telemetry & Authoritative Progress Card
                    NeuCard(
                      padding: const EdgeInsets.all(20),
                      accent: AppColors.accent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isDelivered
                                    ? 'Delivery Summary'
                                    : 'Flight Telemetry',
                                style: AppTextStyles.title(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accent,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (isDelivered
                                              ? AppColors.success
                                              : AppColors.accent)
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color:
                                        (isDelivered
                                                ? AppColors.success
                                                : AppColors.accent)
                                            .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  progressBadge,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDelivered
                                        ? AppColors.success
                                        : AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progressValue,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation(
                                isDelivered
                                    ? AppColors.success
                                    : AppColors.accent,
                              ),
                              minHeight: 8,
                            ),
                          ),
                          if (activeDelivery.isMultiTrip) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Trip ${activeDelivery.currentTrip} of ${activeDelivery.tripsRequired}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDelivered
                                    ? AppColors.success
                                    : AppColors.accent,
                              ),
                            ),
                          ],
                          Divider(color: AppColors.border, height: 24),
                          _rowDetail(
                            Icons.airplanemode_active_rounded,
                            'Drone',
                            _droneName,
                          ),
                          _rowDetail(
                            Icons.my_location_rounded,
                            'Current Location',
                            isDelivered
                                ? _dropoffName
                                : (isAssigning
                                      ? 'En route to $_pickupName'
                                      : 'Flying along campus flight path'),
                          ),
                          _rowDetail(
                            Icons.flag_rounded,
                            'Destination',
                            _dropoffName,
                          ),
                          Builder(
                            builder: (context) {
                              final tel = ref.watch(
                                deliveryTelemetryProvider(widget.deliveryId),
                              );
                              final batteryDisplay = tel?.batteryLevel != null
                                  ? '${tel!.batteryLevel!.round()}%'
                                  : (activeDelivery.batteryLevel != null
                                        ? '${activeDelivery.batteryLevel!.round()}%'
                                        : _droneBatteryText);
                              final speedDisplay = isDelivered
                                  ? '0.0 m/s'
                                  : (tel?.speed != null
                                        ? '${tel!.speed!.toStringAsFixed(1)} m/s'
                                        : ((activeDelivery.currentSpeed ??
                                                      0.0) >
                                                  0
                                              ? '${activeDelivery.currentSpeed!.toStringAsFixed(1)} m/s'
                                              : '—'));
                              final altDisplay = isDelivered
                                  ? '0.0 m'
                                  : (tel?.altitude != null
                                        ? '${tel!.altitude!.toStringAsFixed(1)} m'
                                        : ((activeDelivery.currentAltitude ??
                                                      0.0) >
                                                  0
                                              ? '${activeDelivery.currentAltitude!.toStringAsFixed(1)} m'
                                              : '—'));
                              final sigDisplay = tel?.signalStrength != null
                                  ? '${tel!.signalStrength!.round()}%'
                                  : _signalStrengthText;
                              final headDisplay = tel?.heading != null
                                  ? '${tel!.heading!.round()}°'
                                  : _headingText;

                              return Column(
                                children: [
                                  _rowDetail(
                                    Icons.battery_charging_full_rounded,
                                    'Battery Level',
                                    batteryDisplay,
                                  ),
                                  _rowDetail(
                                    Icons.speed_rounded,
                                    'Flight Speed',
                                    speedDisplay,
                                  ),
                                  _rowDetail(
                                    Icons.height_rounded,
                                    'Altitude',
                                    altDisplay,
                                  ),
                                  _rowDetail(
                                    Icons.wifi_rounded,
                                    'Signal Strength',
                                    sigDisplay,
                                  ),
                                  _rowDetail(
                                    Icons.explore_rounded,
                                    'Heading',
                                    headDisplay,
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Route details
                    NeuCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Route Waypoints',
                            style: AppTextStyles.title(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Divider(color: AppColors.border, height: 24),
                          _rowDetail(
                            Icons.storefront_rounded,
                            'Pickup Point',
                            _pickupName,
                          ),
                          _rowDetail(
                            Icons.place_rounded,
                            'Drop-off Pad',
                            _dropoffName,
                          ),
                          _rowDetail(
                            Icons.shield_outlined,
                            'Autopilot Mode',
                            isDelivered
                                ? 'Delivery Complete (Landed)'
                                : (isAssigning
                                      ? 'Waypoints Engaged (Leg 1)'
                                      : 'Autonomous Transit (Leg 2)'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowDetail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTextStyles.body(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: AppTextStyles.title(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
