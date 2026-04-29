import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/theme/app_theme_controller.dart';
import 'shells/staff_beta/staff_beta_shell_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ufctmsjoxqcnxkgstzft.supabase.co',
    anonKey: 'sb_publishable_aUScf8Z4Dtg-AQRhEwgZog_8LVIdrly',
  );

  final themeController = AppThemeController();

  runApp(
  MyApp(
    themeController: themeController,
  ),
);
}