import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config.dart';
import 'core/tab_session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');

  if (AppConfig.isConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseKey,
      // Na web cada aba tem o próprio login (vários usuários ao mesmo tempo).
      authOptions: kIsWeb
          ? FlutterAuthClientOptions(
              localStorage: TabSessionStorage(
                legacyKey:
                    'sb-${Uri.parse(AppConfig.supabaseUrl).host.split('.').first}-auth-token',
              ),
            )
          : const FlutterAuthClientOptions(),
    );
  }
  runApp(const OrtodoctorApp());
}
