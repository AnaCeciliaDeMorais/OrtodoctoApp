import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/app_theme_controller.dart';
import '../features/auth/presentation/pages/login_page.dart';

class MyApp extends StatelessWidget {
  final AppThemeController themeController;

  const MyApp({
    super.key,
    required this.themeController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeController.themeMode,
          home: const LoginPage(),
        );
      },
    );
  }
}