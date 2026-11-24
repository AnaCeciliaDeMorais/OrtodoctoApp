import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/supabase.dart';
import '../../core/widgets/common.dart';
import '../auth/new_password_page.dart';

/// Meus dados do cliente. O paciente só altera o telefone e a senha;
/// o resto do cadastro é alterado pela clínica (garantido também no banco).
class ClientDataPage extends StatefulWidget {
  const ClientDataPage({super.key});

  @override
  State<ClientDataPage> createState() => _ClientDataPageState();
}

class _ClientDataPageState extends State<ClientDataPage> {
  final _form = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: f.phone(_currentPhone()));
  bool _saving = false;

  String? _currentPhone() {
    final s = SessionScope.read(context);
    for (final p in s.myPatients) {
      if ((p.phone ?? '').isNotEmpty) return p.phone;
    }
    return s.profile?.phone;
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _savePhone() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final session = SessionScope.read(context);
    await runGuarded(context, () async {
      await sb.rpc('update_my_phone', params: {'p_phone': f.onlyDigits(_phone.text)});
      await session.refreshProfile();
      await session.refreshCompanies();
    }, success: 'Telefone atualizado.');
    if (mounted) setState(() => _saving = false);
  }

  String? _validatePhone(String? v) {
    final d = f.onlyDigits(v);
    if (d.isEmpty) return null;
    if (d.length < 10 || d.length > 11) return 'Informe DDD + número (10 ou 11 dígitos).';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Meus dados')),
      body: ContentWidth(
        maxWidth: 640,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Form(
            key: _form,
            child: TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefone', prefixIcon: Icon(Icons.phone_outlined)),
              validator: _validatePhone,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _saving ? null : _savePhone,
            child: const Text('Salvar telefone'),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.password),
            title: const Text('Alterar senha'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewPasswordPage())),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text('Sair', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () async {
              Navigator.of(context).popUntil((r) => r.isFirst);
              await session.signOut();
            },
          ),
          const Divider(height: 32),
          if (session.myPatients.isEmpty)
            const Text('Nenhum cadastro encontrado.')
          else
            for (final p in session.myPatients)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.business),
                    title: Text(session.companies.where((c) => c.id == p.companyId).firstOrNull?.name ?? ''),
                  ),
                  _row('Nome', p.fullName),
                  _row('CPF', p.cpf == null ? null : f.cpf(p.cpf)),
                  _row('Nascimento', p.birthDate == null ? null : f.date(p.birthDate)),
                  _row('E-mail', p.email ?? session.profile?.email),
                  _row('Responsável', p.guardianName),
                  _row('Endereço', p.address),
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Para corrigir estes dados, fale com a clínica.', style: TextStyle(fontSize: 12)),
                  ),
                ]),
              ),
        ]),
      ),
    );
  }

  Widget _row(String label, String? value) => value == null || value.isEmpty
      ? const SizedBox.shrink()
      : ListTile(dense: true, title: Text(value), subtitle: Text(label));
}
