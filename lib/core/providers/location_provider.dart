import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

class CampusLocation {
  final String id;
  final String name;
  final String locationCode;
  final double latitude;
  final double longitude;
  final bool isActive;

  CampusLocation({
    required this.id,
    required this.name,
    required this.locationCode,
    required this.latitude,
    required this.longitude,
    required this.isActive,
  });

  factory CampusLocation.fromMap(Map<String, dynamic> map) {
    return CampusLocation(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      locationCode: map['location_code']?.toString() ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

final campusLocationsProvider = FutureProvider<List<CampusLocation>>((
  ref,
) async {
  if (!SupabaseService.isConfigured) {
    return [
      CampusLocation(
        id: '0b29ab20-8522-4778-a9d8-827516a57a6a',
        name: 'UCLM Main Building',
        locationCode: 'MAIN',
        latitude: 10.325210,
        longitude: 123.953201,
        isActive: true,
      ),
      CampusLocation(
        id: '19f9571d-9c16-47d2-b54b-632d9f7a37c2',
        name: 'UCLM Annex 2',
        locationCode: 'ANNEX-2',
        latitude: 10.325633,
        longitude: 123.953770,
        isActive: true,
      ),
      CampusLocation(
        id: '20e78551-c5a0-4d6f-8607-40628693589b',
        name: 'UCLM Basic Education',
        locationCode: 'BASIC-ED',
        latitude: 10.325133,
        longitude: 123.953853,
        isActive: true,
      ),
      CampusLocation(
        id: 'b59b7f2d-07a2-44a4-a552-fb945c18452e',
        name: 'UCLM Maritime Building',
        locationCode: 'MARITIME',
        latitude: 10.326184,
        longitude: 123.954843,
        isActive: true,
      ),
      CampusLocation(
        id: 'd637fc1f-64af-4911-9edb-b80ee587bb1e',
        name: 'Campus Base Hub',
        locationCode: 'BASE-HUB',
        latitude: 10.325152,
        longitude: 123.953046,
        isActive: true,
      ),
    ];
  }
  final response = await SupabaseService.client
      .from('campus_locations')
      .select()
      .order('name', ascending: true);

  return (response as List)
      .map((item) => CampusLocation.fromMap(Map<String, dynamic>.from(item)))
      .toList();
});

/// Drop-off locations available to customers (excludes BASE-HUB as it is an operational hub).
final dropoffLocationsProvider = FutureProvider<List<CampusLocation>>((
  ref,
) async {
  final allLocations = await ref.watch(campusLocationsProvider.future);
  return allLocations
      .where(
        (loc) =>
            loc.isActive &&
            loc.locationCode.toUpperCase() != 'BASE-HUB' &&
            loc.locationCode.toUpperCase() != 'BASE_HUB' &&
            !loc.name.toLowerCase().contains('base hub'),
      )
      .toList();
});

/// Resolves the campus drone hub from the database. When no BASE-HUB row is
/// found, falls back to the real hub row (migration 37): id
/// d637fc1f-64af-4911-9edb-b80ee587bb1e at 10.3251520, 123.9530460, so
/// anything keyed by id, like campus_distance_km, still resolves to the hub.
final baseHubLocationProvider = FutureProvider<CampusLocation>((
  ref,
) async {
  final allLocations = await ref.watch(campusLocationsProvider.future);
  return allLocations.firstWhere(
    (loc) =>
        loc.locationCode.toUpperCase() == 'BASE-HUB' ||
        loc.locationCode.toUpperCase() == 'BASE_HUB' ||
        loc.name.toLowerCase().contains('base hub'),
    orElse: () => CampusLocation(
      id: 'd637fc1f-64af-4911-9edb-b80ee587bb1e',
      name: 'Campus Drone Hub',
      locationCode: 'BASE-HUB',
      latitude: 10.3251520,
      longitude: 123.9530460,
      isActive: true,
    ),
  );
});
