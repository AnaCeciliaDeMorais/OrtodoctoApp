import 'formatters.dart';

class Validators {
  static String? required(String? v, [String msg = 'Campo obrigatório']) =>
      (v == null || v.trim().isEmpty) ? msg : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'E-mail inválido';
  }

  /// RN.7: mínimo 8 caracteres, 1 número e 1 caractere especial.
  static String? password(String? v) {
    final s = v ?? '';
    if (s.length < 8) return 'A senha precisa ter pelo menos 8 caracteres';
    if (!RegExp(r'\d').hasMatch(s)) return 'Inclua pelo menos 1 número';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(s)) {
      return 'Inclua pelo menos 1 caractere especial (ex.: ! @ # \$)';
    }
    return null;
  }

  static String? money(String? v, {bool allowZero = false}) {
    final value = parseMoney(v ?? '');
    if (value == null) return 'Informe um valor';
    if (value < 0 || (!allowZero && value == 0)) return 'Valor inválido';
    return null;
  }

  static String? cpfOptional(String? v) {
    final d = onlyDigits(v);
    if (d.isEmpty) return null;
    return isValidCpf(d) ? null : 'CPF inválido';
  }

  static bool isValidCpf(String digits) {
    if (digits.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return false;
    int calc(int len) {
      var sum = 0;
      for (var i = 0; i < len; i++) {
        sum += int.parse(digits[i]) * (len + 1 - i);
      }
      final r = (sum * 10) % 11;
      return r == 10 ? 0 : r;
    }
    return calc(9) == int.parse(digits[9]) && calc(10) == int.parse(digits[10]);
  }
}
