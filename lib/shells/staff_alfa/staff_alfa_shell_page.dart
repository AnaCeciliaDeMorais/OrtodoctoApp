import 'package:flutter/material.dart';
import '../../features/scheduling/presentation/pages/scheduling_page.dart';
import '../../features/clients/presentation/pages/clients_page.dart';
import '../../features/treatments/presentation/pages/treatments_page.dart';
import '../../features/team/presentation/pages/team_page.dart';
import '../../features/report/presentation/pages/reports_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/payments/presentation/pages/payments_page.dart';

class StaffAlfaShellPage extends StatefulWidget {
  const StaffAlfaShellPage({super.key});

  @override
  State<StaffAlfaShellPage> createState() => _StaffAlfaShellPageState();
}

class _StaffAlfaShellPageState extends State<StaffAlfaShellPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    SchedulingPage(profileLevel: 'staff_alfa'),
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
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services),
            label: 'Tratam.',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_hospital_outlined),
            selectedIcon: Icon(Icons.local_hospital),
            label: 'Clínica',
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