import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/delivery_model.dart';
import 'drone_provider.dart';
import '../models/drone_model.dart';
import '../config/simulation_config.dart';
import '../../providers/mock/delivery_mock_provider.dart';
import '../services/supabase_service.dart';
import 'notification_provider.dart';

class DeliveryNotifier extends StateNotifier<List<DeliveryModel>> {
  final Ref ref;
  Timer? _simulationTimer;
  final Map<String, double> _deliveryStartBatteries = {};

  DeliveryNotifier(this.ref) : super([]) {
    if (kSimulationMode) {
      ref.listen<List<DeliveryModel>>(deliveryMockProvider, (previous, next) {
        state = next;
      }, fireImmediately: true);
    } else {
      Future.microtask(loadDeliveriesFromSupabase);
      Future.microtask(refreshPendingDeliveriesCount);
      _startSimulation();
    }
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
      case 'assigning':
        return DeliveryStatus.pending;
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

  // ── Timestamp-based progress helpers ────────────────────────────────────

  double _calculateProgressFromTimestamps(Map<String, dynamic> data) {
    final status = data['status']?.toString().toLowerCase() ?? '';
    if (status == 'delivered') return 1.0;
    if (status != 'intransit' && status != 'in_transit') return 0.0;

    final startedAt = data['delivery_started_at'] != null
        ? DateTime.tryParse(data['delivery_started_at'].toString())
        : null;
    if (startedAt == null) return 0.0;

    final totalSecs =
        (data['estimated_delivery_seconds'] as num?)?.toInt() ?? 60;
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    return (elapsed / totalSecs).clamp(0.0, 1.0);
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

    final totalSecs =
        (data['estimated_delivery_seconds'] as num?)?.toInt() ?? 60;
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final remaining = (totalSecs - elapsed).clamp(0, totalSecs);
    if (remaining <= 0) return '0 mins';
    if (remaining < 60) return '$remaining secs';
    return '${(remaining / 60).ceil()} mins';
  }

  bool _isDeliveryCompleteFromTimestamps(Map<String, dynamic> data) {
    final status = data['status']?.toString().toLowerCase() ?? '';
    if (status == 'delivered') return true;
    if (status != 'intransit' && status != 'in_transit') return false;

    final startedAt = data['delivery_started_at'] != null
        ? DateTime.tryParse(data['delivery_started_at'].toString())
        : null;
    if (startedAt == null) return false;

    final totalSecs =
        (data['estimated_delivery_seconds'] as num?)?.toInt() ?? 60;
    return DateTime.now().difference(startedAt).inSeconds >= totalSecs;
  }

  /// Marks a delivery as delivered in Supabase and local state if elapsed time
  /// has reached estimatedDeliverySeconds. Idempotent — checks status first.
  Future<void> _completeDeliveryIfNeeded(
    String deliveryId,
    String? droneId,
  ) async {
    if (!SupabaseService.isConfigured) return;
    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();

      // Use plain text status — no UUID lookup needed.
      await SupabaseService.client
          .from('deliveries')
          .update({
            'status': 'delivered',
            'eta': '0 mins',
            'delivery_progress': 1.0,
            'delivered_at': nowStr,
          })
          .eq('id', deliveryId)
          .eq('status', 'in_transit'); // only if still in_transit

      await _insertStatusLog(
        deliveryId: deliveryId,
        status: 'delivered',
        message: 'Delivery completed successfully.',
      );

      if (droneId != null) {
        final drones = ref.read(droneProvider);
        final idx = drones.indexWhere((d) => d.id == droneId);
        final battery = idx != -1 ? drones[idx].batteryLevel : 0.0;
        ref
            .read(droneProvider.notifier)
            .updateStatus(droneId, DroneStatus.available);

        final droneLookup = await SupabaseService.client
            .from('drones')
            .select('id')
            .eq('drone_code', 'DRN-001')
            .maybeSingle();
        final droneUuid = droneLookup != null
            ? droneLookup['id'].toString()
            : '80000000-0000-0000-0000-000000000001';

        await SupabaseService.client
            .from('drones')
            .update({'status': 'available', 'battery_level': battery})
            .eq('id', droneUuid);
      }
    } catch (e) {
      debugPrint('Auto-complete delivery error: $e');
    }
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

    final isComplete = _isDeliveryCompleteFromTimestamps(data);
    final status = isComplete
        ? DeliveryStatus.delivered
        : _parseDeliveryStatus(data['status']);

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
      progress: _calculateProgressFromTimestamps(data),
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
    );
  }

  Future<void> loadDeliveriesFromSupabase() async {
    if (kSimulationMode) return;
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

      final deliveries = (response as List)
          .where((item) {
            final userId = item['orders']?['user_id']?.toString();
            return userId == currentUser.id;
          })
          .map<DeliveryModel>((item) {
            final data = Map<String, dynamic>.from(item);
            return _mapToDeliveryModel(data);
          })
          .toList();

      state = deliveries;

      // Auto-complete any inTransit deliveries that have already elapsed
      for (final d in deliveries) {
        if (d.status == DeliveryStatus.inTransit &&
            d.deliveryStartedAt != null &&
            DateTime.now().difference(d.deliveryStartedAt!).inSeconds >=
                d.estimatedDeliverySeconds) {
          _completeDeliveryIfNeeded(d.id, d.droneId);
        }
      }
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
          'p_signal_strength': 100,
          'p_heading': 0.0,
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
    _simulationTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser == null) {
        timer.cancel();
        _simulationTimer?.cancel();
        _simulationTimer = null;
        return;
      }
      if (!state.any((d) => d.status == DeliveryStatus.inTransit)) return;

      // 1. Dynamically obtain drone UUID by drone_code = DRN-001
      String droneUuid = '80000000-0000-0000-0000-000000000001';
      if (SupabaseService.isConfigured) {
        try {
          final res = await SupabaseService.client
              .from('drones')
              .select('id')
              .eq('drone_code', 'DRN-001')
              .maybeSingle();
          if (res != null) {
            droneUuid = res['id'].toString();
          }
        } catch (e) {
          debugPrint('Error getting drone UUID: $e');
        }
      }

      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final toComplete = <String, String?>{}; // deliveryId -> droneId

      state = state.map((delivery) {
        if (delivery.status != DeliveryStatus.inTransit) return delivery;

        final startedAt = delivery.deliveryStartedAt;
        if (startedAt == null) return delivery;

        final totalSecs = delivery.estimatedDeliverySeconds;
        final elapsed = now.difference(startedAt).inSeconds;
        final progress = (elapsed / totalSecs).clamp(0.0, 1.0);

        final address = delivery.deliveryAddress;
        String pickup = 'Old Building';
        String dropoff = 'Old Building';
        if (address.startsWith('From ') && address.contains(' to ')) {
          pickup = address.substring(5, address.indexOf(' to '));
          dropoff = address.substring(address.indexOf(' to ') + 4);
        }

        final coords = {
          'old building': (10.3156, 123.9016),
          'annex 1 building': (10.3159, 123.9019),
          'annex 2 building': (10.3154, 123.9021),
          'basic education building': (10.3148, 123.9014),
          'maritime building': (10.3163, 123.9025),
        };

        final hub = (10.3168, 123.9010);
        final vendorLoc = coords[pickup.toLowerCase()] ?? (10.3156, 123.9016);
        final customerLoc =
            coords[dropoff.toLowerCase()] ?? (10.3156, 123.9016);

        double lat;
        double lng;
        double altitude = 15.0;

        if (progress < 0.5) {
          // Leg 1: Hub to Vendor (0.0 to 0.5 progress)
          final legProgress = progress / 0.5;
          lat = hub.$1 + (vendorLoc.$1 - hub.$1) * legProgress;
          lng = hub.$2 + (vendorLoc.$2 - hub.$2) * legProgress;
          // Hover near the vendor pickup area at the end of leg 1
          if (legProgress > 0.9) altitude = 2.0;
        } else {
          // Leg 2: Vendor to Customer (0.5 to 1.0 progress)
          final legProgress = (progress - 0.5) / 0.5;
          lat = vendorLoc.$1 + (customerLoc.$1 - vendorLoc.$1) * legProgress;
          lng = vendorLoc.$2 + (customerLoc.$2 - vendorLoc.$2) * legProgress;
          // Descend to drop off package at the end of leg 2
          if (legProgress > 0.9) altitude = 0.5;
        }

        final startBattery = _deliveryStartBatteries[delivery.id] ?? 95.0;
        final double tripConsumption = 12.0; // 12% total drain per trip
        final newBattery = (startBattery - (tripConsumption * progress)).clamp(
          0.0,
          100.0,
        );

        if (progress >= 1.0) {
          toComplete[delivery.id] = delivery.droneId;

          if (SupabaseService.isConfigured) {
            SupabaseService.client
                .rpc(
                  'record_simulated_telemetry',
                  params: {
                    'p_delivery_id': delivery.id,
                    'p_latitude': customerLoc.$1,
                    'p_longitude': customerLoc.$2,
                    'p_altitude': 0.0,
                    'p_speed': 0.0,
                    'p_battery_level': newBattery,
                    'p_signal_strength': 100,
                    'p_heading': 0.0,
                  },
                )
                .then((_) {})
                .catchError((e) {
                  debugPrint('Final telemetry RPC failed: $e');
                });
          }

          _deliveryStartBatteries.remove(delivery.id);

          return delivery.copyWith(
            status: DeliveryStatus.delivered,
            progress: 1.0,
            eta: '0 mins',
          );
        }

        if (delivery.droneId != null) {
          ref.read(droneProvider.notifier).updateBattery('DRN-001', newBattery);

          if (SupabaseService.isConfigured) {
            SupabaseService.client
                .rpc(
                  'record_simulated_telemetry',
                  params: {
                    'p_delivery_id': delivery.id,
                    'p_latitude': lat,
                    'p_longitude': lng,
                    'p_altitude': altitude,
                    'p_speed': 5.0,
                    'p_battery_level': newBattery,
                    'p_signal_strength': 95,
                    'p_heading': 90.0,
                  },
                )
                .then((_) {})
                .catchError((e) {
                  debugPrint('Active telemetry RPC failed: $e');
                });

            SupabaseService.client
                .from('drones')
                .update({'battery_level': newBattery})
                .eq('id', droneUuid)
                .then((_) {})
                .catchError((e) {
                  debugPrint('Update drone battery failed: $e');
                });
          }
        }

        final remaining = (totalSecs - elapsed).clamp(0, totalSecs);
        final etaStr = remaining <= 0
            ? '0 mins'
            : remaining < 60
            ? '$remaining secs'
            : '${(remaining / 60).ceil()} mins';

        return delivery.copyWith(progress: progress, eta: etaStr);
      }).toList();

      for (final entry in toComplete.entries) {
        _completeDeliveryIfNeeded(entry.key, entry.value);
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
    if (kSimulationMode) {
      ref
          .read(deliveryMockProvider.notifier)
          .createDelivery(
            senderName: senderName,
            recipientName: recipientName,
            recipientPhone: recipientPhone,
            deliveryAddress: deliveryAddress,
            packageName: packageName,
            packageWeight: packageWeight,
            packageType: packageType,
          );
      return null;
    }

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
    if (kSimulationMode) {
      ref
          .read(deliveryMockProvider.notifier)
          .updateDeliveryStatus(id, status, droneId: droneId);
      return;
    }

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
            'eta': '1 min',
            'admin_decision_by': currentUser.id,
            'admin_decision_at': nowStr,
            'accepted_at': nowStr,
            'delivery_started_at': nowStr,
            'estimated_delivery_seconds': 60,
            'delivery_progress': 0,
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
    if (kSimulationMode) {
      state = state.map((d) {
        if (d.id == deliveryId) {
          return d.copyWith(status: DeliveryStatus.cancelled);
        }
        return d;
      }).toList();
      return null;
    }

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
    if (kSimulationMode) return;
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

      // Auto-complete any inTransit deliveries that have already elapsed
      for (final d in deliveries) {
        if (d.status == DeliveryStatus.inTransit &&
            d.deliveryStartedAt != null &&
            DateTime.now().difference(d.deliveryStartedAt!).inSeconds >=
                d.estimatedDeliverySeconds) {
          _completeDeliveryIfNeeded(d.id, d.droneId);
        }
      }
    } catch (error) {
      debugPrint('Load admin deliveries failed: $error');
    }
  }

  Future<void> refreshPendingDeliveriesCount() async {
    if (kSimulationMode) {
      final count = state
          .where((d) => d.status == DeliveryStatus.pending)
          .length;
      ref.read(pendingDeliveriesCountProvider.notifier).state = count;
      return;
    }
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

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }
}

final pendingDeliveriesCountProvider = StateProvider<int>((ref) => 0);

final deliveryProvider =
    StateNotifierProvider<DeliveryNotifier, List<DeliveryModel>>((ref) {
      return DeliveryNotifier(ref);
    });
