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
        id: '10000000-0000-0000-0000-000000000001',
        name: 'UCLM Main Building',
        locationCode: 'MAIN',
        latitude: 10.325210,
        longitude: 123.953201,
        isActive: true,
      ),
      CampusLocation(
        id: '10000000-0000-0000-0000-000000000002',
        name: 'UCLM Annex 2',
        locationCode: 'ANNEX-2',
        latitude: 10.325633,
        longitude: 123.953770,
        isActive: true,
      ),
      CampusLocation(
        id: '10000000-0000-0000-0000-000000000003',
        name: 'UCLM Basic Education',
        locationCode: 'BASIC-ED',
        latitude: 10.325133,
        longitude: 123.953853,
        isActive: true,
      ),
      CampusLocation(
        id: '10000000-0000-0000-0000-000000000004',
        name: 'UCLM Maritime Building',
        locationCode: 'MARITIME',
        latitude: 10.326184,
        longitude: 123.954843,
        isActive: true,
      ),
      CampusLocation(
        id: '10000000-0000-0000-0000-000000000005',
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

/// Resolves the campus Base Hub location from database, falling back safely to 10.325152, 123.953046.
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
      id: '10000000-0000-0000-0000-000000000005',
      name: 'Campus Base Hub',
      locationCode: 'BASE-HUB',
      latitude: 10.325152,
      longitude: 123.953046,
      isActive: true,
    ),
  );
});
