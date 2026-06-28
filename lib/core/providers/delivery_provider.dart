import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/delivery_model.dart';
import 'drone_provider.dart';
import '../models/drone_model.dart';
import '../config/simulation_config.dart';
import '../../providers/mock/delivery_mock_provider.dart';

class DeliveryNotifier extends StateNotifier<List<DeliveryModel>> {
  final Ref ref;
  Timer? _simulationTimer;

  DeliveryNotifier(this.ref)
      : super(kSimulationMode
            ? []
            : [
                DeliveryModel(
                  id: 'DEL-892',
                  senderName: 'UCLM Science Lab',
                  recipientName: 'Engineering Bldg B',
                  recipientPhone: '+63 912 345 6789',
                  deliveryAddress: 'UCLM Campus, Engineering Hub Room 204',
                  packageName: 'Microscope Slides & Samples',
                  packageWeight: 1.2,
                  packageType: 'Medicine',
                  status: DeliveryStatus.inTransit,
                  droneId: 'DRN-001',
                  eta: '8 mins',
                  createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
                  progress: 0.4,
                ),
                DeliveryModel(
                  id: 'DEL-541',
                  senderName: 'Admin Office',
                  recipientName: 'Main Library Lobby',
                  recipientPhone: '+63 998 765 4321',
                  deliveryAddress: 'UCLM Main Campus, Library reception desk',
                  packageName: 'Confidential Document Envelopes',
                  packageWeight: 0.5,
                  packageType: 'Document',
                  status: DeliveryStatus.delivered,
                  droneId: 'DRN-002',
                  eta: '0 mins',
                  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
                  progress: 1.0,
                ),
                DeliveryModel(
                  id: 'DEL-310',
                  senderName: 'Campus Canteen',
                  recipientName: 'Student Pavilion',
                  recipientPhone: '+63 945 111 2222',
                  deliveryAddress: 'Outdoor Study Area, Pavilion Table 4',
                  packageName: 'Warm Lunch Bento Boxes',
                  packageWeight: 2.1,
                  packageType: 'Food',
                  status: DeliveryStatus.pending,
                  droneId: null,
                  eta: 'TBD',
                  createdAt: DateTime.now(),
                  progress: 0.0,
                ),
              ]) {
    if (kSimulationMode) {
      ref.listen<List<DeliveryModel>>(deliveryMockProvider, (previous, next) {
        state = next;
      }, fireImmediately: true);
    } else {
      _startSimulation();
    }
  }

  void _startSimulation() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      // ponytail: skip if nothing to advance — avoids allocating a new list
      if (!state.any((d) => d.status == DeliveryStatus.inTransit)) return;
      state = state.map((delivery) {
        if (delivery.status == DeliveryStatus.inTransit) {
          final nextProgress = delivery.progress + 0.15;
          if (nextProgress >= 1.0) {
            if (delivery.droneId != null) {
              ref.read(droneProvider.notifier).updateStatus(delivery.droneId!, DroneStatus.available);
              ref.read(droneProvider.notifier).updateBattery(delivery.droneId!, 85.0);
            }
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
                ref.read(droneProvider.notifier).updateBattery(
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

  void createDelivery({
    required String senderName,
    required String recipientName,
    required String recipientPhone,
    required String deliveryAddress,
    required String packageName,
    required double packageWeight,
    required String packageType,
  }) {
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
      return;
    }
    final newId = 'DEL-${100 + state.length + 1}';
    final availableDrones = ref.read(droneProvider).where((d) => d.status == DroneStatus.available && d.batteryLevel > 20.0).toList();
    
    String? assignedDroneId;
    DeliveryStatus status = DeliveryStatus.pending;
    String eta = 'TBD';
    
    if (availableDrones.isNotEmpty) {
      assignedDroneId = availableDrones.first.id;
      status = DeliveryStatus.inTransit;
      eta = '12 mins';
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
  }

  void updateDeliveryStatus(String id, DeliveryStatus status, {String? droneId}) {
    if (kSimulationMode) {
      ref.read(deliveryMockProvider.notifier).updateDeliveryStatus(id, status, droneId: droneId);
      return;
    }
    state = state.map((delivery) {
      if (delivery.id == id) {
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

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }
}

final deliveryProvider = StateNotifierProvider<DeliveryNotifier, List<DeliveryModel>>((ref) {
  return DeliveryNotifier(ref);
});

