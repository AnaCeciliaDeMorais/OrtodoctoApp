import 'package:flutter/foundation.dart';

/// Endereço e chave pública do projeto Supabase.
///
/// Os valores padrão abaixo já apontam para o projeto Supabase do Ortodoctor,
/// então basta rodar `flutter run` (ou `flutter build ...`).
/// Para usar outro projeto (ex.: um de testes), informe na hora de rodar:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_KEY=sb_publishable_xxxx
///
/// NUNCA coloque aqui a chave secreta (sb_secret_...).
///
/// A chave pública (publishable/anon) pode ficar no app: quem protege os dados
/// são as regras de acesso (RLS) do banco.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://fyzfzaaydxdcshxduopp.supabase.co',
  );
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_SPk3UulW9DU208LxoQBH0w_YIM2Zp0p',
  );

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Para onde o link de "esqueci minha senha" leva.
  /// No celular abre o app (esquema registrado no Android e no iOS);
  /// no site volta para o próprio endereço do site.
  static String get passwordResetRedirect =>
      kIsWeb ? Uri.base.origin : 'br.com.ortodoctor.app://reset-password';
}
