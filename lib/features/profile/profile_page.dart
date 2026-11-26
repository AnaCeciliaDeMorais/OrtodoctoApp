import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/supabase.dart';
import '../../core/validators.dart';
import '../../core/widgets/common.dart';
import '../auth/new_password_page.dart';

/// Perfil da equipe (RF.15): nome, telefone, senha e sair.
/// Vale para o gestor (chefe) e para o funcionário; o paciente usa "Meus dados".
/// O tema fica no ícone do canto superior direito de "Mais".
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: SessionScope.read(context).profile?.fullName);
  late final _phone = TextEditingController(text: f.phone(SessionScope.read(context).profile?.phone));
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _validatePhone(String? v) {
    final d = f.onlyDigits(v);
    if (d.isEmpty) return null;
    if (d.length < 10 || d.length > 11) return 'Informe DDD + número (10 ou 11 dígitos).';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final session = SessionScope.read(context);
    final ok = await runGuarded(context, () async {
      await sb.rpc('update_my_profile', params: {
        'p_full_name': _name.text.trim(),
        'p_phone': f.onlyDigits(_phone.text),
      });
      await session.refreshProfile();
    }, success: 'Dados salvos.');
    if (ok && mounted) {
      _name.text = session.profile?.fullName ?? _name.text;
      _phone.text = f.phone(session.profile?.phone);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final p = session.profile!;
    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: ContentWidth(
        maxWidth: 560,
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(p.email ?? ''),
              subtitle: Text('Perfil: ${p.role.label}'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: Validators.required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefone', hintText: '(11) 99999-9999'),
              validator: _validatePhone,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Salvando...' : 'Salvar dados'),
            ),
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.password),
              title: const Text('Alterar senha'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewPasswordPage())),
            ),
            const Divider(height: 32),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Sair'),
              onPressed: () async {
                Navigator.of(context).popUntil((r) => r.isFirst);
                await session.signOut();
              },
            ),
          ]),
        ),
      ),
    );
  }
}
