import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/telemetry_model.dart';
import '../services/supabase_service.dart';

/// Single authoritative telemetry provider family keyed by [deliveryId].
/// Synchronizes across Customer, Vendor, and Admin using real Supabase telemetry records.
final deliveryTelemetryProvider =
    StateNotifierProvider.family<DeliveryTelemetryNotifier, TelemetryModel?, String>(
  (ref, deliveryId) {
    return DeliveryTelemetryNotifier(ref, deliveryId);
  },
);

class DeliveryTelemetryNotifier extends StateNotifier<TelemetryModel?> {
  final Ref ref;
  final String deliveryId;
  RealtimeChannel? _channel;

  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  bool get _isValidUuid => _uuidRegex.hasMatch(deliveryId);

  DeliveryTelemetryNotifier(this.ref, this.deliveryId) : super(null) {
    if (deliveryId.isNotEmpty && _isValidUuid) {
      loadLatestTelemetry();
      _setupRealtime();
    }
  }

  void _setupRealtime() {
    if (!SupabaseService.isConfigured || deliveryId.isEmpty || !_isValidUuid) return;

    try {
      _channel = SupabaseService.client
          .channel('telemetry_stream:$deliveryId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'drone_telemetry',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'delivery_id',
              value: deliveryId,
            ),
            callback: (payload) {
              final rec = payload.newRecord;
              if (rec.isNotEmpty) {
                state = TelemetryModel.fromMap(rec);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime telemetry subscription error: $e');
    }
  }

  Future<void> loadLatestTelemetry() async {
    if (!SupabaseService.isConfigured || deliveryId.isEmpty || !_isValidUuid) return;

    try {
      final res = await SupabaseService.client
          .from('drone_telemetry')
          .select()
          .eq('delivery_id', deliveryId)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null) {
        state = TelemetryModel.fromMap(Map<String, dynamic>.from(res));
      } else {
        // Fallback to drone's latest telemetry if delivery-specific record is not yet emitted
        final delRes = await SupabaseService.client
            .from('deliveries')
            .select('drone_id, progress')
            .eq('id', deliveryId)
            .maybeSingle();

        if (delRes != null && delRes['drone_id'] != null) {
          final droneTel = await SupabaseService.client
              .from('drone_telemetry')
              .select()
              .eq('drone_id', delRes['drone_id'])
              .order('recorded_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (droneTel != null) {
            final map = Map<String, dynamic>.from(droneTel);
            map['delivery_id'] = deliveryId;
            map['progress'] = (delRes['progress'] as num?)?.toDouble() ?? 0.0;
            state = TelemetryModel.fromMap(map);
          }
        }
      }
    } catch (e) {
      debugPrint('loadLatestTelemetry error for delivery $deliveryId: $e');
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

/// Provides latest fleet telemetry for Admin Dashboard / Radar.
/// Only reflects ACTIVE deliveries in flight — never completed/historical flights.
final fleetTelemetryProvider =
    StateNotifierProvider<FleetTelemetryNotifier, TelemetryModel?>((ref) {
  return FleetTelemetryNotifier(ref);
});

class FleetTelemetryNotifier extends StateNotifier<TelemetryModel?> {
  final Ref ref;
  RealtimeChannel? _channel;

  FleetTelemetryNotifier(this.ref) : super(null) {
    loadFleetTelemetry();
    _setupRealtime();
  }

  void _setupRealtime() {
    if (!SupabaseService.isConfigured) return;

    try {
      _channel = SupabaseService.client
          .channel('fleet_telemetry_stream')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'drone_telemetry',
            callback: (payload) {
              final rec = payload.newRecord;
              if (rec.isNotEmpty) {
                state = TelemetryModel.fromMap(rec);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Fleet realtime telemetry subscription error: $e');
    }
  }

  Future<void> loadFleetTelemetry() async {
    if (!SupabaseService.isConfigured) return;

    try {
      // 1. Check if drone is returning to base
      final returningDrone = await SupabaseService.client
          .from('drones')
          .select('id, status')
          .eq('status', 'returning')
          .limit(1)
          .maybeSingle();

      if (returningDrone != null && returningDrone['id'] != null) {
        final res = await SupabaseService.client
            .from('drone_telemetry')
            .select()
            .eq('drone_id', returningDrone['id'])
            .order('recorded_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (res != null) {
          state = TelemetryModel.fromMap(Map<String, dynamic>.from(res));
          return;
        }
      }

      // 2. Find currently active delivery (assigning or in_transit)
      final activeDel = await SupabaseService.client
          .from('deliveries')
          .select('id, status, progress')
          .inFilter('status', ['assigning', 'in_transit'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (activeDel != null && activeDel['id'] != null) {
        final activeId = activeDel['id'].toString();
        final res = await SupabaseService.client
            .from('drone_telemetry')
            .select()
            .eq('delivery_id', activeId)
            .order('recorded_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (res != null) {
          state = TelemetryModel.fromMap(Map<String, dynamic>.from(res));
          return;
        }
      }

      // No active flight in progress -> standby state
      state = null;
    } catch (e) {
      debugPrint('loadFleetTelemetry error: $e');
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
