import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/session.dart';
import '../../core/errors.dart';
import '../../core/supabase.dart';
import '../../core/validators.dart';
import '../../core/widgets/common.dart';

/// Definir nova senha: aberta pelo link do e-mail ([recovery] = true) ou
/// pelo perfil (RF.15 — alterar senha).
class NewPasswordPage extends StatefulWidget {
  const NewPasswordPage({super.key, this.recovery = false});
  final bool recovery;

  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await sb.auth.updateUser(UserAttributes(password: _password.text));
      if (!mounted) return;
      showSnack(context, 'Senha alterada.');
      if (widget.recovery) {
        await SessionScope.read(context).finishPasswordRecovery();
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recovery ? 'Criar nova senha' : 'Alterar senha'),
        actions: [
          if (widget.recovery)
            TextButton(
              onPressed: () => SessionScope.read(context).signOut(),
              child: const Text('Cancelar'),
            ),
        ],
      ),
      body: ContentWidth(
        maxWidth: 480,
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nova senha',
                helperText: 'Mínimo 8 caracteres, 1 número e 1 caractere especial',
              ),
              validator: Validators.password,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmar nova senha'),
              validator: (v) => v != _password.text ? 'As senhas não conferem' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Salvando...' : 'Salvar nova senha'),
            ),
          ]),
        ),
      ),
    );
  }
}
