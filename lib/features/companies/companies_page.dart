import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/formatters.dart';
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import 'companies_repository.dart';
import 'company_form_sheet.dart';
import 'staff_form_sheet.dart';

/// Chefe: lista de empresas; cada uma abre a equipe (RF.2).
class CompaniesPage extends StatelessWidget {
  const CompaniesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Empresas e equipe')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCompanyForm(context),
        icon: const Icon(Icons.add_business),
        label: const Text('Nova empresa'),
      ),
      body: session.companies.isEmpty
          ? const EmptyState(icon: Icons.business, message: 'Nenhuma empresa cadastrada.')
          : ContentWidth(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: session.companies.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = session.companies[i];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.business)),
                      title: Text(c.name),
                      subtitle: Text([
                        if (c.phone != null) phone(c.phone),
                        'Agenda ${c.openingTime}–${c.closingTime}, ${c.maxPerSlot} por horário',
                      ].join(' · ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CompanyTeamPage(company: c)),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class CompanyTeamPage extends StatefulWidget {
  const CompanyTeamPage({super.key, required this.company});
  final Company company;

  @override
  State<CompanyTeamPage> createState() => _CompanyTeamPageState();
}

class _CompanyTeamPageState extends State<CompanyTeamPage> {
  final _repo = CompaniesRepository();
  final _loader = GlobalKey<AsyncLoaderState<List<Profile>>>();

  Company get _company {
    final session = SessionScope.read(context);
    return session.companies.firstWhere((c) => c.id == widget.company.id,
        orElse: () => widget.company);
  }

  Future<void> _reload() async => _loader.currentState?.reload();

  Future<void> _deleteCompany() async {
    final ok = await confirm(
      context,
      'Excluir empresa',
      'Excluir "${_company.name}" apaga clientes, agenda, cobranças, caixa e produtos dela. '
          'Esta ação não pode ser desfeita.',
      ok: 'Excluir',
      danger: true,
    );
    if (!ok || !mounted) return;
    final done = await runGuarded(context, () => _repo.delete(_company.id), success: 'Empresa excluída.');
    if (done && mounted) {
      await SessionScope.read(context).refreshCompanies();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _staffActions(Profile p) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(p.fullName), subtitle: Text(p.email ?? '')),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Editar nome e telefone'),
            onTap: () => Navigator.pop(ctx, 'edit'),
          ),
          if (SessionScope.read(context).companies.length > 1)
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Mudar de empresa'),
              onTap: () => Navigator.pop(ctx, 'move'),
            ),
          ListTile(
            leading: Icon(p.active ? Icons.block : Icons.check_circle_outline),
            title: Text(p.active ? 'Desativar acesso' : 'Reativar acesso'),
            onTap: () => Navigator.pop(ctx, 'toggle'),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
            title: const Text('Excluir funcionário'),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        final saved = await showFormSheet<bool>(
            context, (_) => StaffFormSheet(companyId: _company.id, staff: p));
        if (saved == true) _reload();
      case 'move':
        final session = SessionScope.read(context);
        final target = await showDialog<Company>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('Mover para'),
            children: [
              for (final c in session.companies.where((c) => c.id != _company.id))
                SimpleDialogOption(onPressed: () => Navigator.pop(ctx, c), child: Text(c.name)),
            ],
          ),
        );
        if (target == null || !mounted) return;
        if (await runGuarded(context, () => _repo.updateStaff(p.id, companyId: target.id),
            success: '${p.firstName} agora está em ${target.name}.')) {
          _reload();
        }
      case 'toggle':
        if (await runGuarded(context, () => _repo.updateStaff(p.id, active: !p.active),
            success: p.active ? 'Acesso desativado.' : 'Acesso reativado.')) {
          _reload();
        }
      case 'delete':
        final ok = await confirm(
          context,
          'Excluir funcionário',
          'O login de ${p.fullName} será apagado. Se ele já tem lançamentos no caixa, '
              'desative o acesso em vez de excluir (o histórico continua nos relatórios).',
          ok: 'Excluir',
          danger: true,
        );
        if (!ok || !mounted) return;
        if (await runGuarded(context, () => _repo.deleteStaff(p.id), success: 'Funcionário excluído.')) {
          _reload();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    SessionScope.of(context);
    final c = _company;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          IconButton(
            tooltip: 'Editar empresa',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showCompanyForm(context, company: c),
          ),
          IconButton(
            tooltip: 'Excluir empresa',
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteCompany,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await showFormSheet<bool>(context, (_) => StaffFormSheet(companyId: c.id));
          if (saved == true) _reload();
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Novo funcionário'),
      ),
      body: ContentWidth(
        child: AsyncLoader<List<Profile>>(
          key: _loader,
          load: () => _repo.staff(c.id),
          builder: (context, staff, _) {
            if (staff.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 80),
                EmptyState(
                  icon: Icons.group_outlined,
                  message: 'Nenhum funcionário nesta empresa.\n'
                      'Cada funcionário entra com o próprio e-mail e vê só esta empresa e o próprio caixa.',
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: staff.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final p = staff[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(p.fullName.isEmpty ? '?' : p.fullName[0])),
                    title: Text(p.fullName),
                    subtitle: Text([p.email ?? '', if (p.phone != null) phone(p.phone)].join(' · ')),
                    trailing: p.active
                        ? null
                        : StatusChip('Inativo', Theme.of(context).colorScheme.error),
                    onTap: () => _staffActions(p),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
