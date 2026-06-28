import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/drone_model.dart';
import '../config/simulation_config.dart';
import '../../providers/mock/drone_mock_provider.dart';

class DroneNotifier extends StateNotifier<List<DroneModel>> {
  final Ref? ref;

  DroneNotifier([this.ref])
      : super(kSimulationMode
            ? []
            : [
                DroneModel(
                  id: 'DRN-001',
                  name: 'AeroCarrier Falcon',
                  batteryLevel: 92.5,
                  status: DroneStatus.available,
                  maxPayload: 5.0,
                  modelType: 'AeroCarrier-X',
                  currentCoordinates: '10.3276° N, 123.9507° E',
                ),
                DroneModel(
                  id: 'DRN-002',
                  name: 'SkyLifter Titan',
                  batteryLevel: 45.0,
                  status: DroneStatus.busy,
                  maxPayload: 15.0,
                  modelType: 'SkyLifter-V2',
                  currentCoordinates: '10.3286° N, 123.9512° E',
                ),
                DroneModel(
                  id: 'DRN-003',
                  name: 'AeroCarrier Hawk',
                  batteryLevel: 15.0,
                  status: DroneStatus.maintenance,
                  maxPayload: 5.0,
                  modelType: 'AeroCarrier-X',
                  currentCoordinates: '10.3280° N, 123.9498° E',
                ),
                DroneModel(
                  id: 'DRN-004',
                  name: 'Shadow Swift',
                  batteryLevel: 0.0,
                  status: DroneStatus.offline,
                  maxPayload: 2.5,
                  modelType: 'Swift-Lite',
                  currentCoordinates: '10.3272° N, 123.9518° E',
                ),
              ]) {
    if (kSimulationMode && ref != null) {
      ref!.listen<List<DroneModel>>(droneMockProvider, (previous, next) {
        state = next;
      }, fireImmediately: true);
    }
  }

  void addDrone(DroneModel drone) {
    if (kSimulationMode && ref != null) {
      ref!.read(droneMockProvider.notifier).addDrone(drone);
      return;
    }
    state = [...state, drone];
  }

  void editDrone(DroneModel updatedDrone) {
    if (kSimulationMode && ref != null) {
      ref!.read(droneMockProvider.notifier).editDrone(updatedDrone);
      return;
    }
    state = state.map((drone) => drone.id == updatedDrone.id ? updatedDrone : drone).toList();
  }

  void deleteDrone(String id) {
    if (kSimulationMode && ref != null) {
      ref!.read(droneMockProvider.notifier).deleteDrone(id);
      return;
    }
    state = state.where((drone) => drone.id != id).toList();
  }

  void updateBattery(String id, double level) {
    if (kSimulationMode && ref != null) {
      ref!.read(droneMockProvider.notifier).updateBattery(id, level);
      return;
    }
    state = state.map((drone) {
      if (drone.id == id) {
        return drone.copyWith(batteryLevel: level);
      }
      return drone;
    }).toList();
  }

  void updateStatus(String id, DroneStatus status) {
    if (kSimulationMode && ref != null) {
      ref!.read(droneMockProvider.notifier).updateStatus(id, status);
      return;
    }
    state = state.map((drone) {
      if (drone.id == id) {
        return drone.copyWith(status: status);
      }
      return drone;
    }).toList();
  }

  void updateCoordinates(String id, String coords) {
    if (kSimulationMode && ref != null) {
      ref!.read(droneMockProvider.notifier).updateCoordinates(id, coords);
      return;
    }
    state = state.map((drone) {
      if (drone.id == id) {
        return drone.copyWith(currentCoordinates: coords);
      }
      return drone;
    }).toList();
  }
}

final droneProvider = StateNotifierProvider<DroneNotifier, List<DroneModel>>((ref) {
  return DroneNotifier(ref);
});

