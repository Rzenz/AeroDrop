import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/drone_model.dart';
import '../../mock_data/drones_mock.dart';

class DroneMockNotifier extends StateNotifier<List<DroneModel>> {
  DroneMockNotifier() : super(List.from(mockDrones));

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

  void updateCoordinates(String id, String coords) {
    state = state.map((drone) {
      if (drone.id == id) {
        return drone.copyWith(currentCoordinates: coords);
      }
      return drone;
    }).toList();
  }

  void reset() {
    state = List.from(mockDrones);
  }
}

final droneMockProvider = StateNotifierProvider<DroneMockNotifier, List<DroneModel>>((ref) {
  return DroneMockNotifier();
});
