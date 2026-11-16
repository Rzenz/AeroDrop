import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

/// The circle a customer may pin a drop-off inside, from delivery_zone_info().
class DeliveryZone {
  final double centerLatitude;
  final double centerLongitude;
  final String centerName;
  final double radiusMeters;

  const DeliveryZone({
    required this.centerLatitude,
    required this.centerLongitude,
    required this.centerName,
    required this.radiusMeters,
  });

  /// Null when the reply lacks a centre or a usable radius. Nothing is filled
  /// in with a guess: without the server's figures there is no zone.
  static DeliveryZone? fromMap(Map<String, dynamic> map) {
    double? num_(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    final lat = num_(map['center_latitude']);
    final lng = num_(map['center_longitude']);
    final radius = num_(map['radius_meters']);
    if (lat == null || lng == null || radius == null || radius <= 0) {
      return null;
    }
    final name = map['center_name']?.toString().trim() ?? '';
    return DeliveryZone(
      centerLatitude: lat,
      centerLongitude: lng,
      centerName: name.isEmpty ? 'the campus hub' : name,
      radiusMeters: radius,
    );
  }
}

/// The delivery zone, kept for the session since it rarely changes.
///
/// Null when it cannot be loaded. Callers then leave the "Pin on map" option
/// out entirely; the radius and centre are never assumed on the client.
final deliveryZoneProvider = FutureProvider<DeliveryZone?>((ref) async {
  if (!SupabaseService.isConfigured) return null;
  try {
    final res = await SupabaseService.client.rpc('delivery_zone_info');
    if (res is! Map) return null;
    return DeliveryZone.fromMap(Map<String, dynamic>.from(res));
  } catch (e) {
    debugPrint('delivery_zone_info failed; map pins are unavailable: $e');
    return null;
  }
});
