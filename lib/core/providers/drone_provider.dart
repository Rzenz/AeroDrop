import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/drone_model.dart';
import '../services/supabase_service.dart';

// ── Notifier ──────────────────────────────────────────────────────────────────

class DroneNotifier extends StateNotifier<List<DroneModel>> {
  final Ref? ref;
  String? _resolvedDroneId;
  RealtimeChannel? _dronesChannel;

  DroneNotifier(this.ref) : super([]) {
    Future.microtask(() {
      if (mounted) {
        loadDronesFromSupabase();
        _subscribeRealtime();
      }
    });
  }

  void _subscribeRealtime() {
    if (!SupabaseService.isConfigured) return;
    _dronesChannel?.unsubscribe();
    try {
      _dronesChannel = SupabaseService.client
          .channel('public:drones_sync')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'drones',
            callback: (payload) {
              final rec = payload.newRecord;
              if (rec.isNotEmpty && mounted) {
                final statusName = rec['status']?.toString();
                final battery = _toDouble(rec['battery_level'], 100.0);
                final droneCode = rec['drone_code']?.toString() ?? 'DRN-001';
                final dbId = rec['id']?.toString() ?? '80000000-0000-0000-0000-000000000001';
                state = state.map((d) {
                  if (d.id == droneCode || d.dbId == dbId) {
                    return d.copyWith(
                      status: statusName != null
                          ? _parseDroneStatus(statusName)
                          : d.status,
                      batteryLevel: battery,
                    );
                  }
                  return d;
                }).toList();
              }
              if (mounted) loadDronesFromSupabase();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to drones realtime: $e');
    }
  }

  double _toDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  DroneStatus _parseDroneStatus(String? s) => switch (s?.toLowerCase()) {
    'available' => DroneStatus.available,
    'assigned' => DroneStatus.assigned,
    'busy' => DroneStatus.busy,
    'charging' => DroneStatus.charging,
    'maintenance' => DroneStatus.maintenance,
    'offline' => DroneStatus.offline,
    'returning' => DroneStatus.returning,
    _ => DroneStatus.available,
  };

  Future<String> _resolveDroneId() async {
    if (_resolvedDroneId != null) return _resolvedDroneId!;
    final authUser = SupabaseService.client.auth.currentUser;
    if (authUser == null) return '80000000-0000-0000-0000-000000000001';
    try {
      final res = await SupabaseService.client
          .from('drones')
          .select('id')
          .eq('drone_code', 'DRN-001')
          .maybeSingle();
      if (res != null) {
        _resolvedDroneId = res['id'].toString();
        return _resolvedDroneId!;
      }
    } catch (e) {
      debugPrint('Error resolving drone UUID: $e');
    }
    return '80000000-0000-0000-0000-000000000001'; // fallback
  }

  Future<void> loadDronesFromSupabase() async {
    if (!SupabaseService.isConfigured) return;
    final authUser = SupabaseService.client.auth.currentUser;
    if (authUser == null) {
      if (!mounted) return;
      state = [];
      return;
    }

    try {
      final droneId = await _resolveDroneId();
      if (!mounted) return;

      final response = await SupabaseService.client
          .from('drones')
          .select()
          .eq('id', droneId)
          .maybeSingle();

      if (!mounted) return;
      if (response == null) return;

      final data = Map<String, dynamic>.from(response);

      // status is now a text column ('available', 'busy', …)
      final statusName = data['status']?.toString();

      final telemetryRes = await SupabaseService.client
          .from('drone_telemetry')
          .select('latitude, longitude')
          .eq('drone_id', droneId)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      String coords = '10.3156,123.9016';
      if (telemetryRes != null) {
        coords = '${telemetryRes['latitude']},${telemetryRes['longitude']}';
      }

      state = [
        DroneModel(
          id: data['drone_code']?.toString() ?? 'DRN-001',
          dbId: data['id']?.toString() ?? droneId,
          name: data['drone_name']?.toString() ?? 'AeroCarrier Alpha',
          batteryLevel: _toDouble(data['battery_level'], 100.0),
          status: _parseDroneStatus(statusName),
          maxPayload: _toDouble(data['max_payload_kg'], 0.5),
          modelType: data['model']?.toString() ?? 'AeroCarrier',
          currentCoordinates: coords,
        ),
      ];
    } catch (error) {
      debugPrint('Load drones from Supabase failed: $error');
    }
  }

  Future<String?> addDroneToSupabase(DroneModel drone) async {
    return 'Drone registration is locked. Only one drone (AeroCarrier Alpha) is permitted.';
  }

  Future<String?> editDroneInSupabase(DroneModel drone) async {
    if (drone.id != 'DRN-001' && drone.dbId != await _resolveDroneId()) {
      return 'Editing other drones is not permitted.';
    }
    if (!SupabaseService.isConfigured) return 'Supabase is not configured.';
    final authUser = SupabaseService.client.auth.currentUser;
    if (authUser == null) return 'You must be logged in.';

    try {
      final droneId = drone.dbId.isNotEmpty ? drone.dbId : await _resolveDroneId();
      if (!mounted) return 'Notifier disposed';

      await SupabaseService.client
          .from('drones')
          .update({
            'drone_name': drone.name,
            'battery_level': drone.batteryLevel,
            'status': drone.status.name, // plain text
            'max_payload_kg': drone.maxPayload,
            'model': drone.modelType,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', droneId);

      if (!mounted) return null;
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
    if (!SupabaseService.isConfigured) return 'Supabase is not configured.';
    final authUser = SupabaseService.client.auth.currentUser;
    if (authUser == null) return 'You must be logged in.';

    try {
      final droneIdDb = await _resolveDroneId();
      if (!mounted) return 'Notifier disposed';

      await SupabaseService.client
          .from('drones')
          .update({
            'battery_level': 100.0,
            'status': 'available', // plain text
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', droneIdDb);

      if (!mounted) return null;
      state = state
          .map(
            (d) => (d.id == droneId || d.dbId == droneId)
                ? d.copyWith(batteryLevel: 100.0, status: DroneStatus.available)
                : d,
          )
          .toList();
      return null;
    } catch (e) {
      debugPrint('Recharge drone failed: $e');
      return 'Failed to recharge drone: $e';
    }
  }

  void addDrone(DroneModel drone) => addDroneToSupabase(drone);
  void editDrone(DroneModel updatedDrone) => editDroneInSupabase(updatedDrone);
  void deleteDrone(String id) => deleteDroneFromSupabase(id);

  void updateBattery(String id, double level) {
    state = state
        .map(
          (d) => (d.id == id || d.dbId == id || state.length == 1)
              ? d.copyWith(batteryLevel: level)
              : d,
        )
        .toList();
  }

  void updateStatus(String id, DroneStatus status) {
    state = state
        .map(
          (d) => (d.id == id || d.dbId == id || state.length == 1)
              ? d.copyWith(status: status)
              : d,
        )
        .toList();

    if (SupabaseService.isConfigured) {
      _resolveDroneId().then((droneId) {
        SupabaseService.client
            .from('drones')
            .update({
              'status': status.name, // plain text, no UUID
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', droneId)
            .then((_) {})
            .catchError((e) {
              debugPrint('Update drone status in Supabase failed: $e');
            });
      });
    }
  }

  void updateCoordinates(String id, String coords) {
    state = state
        .map(
          (d) => (d.id == id || d.dbId == id || state.length == 1)
              ? d.copyWith(currentCoordinates: coords)
              : d,
        )
        .toList();
  }

  @override
  void dispose() {
    _dronesChannel?.unsubscribe();
    super.dispose();
  }
}

final droneProvider = StateNotifierProvider<DroneNotifier, List<DroneModel>>((
  ref,
) {
  return DroneNotifier(ref);
});
