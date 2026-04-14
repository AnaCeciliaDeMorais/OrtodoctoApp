import 'package:flutter/material.dart';
import 'package:ortodoctor/features/clients/presentation/pages/clients_page.dart';
import '../../features/scheduling/presentation/pages/scheduling_page.dart';
import '../../features/payments/presentation/pages/payments_page.dart';
import '../../features/treatments/presentation/pages/treatments_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';

class ClientShellPage extends StatefulWidget {
  const ClientShellPage({super.key});

  @override
  State<ClientShellPage> createState() => _ClientShellPageState();
}

class _ClientShellPageState extends State<ClientShellPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    SchedulingPage(profileLevel: 'client'),
    const ClientsPage(),
    const TreatmentsPage(),
    const PaymentsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Agend.',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Pagam.',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services),
            label: 'Tratam.',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}