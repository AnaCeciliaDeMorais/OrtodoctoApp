import 'dart:async';
import 'dart:io' show SocketException;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Mensagem em português para mostrar ao usuário.
String friendlyError(Object error) {
  if (error is AppException) return error.message;

  if (error is AuthException) {
    final code = error.code ?? '';
    final msg = error.message.toLowerCase();
    if (code == 'invalid_credentials' || msg.contains('invalid login')) {
      return 'E-mail ou senha incorretos.';
    }
    if (code == 'email_not_confirmed') return 'Confirme o seu e-mail antes de entrar.';
    if (code == 'over_email_send_rate_limit' || error.statusCode == '429') {
      return 'Muitas tentativas. Aguarde alguns minutos e tente de novo.';
    }
    if (code == 'same_password') return 'A nova senha precisa ser diferente da atual.';
    if (code == 'weak_password') return 'Senha fraca. Use letras, números e um caractere especial.';
    if (code == 'user_banned') return 'Este acesso está bloqueado.';
    return 'Não foi possível entrar: ${error.message}';
  }

  if (error is PostgrestException) {
    // As regras do banco já levantam mensagens em português.
    const own = {'42501', '23514', '23505', '22023', 'P0001'};
    if (own.contains(error.code) && !error.message.startsWith('new row violates')) {
      if (error.code == '23505' && error.message.contains('duplicate key')) {
        return 'Já existe um cadastro com esses dados.';
      }
      return error.message;
    }
    if (error.code == '42501' || error.message.contains('row-level security')) {
      return 'Você não tem permissão para esta ação.';
    }
    if (error.code == '23503') {
      return 'Este registro está em uso e não pode ser excluído.';
    }
    if (error.code == 'PGRST116') return 'Registro não encontrado.';
    return 'Erro no banco de dados: ${error.message}';
  }

  if (error is FunctionException) {
    final details = error.details;
    if (details is Map && details['error'] is String) return details['error'] as String;
    return 'Erro no servidor (${error.status}).';
  }

  if (error is StorageException) return 'Erro ao enviar arquivo: ${error.message}';
  if (error is TimeoutException) return 'O servidor demorou para responder. Tente de novo.';
  if (_isNetwork(error)) return 'Sem conexão com a internet.';
  return 'Erro inesperado: $error';
}

bool _isNetwork(Object e) {
  try {
    if (e is SocketException) return true;
  } catch (_) {
    // dart:io não existe no site (web).
  }
  final s = e.toString();
  return s.contains('Failed host lookup') || s.contains('XMLHttpRequest') ||
      s.contains('ClientException');
}

class AppException implements Exception {
  AppException(this.message);
  final String message;
  @override
  String toString() => message;
}
