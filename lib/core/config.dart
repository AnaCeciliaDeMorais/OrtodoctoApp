import 'package:flutter/foundation.dart';

/// Endereço e chave pública do projeto Supabase.
///
/// Preencha os valores padrão abaixo ou informe na hora de rodar/compilar:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_KEY=sb_publishable_xxxx
///
/// A chave pública (publishable/anon) pode ficar no app: quem protege os dados
/// são as regras de acesso (RLS) do banco.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY', defaultValue: '');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Para onde o link de "esqueci minha senha" leva.
  /// No celular abre o app (esquema registrado no Android e no iOS);
  /// no site volta para o próprio endereço do site.
  static String get passwordResetRedirect =>
      kIsWeb ? Uri.base.origin : 'br.com.ortodoctor.app://reset-password';
}
