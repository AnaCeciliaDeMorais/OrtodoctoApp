import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../home/company_switcher.dart';
import 'patient_detail_page.dart';
import 'patient_form_sheet.dart';
import 'patients_repository.dart';

/// Clientes da empresa (RF.1): busca, cadastro e acesso à ficha.
class PatientsPage extends StatefulWidget {
  const PatientsPage({super.key});

  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  final _repo = PatientsRepository();
  final _loader = GlobalKey<AsyncLoaderState<List<Patient>>>();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _new(Company company) async {
    final saved = await showFormSheet<Patient>(context, (_) => PatientFormSheet(companyId: company.id));
    if (saved == null || !mounted) return;
    _loader.currentState?.reload();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PatientDetailPage(patientId: saved.id)));
    _loader.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return RequireCompany(
      title: 'Clientes',
      child: Builder(builder: (context) {
        final company = SessionScope.of(context).current!;
        return Scaffold(
          appBar: AppBar(title: const CompanyTitle('Clientes')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _new(company),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Novo cliente'),
          ),
          body: ContentWidth(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por nome, CPF ou telefone',
                  ),
                  onChanged: (q) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = q));
                  },
                ),
              ),
              Expanded(
                child: AsyncLoader<List<Patient>>(
                  key: _loader,
                  reloadKey: _query,
                  load: () => _repo.list(company.id, query: _query),
                  builder: (context, items, reload) {
                    if (items.isEmpty) {
                      return ListView(children: [
                        const SizedBox(height: 60),
                        EmptyState(
                          icon: Icons.people_outline,
                          message: _query.isEmpty ? 'Nenhum cliente cadastrado.' : 'Nenhum cliente encontrado.',
                        ),
                      ]);
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = items[i];
                        return ListTile(
                          leading: CircleAvatar(child: Text(p.fullName[0].toUpperCase())),
                          title: Text(p.fullName),
                          subtitle: Text([
                            if (p.phone != null) f.phone(p.phone),
                            if (p.cpf != null) 'CPF ${f.cpf(p.cpf)}',
                          ].join(' · ')),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (p.hasAccess)
                              const Tooltip(message: 'Tem acesso ao app', child: Icon(Icons.phone_iphone, size: 18)),
                            if (!p.active) StatusChip('Inativo', Theme.of(context).colorScheme.error),
                          ]),
                          onTap: () async {
                            await Navigator.push(context,
                                MaterialPageRoute(builder: (_) => PatientDetailPage(patientId: p.id)));
                            reload();
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }
}
