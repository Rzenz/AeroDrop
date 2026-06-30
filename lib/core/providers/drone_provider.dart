import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/drone_model.dart';
import '../config/simulation_config.dart';
import '../../providers/mock/drone_mock_provider.dart';
import '../services/supabase_service.dart';

class DroneNotifier extends StateNotifier<List<DroneModel>> {
  final Ref? ref;

  DroneNotifier([this.ref]) : super([]) {
    if (kSimulationMode) {
      state = [
        DroneModel(
          id: 'DRN-001',
          name: 'AeroCarrier Alpha',
          batteryLevel: 100.0,
          status: DroneStatus.available,
          maxPayload: 0.5,
          modelType: '001',
          currentCoordinates: '10.3456,123.9478',
        ),
      ];
    } else {
      if (SupabaseService.isConfigured) {
        Future.microtask(loadDronesFromSupabase);
      } else {
        // Fallback to local hardcoded list if Supabase is not configured
        state = [
          DroneModel(
            id: 'DRN-001',
            name: 'AeroCarrier Alpha',
            batteryLevel: 100.0,
            status: DroneStatus.available,
            maxPayload: 0.5,
            modelType: '001',
            currentCoordinates: '10.3456,123.9478',
          ),
        ];
      }
    }
  }

  double _toDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  DroneStatus _parseDroneStatus(String? statusStr) {
    switch (statusStr?.toLowerCase()) {
      case 'available':
        return DroneStatus.available;
      case 'busy':
        return DroneStatus.busy;
      case 'maintenance':
        return DroneStatus.maintenance;
      case 'offline':
        return DroneStatus.offline;
      default:
        return DroneStatus.available;
    }
  }

  Future<void> loadDronesFromSupabase() async {
    if (kSimulationMode) return;
    if (!SupabaseService.isConfigured) return;

    try {
      // Ensure DRN-001 exists in the database
      final checkResponse = await SupabaseService.client
          .from('drones')
          .select()
          .eq('id', 'DRN-001')
          .maybeSingle();

      if (checkResponse == null) {
        await SupabaseService.client.from('drones').insert({
          'id': 'DRN-001',
          'name': 'AeroCarrier Alpha',
          'battery_level': 100.0,
          'status': 'available',
          'max_payload': 0.5,
          'model_type': '001',
          'current_coordinates': '10.3456,123.9478',
        });
      }

      // Query DRN-001 only to restrict the fleet list
      final response = await SupabaseService.client
          .from('drones')
          .select()
          .eq('id', 'DRN-001');

      final drones = (response as List).map((item) {
        final data = Map<String, dynamic>.from(item);
        return DroneModel(
          id: data['id'].toString(),
          name: data['name']?.toString() ?? 'AeroCarrier Alpha',
          batteryLevel: _toDouble(data['battery_level'], 100.0),
          status: _parseDroneStatus(data['status']?.toString()),
          maxPayload: _toDouble(data['max_payload'], 0.5),
          modelType: data['model_type']?.toString() ?? '001',
          currentCoordinates: data['current_coordinates']?.toString() ?? '10.3456,123.9478',
        );
      }).toList();

      state = drones;
    } catch (error) {
      debugPrint('Load drones from Supabase failed: $error');
    }
  }

  Future<String?> addDroneToSupabase(DroneModel drone) async {
    return 'Drone registration is locked. Only one drone (AeroCarrier Alpha) is permitted in this workspace.';
  }

  Future<String?> editDroneInSupabase(DroneModel drone) async {
    if (drone.id != 'DRN-001') {
      return 'Editing other drones is not permitted.';
    }

    if (kSimulationMode) {
      state = [drone];
      return null;
    }

    if (!SupabaseService.isConfigured) {
      return 'Supabase is not configured.';
    }

    try {
      await SupabaseService.client.from('drones').update({
        'name': drone.name,
        'battery_level': drone.batteryLevel,
        'status': drone.status.name,
        'max_payload': drone.maxPayload,
        'model_type': drone.modelType,
        'current_coordinates': drone.currentCoordinates,
      }).eq('id', 'DRN-001');

      state = [drone];
      return null;
    } catch (e) {
      debugPrint('Edit drone in Supabase failed: $e');
      return e.toString();
    }
  }

  Future<String?> deleteDroneFromSupabase(String id) async {
    if (id == 'DRN-001') {
      return 'The primary drone AeroCarrier Alpha cannot be deleted.';
    }
    return 'Deleting other drones is not permitted.';
  }

  Future<String?> rechargeDrone(String droneId) async {
    if (kSimulationMode) {
      state = state.map((d) {
        if (d.id == droneId) {
          return d.copyWith(batteryLevel: 100.0, status: DroneStatus.available);
        }
        return d;
      }).toList();
      return null;
    }

    if (!SupabaseService.isConfigured) return 'Supabase is not configured.';

    try {
      await SupabaseService.client.from('drones').update({
        'battery_level': 100.0,
        'status': 'available',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', droneId);

      state = state.map((d) {
        if (d.id == droneId) {
          return d.copyWith(batteryLevel: 100.0, status: DroneStatus.available);
        }
        return d;
      }).toList();

      return null;
    } catch (e) {
      debugPrint('Recharge drone failed: $e');
      return 'Failed to recharge drone: ${e.toString()}';
    }
  }

  void addDrone(DroneModel drone) {
    addDroneToSupabase(drone);
  }

  void editDrone(DroneModel updatedDrone) {
    editDroneInSupabase(updatedDrone);
  }

  void deleteDrone(String id) {
    deleteDroneFromSupabase(id);
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

