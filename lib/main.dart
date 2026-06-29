import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
<<<<<<< HEAD
  runApp(const ProviderScope(child: AeroDropApp()));
}
=======
  runApp(
    const ProviderScope(
      child: AeroDropApp(),
    ),
  );
}
>>>>>>> 5b6b7b1e3cbcc6cfb4e7ffb4cce8b6e56b3d0c51
