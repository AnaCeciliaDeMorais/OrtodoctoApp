import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/errors.dart';
import '../../core/functions.dart';
import '../../core/validators.dart';
import '../../core/widgets/common.dart';

/// Cadastro do chefe (Staff Alfa — RF.17). Exige o código de cadastro definido
/// no servidor, para que só quem a Ortodoctor autorizar crie contas de gestor.
class OwnerSignupPage extends StatefulWidget {
  const OwnerSignupPage({super.key});

  @override
  State<OwnerSignupPage> createState() => _OwnerSignupPageState();
}

class _OwnerSignupPageState extends State<OwnerSignupPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await callFunction('admin-users', {
        'action': 'register_owner',
        'full_name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text,
        'signup_code': _code.text.trim(),
      });
      if (!mounted) return;
      await SessionScope.read(context).signIn(_email.text, _password.text, ownerArea: true);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta de gestor')),
      body: ContentWidth(
        maxWidth: 480,
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome completo'),
              validator: Validators.required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
              validator: Validators.email,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefone (opcional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha',
                helperText: 'Mínimo 8 caracteres, 1 número e 1 caractere especial',
              ),
              validator: Validators.password,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmar senha'),
              validator: (v) => v != _password.text ? 'As senhas não conferem' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Código de cadastro',
                helperText: 'Fornecido pela administração do Ortodoctor',
              ),
              validator: Validators.required,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Criando...' : 'Criar conta'),
            ),
          ]),
        ),
      ),
    );
  }
}
