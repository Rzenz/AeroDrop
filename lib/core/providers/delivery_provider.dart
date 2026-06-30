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

  DeliveryNotifier(this.ref) : super([]) {
    if (kSimulationMode) {
      ref.listen<List<DeliveryModel>>(
        deliveryMockProvider,
        (previous, next) {
          state = next;
        },
        fireImmediately: true,
      );
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

    final totalSecs = (data['estimated_delivery_seconds'] as num?)?.toInt() ?? 60;
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

    final totalSecs = (data['estimated_delivery_seconds'] as num?)?.toInt() ?? 60;
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

    final totalSecs = (data['estimated_delivery_seconds'] as num?)?.toInt() ?? 60;
    return DateTime.now().difference(startedAt).inSeconds >= totalSecs;
  }

  /// Marks a delivery as delivered in Supabase and local state if elapsed time
  /// has reached estimatedDeliverySeconds. Idempotent — checks status first.
  Future<void> _completeDeliveryIfNeeded(String deliveryId, String? droneId) async {
    if (!SupabaseService.isConfigured) return;
    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();

      await SupabaseService.client.from('deliveries').update({
        'status': 'delivered',
        'eta': '0 mins',
        'delivery_progress': 1.0,
        'delivered_at': nowStr,
      }).eq('id', deliveryId).eq('status', 'inTransit'); // only if still inTransit

      await _insertStatusLog(
        deliveryId: deliveryId,
        status: 'delivered',
        message: 'Delivery completed successfully.',
      );

      if (droneId != null) {
        final drones = ref.read(droneProvider);
        final idx = drones.indexWhere((d) => d.id == droneId);
        final battery = idx != -1 ? drones[idx].batteryLevel : 0.0;
        ref.read(droneProvider.notifier).updateStatus(droneId, DroneStatus.available);
        await SupabaseService.client.from('drones').update({
          'status': 'available',
          'battery_level': battery,
        }).eq('id', droneId);
      }
    } catch (e) {
      debugPrint('Auto-complete delivery error: $e');
    }
  }

  // ── Legacy fallback (used only when no timestamps available) ────────────
  double _progressFromStatus(dynamic value) {
    final status = value?.toString() ?? '';
    if (status == 'delivered') return 1.0;
    return 0.0;
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

  Future<void> loadDeliveriesFromSupabase() async {
    if (kSimulationMode) return;
    if (!SupabaseService.isConfigured) return;

    final currentUser = SupabaseService.client.auth.currentUser;

    if (currentUser == null) {
      debugPrint('Load deliveries skipped: no logged in user.');
      return;
    }

    try {
      final response = await SupabaseService.client
          .from('deliveries')
          .select()
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false);

      final deliveries = (response as List).map((item) {
        final data = Map<String, dynamic>.from(item);
        final isComplete = _isDeliveryCompleteFromTimestamps(data);
        return DeliveryModel(
          id: data['id'].toString(),
          senderName: data['sender_name']?.toString() ?? 'Unknown Sender',
          recipientName: data['recipient_name']?.toString() ?? 'Unknown Recipient',
          recipientPhone: data['recipient_phone']?.toString() ?? '',
          deliveryAddress: data['delivery_address']?.toString() ?? '',
          packageName: data['package_name']?.toString() ?? 'AeroDrop Package',
          packageWeight: _toDouble(data['package_weight'], 0.0),
          packageType: data['package_type']?.toString() ?? 'Other',
          status: isComplete ? DeliveryStatus.delivered : _parseDeliveryStatus(data['status']),
          droneId: data['drone_id']?.toString(),
          eta: _calculateEtaFromTimestamps(data),
          createdAt: _toDateTime(data['created_at']),
          progress: _calculateProgressFromTimestamps(data),
          estimatedDistanceKm: data.containsKey('estimated_distance_km') ? _toDoubleOrNull(data['estimated_distance_km']) : null,
          paymentAmount: data.containsKey('payment_amount') ? _toDoubleOrNull(data['payment_amount']) : null,
          deliveryStartedAt: data['delivery_started_at'] != null ? DateTime.tryParse(data['delivery_started_at'].toString()) : null,
          estimatedDeliverySeconds: (data['estimated_delivery_seconds'] as num?)?.toInt() ?? 60,
          deliveredAt: data['delivered_at'] != null ? DateTime.tryParse(data['delivered_at'].toString()) : null,
        );
      }).toList();

      state = deliveries;

      // Auto-complete any inTransit deliveries that have already elapsed
      for (final d in deliveries) {
        if (d.status == DeliveryStatus.inTransit &&
            d.deliveryStartedAt != null &&
            DateTime.now().difference(d.deliveryStartedAt!).inSeconds >= d.estimatedDeliverySeconds) {
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
          .eq('id', 1)
          .maybeSingle();

      if (weather == null) return null;

      final dispatchEnabled = weather['dispatch_enabled'] == true;
      final windSpeed = _toDouble(weather['wind_speed_kph']);
      final temp = _toDouble(weather['temperature_c']);
      final maxWind = _toDouble(weather['max_safe_wind_kph'], 35);
      final maxTemp = _toDouble(weather['max_safe_temperature_c'], 38);
      final advisory = weather['advisory_message']?.toString() ??
          'Weather conditions are unsafe for dispatch.';

      if (!dispatchEnabled) {
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
      return null;
    }
  }



  Future<void> _insertFirstTelemetry({
    required String droneId,
    required double batteryLevel,
  }) async {
    if (!SupabaseService.isConfigured) return;

    try {
      await SupabaseService.client.from('drone_telemetry').insert({
        'drone_id': droneId,
        'latitude': 10.32800,
        'longitude': 123.95000,
        'altitude': 0,
        'speed': 0,
        'battery_level': batteryLevel,
        'signal_strength': 100,
        'heading': 0,
      });
    } catch (error) {
      debugPrint('Telemetry placeholder insert failed: $error');
    }
  }

  Future<void> _insertStatusLog({
    required String deliveryId,
    required String status,
    required String message,
  }) async {
    if (!SupabaseService.isConfigured) return;

    try {
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

  Future<void> _insertPayment({
    required String deliveryId,
    required String userId,
    required String paymentMethod,
    required double amount,
    required String status,
    required String referenceNumber,
  }) async {
    if (!SupabaseService.isConfigured) return;

    try {
      await SupabaseService.client
          .from('payments')
          .insert({
            'delivery_id': deliveryId,
            'user_id': userId,
            'payment_method': paymentMethod,
            'amount': amount,
            'status': status,
            'reference_number': referenceNumber,
            'is_simulated': true,
            'notes': 'Simulated payment for AeroDrop delivery.',
          });
    } catch (error) {
      debugPrint('Payment insert failed: $error');
    }
  }

  void _startSimulation() {
    // ponytail: 5-second tick is a reasonable balance between responsiveness
    // and Supabase write pressure. Progress is read from timestamps so any
    // number of ticks doesn't accumulate error.
    _simulationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!state.any((d) => d.status == DeliveryStatus.inTransit)) return;

      final now = DateTime.now();

      // Track deliveries we need to auto-complete to avoid concurrent calls
      final toComplete = <String, String?>{}; // deliveryId -> droneId

      state = state.map((delivery) {
        if (delivery.status != DeliveryStatus.inTransit) return delivery;

        final startedAt = delivery.deliveryStartedAt;
        if (startedAt == null) return delivery;

        final totalSecs = delivery.estimatedDeliverySeconds;
        final elapsed = now.difference(startedAt).inSeconds;
        final progress = (elapsed / totalSecs).clamp(0.0, 1.0);

        if (progress >= 1.0) {
          toComplete[delivery.id] = delivery.droneId;
          return delivery.copyWith(
            status: DeliveryStatus.delivered,
            progress: 1.0,
            eta: '0 mins',
          );
        }

        // Drain battery while in transit
        if (delivery.droneId != null) {
          final drones = ref.read(droneProvider);
          final idx = drones.indexWhere((d) => d.id == delivery.droneId);
          if (idx != -1) {
            ref.read(droneProvider.notifier).updateBattery(
              delivery.droneId!,
              (drones[idx].batteryLevel - 1.5).clamp(0.0, 100.0),
            );
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

      // Fire-and-forget auto-completion for each completed delivery
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
      ref.read(deliveryMockProvider.notifier).createDelivery(
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

    if (pickupLocationId != null && dropoffLocationId != null && pickupLocationId == dropoffLocationId) {
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
      final status = DeliveryStatus.pending;
      const eta = 'Waiting for admin approval';

      final paymentAmount = _calculatePaymentAmount(
        packageWeight: packageWeight,
        priority: priority,
        packageType: packageType,
        estimatedDistanceKm: estimatedDistanceKm,
      );
      const paymentStatus = 'paid';
      final paymentReference = _generatePaymentReference();

      final deliveryPayload = <String, dynamic>{
        'user_id': currentUser.id,
        'sender_name': senderName,
        'recipient_name': recipientName,
        'recipient_phone': recipientPhone,
        'delivery_address': deliveryAddress,
        'package_name': packageName,
        'package_weight': packageWeight,
        'package_type': packageType,
        'status': status.name,
        'drone_id': null,
        'eta': eta,
        'priority': priority,
        'pickup_location_id': pickupLocationId,
        'dropoff_location_id': dropoffLocationId,
        'scheduled_at': scheduledAt?.toIso8601String(),
        'pickup_latitude': pickupLatitude,
        'pickup_longitude': pickupLongitude,
        'dropoff_latitude': dropoffLatitude,
        'dropoff_longitude': dropoffLongitude,
        'safety_status': 'Pending',
        'safety_message': 'Awaiting admin review.',
        'payment_method': paymentMethod,
        'payment_status': paymentStatus,
        'payment_amount': paymentAmount,
        'payment_reference': paymentReference,
        'estimated_distance_km': estimatedDistanceKm,
      };

      deliveryPayload.removeWhere((key, value) => value == null);

      dynamic response;
      try {
        response = await SupabaseService.client
            .from('deliveries')
            .insert(deliveryPayload)
            .select()
            .single();
      } catch (error) {
        final errStr = error.toString();
        if (errStr.contains('estimated_distance_km') || errStr.contains('column') || errStr.contains('42703')) {
          debugPrint('estimated_distance_km column does not exist, retrying without it...');
          deliveryPayload.remove('estimated_distance_km');
          response = await SupabaseService.client
              .from('deliveries')
              .insert(deliveryPayload)
              .select()
              .single();
        } else {
          rethrow;
        }
      }

      await _insertStatusLog(
        deliveryId: response['id'].toString(),
        status: status.name,
        message: 'Delivery request submitted and waiting for admin approval.',
      );

      await _insertPayment(
        deliveryId: response['id'].toString(),
        userId: currentUser.id,
        paymentMethod: paymentMethod,
        amount: paymentAmount,
        status: paymentStatus,
        referenceNumber: paymentReference,
      );

      final createdDelivery = DeliveryModel(
        id: response['id'].toString(),
        senderName: response['sender_name'] ?? senderName,
        recipientName: response['recipient_name'] ?? recipientName,
        recipientPhone: response['recipient_phone'] ?? recipientPhone,
        deliveryAddress: response['delivery_address'] ?? deliveryAddress,
        packageName: response['package_name'] ?? packageName,
        packageWeight: _toDouble(
          response['package_weight'],
          packageWeight,
        ),
        packageType: response['package_type'] ?? packageType,
        status: _parseDeliveryStatus(response['status']),
        droneId: response['drone_id']?.toString(),
        eta: response['eta'] ?? eta,
        createdAt: _toDateTime(response['created_at']),
        progress: _progressFromStatus(response['status']),
        estimatedDistanceKm: response.containsKey('estimated_distance_km') ? _toDoubleOrNull(response['estimated_distance_km']) : null,
        paymentAmount: response.containsKey('payment_amount') ? _toDoubleOrNull(response['payment_amount']) : null,
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
      ref.read(deliveryMockProvider.notifier).updateDeliveryStatus(
            id,
            status,
            droneId: droneId,
          );
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
          .update({
            'status': status.name,
            'drone_id': droneId,
          })
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
          .select()
          .eq('id', deliveryId)
          .maybeSingle();

      if (deliveryData == null) {
        return 'Delivery request not found.';
      }

      final statusStr = deliveryData['status']?.toString().toLowerCase();
      if (statusStr == 'cancelled') {
        return 'This delivery request has already been cancelled.';
      }

      final packageWeight = _toDouble(deliveryData['package_weight'], 0.0);

      if (packageWeight > 0.5) {
        return 'Package is too heavy. Maximum supported drone payload is 0.5 kg.';
      }

      final weatherError = await _checkWeatherSafety();
      if (weatherError != null) {
        return 'Weather check failed: $weatherError';
      }

      // Query DRN-001 (AeroCarrier Alpha) only
      final dronesResponse = await SupabaseService.client
          .from('drones')
          .select()
          .eq('id', 'DRN-001')
          .maybeSingle();

      if (dronesResponse == null) {
        return 'AeroCarrier Alpha drone configuration not found in database.';
      }

      final droneStatus = dronesResponse['status']?.toString().toLowerCase();
      if (droneStatus != 'available') {
        return 'The drone is currently busy. Please wait until it becomes available.';
      }

      const minimumBatteryForDelivery = 10.0;
      final selectedDrone = dronesResponse;
      final droneId = 'DRN-001';
      final droneBattery = _toDouble(selectedDrone['battery_level'], 100.0);

      if (droneBattery < minimumBatteryForDelivery) {
        return 'Drone battery is too low. Please recharge the drone before accepting deliveries.';
      }

      final nowStr = DateTime.now().toUtc().toIso8601String();

      final updatedResponse = await SupabaseService.client
          .from('deliveries')
          .update({
            'status': 'inTransit',
            'drone_id': droneId,
            'eta': '1 min',
            'admin_decision_by': currentUser.id,
            'admin_decision_at': nowStr,
            'accepted_at': nowStr,
            'safety_status': 'Safe',
            'safety_message': 'Accepted by admin. Drone assigned successfully.',
            'delivery_started_at': nowStr,
            'estimated_delivery_seconds': 60,
            'delivery_progress': 0,
          })
          .eq('id', deliveryId)
          .select()
          .single();

      await SupabaseService.client
          .from('drones')
          .update({
            'status': 'busy',
          })
          .eq('id', droneId);

      await _insertFirstTelemetry(
        droneId: droneId,
        batteryLevel: droneBattery,
      );

      await _insertStatusLog(
        deliveryId: deliveryId,
        status: 'accepted',
        message: 'Delivery request accepted by admin.',
      );

      await _insertStatusLog(
        deliveryId: deliveryId,
        status: 'inTransit',
        message: 'Delivery is now in transit.',
      );

      ref.read(droneProvider.notifier).updateStatus(droneId, DroneStatus.busy);

      final startedAt = DateTime.now().toUtc();
      final updatedDelivery = DeliveryModel(
        id: updatedResponse['id'].toString(),
        senderName: updatedResponse['sender_name']?.toString() ?? '',
        recipientName: updatedResponse['recipient_name']?.toString() ?? '',
        recipientPhone: updatedResponse['recipient_phone']?.toString() ?? '',
        deliveryAddress: updatedResponse['delivery_address']?.toString() ?? '',
        packageName: updatedResponse['package_name']?.toString() ?? '',
        packageWeight: _toDouble(updatedResponse['package_weight']),
        packageType: updatedResponse['package_type']?.toString() ?? '',
        status: DeliveryStatus.inTransit,
        droneId: updatedResponse['drone_id']?.toString(),
        eta: '1 min',
        createdAt: _toDateTime(updatedResponse['created_at']),
        progress: 0.0,
        estimatedDistanceKm: updatedResponse.containsKey('estimated_distance_km') ? _toDoubleOrNull(updatedResponse['estimated_distance_km']) : null,
        paymentAmount: updatedResponse.containsKey('payment_amount') ? _toDoubleOrNull(updatedResponse['payment_amount']) : null,
        deliveryStartedAt: startedAt,
        estimatedDeliverySeconds: 60,
      );

      state = state.map((d) => d.id == deliveryId ? updatedDelivery : d).toList();

      await refreshPendingDeliveriesCount();

      return null;
    } catch (e) {
      debugPrint('Accept delivery error: $e');
      return 'Failed to accept delivery: ${e.toString()}';
    }
  }

  Future<String?> rejectDelivery(String deliveryId, {String reason = 'Rejected by admin'}) async {
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
        final statusStr = deliveryData['status']?.toString().toLowerCase();
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
            'rejected_at': nowStr,
            'rejection_reason': reason,
            'safety_status': 'Rejected',
            'safety_message': reason,
          })
          .eq('id', deliveryId)
          .select()
          .single();

      await _insertStatusLog(
        deliveryId: deliveryId,
        status: 'cancelled',
        message: 'Delivery request rejected: $reason',
      );

      final updatedDelivery = DeliveryModel(
        id: updatedResponse['id'].toString(),
        senderName: updatedResponse['sender_name']?.toString() ?? '',
        recipientName: updatedResponse['recipient_name']?.toString() ?? '',
        recipientPhone: updatedResponse['recipient_phone']?.toString() ?? '',
        deliveryAddress: updatedResponse['delivery_address']?.toString() ?? '',
        packageName: updatedResponse['package_name']?.toString() ?? '',
        packageWeight: _toDouble(updatedResponse['package_weight']),
        packageType: updatedResponse['package_type']?.toString() ?? '',
        status: _parseDeliveryStatus(updatedResponse['status']),
        droneId: updatedResponse['drone_id']?.toString(),
        eta: updatedResponse['eta']?.toString() ?? 'TBD',
        createdAt: _toDateTime(updatedResponse['created_at']),
        progress: _progressFromStatus(updatedResponse['status']),
        estimatedDistanceKm: updatedResponse.containsKey('estimated_distance_km') ? _toDoubleOrNull(updatedResponse['estimated_distance_km']) : null,
        paymentAmount: updatedResponse.containsKey('payment_amount') ? _toDoubleOrNull(updatedResponse['payment_amount']) : null,
      );

      state = state.map((d) => d.id == deliveryId ? updatedDelivery : d).toList();

      await refreshPendingDeliveriesCount();

      return null;
    } catch (e) {
      debugPrint('Reject delivery error: $e');
      return 'Failed to reject delivery: ${e.toString()}';
    }
  }

  Future<String?> cancelDeliveryRequest(String deliveryId, {String reason = 'Cancelled by user'}) async {
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
          .select()
          .eq('id', deliveryId)
          .maybeSingle();

      if (deliveryData == null) {
        return 'Delivery request not found.';
      }

      final userId = deliveryData['user_id']?.toString();
      if (userId != currentUser.id) {
        return 'You do not have permission to cancel this delivery request.';
      }

      final statusStr = deliveryData['status']?.toString().toLowerCase();
      if (statusStr != 'pending') {
        return 'Only pending delivery requests can be cancelled.';
      }

      final nowStr = DateTime.now().toUtc().toIso8601String();

      final updatedResponse = await SupabaseService.client
          .from('deliveries')
          .update({
            'status': 'cancelled',
            'cancelled_at': nowStr,
            'cancelled_by': currentUser.id,
            'cancellation_reason': reason,
            'safety_status': 'Cancelled',
            'safety_message': reason,
            'eta': 'Cancelled',
          })
          .eq('id', deliveryId)
          .select()
          .single();

      await _insertStatusLog(
        deliveryId: deliveryId,
        status: 'cancelled',
        message: 'Delivery request was cancelled by the user.',
      );

      // Correct the trigger-generated notification to user-cancel copy
      await _fixCancelNotification(deliveryId, currentUser.id);

      final updatedDelivery = DeliveryModel(
        id: updatedResponse['id'].toString(),
        senderName: updatedResponse['sender_name']?.toString() ?? '',
        recipientName: updatedResponse['recipient_name']?.toString() ?? '',
        recipientPhone: updatedResponse['recipient_phone']?.toString() ?? '',
        deliveryAddress: updatedResponse['delivery_address']?.toString() ?? '',
        packageName: updatedResponse['package_name']?.toString() ?? '',
        packageWeight: _toDouble(updatedResponse['package_weight']),
        packageType: updatedResponse['package_type']?.toString() ?? '',
        status: _parseDeliveryStatus(updatedResponse['status']),
        droneId: updatedResponse['drone_id']?.toString(),
        eta: updatedResponse['eta']?.toString() ?? 'Cancelled',
        createdAt: _toDateTime(updatedResponse['created_at']),
        progress: _progressFromStatus(updatedResponse['status']),
        estimatedDistanceKm: updatedResponse.containsKey('estimated_distance_km') ? _toDoubleOrNull(updatedResponse['estimated_distance_km']) : null,
        paymentAmount: updatedResponse.containsKey('payment_amount') ? _toDoubleOrNull(updatedResponse['payment_amount']) : null,
      );

      state = state.map((d) => d.id == deliveryId ? updatedDelivery : d).toList();

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

    try {
      final response = await SupabaseService.client
          .from('deliveries')
          .select()
          .order('created_at', ascending: false);

      final deliveries = (response as List).map((item) {
        final data = Map<String, dynamic>.from(item);
        final isComplete = _isDeliveryCompleteFromTimestamps(data);
        return DeliveryModel(
          id: data['id'].toString(),
          senderName: data['sender_name']?.toString() ?? 'Unknown Sender',
          recipientName: data['recipient_name']?.toString() ?? 'Unknown Recipient',
          recipientPhone: data['recipient_phone']?.toString() ?? '',
          deliveryAddress: data['delivery_address']?.toString() ?? '',
          packageName: data['package_name']?.toString() ?? 'AeroDrop Package',
          packageWeight: _toDouble(data['package_weight'], 0.0),
          packageType: data['package_type']?.toString() ?? 'Other',
          status: isComplete ? DeliveryStatus.delivered : _parseDeliveryStatus(data['status']),
          droneId: data['drone_id']?.toString(),
          eta: _calculateEtaFromTimestamps(data),
          createdAt: _toDateTime(data['created_at']),
          progress: _calculateProgressFromTimestamps(data),
          estimatedDistanceKm: data.containsKey('estimated_distance_km') ? _toDoubleOrNull(data['estimated_distance_km']) : null,
          paymentAmount: data.containsKey('payment_amount') ? _toDoubleOrNull(data['payment_amount']) : null,
          deliveryStartedAt: data['delivery_started_at'] != null ? DateTime.tryParse(data['delivery_started_at'].toString()) : null,
          estimatedDeliverySeconds: (data['estimated_delivery_seconds'] as num?)?.toInt() ?? 60,
          deliveredAt: data['delivered_at'] != null ? DateTime.tryParse(data['delivered_at'].toString()) : null,
        );
      }).toList();

      state = deliveries;
      await refreshPendingDeliveriesCount();

      // Auto-complete any inTransit deliveries that have already elapsed
      for (final d in deliveries) {
        if (d.status == DeliveryStatus.inTransit &&
            d.deliveryStartedAt != null &&
            DateTime.now().difference(d.deliveryStartedAt!).inSeconds >= d.estimatedDeliverySeconds) {
          _completeDeliveryIfNeeded(d.id, d.droneId);
        }
      }
    } catch (error) {
      debugPrint('Load admin deliveries failed: $error');
    }
  }

  Future<void> refreshPendingDeliveriesCount() async {
    if (kSimulationMode) {
      final count = state.where((d) => d.status == DeliveryStatus.pending).length;
      ref.read(pendingDeliveriesCountProvider.notifier).state = count;
      return;
    }
    if (!SupabaseService.isConfigured) return;

    try {
      final response = await SupabaseService.client
          .from('deliveries')
          .select('id')
          .eq('status', 'pending');
      
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