import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/config.dart';
import '../../core/errors.dart';
import '../../core/supabase.dart';
import '../../core/validators.dart';
import '../../core/widgets/common.dart';
import 'owner_signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _ownerArea = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SessionScope.read(context).signIn(_email.text, _password.text, ownerArea: _ownerArea);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgot() async {
    final controller = TextEditingController(text: _email.text);
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Esqueci minha senha'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Enviaremos um link para você criar uma nova senha.'),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Enviar link'),
          ),
        ],
      ),
    );
    if (email == null || !mounted) return;
    if (Validators.email(email) != null) {
      showSnack(context, 'Informe um e-mail válido.', error: true);
      return;
    }
    await runGuarded(
      context,
      () => sb.auth.resetPasswordForEmail(email, redirectTo: AppConfig.passwordResetRedirect),
      success: 'Se o e-mail estiver cadastrado, o link chegará em instantes.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Icon(Icons.medical_services_outlined, size: 56, color: scheme.primary),
                  const SizedBox(height: 8),
                  Text('Ortodoctor',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold, color: scheme.primary)),
                  const SizedBox(height: 24),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                          value: false,
                          icon: Icon(Icons.people_outline),
                          label: Text('Clínica')),
                      ButtonSegment(
                          value: true,
                          icon: Icon(Icons.business_center_outlined),
                          label: Text('Gestor')),
                    ],
                    selected: {_ownerArea},
                    onSelectionChanged: (s) => setState(() {
                      _ownerArea = s.first;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _ownerArea
                        ? 'Acesso do chefe: gerencie suas empresas, equipe e relatórios.'
                        : 'Acesso de funcionários e clientes.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline)),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Mostrar senha' : 'Esconder senha',
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => Validators.required(v, 'Informe a senha'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: scheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _loading
                          ? const SizedBox(
                              height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_ownerArea ? 'Entrar como gestor' : 'Entrar'),
                    ),
                  ),
                  TextButton(onPressed: _forgot, child: const Text('Esqueci minha senha')),
                  if (_ownerArea)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_business_outlined),
                      label: const Text('Criar conta de gestor'),
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const OwnerSignupPage())),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
