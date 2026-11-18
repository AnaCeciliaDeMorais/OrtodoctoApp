import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/widgets/common.dart';

/// Dados cadastrais do cliente (somente leitura; alterações pela clínica).
class ClientDataPage extends StatelessWidget {
  const ClientDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Meus dados')),
      body: session.myPatients.isEmpty
          ? const EmptyState(icon: Icons.badge_outlined, message: 'Nenhum cadastro encontrado.')
          : ContentWidth(
              child: ListView(padding: const EdgeInsets.all(8), children: [
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
                      _row('Telefone', p.phone == null ? null : f.phone(p.phone)),
                      _row('E-mail', p.email),
                      _row('Responsável', p.guardianName),
                      _row('Endereço', p.address),
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Algo errado? Peça a correção à clínica.', style: TextStyle(fontSize: 12)),
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
