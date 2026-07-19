import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient(
    'https://owpbhztzjpillorjzpta.supabase.co',
    'sb_publishable_ZkdB7iXSZiDWBQGaNKDghA_Hjf-8tnk',
  );

  final tables = [
    'users',
    'user_credentials',
    'user_profiles',
    'user_roles',
    'campus_locations',
    'vendors',
    'vendor_statuses',
    'products',
    'product_categories',
    'orders',
    'order_statuses',
    'order_items',
    'payments',
    'payment_methods',
    'payment_statuses',
    'drones',
    'drone_statuses',
    'deliveries',
    'delivery_statuses',
    'delivery_packages',
    'package_types',
    'delivery_safety_checks',
    'delivery_status_logs',
    'drone_telemetry',
    'notifications',
    'notification_types',
    'notification_statuses',
    'package_verifications',
    'package_verification_statuses',
    'weather_safety',
    'weather_statuses',
    'no_fly_zones',
    'no_fly_zone_statuses',
  ];

  debugPrint('=== INSPECTING DATABASE SCHEMAS ===');
  for (final table in tables) {
    try {
      final res = await client.from(table).select().limit(1);
      if (res.isNotEmpty) {
        debugPrint('$table columns: ${res.first.keys}');
      } else {
        debugPrint('$table columns: (empty table, but exists)');
      }
    } catch (e) {
      debugPrint('$table error: $e');
    }
  }
  debugPrint('=== INSPECTION COMPLETED ===');
}
