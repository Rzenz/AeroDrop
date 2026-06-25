import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/drone_model.dart';

class DroneNotifier extends StateNotifier<List<DroneModel>> {
  DroneNotifier()
      : super([
          DroneModel(
            id: 'DRN-001',
            name: 'AeroCarrier Falcon',
            batteryLevel: 92.5,
            status: DroneStatus.available,
            maxPayload: 5.0,
            modelType: 'AeroCarrier-X',
            currentCoordinates: '10.3157° N, 123.8854° E',
          ),
          DroneModel(
            id: 'DRN-002',
            name: 'SkyLifter Titan',
            batteryLevel: 45.0,
            status: DroneStatus.busy,
            maxPayload: 15.0,
            modelType: 'SkyLifter-V2',
            currentCoordinates: '10.3200° N, 123.8900° E',
          ),
          DroneModel(
            id: 'DRN-003',
            name: 'AeroCarrier Hawk',
            batteryLevel: 15.0,
            status: DroneStatus.maintenance,
            maxPayload: 5.0,
            modelType: 'AeroCarrier-X',
            currentCoordinates: '10.3100° N, 123.8800° E',
          ),
          DroneModel(
            id: 'DRN-004',
            name: 'Shadow Swift',
            batteryLevel: 0.0,
            status: DroneStatus.offline,
            maxPayload: 2.5,
            modelType: 'Swift-Lite',
            currentCoordinates: '10.3000° N, 123.8700° E',
          ),
        ]);

  void addDrone(DroneModel drone) {
    state = [...state, drone];
  }

  void editDrone(DroneModel updatedDrone) {
    state = state.map((drone) => drone.id == updatedDrone.id ? updatedDrone : drone).toList();
  }

  void deleteDrone(String id) {
    state = state.where((drone) => drone.id != id).toList();
  }

  void updateBattery(String id, double level) {
    state = state.map((drone) {
      if (drone.id == id) {
        return drone.copyWith(batteryLevel: level);
      }
      return drone;
    }).toList();
  }

  void updateStatus(String id, DroneStatus status) {
    state = state.map((drone) {
      if (drone.id == id) {
        return drone.copyWith(status: status);
      }
      return drone;
    }).toList();
  }
}

final droneProvider = StateNotifierProvider<DroneNotifier, List<DroneModel>>((ref) {
  return DroneNotifier();
});
