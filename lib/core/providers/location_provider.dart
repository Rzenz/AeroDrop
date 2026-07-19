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
        locationCode: 'OLD_MAIN',
        latitude: 10.3456,
        longitude: 123.9478,
        isActive: true,
      ),
      CampusLocation(
        id: '10000000-0000-0000-0000-000000000002',
        name: 'UCLM Annex 1',
        locationCode: 'ANNEX_1',
        latitude: 10.3460,
        longitude: 123.9480,
        isActive: true,
      ),
      CampusLocation(
        id: '10000000-0000-0000-0000-000000000003',
        name: 'UCLM Annex 2',
        locationCode: 'ANNEX_2',
        latitude: 10.3452,
        longitude: 123.9475,
        isActive: true,
      ),
      CampusLocation(
        id: '10000000-0000-0000-0000-000000000004',
        name: 'UCLM Basic Education',
        locationCode: 'BASIC_ED',
        latitude: 10.3465,
        longitude: 123.9485,
        isActive: true,
      ),
      CampusLocation(
        id: '10000000-0000-0000-0000-000000000005',
        name: 'UCLM Maritime Building',
        locationCode: 'MARITIME',
        latitude: 10.3448,
        longitude: 123.9470,
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
