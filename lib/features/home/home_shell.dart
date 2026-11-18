import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../shared/models/models.dart';
import '../cash/cash_page.dart';
import '../client/client_appointments_page.dart';
import '../client/client_home_page.dart';
import '../client/client_payments_page.dart';
import '../patients/patients_page.dart';
import '../products/products_page.dart';
import '../schedule/schedule_page.dart';
import 'more_page.dart';

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon, this.page);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}

/// Área logada: a barra de navegação muda conforme o perfil.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  List<_Dest> _destinations(UserRole role) => switch (role) {
        UserRole.owner || UserRole.staff => [
            const _Dest('Agenda', Icons.calendar_month_outlined, Icons.calendar_month, SchedulePage()),
            const _Dest('Clientes', Icons.people_outline, Icons.people, PatientsPage()),
            _Dest(role == UserRole.owner ? 'Caixa' : 'Meu caixa', Icons.point_of_sale_outlined,
                Icons.point_of_sale, const CashPage()),
            const _Dest('Produtos', Icons.storefront_outlined, Icons.storefront, ProductsPage()),
            const _Dest('Mais', Icons.menu, Icons.menu, MorePage()),
          ],
        UserRole.client => const [
            _Dest('Início', Icons.home_outlined, Icons.home, ClientHomePage()),
            _Dest('Consultas', Icons.event_outlined, Icons.event, ClientAppointmentsPage()),
            _Dest('Pagamentos', Icons.receipt_long_outlined, Icons.receipt_long, ClientPaymentsPage()),
            _Dest('Produtos', Icons.storefront_outlined, Icons.storefront, ProductsPage()),
            _Dest('Mais', Icons.menu, Icons.menu, MorePage()),
          ],
      };

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final dests = _destinations(session.role);
    final index = _index.clamp(0, dests.length - 1);
    // Recria a tela ao trocar de empresa para recarregar os dados.
    final body = KeyedSubtree(
      key: ValueKey('${dests[index].label}-${session.current?.id}'),
      child: dests[index].page,
    );
    final wide = MediaQuery.sizeOf(context).width >= 900;

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Icon(Icons.medical_services_outlined,
                  color: Theme.of(context).colorScheme.primary, size: 32),
            ),
            destinations: [
              for (final d in dests)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in dests)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
