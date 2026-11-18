import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../features/auth/login_page.dart';
import '../features/auth/new_password_page.dart';
import '../features/home/home_shell.dart';
import 'session.dart';

class OrtodoctorApp extends StatefulWidget {
  const OrtodoctorApp({super.key});

  @override
  State<OrtodoctorApp> createState() => _OrtodoctorAppState();
}

class _OrtodoctorAppState extends State<OrtodoctorApp> {
  final _session = AppSession();

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: _session,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeMode,
        builder: (context, mode, _) => MaterialApp(
          title: 'Ortodoctor',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

/// Decide a tela inicial: configuração pendente, login, nova senha ou a área
/// do perfil (chefe, funcionário ou cliente).
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isConfigured) return const _NotConfiguredPage();
    final session = SessionScope.of(context);
    if (!session.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (session.recoveringPassword) return const NewPasswordPage(recovery: true);
    if (!session.signedIn) return const LoginPage();
    return HomeShell(key: ValueKey(session.profile!.id));
  }
}

class _NotConfiguredPage extends StatelessWidget {
  const _NotConfiguredPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Supabase não configurado.\n\nRode o app com\n'
              '--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...\n'
              'ou preencha lib/core/config.dart.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}
