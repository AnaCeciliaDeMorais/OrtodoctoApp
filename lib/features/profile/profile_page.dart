import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../core/widgets/common.dart';
import '../auth/new_password_page.dart';

/// Perfil (RF.15): nome, telefone, senha, tema e sair.
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

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final session = SessionScope.read(context);
    await runGuarded(context, () async {
      await sb.rpc('update_my_profile', params: {
        'p_full_name': _name.text.trim(),
        'p_phone': f.onlyDigits(_phone.text),
      });
      await session.refreshProfile();
    }, success: 'Dados salvos.');
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
              decoration: const InputDecoration(labelText: 'Telefone'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _saving ? null : _save, child: const Text('Salvar dados')),
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.password),
              title: const Text('Alterar senha'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewPasswordPage())),
            ),
            const SizedBox(height: 8),
            const Text('Tema'),
            const SizedBox(height: 8),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeMode,
              builder: (context, mode, _) => SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.light, label: Text('Claro'), icon: Icon(Icons.light_mode)),
                  ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Escuro'), icon: Icon(Icons.dark_mode)),
                ],
                selected: {mode},
                onSelectionChanged: (s) => themeMode.value = s.first,
              ),
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
