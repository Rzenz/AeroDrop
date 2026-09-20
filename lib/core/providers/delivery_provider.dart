import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../models/delivery_model.dart';
import 'drone_provider.dart';
import '../models/drone_model.dart';
import '../services/supabase_service.dart';
import 'notification_provider.dart';
import 'auth_provider.dart';
import 'order_provider.dart';
import 'weather_provider.dart';

class DeliveryNotifier extends StateNotifier<List<DeliveryModel>> {
  final Ref ref;
  Timer? _simulationTimer;
  final Map<String, double> _deliveryStartBatteries = {};
  final Map<String, double> _leg3StartBatteries = {};
  final Set<String> _confirmingPickupDeliveryIds = {};
  final Set<String> _completingDeliveryIds = {};
  final Set<String> _completingReturnDroneIds = {};
  final Map<String, double> _leg3Progress = {};
  final Map<String, (double, double)> _leg3Origin = {};
  final Map<String, String> _lastDeliveryIdForDrone = {};
  final Map<String, DateTime> _leaseWriteFailures = {};
  RealtimeChannel? _deliveriesSubscription;
  RealtimeChannel? _telemetrySubscription;
  DateTime? _lastTelemetryWriteTime;

  DeliveryNotifier(this.ref) : super([]) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.user == null || !next.sessionUnlocked) {
        _simulationTimer?.cancel();
        _simulationTimer = null;
        _unsubscribeRealtime();
        state = [];
      } else if (previous?.user?.id != next.user?.id ||
          previous?.sessionUnlocked != next.sessionUnlocked) {
        loadDeliveriesFromSupabase();
        refreshPendingDeliveriesCount();
        _subscribeRealtime();
        _startSimulation();
      }
    });

    Future<void>.microtask(() {
      if (mounted) loadDeliveriesFromSupabase();
    });
    Future<void>.microtask(() {
      if (mounted) refreshPendingDeliveriesCount();
    });
    _subscribeRealtime();
    _startSimulation();
  }

  void _subscribeRealtime() {
    if (!SupabaseService.isConfigured) return;
    _unsubscribeRealtime();

    try {
      // Listen to deliveries table updates
      _deliveriesSubscription = SupabaseService.client
          .channel('public:deliveries_sync')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'deliveries',
            callback: (payload) {
              if (mounted) loadDeliveriesFromSupabase();
            },
          )
          .subscribe();

      // Listen to authoritative telemetry stream
      _telemetrySubscription = SupabaseService.client
          .channel('public:telemetry_sync')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'drone_telemetry',
            callback: (payload) {
              if (mounted) _handleRealtimeTelemetry(payload.newRecord);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to delivery realtime: $e');
    }
  }

  void _unsubscribeRealtime() {
    _deliveriesSubscription?.unsubscribe();
    _deliveriesSubscription = null;
    _telemetrySubscription?.unsubscribe();
    _telemetrySubscription = null;
  }

  void _handleRealtimeTelemetry(Map<String, dynamic> record) {
    final deliveryId = record['delivery_id']?.toString();
    final droneId = record['drone_id']?.toString();

    final lat = _toDoubleOrNull(record['latitude']);
    final lng = _toDoubleOrNull(record['longitude']);
    final alt = _toDoubleOrNull(record['altitude']);
    final speed = _toDoubleOrNull(record['speed']);
    final battery = _toDoubleOrNull(record['battery_level']);
    final progress = _toDoubleOrNull(record['progress']);
    final eventType = record['event_type']?.toString();

    if (battery != null) {
      try {
        ref.read(droneProvider.notifier).updateBattery(droneId ?? 'DRN-001', battery);
      } catch (_) {}
    }

    if (lat != null && lng != null) {
      try {
        ref.read(droneProvider.notifier).updateCoordinates(droneId ?? 'DRN-001', '$lat,$lng');
      } catch (_) {}
    }

    if (deliveryId != null) {
      state = state.map((del) {
        if (del.id == deliveryId) {
          return del.copyWith(
            currentLatitude: lat ?? del.currentLatitude,
            currentLongitude: lng ?? del.currentLongitude,
            currentAltitude: alt ?? del.currentAltitude,
            currentSpeed: speed ?? del.currentSpeed,
            batteryLevel: battery ?? del.batteryLevel,
            progress: (eventType == 'returning_to_base' && del.status == DeliveryStatus.delivered)
                ? del.progress
                : (progress ?? del.progress),
          );
        }
        return del;
      }).toList();
    }
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _unsubscribeRealtime();
    super.dispose();
  }

  double _toDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  DateTime _toDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  DeliveryStatus _parseDeliveryStatus(dynamic value) {
    if (value is DeliveryStatus) return value;
    final status = value?.toString().toLowerCase() ?? '';

    switch (status) {
      case 'pending':
        return DeliveryStatus.pending;
      case 'assigning':
        return DeliveryStatus.assigning;
      case 'intransit':
      case 'in_transit':
        return DeliveryStatus.inTransit;
      case 'delivered':
        return DeliveryStatus.delivered;
      case 'cancelled':
      case 'rejected':
        return DeliveryStatus.cancelled;
      default:
        return DeliveryStatus.pending;
    }
  }


  String _calculateEtaFromTimestamps(Map<String, dynamic> data) {
    final status = data['status']?.toString().toLowerCase() ?? '';
    if (status == 'delivered') return '0 mins';
    if (status != 'intransit' && status != 'in_transit') {
      return data['eta']?.toString() ?? 'TBD';
    }

    final startedAt = data['delivery_started_at'] != null
        ? DateTime.tryParse(data['delivery_started_at'].toString())
        : null;
    if (startedAt == null) return data['eta']?.toString() ?? 'TBD';

    final weather = ref.read(weatherProvider);
    final speedFactor = weather.isCaution ? 0.7 : 1.0;

    final totalSecs =
        (((data['estimated_delivery_seconds'] as num?)?.toInt() ?? 60) /
                speedFactor)
            .round();
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final remaining = (totalSecs - elapsed).clamp(0, totalSecs);
    if (remaining <= 0) return '0 mins';
    if (remaining < 60) return '$remaining secs';
    return '${(remaining / 60).ceil()} mins';
  }

  double _calculatePaymentAmount({
    required double packageWeight,
    required String priority,
    required String packageType,
    required double estimatedDistanceKm,
  }) {
    final baseFee = 20.0;
    final distanceFee = estimatedDistanceKm * 100.0;
    final weightFee = packageWeight * 20.0;

    double itemFee = 5.0;
    switch (packageType) {
      case 'Documents':
        itemFee = 0.0;
        break;
      case 'Medicine':
      case 'Food':
      case 'Other':
        itemFee = 5.0;
        break;
      case 'Electronics':
        itemFee = 10.0;
        break;
    }

    double priorityFee = 0.0;
    switch (priority) {
      case 'Standard':
        priorityFee = 0.0;
        break;
      case 'Express':
        priorityFee = 10.0;
        break;
      case 'Scheduled':
        priorityFee = 5.0;
        break;
    }

    return baseFee + distanceFee + weightFee + itemFee + priorityFee;
  }

  String _generatePaymentReference() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'PAY-$timestamp';
  }

  DeliveryModel _mapToDeliveryModel(Map<String, dynamic> data) {
    final order = data['orders'] != null
        ? Map<String, dynamic>.from(data['orders'])
        : {};

    // Customer/Recipient
    final customer = order['customer'] != null
        ? Map<String, dynamic>.from(order['customer'])
        : {};
    final recipientName =
        customer['full_name']?.toString() ?? 'Unknown Recipient';
    final recipientPhone = customer['phone_number']?.toString() ?? '';

    // Vendor/Sender
    final vendor = order['vendor'] != null
        ? Map<String, dynamic>.from(order['vendor'])
        : {};
    final senderName =
        vendor['business_name']?.toString() ??
        vendor['full_name']?.toString() ??
        'Unknown Vendor';

    // Dropoff location/Address
    final location = order['campus_locations'] != null
        ? Map<String, dynamic>.from(order['campus_locations'])
        : {};
    final deliveryAddress =
        location['name']?.toString() ??
        data['delivery_address']?.toString() ??
        'UCLM Campus';

    final pickupLoc = data['pickup_loc'] != null
        ? Map<String, dynamic>.from(data['pickup_loc'])
        : null;
    final dropoffLoc = data['dropoff_loc'] != null
        ? Map<String, dynamic>.from(data['dropoff_loc'])
        : null;

    final pickupLocationId =
        data['pickup_location_id']?.toString() ?? pickupLoc?['id']?.toString();
    final dropoffLocationId =
        data['dropoff_location_id']?.toString() ??
        dropoffLoc?['id']?.toString();
    final pickupLocationName =
        pickupLoc?['name']?.toString() ??
        (senderName.isNotEmpty ? senderName : 'Vendor Shop');
    final dropoffLocationName =
        dropoffLoc?['name']?.toString() ?? deliveryAddress;

    final currentLat =
        _toDoubleOrNull(data['current_latitude']) ??
        _toDoubleOrNull(data['latitude']) ??
        _toDoubleOrNull(pickupLoc?['latitude']);
    final currentLng =
        _toDoubleOrNull(data['current_longitude']) ??
        _toDoubleOrNull(data['longitude']) ??
        _toDoubleOrNull(pickupLoc?['longitude']);
    final currentAlt =
        _toDoubleOrNull(data['current_altitude']) ??
        _toDoubleOrNull(data['altitude']);
    final currentSpd =
        _toDoubleOrNull(data['current_speed']) ??
        _toDoubleOrNull(data['speed']);
    final battLvl = _toDoubleOrNull(data['battery_level']);

    // Items / Package Details
    final items = order['order_items'] as List? ?? [];
    String packageName = 'AeroDrop Package';
    double packageWeight = 0.0;

    if (items.isNotEmpty) {
      final names = items
          .map(
            (i) =>
                '${i['product_name']?.toString() ?? ''} (x${i['quantity'] ?? 1})',
          )
          .where((n) => n.isNotEmpty)
          .toList();
      packageName = names.join(', ');
      if (packageName.isEmpty) packageName = 'AeroDrop Package';

      int totalWeightGrams = 0;
      for (final i in items) {
        final w = (i['weight_grams'] as num?)?.toInt() ?? 0;
        final q = (i['quantity'] as num?)?.toInt() ?? 1;
        totalWeightGrams += w * q;
      }
      packageWeight = totalWeightGrams / 1000.0;
    } else {
      packageName = 'No package items available.';
    }

    final status = _parseDeliveryStatus(data['status']);

    // Single authoritative source of truth: deliveries.progress
    final double rawProgress = (data['progress'] as num?)?.toDouble() ?? 0.0;
    final progressVal = (status == DeliveryStatus.delivered)
        ? 1.0
        : rawProgress.clamp(0.0, 1.0);

    return DeliveryModel(
      id: data['id'].toString(),
      senderName: senderName,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      deliveryAddress: deliveryAddress,
      packageName: packageName,
      packageWeight: packageWeight,
      packageType: 'Food', // visual label
      status: status,
      droneId: data['drone_id'] != null ? 'DRN-001' : null,
      eta: _calculateEtaFromTimestamps(data),
      createdAt: _toDateTime(data['created_at']),
      progress: progressVal,
      estimatedDistanceKm: data.containsKey('estimated_distance_km')
          ? _toDoubleOrNull(data['estimated_distance_km'])
          : null,
      paymentAmount: _toDoubleOrNull(order['total_amount']),
      deliveryStartedAt: data['delivery_started_at'] != null
          ? DateTime.tryParse(data['delivery_started_at'].toString())
          : null,
      estimatedDeliverySeconds:
          (data['estimated_delivery_seconds'] as num?)?.toInt() ?? 60,
      deliveredAt: data['delivered_at'] != null
          ? DateTime.tryParse(data['delivered_at'].toString())
          : null,
      pickupLocationId: pickupLocationId,
      dropoffLocationId: dropoffLocationId,
      pickupLocationName: pickupLocationName,
      dropoffLocationName: dropoffLocationName,
      currentLatitude: currentLat,
      currentLongitude: currentLng,
      currentAltitude: currentAlt,
      currentSpeed: currentSpd,
      batteryLevel: battLvl,
    );
  }

  Future<void> loadDeliveriesFromSupabase() async {
    if (!SupabaseService.isConfigured) return;

    final currentUser = SupabaseService.client.auth.currentUser;

    if (currentUser == null) {
      debugPrint('Load deliveries skipped: no logged in user.');
      state = [];
      return;
    }

    try {
      final response = await SupabaseService.client
          .from('deliveries')
          .select('''
            *,
            pickup_loc:campus_locations!pickup_location_id(id, name, latitude, longitude),
            dropoff_loc:campus_locations!dropoff_location_id(id, name, latitude, longitude),
            orders!order_id(
              *,
              vendor:users!vendor_id(full_name, business_name),
              customer:users!user_id(full_name, phone_number),
              campus_locations!delivery_location_id(name),
              order_items(product_name, quantity, weight_grams)
            )
          ''')
          .order('created_at', ascending: false);

      if (!mounted) return;

      final authUser = ref.read(authProvider).user;
      final isAdmin = authUser?.isAdmin ?? false;
      final isVendor = authUser?.isVendor ?? false;

      final deliveries = (response as List)
          .where((item) {
            if (isAdmin) return true;
            final ord = item['orders'];
            if (ord == null) return false;
            if (isVendor) {
              return ord['vendor_id']?.toString() == currentUser.id;
            }
            return ord['user_id']?.toString() == currentUser.id;
          })
          .map<DeliveryModel>((item) {
            final data = Map<String, dynamic>.from(item);
            return _mapToDeliveryModel(data);
          })
          .toList();

      state = deliveries;
    } catch (error) {
      debugPrint('Load deliveries failed: $error');
    }
  }

  Future<String?> _checkWeatherSafety() async {
    if (!SupabaseService.isConfigured) return null;

    try {
      final weather = await SupabaseService.client
          .from('weather_safety')
          .select()
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (weather == null) {
        return 'No weather record configured. Drone dispatch blocked.';
      }

      final weatherStatus = weather['safety_status']?.toString();
      final dispatchEnabled = weather['dispatch_enabled'] == true;
      final windSpeed = _toDouble(weather['wind_speed_kph']);
      final temp = _toDouble(weather['temperature_c']);
      final maxWind = _toDouble(weather['max_safe_wind_kph'], 35);
      final maxTemp = _toDouble(weather['max_safe_temperature_c'], 38);
      final advisory =
          weather['advisory_message']?.toString() ??
          'Weather conditions are unsafe for dispatch.';

      if (weatherStatus == 'grounded' || !dispatchEnabled) {
        return advisory;
      }

      if (windSpeed > maxWind) {
        return 'Dispatch disabled. Wind speed is too high.';
      }

      if (temp > maxTemp) {
        return 'Dispatch disabled. Temperature is too high.';
      }

      return null;
    } catch (error) {
      debugPrint('Weather safety check failed: $error');
      return 'Weather check failed: $error';
    }
  }

  Future<void> _insertFirstTelemetry({
    required String deliveryId,
    required double batteryLevel,
  }) async {
    if (!SupabaseService.isConfigured) return;

    try {
      await SupabaseService.client.rpc(
        'record_simulated_telemetry',
        params: {
          'p_delivery_id': deliveryId,
          'p_latitude': 10.32800,
          'p_longitude': 123.95000,
          'p_altitude': 0.0,
          'p_speed': 0.0,
          'p_battery_level': batteryLevel,
          'p_signal_strength': 100.0,
          'p_heading': 0.0,
          'p_event_type': 'standby',
          'p_progress': 0.0,
        },
      );
    } catch (error) {
      debugPrint('First telemetry RPC failed: $error');
    }
  }

  Future<void> _insertStatusLog({
    required String deliveryId,
    required String status,
    required String message,
  }) async {
    if (!SupabaseService.isConfigured) return;

    try {
      // Plain text status column — no UUID lookup needed.
      await SupabaseService.client.from('delivery_status_logs').insert({
        'delivery_id': deliveryId,
        'status': status,
        'message': message,
      });
    } catch (error) {
      debugPrint('Delivery status log insert failed: $error');
    }
  }

  /// After a user-initiated cancellation the Supabase trigger inserts a
  /// 'Delivery Rejected' notification (it can't distinguish who cancelled).
  /// This patches that row to the correct user-cancellation copy.
  Future<void> _fixCancelNotification(String deliveryId, String userId) async {
    if (!SupabaseService.isConfigured) return;
    try {
      await SupabaseService.client
          .from('notifications')
          .update({
            'title': 'Delivery Request Cancelled',
            'message': 'You cancelled your delivery request.',
            'type': 'delivery_cancelled',
          })
          .eq('user_id', userId)
          .eq('related_delivery_id', deliveryId)
          .or('type.eq.delivery_rejected,type.eq.delivery_cancelled');
    } catch (e) {
      debugPrint('Fix cancel notification error: $e');
    }
  }

  void _startSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser == null) {
        timer.cancel();
        _simulationTimer?.cancel();
        _simulationTimer = null;
        return;
      }

      final activeDeliveries = state
          .where(
            (d) =>
                (d.status == DeliveryStatus.assigning ||
                    d.status == DeliveryStatus.inTransit) &&
                !_completingDeliveryIds.contains(d.id),
          )
          .toList();

      final dronesList = ref.read(droneProvider);
      _completingReturnDroneIds.removeWhere((id) => dronesList.any(
            (d) => (d.id == id || d.dbId == id) && d.status != DroneStatus.returning,
          ));
      final returningDrone = dronesList
          .where((d) =>
              d.status == DroneStatus.returning &&
              !_completingReturnDroneIds.contains(d.dbId) &&
              !_completingReturnDroneIds.contains(d.id))
          .firstOrNull;

      if (activeDeliveries.isEmpty && returningDrone == null) return;

      // Single-writer coordination: avoid competing write loops
      if (_lastTelemetryWriteTime != null &&
          DateTime.now().difference(_lastTelemetryWriteTime!).inMilliseconds <
              2200) {
        return;
      }
      _lastTelemetryWriteTime = DateTime.now();

      final weatherState = ref.read(weatherProvider);
      final isCaution = weatherState.isCaution;
      final speed = isCaution ? 3.5 : 5.0;
      final stepLeg1 = isCaution ? 0.07 : 0.12;
      final stepLeg2 = isCaution ? 0.07 : 0.10;
      final stepLeg3 = isCaution ? 0.07 : 0.10;
      final batteryDrainPerLeg = isCaution ? 8.5 : 6.0;

      String droneUuid = '80000000-0000-0000-0000-000000000001';
      if (returningDrone != null && returningDrone.dbId.isNotEmpty) {
        droneUuid = returningDrone.dbId;
      } else if (dronesList.isNotEmpty && dronesList.first.dbId.isNotEmpty) {
        droneUuid = dronesList.first.dbId;
      } else if (SupabaseService.isConfigured) {
        try {
          final res = await SupabaseService.client
              .from('drones')
              .select('id')
              .eq('drone_code', 'DRN-001')
              .maybeSingle();
          if (res != null) {
            droneUuid = res['id'].toString();
          }
        } catch (_) {}
      }

      if (!mounted) {
        timer.cancel();
        return;
      }

      final coords = {
        'old building': (10.3156, 123.9016),
        'main': (10.3156, 123.9016),
        'annex 1 building': (10.3159, 123.9019),
        'annex-1': (10.3159, 123.9019),
        'annex 2 building': (10.3154, 123.9021),
        'annex-2': (10.3154, 123.9021),
        'basic education building': (10.3148, 123.9014),
        'basic-ed': (10.3148, 123.9014),
        'maritime building': (10.3163, 123.9025),
        'maritime': (10.3163, 123.9025),
      };
      final hub = (10.3168, 123.9010);

      for (final delivery in activeDeliveries) {
        if (_completingDeliveryIds.contains(delivery.id) ||
            delivery.status == DeliveryStatus.delivered ||
            delivery.progress >= 1.0) {
          continue;
        }

        final pickupQuery = (delivery.pickupLocationName ?? 'old building')
            .toLowerCase();
        final dropoffQuery =
            (delivery.dropoffLocationName ?? delivery.deliveryAddress)
                .toLowerCase();

        (double, double) vendorLoc = (10.3156, 123.9016);
        for (final entry in coords.entries) {
          if (pickupQuery.contains(entry.key) ||
              entry.key.contains(pickupQuery)) {
            vendorLoc = entry.value;
            break;
          }
        }

        (double, double) customerLoc = (10.3156, 123.9016);
        for (final entry in coords.entries) {
          if (dropoffQuery.contains(entry.key) ||
              entry.key.contains(dropoffQuery)) {
            customerLoc = entry.value;
            break;
          }
        }

        if (delivery.status == DeliveryStatus.assigning) {
          // ── PHASE 1: PICKUP (Hub -> Vendor) ──
          final currentLegProgress = delivery.progress.clamp(0.0, 1.0);
          final newLegProgress = (currentLegProgress + stepLeg1).clamp(0.0, 1.0);

          final lat = hub.$1 + (vendorLoc.$1 - hub.$1) * newLegProgress;
          final lng = hub.$2 + (vendorLoc.$2 - hub.$2) * newLegProgress;
          final alt = newLegProgress > 0.85 ? 1.5 : 15.0;

          final startBattery = _deliveryStartBatteries[delivery.id] ?? 98.0;
          final newBattery = (startBattery - (batteryDrainPerLeg * newLegProgress)).clamp(
            0.0,
            100.0,
          );

          _lastDeliveryIdForDrone[droneUuid] = delivery.id;
          _leg3Origin[droneUuid] = (lat, lng);

          if (SupabaseService.isConfigured) {
            SupabaseService.client
                .rpc(
                  'record_simulated_telemetry',
                  params: {
                    'p_delivery_id': delivery.id,
                    'p_latitude': lat,
                    'p_longitude': lng,
                    'p_altitude': alt,
                    'p_speed': speed,
                    'p_battery_level': newBattery,
                    'p_signal_strength': 98.0,
                    'p_heading': 90.0,
                    'p_event_type': 'traveling_to_pickup',
                    'p_progress': newLegProgress,
                  },
                )
                .catchError(
                  (e) => debugPrint('Pickup telemetry RPC error: $e'),
                );

            SupabaseService.client
                .from('drones')
                .update({'battery_level': newBattery})
                .eq('id', droneUuid)
                .catchError(
                  (e) => debugPrint('Drone battery update error: $e'),
                );
          }

          if (newLegProgress >= 1.0) {
            // Drone arrived at vendor! Idempotently confirm package pickup
            if (!_confirmingPickupDeliveryIds.contains(delivery.id)) {
              _confirmingPickupDeliveryIds.add(delivery.id);

              // Optimistically transition to inTransit with progress 0.0 immediately
              state = state
                  .map(
                    (d) => d.id == delivery.id
                        ? d.copyWith(
                            status: DeliveryStatus.inTransit,
                            progress: 0.0,
                            currentLatitude: vendorLoc.$1,
                            currentLongitude: vendorLoc.$2,
                            currentAltitude: 1.5,
                            batteryLevel: newBattery,
                          )
                        : d,
                  )
                  .toList();

              if (SupabaseService.isConfigured) {
                try {
                  await SupabaseService.client.rpc(
                    'confirm_package_pickup',
                    params: {'p_delivery_id': delivery.id},
                  );
                } catch (e) {
                  debugPrint('confirm_package_pickup RPC error: $e');
                }
              }

              try {
                ref.read(orderProvider.notifier).loadOrders();
                ref.read(vendorOrdersProvider.notifier).loadOrders();
                loadDeliveriesFromSupabase();
              } catch (_) {}
            }
          } else {
            state = state
                .map(
                  (d) => d.id == delivery.id
                      ? d.copyWith(
                          progress: newLegProgress,
                          currentLatitude: lat,
                          currentLongitude: lng,
                          currentAltitude: alt,
                          currentSpeed: speed,
                          batteryLevel: newBattery,
                        )
                      : d,
                )
                .toList();
          }
        } else if (delivery.status == DeliveryStatus.inTransit) {
          // ── PHASE 2: TRANSIT (Vendor -> Customer) ──
          final currentLegProgress = delivery.progress.clamp(0.0, 1.0);
          final newLegProgress = (currentLegProgress + stepLeg2).clamp(0.0, 1.0);

          final lat =
              vendorLoc.$1 + (customerLoc.$1 - vendorLoc.$1) * newLegProgress;
          final lng =
              vendorLoc.$2 + (customerLoc.$2 - vendorLoc.$2) * newLegProgress;
          final alt = newLegProgress > 0.85 ? 0.5 : 15.0;

          final startBattery = _deliveryStartBatteries[delivery.id] ?? (98.0 - batteryDrainPerLeg);
          final newBattery = (startBattery - (batteryDrainPerLeg * newLegProgress)).clamp(
            0.0,
            100.0,
          );

          _lastDeliveryIdForDrone[droneUuid] = delivery.id;
          _leg3Origin[droneUuid] = (lat, lng);

          if (newLegProgress >= 1.0) {
            // Drone arrived at customer dropoff! Idempotently complete delivery
            if (!_completingDeliveryIds.contains(delivery.id)) {
              _completingDeliveryIds.add(delivery.id);
              _deliveryStartBatteries.remove(delivery.id);
              _lastDeliveryIdForDrone[droneUuid] = delivery.id;
              _leg3Origin[droneUuid] = customerLoc;
              _leg3Progress[droneUuid] = 0.0;
              _leg3StartBatteries[droneUuid] = newBattery;

              // Optimistically transition to delivered with progress 1.0
              state = state
                  .map(
                    (d) => d.id == delivery.id
                        ? d.copyWith(
                            status: DeliveryStatus.delivered,
                            progress: 1.0,
                            currentLatitude: customerLoc.$1,
                            currentLongitude: customerLoc.$2,
                            currentAltitude: 0.0,
                            batteryLevel: newBattery,
                          )
                        : d,
                  )
                  .toList();

              if (SupabaseService.isConfigured) {
                try {
                  await SupabaseService.client.rpc(
                    'complete_delivery_order',
                    params: {'p_delivery_id': delivery.id},
                  );
                } catch (e) {
                  debugPrint('complete_delivery_order RPC error: $e');
                }
              }

              try {
                ref.read(orderProvider.notifier).loadOrders();
                ref.read(vendorOrdersProvider.notifier).loadOrders();
                ref
                    .read(droneProvider.notifier)
                    .updateStatus('DRN-001', DroneStatus.returning);
                loadDeliveriesFromSupabase();
              } catch (_) {}
            }
          } else {
            // Only send in-flight telemetry while still active and uncompleted
            if (SupabaseService.isConfigured &&
                !_completingDeliveryIds.contains(delivery.id)) {
              SupabaseService.client
                  .rpc(
                    'record_simulated_telemetry',
                    params: {
                      'p_delivery_id': delivery.id,
                      'p_latitude': lat,
                      'p_longitude': lng,
                      'p_altitude': alt,
                      'p_speed': speed,
                      'p_battery_level': newBattery,
                      'p_signal_strength': 98.0,
                      'p_heading': 90.0,
                      'p_event_type': 'in_flight',
                      'p_progress': newLegProgress,
                    },
                  )
                  .catchError(
                    (e) => debugPrint('Transit telemetry RPC error: $e'),
                  );

              SupabaseService.client
                  .from('drones')
                  .update({'battery_level': newBattery})
                  .eq('id', droneUuid)
                  .catchError(
                    (e) => debugPrint('Drone battery update error: $e'),
                  );
            }

            state = state
                .map(
                  (d) => d.id == delivery.id
                      ? d.copyWith(
                          progress: newLegProgress,
                          currentLatitude: lat,
                          currentLongitude: lng,
                          currentAltitude: alt,
                          currentSpeed: speed,
                          batteryLevel: newBattery,
                        )
                      : d,
                )
                .toList();
          }
        }
      }

      // ── PHASE 3: LEG 3 DRIVER (Customer/Aborted Position -> Base Hub) ──
      if (returningDrone != null) {
        final dUuid = returningDrone.dbId.isNotEmpty
            ? returningDrone.dbId
            : droneUuid;
        String? deliveryIdForTelemetry = _lastDeliveryIdForDrone[dUuid];

        if (deliveryIdForTelemetry == null) {
          // Find the most recently updated delivery for THIS drone with status 'delivered' OR 'cancelled'
          final matchingDeliveries = state.where((d) {
            final matchesDrone = d.droneId == dUuid ||
                d.droneId == returningDrone.id ||
                d.droneId == returningDrone.dbId ||
                d.droneId == returningDrone.name ||
                d.droneId == 'DRN-001';
            final isDeliveredOrCancelled =
                d.status == DeliveryStatus.delivered ||
                d.status == DeliveryStatus.cancelled;
            return matchesDrone && isDeliveredOrCancelled;
          }).toList();

          if (matchingDeliveries.isNotEmpty) {
            matchingDeliveries.sort((a, b) {
              final timeA = a.deliveredAt ?? a.createdAt;
              final timeB = b.deliveredAt ?? b.createdAt;
              return timeB.compareTo(timeA);
            });
            deliveryIdForTelemetry = matchingDeliveries.first.id;
          } else if (SupabaseService.isConfigured) {
            try {
              final res = await SupabaseService.client
                  .from('deliveries')
                  .select('id')
                  .eq('drone_id', dUuid)
                  .inFilter('status', ['delivered', 'cancelled'])
                  .order('updated_at', ascending: false)
                  .limit(1)
                  .maybeSingle();
              if (res != null) {
                deliveryIdForTelemetry = res['id']?.toString();
              }
            } catch (_) {}
          }
        }

        // If none is found, skip writing telemetry this tick.
        if (deliveryIdForTelemetry == null) return;

        // Check if current user is authorized to write telemetry for this delivery
        final authUser = ref.read(authProvider).user;
        final isAdmin = authUser?.role == 'admin';
        final isCustomer = ref.read(orderProvider).orders.any(
              (o) =>
                  o.deliveryId == deliveryIdForTelemetry ||
                  o.id == deliveryIdForTelemetry,
            );
        final isVendor = ref.read(vendorOrdersProvider).orders.any(
              (o) =>
                  o.deliveryId == deliveryIdForTelemetry ||
                  o.id == deliveryIdForTelemetry,
            );

        final isAuthorized = isAdmin || isCustomer || isVendor;

        final lastFailure = _leaseWriteFailures[dUuid];
        final isBackoffActive = lastFailure != null &&
            DateTime.now().difference(lastFailure).inSeconds < 15;

        bool hasLease = false;
        // Only try to claim/renew lease if authorized and not in 15s failure backoff
        if (isAuthorized &&
            !isBackoffActive &&
            SupabaseService.isConfigured) {
          try {
            final leaseRes = await SupabaseService.client.rpc(
              'claim_drone_sim_lease',
              params: {'p_drone_id': dUuid},
            );
            hasLease = leaseRes == true;
          } catch (e) {
            debugPrint('claim_drone_sim_lease RPC error: $e');
          }
        }

        if (hasLease) {
          final leg3Start = _leg3Origin[dUuid] ??
              (returningDrone.currentCoordinates.contains(',')
                  ? (
                      double.tryParse(
                            returningDrone.currentCoordinates
                                .split(',')[0]
                                .trim(),
                          ) ??
                          10.3156,
                      double.tryParse(
                            returningDrone.currentCoordinates
                                .split(',')[1]
                                .trim(),
                          ) ??
                          123.9016,
                    )
                  : (10.3156, 123.9016));

          final currentLeg3Progress =
              (_leg3Progress[dUuid] ?? 0.0).clamp(0.0, 1.0);
          final newLeg3Progress =
              (currentLeg3Progress + stepLeg3).clamp(0.0, 1.0);
          _leg3Progress[dUuid] = newLeg3Progress;

          final lat =
              leg3Start.$1 + (hub.$1 - leg3Start.$1) * newLeg3Progress;
          final lng =
              leg3Start.$2 + (hub.$2 - leg3Start.$2) * newLeg3Progress;
          final alt = newLeg3Progress > 0.85 ? 0.0 : 15.0;

          final startBattery = _leg3StartBatteries[dUuid] ?? returningDrone.batteryLevel;
          if (!_leg3StartBatteries.containsKey(dUuid)) {
            _leg3StartBatteries[dUuid] = startBattery;
          }
          final newBattery = (startBattery -
                  (batteryDrainPerLeg * newLeg3Progress))
              .clamp(0.0, 100.0);

          if (SupabaseService.isConfigured) {
            try {
              await SupabaseService.client.rpc(
                'record_simulated_telemetry',
                params: {
                  'p_delivery_id': deliveryIdForTelemetry,
                  'p_latitude': lat,
                  'p_longitude': lng,
                  'p_altitude': alt,
                  'p_speed': speed,
                  'p_battery_level': newBattery,
                  'p_signal_strength': 98.0,
                  'p_heading': 270.0,
                  'p_event_type': 'returning_to_base',
                  'p_progress': newLeg3Progress,
                },
              );
              // Telemetry write succeeded: clear failure backoff
              _leaseWriteFailures.remove(dUuid);
            } catch (e) {
              debugPrint('Leg 3 telemetry RPC error: $e');
              // Record failure time: stop renewing lease for 15s to allow other clients or safety net to take over
              _leaseWriteFailures[dUuid] = DateTime.now();
            }

            SupabaseService.client
                .from('drones')
                .update({'battery_level': newBattery})
                .eq('id', dUuid)
                .catchError(
                  (e) => debugPrint('Drone battery update error: $e'),
                );
          }

          ref
              .read(droneProvider.notifier)
              .updateBattery(returningDrone.id, newBattery);

          if (newLeg3Progress >= 1.0) {
            // Drone arrived back at Campus Base Hub!
            _completingReturnDroneIds.add(dUuid);
            _completingReturnDroneIds.add(returningDrone.id);
            _leg3Progress.remove(dUuid);
            _leg3Origin.remove(dUuid);
            _lastDeliveryIdForDrone.remove(dUuid);
            _leaseWriteFailures.remove(dUuid);
            _leg3StartBatteries.remove(dUuid);

            // Optimistically set available status so display updates and no more leg 3 ticks write
            ref
                .read(droneProvider.notifier)
                .updateStatus(returningDrone.id, DroneStatus.available);

            if (SupabaseService.isConfigured) {
              try {
                await SupabaseService.client.rpc(
                  'complete_drone_return',
                  params: {'p_drone_id': dUuid},
                );
              } catch (e) {
                debugPrint('complete_drone_return RPC error: $e');
              }
            }

            try {
              ref.read(droneProvider.notifier).loadDronesFromSupabase();
              ref.read(orderProvider.notifier).loadOrders();
              ref.read(vendorOrdersProvider.notifier).loadOrders();
              loadDeliveriesFromSupabase();
            } catch (_) {}
          }
        }
      }
    });
  }

  Future<String?> createDelivery({
    required String senderName,
    required String recipientName,
    required String recipientPhone,
    required String deliveryAddress,
    required String packageName,
    required double packageWeight,
    required String packageType,
    String priority = 'Standard',
    String paymentMethod = 'Cash',
    String? pickupLocationId,
    String? dropoffLocationId,
    DateTime? scheduledAt,
    double? pickupLatitude,
    double? pickupLongitude,
    double? dropoffLatitude,
    double? dropoffLongitude,
    double estimatedDistanceKm = 0.0,
  }) async {
    if (packageWeight <= 0) {
      return 'Please enter a valid package weight.';
    }

    if (packageWeight > 0.5) {
      return 'Package is too heavy. Maximum supported drone payload is 0.5 kg.';
    }

    if (pickupLocationId != null &&
        dropoffLocationId != null &&
        pickupLocationId == dropoffLocationId) {
      return 'Pickup and drop-off location cannot be the same.';
    }

    if (!SupabaseService.isConfigured) {
      return 'Supabase is not configured.';
    }

    final currentUser = SupabaseService.client.auth.currentUser;

    if (currentUser == null) {
      return 'You must be logged in to request a delivery.';
    }

    try {
      // 1. Check DRN-001 Drone Battery
      final droneResponse = await SupabaseService.client
          .from('drones')
          .select('battery_level')
          .eq('drone_code', 'DRN-001')
          .maybeSingle();

      if (droneResponse != null) {
        final droneBattery = _toDouble(droneResponse['battery_level'], 100.0);
        if (droneBattery < 10.0) {
          return 'Drone battery is too low. Please try again later.';
        }
      }

      // 2. Check Weather Safety
      final weatherResponse = await SupabaseService.client
          .from('weather_safety')
          .select()
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (weatherResponse == null) {
        return 'No weather record configured. Drone dispatch blocked.';
      }

      final weatherStatus =
          weatherResponse['safety_status']?.toString() ?? 'grounded';
      final dispatchEnabled = weatherResponse['dispatch_enabled'] != false;

      // Grounded check — insert a cancelled record for audit trail then block
      if (weatherStatus == 'grounded' || !dispatchEnabled) {
        try {
          final paymentAmountGrounded = _calculatePaymentAmount(
            packageWeight: packageWeight,
            priority: priority,
            packageType: packageType,
            estimatedDistanceKm: estimatedDistanceKm,
          );
          final nowStr = DateTime.now().toUtc().toIso8601String();

          // 1. Insert order (cancelled)
          final orderRes = await SupabaseService.client
              .from('orders')
              .insert({
                'user_id': currentUser.id,
                'order_status': 'cancelled',
                'delivery_location_id':
                    dropoffLocationId ?? '10000000-0000-0000-0000-000000000001',
                'total_amount': paymentAmountGrounded,
                'created_at': nowStr,
                'updated_at': nowStr,
              })
              .select()
              .single();
          final orderId = orderRes['id'].toString();

          // 2. Insert delivery (cancelled)
          await SupabaseService.client
              .from('deliveries')
              .insert({
                'order_id': orderId,
                'status': 'cancelled',
                'priority': priority,
                'pickup_location_id':
                    pickupLocationId ?? '10000000-0000-0000-0000-000000000001',
                'dropoff_location_id':
                    dropoffLocationId ?? '10000000-0000-0000-0000-000000000001',
                'delivery_progress': 0.0,
                'eta': 'Cancelled',
                'estimated_distance_km': estimatedDistanceKm,
                'created_at': nowStr,
                'updated_at': nowStr,
                'delivered_at': nowStr,
              })
              .select()
              .single();

          // 3. Insert package as order item
          await SupabaseService.client.from('order_items').insert({
            'order_id': orderId,
            'product_name': packageName,
            'quantity': 1,
            'unit_price': paymentAmountGrounded,
            'weight_grams': (packageWeight * 1000).toInt(),
            'subtotal': paymentAmountGrounded,
            'created_at': nowStr,
          });
        } catch (e) {
          debugPrint('Grounded delivery audit insert failed (non-fatal): $e');
        }
        return 'Delivery cancelled due to unsafe weather.';
      }

      // Caution check

      const eta = 'Waiting for admin approval';

      final paymentAmount = _calculatePaymentAmount(
        packageWeight: packageWeight,
        priority: priority,
        packageType: packageType,
        estimatedDistanceKm: estimatedDistanceKm,
      );
      const paymentStatus = 'paid';
      final paymentReference = _generatePaymentReference();

      final nowStr = DateTime.now().toUtc().toIso8601String();

      // 1. Insert order
      final orderRes = await SupabaseService.client
          .from('orders')
          .insert({
            'user_id': currentUser.id,
            'order_status': 'pending',
            'delivery_location_id':
                dropoffLocationId ?? '10000000-0000-0000-0000-000000000001',
            'total_amount': paymentAmount,
            'payment_method': paymentMethod,
            'payment_status': paymentStatus,
            'payment_reference': paymentReference,
            'created_at': nowStr,
            'updated_at': nowStr,
          })
          .select()
          .single();
      final orderId = orderRes['id'].toString();

      // 2. Insert delivery
      final deliveryRes = await SupabaseService.client
          .from('deliveries')
          .insert({
            'order_id': orderId,
            'status': 'pending',
            'priority': priority,
            'pickup_location_id':
                pickupLocationId ?? '10000000-0000-0000-0000-000000000001',
            'dropoff_location_id':
                dropoffLocationId ?? '10000000-0000-0000-0000-000000000001',
            'delivery_progress': 0.0,
            'eta': eta,
            'estimated_distance_km': estimatedDistanceKm,
            'created_at': nowStr,
            'updated_at': nowStr,
          })
          .select()
          .single();
      final deliveryId = deliveryRes['id'].toString();

      // 3. Insert package as order item
      await SupabaseService.client.from('order_items').insert({
        'order_id': orderId,
        'product_name': packageName,
        'quantity': 1,
        'unit_price': paymentAmount,
        'weight_grams': (packageWeight * 1000).toInt(),
        'subtotal': paymentAmount,
        'created_at': nowStr,
      });

      // Fetch the full delivery data with all joins to map it correctly
      final fullDeliveryRes = await SupabaseService.client
          .from('deliveries')
          .select('''
            *,
            orders!order_id(
              *,
              vendor:users!vendor_id(full_name, business_name),
              customer:users!user_id(full_name, phone_number),
              campus_locations!delivery_location_id(name),
              order_items(product_name, quantity, weight_grams)
            )
          ''')
          .eq('id', deliveryId)
          .single();

      final createdDelivery = _mapToDeliveryModel(
        Map<String, dynamic>.from(fullDeliveryRes),
      );

      state = [createdDelivery, ...state];
      return null;
    } catch (error) {
      debugPrint('Create delivery failed: $error');
      return 'Delivery request failed. Please check Supabase or terminal logs.';
    }
  }

  void updateDeliveryStatus(
    String id,
    DeliveryStatus status, {
    String? droneId,
  }) {
    state = state.map((delivery) {
      if (delivery.id == id) {
        return delivery.copyWith(
          status: status,
          droneId: droneId ?? delivery.droneId,
          progress: status == DeliveryStatus.delivered
              ? 1.0
              : (status == DeliveryStatus.inTransit ? 0.1 : 0.0),
          eta: status == DeliveryStatus.delivered
              ? '0 mins'
              : (status == DeliveryStatus.inTransit ? '10 mins' : 'TBD'),
        );
      }

      return delivery;
    }).toList();

    if (SupabaseService.isConfigured) {
      SupabaseService.client
          .from('deliveries')
          .update({'status': status.name, 'drone_id': droneId})
          .eq('id', id)
          .then((_) async {
            await _insertStatusLog(
              deliveryId: id,
              status: status.name,
              message: 'Delivery status updated to ${status.name}.',
            );
          })
          .catchError((error) {
            debugPrint('Delivery status update failed: $error');
          });
    }
  }

  Future<String?> acceptDelivery(String deliveryId) async {
    if (!SupabaseService.isConfigured) return 'Supabase is not configured';

    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) return 'You must be logged in.';

    try {
      final deliveryData = await SupabaseService.client
          .from('deliveries')
          .select('*, orders!order_id(*, order_items(weight_grams, quantity))')
          .eq('id', deliveryId)
          .maybeSingle();

      if (deliveryData == null) {
        return 'Delivery request not found.';
      }

      // Plain text status column
      final statusStr = deliveryData['status']?.toString();
      if (statusStr == 'cancelled') {
        return 'This delivery request has already been cancelled.';
      }

      final orderMap = deliveryData['orders'] as Map<String, dynamic>?;
      final orderItems = orderMap?['order_items'] as List? ?? [];

      int totalWeightGrams = 0;
      for (final item in orderItems) {
        final w = (item['weight_grams'] as num?)?.toInt() ?? 0;
        final q = (item['quantity'] as num?)?.toInt() ?? 1;
        totalWeightGrams += w * q;
      }
      final packageWeight = totalWeightGrams / 1000.0;

      if (packageWeight > 0.5) {
        return 'Package is too heavy. Maximum supported drone payload is 0.5 kg.';
      }

      final weatherError = await _checkWeatherSafety();
      if (weatherError != null) {
        return 'Weather check failed: $weatherError';
      }

      // Query DRN-001 drone UUID dynamically
      final droneLookup = await SupabaseService.client
          .from('drones')
          .select()
          .eq('drone_code', 'DRN-001')
          .maybeSingle();

      if (droneLookup == null) {
        return 'AeroCarrier Alpha drone configuration (DRN-001) not found in database.';
      }

      final droneUuid = droneLookup['id'].toString();
      // status is now a plain text column
      final droneStatus = droneLookup['status']?.toString().toLowerCase();
      if (droneStatus != 'available') {
        return 'The drone is currently busy. Please wait until it becomes available.';
      }

      const minimumBatteryForDelivery = 10.0;
      final droneBattery = _toDouble(droneLookup['battery_level'], 100.0);

      if (droneBattery < minimumBatteryForDelivery) {
        return 'Drone battery is too low. Please recharge the drone before accepting deliveries.';
      }

      // Record battery level at start for progress-based drain simulation
      _deliveryStartBatteries[deliveryId] = droneBattery;

      final nowStr = DateTime.now().toUtc().toIso8601String();

      final updatedResponse = await SupabaseService.client
          .from('deliveries')
          .update({
            'status': 'in_transit',
            'drone_id': droneUuid,
            'delivery_started_at': nowStr,
            'estimated_delivery_seconds': 60,
            'progress': 0.0,
            'updated_at': nowStr,
          })
          .eq('id', deliveryId)
          .select('''
            *,
            orders!order_id(
              *,
              vendor:users!vendor_id(full_name, business_name),
              customer:users!user_id(full_name, phone_number),
              campus_locations!delivery_location_id(name),
              order_items(product_name, quantity, weight_grams)
            )
          ''')
          .single();

      await SupabaseService.client
          .from('drones')
          .update({'status': 'busy'})
          .eq('id', droneUuid);

      await _insertFirstTelemetry(
        deliveryId: deliveryId,
        batteryLevel: droneBattery,
      );

      await _insertStatusLog(
        deliveryId: deliveryId,
        status: 'accepted',
        message: 'Delivery request accepted by admin.',
      );

      await _insertStatusLog(
        deliveryId: deliveryId,
        status: 'in_transit',
        message: 'Delivery is now in transit.',
      );

      ref
          .read(droneProvider.notifier)
          .updateStatus('DRN-001', DroneStatus.busy);

      final updatedDelivery = _mapToDeliveryModel(
        Map<String, dynamic>.from(updatedResponse),
      );

      state = state
          .map((d) => d.id == deliveryId ? updatedDelivery : d)
          .toList();

      await refreshPendingDeliveriesCount();
      try {
        ref.read(orderProvider.notifier).loadOrders();
        ref.read(vendorOrdersProvider.notifier).loadOrders();
      } catch (_) {}

      return null;
    } catch (e) {
      debugPrint('Accept delivery error: $e');
      return 'Failed to accept delivery: ${e.toString()}';
    }
  }

  Future<bool> verifyPackage({
    required String deliveryId,
    required String remarks,
    String photoUrl = '',
  }) async {
    return true;
  }

  Future<String?> rejectDelivery(
    String deliveryId, {
    String reason = 'Rejected by admin',
  }) async {
    if (!SupabaseService.isConfigured) return 'Supabase is not configured';

    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) return 'You must be logged in.';

    try {
      final deliveryData = await SupabaseService.client
          .from('deliveries')
          .select('status')
          .eq('id', deliveryId)
          .maybeSingle();

      if (deliveryData != null) {
        final statusStr = deliveryData['status']?.toString();
        if (statusStr == 'cancelled') {
          return 'This delivery request has already been cancelled.';
        }
      }

      final nowStr = DateTime.now().toUtc().toIso8601String();

      final updatedResponse = await SupabaseService.client
          .from('deliveries')
          .update({
            'status': 'cancelled',
            'admin_decision_by': currentUser.id,
            'admin_decision_at': nowStr,
            'delivered_at': nowStr, // mark end time
          })
          .eq('id', deliveryId)
          .select('''
            *,
            orders!order_id(
              *,
              vendor:users!vendor_id(full_name, business_name),
              customer:users!user_id(full_name, phone_number),
              campus_locations!delivery_location_id(name),
              order_items(product_name, quantity, weight_grams)
            )
          ''')
          .single();

      final orderId = updatedResponse['order_id']?.toString() ??
          updatedResponse['orders']?['id']?.toString();
      if (orderId != null) {
        await SupabaseService.client
            .from('orders')
            .update({
              'order_status': 'cancelled',
              'cancellation_reason': 'vendor',
              'updated_at': nowStr,
            })
            .eq('id', orderId);
      }

      await _insertStatusLog(
        deliveryId: deliveryId,
        status: 'cancelled',
        message: 'Delivery request rejected: $reason',
      );

      final updatedDelivery = _mapToDeliveryModel(
        Map<String, dynamic>.from(updatedResponse),
      );

      state = state
          .map((d) => d.id == deliveryId ? updatedDelivery : d)
          .toList();

      await refreshPendingDeliveriesCount();

      return null;
    } catch (e) {
      debugPrint('Reject delivery error: $e');
      return 'Failed to reject delivery: ${e.toString()}';
    }
  }

  Future<String?> cancelDeliveryRequest(
    String deliveryId, {
    String reason = 'Cancelled by user',
  }) async {
    if (!SupabaseService.isConfigured) return 'Supabase is not configured';

    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) return 'You must be logged in.';

    try {
      final deliveryData = await SupabaseService.client
          .from('deliveries')
          .select('*, orders(user_id)')
          .eq('id', deliveryId)
          .maybeSingle();

      if (deliveryData == null) {
        return 'Delivery request not found.';
      }

      final userId = deliveryData['orders']?['user_id']?.toString();
      if (userId != currentUser.id) {
        return 'You do not have permission to cancel this delivery request.';
      }

      final statusStr = deliveryData['status']?.toString();
      if (statusStr != 'pending') {
        return 'Only pending delivery requests can be cancelled.';
      }

      final nowStr = DateTime.now().toUtc().toIso8601String();

      final updatedResponse = await SupabaseService.client
          .from('deliveries')
          .update({'status': 'cancelled', 'delivered_at': nowStr})
          .eq('id', deliveryId)
          .select('''
            *,
            orders!order_id(
              *,
              vendor:users!vendor_id(full_name, business_name),
              customer:users!user_id(full_name, phone_number),
              campus_locations!delivery_location_id(name),
              order_items(product_name, quantity, weight_grams)
            )
          ''')
          .single();

      final orderId = updatedResponse['order_id']?.toString() ??
          updatedResponse['orders']?['id']?.toString();
      if (orderId != null) {
        await SupabaseService.client
            .from('orders')
            .update({
              'order_status': 'cancelled',
              'cancellation_reason': 'customer',
              'updated_at': nowStr,
            })
            .eq('id', orderId);
      }

      await _insertStatusLog(
        deliveryId: deliveryId,
        status: 'cancelled',
        message: 'Delivery request was cancelled by the user.',
      );

      // Correct the trigger-generated notification to user-cancel copy
      await _fixCancelNotification(deliveryId, currentUser.id);

      final updatedDelivery = _mapToDeliveryModel(
        Map<String, dynamic>.from(updatedResponse),
      );

      state = state
          .map((d) => d.id == deliveryId ? updatedDelivery : d)
          .toList();

      await refreshPendingDeliveriesCount();

      // Reload notifications so the UI reflects the patched title/message
      ref.read(notificationProvider.notifier).loadNotifications();

      return null;
    } catch (e) {
      debugPrint('Cancel delivery request error: $e');
      return 'Failed to cancel request: ${e.toString()}';
    }
  }

  Future<void> loadAdminDeliveriesFromSupabase() async {
    if (!SupabaseService.isConfigured) return;
    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) {
      debugPrint('Load admin deliveries skipped: no logged in user.');
      state = [];
      return;
    }

    try {
      final response = await SupabaseService.client
          .from('deliveries')
          .select('''
            *,
            pickup_loc:campus_locations!pickup_location_id(id, name, latitude, longitude),
            dropoff_loc:campus_locations!dropoff_location_id(id, name, latitude, longitude),
            orders!order_id(
              *,
              vendor:users!vendor_id(full_name, business_name),
              customer:users!user_id(full_name, phone_number),
              campus_locations!delivery_location_id(name),
              order_items(product_name, quantity, weight_grams)
            )
          ''')
          .order('created_at', ascending: false);

      if (!mounted) return;

      final deliveries = (response as List).map<DeliveryModel>((item) {
        final data = Map<String, dynamic>.from(item);
        return _mapToDeliveryModel(data);
      }).toList();

      state = deliveries;
      await refreshPendingDeliveriesCount();
    } catch (error) {
      debugPrint('Load admin deliveries failed: $error');
    }
  }

  Future<void> refreshPendingDeliveriesCount() async {
    if (!SupabaseService.isConfigured) return;
    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) {
      debugPrint('Refresh pending count skipped: no logged in user.');
      ref.read(pendingDeliveriesCountProvider.notifier).state = 0;
      return;
    }

    try {
      final response = await SupabaseService.client
          .from('deliveries')
          .select('id')
          .eq('status', 'pending');

      if (!mounted) return;
      final count = (response as List).length;
      ref.read(pendingDeliveriesCountProvider.notifier).state = count;
    } catch (e) {
      debugPrint('Error refreshing pending deliveries count: $e');
    }
  }

  void clearDeliveries() {
    state = [];
  }
}

final pendingDeliveriesCountProvider = StateProvider<int>((ref) => 0);

final deliveryProvider =
    StateNotifierProvider<DeliveryNotifier, List<DeliveryModel>>((ref) {
      return DeliveryNotifier(ref);
    });
