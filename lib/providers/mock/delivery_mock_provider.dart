import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/delivery_model.dart';
import '../../core/models/drone_model.dart';
import '../../core/providers/drone_provider.dart';
import '../../core/providers/notification_provider.dart';
import '../../mock_data/deliveries_mock.dart';
import '../../mock_data/weather_mock.dart';
import 'weather_mock_provider.dart';
import 'analytics_mock_provider.dart';

class DeliveryMockNotifier extends StateNotifier<List<DeliveryModel>> {
  final Ref ref;
  Timer? _simulationTimer;

  DeliveryMockNotifier(this.ref) : super(List.from(mockDeliveries)) {
    _startSimulation();
  }

  ({double lat, double lng}) _getDestinationCoordinates(String address) {
    final lower = address.toLowerCase();
    if (lower.contains('engineer') || lower.contains('eng.')) {
      return (lat: 10.3286, lng: 123.9512);
    } else if (lower.contains('library') || lower.contains('lib')) {
      return (lat: 10.3272, lng: 123.9518);
    } else if (lower.contains('pavilion') || lower.contains('student')) {
      return (lat: 10.3268, lng: 123.9502);
    } else if (lower.contains('dorm') || lower.contains('dormitory')) {
      return (lat: 10.3292, lng: 123.9505);
    } else if (lower.contains('science') || lower.contains('lab')) {
      return (lat: 10.3280, lng: 123.9498);
    }
    return (lat: 10.3280, lng: 123.9498); // Default to Science Lab
  }

  void _startSimulation() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final weather = ref.read(weatherMockProvider);
      // If weather is dangerous, airspace closed, flights blocked, so pause progression!
      if (weather.scenario == WeatherScenario.dangerous) {
        return;
      }

      state = state.map((delivery) {
        if (delivery.status == DeliveryStatus.inTransit) {
          final nextProgress = delivery.progress + 0.05;
          if (nextProgress >= 1.0) {
            if (delivery.droneId != null) {
              ref.read(droneProvider.notifier).updateStatus(delivery.droneId!, DroneStatus.available);
              ref.read(droneProvider.notifier).updateBattery(delivery.droneId!, 85.0);
            }
            ref.read(analyticsMockProvider.notifier).incrementDeliveries();
            
            // Trigger local success notification
            ref.read(notificationProvider.notifier).addNotification(
              'Delivery ${delivery.id} Arrived',
              'Package "${delivery.packageName}" has been successfully dropped off at ${delivery.deliveryAddress}.',
            );

            return delivery.copyWith(
              status: DeliveryStatus.delivered,
              progress: 1.0,
              eta: '0 mins',
            );
          } else {
            if (delivery.droneId != null) {
              final drones = ref.read(droneProvider);
              final index = drones.indexWhere((d) => d.id == delivery.droneId);
              if (index != -1) {
                final currentBattery = drones[index].batteryLevel;
                ref.read(droneProvider.notifier).updateBattery(
                  delivery.droneId!,
                  (currentBattery - 1.0).clamp(0.0, 100.0),
                );
                
                // Interpolate coordinates from UCLM Hub to destination
                const originLat = 10.3276;
                const originLng = 123.9507;
                final target = _getDestinationCoordinates(delivery.deliveryAddress);
                
                final currentLat = originLat + (nextProgress * (target.lat - originLat));
                final currentLng = originLng + (nextProgress * (target.lng - originLng));
                
                ref.read(droneProvider.notifier).updateCoordinates(
                  delivery.droneId!,
                  '${currentLat.toStringAsFixed(4)}° N, ${currentLng.toStringAsFixed(4)}° E',
                );
              }
            }
            final remainingMins = ((1.0 - nextProgress) * 10).round();
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

  void createDelivery({
    required String senderName,
    required String recipientName,
    required String recipientPhone,
    required String deliveryAddress,
    required String packageName,
    required double packageWeight,
    required String packageType,
  }) {
    final rand = Random();
    final uniqueNum = 10000 + rand.nextInt(90000);
    final newId = 'ADR-2026-$uniqueNum';

    final availableDrones = ref.read(droneProvider).where((d) => d.status == DroneStatus.available && d.batteryLevel > 20.0).toList();
    
    String? assignedDroneId;
    DeliveryStatus status = DeliveryStatus.pending;
    String eta = 'TBD';
    
    if (availableDrones.isNotEmpty) {
      assignedDroneId = availableDrones.first.id;
      status = DeliveryStatus.inTransit;
      eta = '10 mins';
      ref.read(droneProvider.notifier).updateStatus(assignedDroneId, DroneStatus.busy);
    }

    final newDelivery = DeliveryModel(
      id: newId,
      senderName: senderName,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      deliveryAddress: deliveryAddress,
      packageName: packageName,
      packageWeight: packageWeight,
      packageType: packageType,
      status: status,
      droneId: assignedDroneId,
      eta: eta,
      createdAt: DateTime.now(),
      progress: 0.0,
    );

    state = [newDelivery, ...state];

    // Trigger local notification for creation
    ref.read(notificationProvider.notifier).addNotification(
      'Delivery Request Created',
      'Request $newId for "$packageName" created and ${assignedDroneId != null ? "assigned to $assignedDroneId" : "queued"}.',
    );
  }

  void updateDeliveryStatus(String id, DeliveryStatus status, {String? droneId}) {
    state = state.map((delivery) {
      if (delivery.id == id) {
        if (status == DeliveryStatus.delivered && delivery.droneId != null) {
          ref.read(droneProvider.notifier).updateStatus(delivery.droneId!, DroneStatus.available);
        }
        return delivery.copyWith(
          status: status,
          droneId: droneId ?? delivery.droneId,
          progress: status == DeliveryStatus.delivered ? 1.0 : (status == DeliveryStatus.inTransit ? 0.1 : 0.0),
          eta: status == DeliveryStatus.delivered ? '0 mins' : (status == DeliveryStatus.inTransit ? '10 mins' : 'TBD'),
        );
      }
      return delivery;
    }).toList();
  }

  void reset() {
    state = List.from(mockDeliveries);
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }
}

final deliveryMockProvider = StateNotifierProvider<DeliveryMockNotifier, List<DeliveryModel>>((ref) {
  return DeliveryMockNotifier(ref);
});
