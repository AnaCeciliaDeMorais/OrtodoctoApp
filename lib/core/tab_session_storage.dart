import 'package:supabase_flutter/supabase_flutter.dart';

import 'tab_session_storage_stub.dart'
    if (dart.library.js_interop) 'tab_session_storage_web.dart'
    as impl;

/// Na web, cada aba do navegador guarda o próprio login (sessionStorage).
/// Assim dá para ter, por exemplo, o gestor numa aba, um funcionário em
/// outra e um paciente numa terceira, sem um derrubar o outro.
/// O login continua ao recarregar a página; ao fechar a aba, é preciso
/// entrar de novo. No celular nada muda (usa o armazenamento padrão).
///
/// Complementa o script em web/index.html, que impede o Supabase de
/// repassar entrada/saída de uma aba para as outras.
class TabSessionStorage extends LocalStorage {
  const TabSessionStorage({required this.legacyKey});

  /// Chave em que o Supabase guardava o login compartilhado (localStorage).
  /// É apagada para não deixar sessão antiga esquecida no navegador.
  final String legacyKey;

  static const _key = 'ortodoctor-login-desta-aba';

  @override
  Future<void> initialize() async => impl.removeShared(legacyKey);

  @override
  Future<bool> hasAccessToken() async => impl.read(_key) != null;

  @override
  Future<String?> accessToken() async => impl.read(_key);

  @override
  Future<void> removePersistedSession() async => impl.remove(_key);

  @override
  Future<void> persistSession(String persistSessionString) async =>
      impl.write(_key, persistSessionString);
}
