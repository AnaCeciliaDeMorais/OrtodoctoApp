import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/theme/app_theme_controller.dart';
import 'core/supabase/supabase_config.dart';
import 'shells/staff_alfa/staff_alfa_shell_page.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final themeController = AppThemeController();

  runApp(
    MyApp(
      themeController: themeController,
    ),
  );
}