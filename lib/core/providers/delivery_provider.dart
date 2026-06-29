import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/delivery_model.dart';
import 'drone_provider.dart';
import '../models/drone_model.dart';
import '../config/simulation_config.dart';
import '../../providers/mock/delivery_mock_provider.dart';
import '../services/supabase_service.dart';

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
      _startSimulation();
    }
  }

  double _toDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  DateTime _toDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  DeliveryStatus _parseDeliveryStatus(dynamic value) {
    final status = value?.toString() ?? '';

    switch (status) {
      case 'pending':
        return DeliveryStatus.pending;
      case 'inTransit':
      case 'in_transit':
        return DeliveryStatus.inTransit;
      case 'delivered':
        return DeliveryStatus.delivered;
      default:
        return DeliveryStatus.pending;
    }
  }

  double _progressFromStatus(dynamic value) {
    final status = value?.toString() ?? '';

    switch (status) {
      case 'delivered':
        return 1.0;
      case 'inTransit':
      case 'in_transit':
        return 0.25;
      default:
        return 0.0;
    }
  }

  double _calculatePaymentAmount({
    required double packageWeight,
    required String priority,
  }) {
    const baseFee = 50.0;
    final weightFee = packageWeight * 10.0;

    double priorityFee = 0.0;

    if (priority == 'Express') {
      priorityFee = 25.0;
    } else if (priority == 'Scheduled') {
      priorityFee = 10.0;
    }

    return baseFee + weightFee + priorityFee;
  }

  String _paymentStatusFromMethod(String paymentMethod) {
    if (paymentMethod == 'Cash') {
      return 'pending';
    }

    return 'paid';
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
      print('Load deliveries skipped: no logged in user.');
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

        return DeliveryModel(
          id: data['id'].toString(),
          senderName: data['sender_name']?.toString() ?? 'Unknown Sender',
          recipientName:
              data['recipient_name']?.toString() ?? 'Unknown Recipient',
          recipientPhone: data['recipient_phone']?.toString() ?? '',
          deliveryAddress: data['delivery_address']?.toString() ?? '',
          packageName: data['package_name']?.toString() ?? 'AeroDrop Package',
          packageWeight: _toDouble(data['package_weight'], 0.0),
          packageType: data['package_type']?.toString() ?? 'Other',
          status: _parseDeliveryStatus(data['status']),
          droneId: data['drone_id']?.toString(),
          eta: data['eta']?.toString() ?? 'TBD',
          createdAt: _toDateTime(data['created_at']),
          progress: _progressFromStatus(data['status']),
        );
      }).toList();

      state = deliveries;
    } catch (error) {
      print('Load deliveries failed: $error');
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
<<<<<<< HEAD
      final advisory =
          weather['advisory_message']?.toString() ??
=======
      final advisory = weather['advisory_message']?.toString() ??
>>>>>>> 5b6b7b1e3cbcc6cfb4e7ffb4cce8b6e56b3d0c51
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
      print('Weather safety check failed: $error');
      return null;
    }
  }

<<<<<<< HEAD
  Future<Map<String, dynamic>?> _findAvailableDrone(
    double packageWeight,
  ) async {
=======
  Future<Map<String, dynamic>?> _findAvailableDrone(double packageWeight) async {
>>>>>>> 5b6b7b1e3cbcc6cfb4e7ffb4cce8b6e56b3d0c51
    if (!SupabaseService.isConfigured) return null;

    final drones = await SupabaseService.client
        .from('drones')
        .select()
        .eq('status', 'available')
        .gt('battery_level', 20)
        .gte('max_payload', packageWeight)
        .order('battery_level', ascending: false)
        .limit(1);

<<<<<<< HEAD
    if (drones.isNotEmpty) {
=======
    if (drones is List && drones.isNotEmpty) {
>>>>>>> 5b6b7b1e3cbcc6cfb4e7ffb4cce8b6e56b3d0c51
      return Map<String, dynamic>.from(drones.first);
    }

    return null;
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
      print('Telemetry placeholder insert failed: $error');
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
      print('Delivery status log insert failed: $error');
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
      final payment = await SupabaseService.client
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
          })
          .select()
          .single();

      await SupabaseService.client.from('payment_status_logs').insert({
        'payment_id': payment['id'],
        'delivery_id': deliveryId,
        'status': status,
        'message': status == 'paid'
            ? 'Simulated payment completed using $paymentMethod.'
            : 'Payment is pending using $paymentMethod.',
      });
    } catch (error) {
      print('Payment insert failed: $error');
    }
  }

  void _startSimulation() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!state.any((d) => d.status == DeliveryStatus.inTransit)) return;

      state = state.map((delivery) {
        if (delivery.status == DeliveryStatus.inTransit) {
          final nextProgress = delivery.progress + 0.15;

          if (nextProgress >= 1.0) {
            if (delivery.droneId != null) {
<<<<<<< HEAD
              ref
                  .read(droneProvider.notifier)
                  .updateStatus(delivery.droneId!, DroneStatus.available);

              ref
                  .read(droneProvider.notifier)
                  .updateBattery(delivery.droneId!, 85.0);
=======
              ref.read(droneProvider.notifier).updateStatus(
                    delivery.droneId!,
                    DroneStatus.available,
                  );

              ref.read(droneProvider.notifier).updateBattery(
                    delivery.droneId!,
                    85.0,
                  );
>>>>>>> 5b6b7b1e3cbcc6cfb4e7ffb4cce8b6e56b3d0c51

              if (SupabaseService.isConfigured) {
                SupabaseService.client
                    .from('drones')
<<<<<<< HEAD
                    .update({'status': 'available', 'battery_level': 85.0})
=======
                    .update({
                      'status': 'available',
                      'battery_level': 85.0,
                    })
>>>>>>> 5b6b7b1e3cbcc6cfb4e7ffb4cce8b6e56b3d0c51
                    .eq('id', delivery.droneId!)
                    .then((_) {})
                    .catchError((error) {
                      print('Drone release failed: $error');
                    });
              }
            }

            if (SupabaseService.isConfigured) {
              SupabaseService.client
                  .from('deliveries')
                  .update({
                    'status': DeliveryStatus.delivered.name,
                    'eta': '0 mins',
                  })
                  .eq('id', delivery.id)
                  .then((_) async {
                    await _insertStatusLog(
                      deliveryId: delivery.id,
                      status: DeliveryStatus.delivered.name,
                      message: 'Delivery completed successfully.',
                    );
                  })
                  .catchError((error) {
                    print('Delivery completion update failed: $error');
                  });
            }

            return delivery.copyWith(
              status: DeliveryStatus.delivered,
              progress: 1.0,
              eta: '0 mins',
            );
          } else {
            if (delivery.droneId != null) {
              final drones = ref.read(droneProvider);
<<<<<<< HEAD
              final index = drones.indexWhere((d) => d.id == delivery.droneId);

              if (index != -1) {
                ref
                    .read(droneProvider.notifier)
                    .updateBattery(
=======
              final index = drones.indexWhere(
                (d) => d.id == delivery.droneId,
              );

              if (index != -1) {
                ref.read(droneProvider.notifier).updateBattery(
>>>>>>> 5b6b7b1e3cbcc6cfb4e7ffb4cce8b6e56b3d0c51
                      delivery.droneId!,
                      (drones[index].batteryLevel - 1.5).clamp(0.0, 100.0),
                    );
              }
            }

            final remainingMins = ((1.0 - nextProgress) * 12).round();

            return delivery.copyWith(
              progress: nextProgress,
              eta: '$remainingMins mins',
            );
          }
        }

        return delivery;
      }).toList();
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

    if (!SupabaseService.isConfigured) {
      return 'Supabase is not configured.';
    }

    final currentUser = SupabaseService.client.auth.currentUser;

    if (currentUser == null) {
      return 'You must be logged in to request a delivery.';
    }

    try {
      final weatherError = await _checkWeatherSafety();

      if (weatherError != null) {
        return weatherError;
      }

      final selectedDrone = await _findAvailableDrone(packageWeight);

      if (selectedDrone == null) {
        return 'No available drone can carry this package weight.';
      }

      final assignedDroneId = selectedDrone['id'].toString();
      final assignedDroneBattery = _toDouble(selectedDrone['battery_level']);
      final assignedDroneMaxPayload = _toDouble(selectedDrone['max_payload']);

      if (packageWeight > assignedDroneMaxPayload) {
        return 'Package weight exceeds the selected drone capacity.';
      }

      final status = DeliveryStatus.inTransit;
      const eta = '12 mins';

      final paymentAmount = _calculatePaymentAmount(
        packageWeight: packageWeight,
        priority: priority,
      );
      final paymentStatus = _paymentStatusFromMethod(paymentMethod);
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
        'drone_id': assignedDroneId,
        'eta': eta,
        'priority': priority,
        'pickup_location_id': pickupLocationId,
        'dropoff_location_id': dropoffLocationId,
        'scheduled_at': scheduledAt?.toIso8601String(),
        'pickup_latitude': pickupLatitude,
        'pickup_longitude': pickupLongitude,
        'dropoff_latitude': dropoffLatitude,
        'dropoff_longitude': dropoffLongitude,
        'safety_status': 'Safe',
<<<<<<< HEAD
        'safety_message': 'Payload, drone capacity, and weather checks passed.',
=======
        'safety_message':
            'Payload, drone capacity, and weather checks passed.',
>>>>>>> 5b6b7b1e3cbcc6cfb4e7ffb4cce8b6e56b3d0c51
        'payment_method': paymentMethod,
        'payment_status': paymentStatus,
        'payment_amount': paymentAmount,
        'payment_reference': paymentReference,
      };

      deliveryPayload.removeWhere((key, value) => value == null);

      final response = await SupabaseService.client
          .from('deliveries')
          .insert(deliveryPayload)
          .select()
          .single();

<<<<<<< HEAD
      await SupabaseService.client
          .from('drones')
          .update({'status': 'busy', 'battery_level': assignedDroneBattery})
          .eq('id', assignedDroneId);
=======
      await SupabaseService.client.from('drones').update({
        'status': 'busy',
        'battery_level': assignedDroneBattery,
      }).eq('id', assignedDroneId);
>>>>>>> 5b6b7b1e3cbcc6cfb4e7ffb4cce8b6e56b3d0c51

      await _insertFirstTelemetry(
        droneId: assignedDroneId,
        batteryLevel: assignedDroneBattery,
      );

      await _insertStatusLog(
        deliveryId: response['id'].toString(),
        status: status.name,
        message: 'Delivery created and assigned to $assignedDroneId.',
      );

      await _insertPayment(
        deliveryId: response['id'].toString(),
        userId: currentUser.id,
        paymentMethod: paymentMethod,
        amount: paymentAmount,
        status: paymentStatus,
        referenceNumber: paymentReference,
      );

<<<<<<< HEAD
      ref
          .read(droneProvider.notifier)
          .updateStatus(assignedDroneId, DroneStatus.busy);
=======
      ref.read(droneProvider.notifier).updateStatus(
            assignedDroneId,
            DroneStatus.busy,
          );
>>>>>>> 5b6b7b1e3cbcc6cfb4e7ffb4cce8b6e56b3d0c51

      final createdDelivery = DeliveryModel(
        id: response['id'].toString(),
        senderName: response['sender_name'] ?? senderName,
        recipientName: response['recipient_name'] ?? recipientName,
        recipientPhone: response['recipient_phone'] ?? recipientPhone,
        deliveryAddress: response['delivery_address'] ?? deliveryAddress,
        packageName: response['package_name'] ?? packageName,
<<<<<<< HEAD
        packageWeight: _toDouble(response['package_weight'], packageWeight),
=======
        packageWeight: _toDouble(
          response['package_weight'],
          packageWeight,
        ),
>>>>>>> 5b6b7b1e3cbcc6cfb4e7ffb4cce8b6e56b3d0c51
        packageType: response['package_type'] ?? packageType,
        status: _parseDeliveryStatus(response['status']),
        droneId: response['drone_id']?.toString(),
        eta: response['eta'] ?? eta,
        createdAt: _toDateTime(response['created_at']),
        progress: _progressFromStatus(response['status']),
      );

      state = [createdDelivery, ...state];

      return null;
    } catch (error) {
      print('Create delivery failed: $error');
      return 'Delivery request failed. Please check Supabase or terminal logs.';
    }
  }

  void updateDeliveryStatus(
    String id,
    DeliveryStatus status, {
    String? droneId,
  }) {
    if (kSimulationMode) {
<<<<<<< HEAD
      ref
          .read(deliveryMockProvider.notifier)
          .updateDeliveryStatus(id, status, droneId: droneId);
=======
      ref.read(deliveryMockProvider.notifier).updateDeliveryStatus(
            id,
            status,
            droneId: droneId,
          );
>>>>>>> 5b6b7b1e3cbcc6cfb4e7ffb4cce8b6e56b3d0c51
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
<<<<<<< HEAD
          .update({'status': status.name, 'drone_id': ?droneId})
=======
          .update({
            'status': status.name,
            if (droneId != null) 'drone_id': droneId,
          })
>>>>>>> 5b6b7b1e3cbcc6cfb4e7ffb4cce8b6e56b3d0c51
          .eq('id', id)
          .then((_) async {
            await _insertStatusLog(
              deliveryId: id,
              status: status.name,
              message: 'Delivery status updated to ${status.name}.',
            );
          })
          .catchError((error) {
            print('Delivery status update failed: $error');
          });
    }
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }
}

final deliveryProvider =
    StateNotifierProvider<DeliveryNotifier, List<DeliveryModel>>((ref) {
<<<<<<< HEAD
      return DeliveryNotifier(ref);
    });
=======
  return DeliveryNotifier(ref);
});
>>>>>>> 5b6b7b1e3cbcc6cfb4e7ffb4cce8b6e56b3d0c51
