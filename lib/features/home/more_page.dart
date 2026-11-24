import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/theme.dart';
import '../approvals/approvals_page.dart';
import '../client/client_data_page.dart';
import '../companies/clinic_days_page.dart';
import '../companies/companies_page.dart';
import '../profile/profile_page.dart';
import '../questions/questions_page.dart';
import '../reports/reports_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    final items = <Widget>[
      if (session.isOwner) ...[
        _item(Icons.bar_chart, 'Relatórios', 'Faturamento, inadimplência, atendimentos e caixas',
            () => open(const ReportsPage())),
        _item(Icons.verified_outlined, 'Aprovações', 'Pagamentos recebidos pela equipe',
            () => open(const ApprovalsPage())),
        _item(Icons.business_outlined, 'Empresas e equipe', 'Cadastrar empresas e funcionários',
            () => open(const CompaniesPage())),
        _item(Icons.event_available_outlined, 'Dias de atendimento', 'Quando a agenda fica aberta',
            () => open(const ClinicDaysPage())),
      ],
      if (session.isManager)
        _item(Icons.forum_outlined, 'Dúvidas dos clientes', 'Responder perguntas',
            () => open(const QuestionsPage())),
      if (session.isClient) ...[
        _item(Icons.forum_outlined, 'Tirar dúvidas', 'Pergunte à clínica',
            () => open(const QuestionsPage())),
        _item(Icons.badge_outlined, 'Meus dados', 'Telefone, senha e sair',
            () => open(const ClientDataPage())),
      ],
      if (session.isManager)
        _item(Icons.person_outline, 'Meu perfil', 'Nome, senha e sair',
            () => open(const ProfilePage())),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Mais'), actions: const [ThemeToggleButton(), SizedBox(width: 8)]),
      body: ListView(children: [
        ListTile(
          leading: CircleAvatar(child: Text(_initials(session.profile?.fullName ?? ''))),
          title: Text(session.profile?.fullName ?? ''),
          subtitle: Text('${session.role.label} · ${session.profile?.email ?? ''}'),
        ),
        const Divider(),
        ...items,
      ]),
    );
  }

  Widget _item(IconData icon, String title, String subtitle, VoidCallback onTap) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// Ícone no canto superior direito de "Mais": alterna entre tema claro e escuro.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return IconButton(
          tooltip: dark ? 'Usar tema claro' : 'Usar tema escuro',
          icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          onPressed: () => themeMode.value = dark ? ThemeMode.light : ThemeMode.dark,
        );
      },
    );
  }
}
