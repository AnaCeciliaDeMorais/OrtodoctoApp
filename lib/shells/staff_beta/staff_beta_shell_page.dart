import 'package:flutter/material.dart';
import '../../features/scheduling/presentation/pages/scheduling_page.dart';
import '../../features/clients/presentation/pages/clients_page.dart';
import '../../features/treatments/presentation/pages/treatments_page.dart';
import '../../features/payments/presentation/pages/payments_page.dart';



class StaffBetaShellPage extends StatefulWidget {
  const StaffBetaShellPage({super.key});

  @override
  State<StaffBetaShellPage> createState() => _StaffBetaShellPageState();
  
}

class _StaffBetaShellPageState extends State<StaffBetaShellPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    SchedulingPage(profileLevel: 'staff_beta'),
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
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_information_outlined),
            selectedIcon: Icon(Icons.medical_information),
            label: 'Tratam.',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Caixa',
          ),
        ],
      ),
    );
  }
}