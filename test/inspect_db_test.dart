import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

void main() {
  test(
    'verify deliveries detailed columns',
    () async {
      final client = SupabaseClient(
        supabaseUrl,
        supabaseKey,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );

      // Sign up a temporary user to get an authenticated session
      final email =
          'test_db_inspect_${DateTime.now().millisecondsSinceEpoch}@example.com';
      await client.auth.signUp(
        email: email,
        password: 'TestPassword123!',
        data: {
          'full_name': 'DB Inspector',
          'phone_number': '+639123456789',
          'requested_role': 'user',
        },
      );

      final columns = [
        'id',
        'order_id',
        'drone_id',
        'status',
        'pickup_location_id',
        'dropoff_location_id',
        'delivery_started_at',
        'delivery_completed_at',
        'estimated_delivery_seconds',
        'progress',
        'created_at',
        'updated_at',
      ];

      final actualColumns = <String>[];
      try {
        for (final col in columns) {
          try {
            await client.from('deliveries').select(col).limit(1);
            actualColumns.add(col);
          } catch (e) {
            // Column not queryable/not found
          }
        }
      } finally {
        await client.auth.signOut();
      }

      for (final col in columns) {
        expect(
          actualColumns,
          contains(col),
          reason: 'Column "$col" should exist in the deliveries table',
        );
      }
    },
    skip: (supabaseUrl.isEmpty || supabaseKey.isEmpty)
        ? 'Supabase credentials missing. Run with --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...'
        : false,
  );
}
