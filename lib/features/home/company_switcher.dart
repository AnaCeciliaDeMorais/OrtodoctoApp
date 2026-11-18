import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../companies/company_form_sheet.dart';
import '../../core/widgets/common.dart';

/// Título da AppBar com a empresa em uso; toca para trocar (chefe e cliente
/// com mais de uma empresa).
class CompanyTitle extends StatelessWidget {
  const CompanyTitle(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final company = session.current;
    final canSwitch = session.companies.length > 1 && !session.isStaff;
    final subtitle = Text(
      company?.name ?? 'Nenhuma empresa',
      style: Theme.of(context).textTheme.bodySmall,
      overflow: TextOverflow.ellipsis,
    );
    final column = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: subtitle),
        if (canSwitch) const Icon(Icons.arrow_drop_down, size: 18),
      ]),
    ]);
    if (!canSwitch) return column;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => pickCompany(context),
      child: column,
    );
  }
}

Future<void> pickCompany(BuildContext context) async {
  final session = SessionScope.read(context);
  final chosen = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('Escolha a empresa', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        for (final c in session.companies)
          ListTile(
            leading: const Icon(Icons.business),
            title: Text(c.name),
            trailing: c.id == session.current?.id ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(ctx, c.id),
          ),
      ]),
    ),
  );
  if (chosen == null) return;
  session.selectCompany(session.companies.firstWhere((c) => c.id == chosen));
}

/// Mostra [child] só se houver empresa em uso; senão, orienta o chefe a
/// cadastrar a primeira.
class RequireCompany extends StatelessWidget {
  const RequireCompany({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    if (session.current != null) return child;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(
        icon: Icons.add_business_outlined,
        message: session.isOwner
            ? 'Cadastre a sua primeira empresa para começar.'
            : session.isStaff
                ? 'Seu acesso ainda não está ligado a uma empresa. Fale com o seu chefe.'
                : 'Seu cadastro ainda não está ligado a uma clínica.',
        action: session.isOwner
            ? FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Cadastrar empresa'),
                onPressed: () => showCompanyForm(context),
              )
            : null,
      ),
    );
  }
}
