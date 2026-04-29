import 'package:flutter/material.dart';

import '../../core/theme/app_theme_controller.dart';
import '../../features/clients/presentation/pages/clients_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/scheduling/presentation/pages/scheduling_page.dart';

class StaffBetaShellPage extends StatefulWidget {
  final AppThemeController themeController;

  const StaffBetaShellPage({
    super.key,
    required this.themeController,
  });

  @override
  State<StaffBetaShellPage> createState() => _StaffBetaShellPageState();
}

class _StaffBetaShellPageState extends State<StaffBetaShellPage> {
  int _currentIndex = 0;

  late final List<Widget> _pages = [
    const SchedulingPage(profileLevel: 'staff_beta'),
    const ClientsPage(),
    ProfilePage(themeController: widget.themeController),
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
            icon: Icon(Icons.calendar_today),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.people),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}