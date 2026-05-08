import 'package:flutter/material.dart';

import '../../core/theme/app_theme_controller.dart';
import '../../features/scheduling/presentation/pages/scheduling_page.dart';
import '../../features/clients/presentation/pages/clients_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/contacts/presentation/contacts/contacts_page.dart';

class StaffAlfaShellPage extends StatefulWidget {
  final AppThemeController themeController;

  const StaffAlfaShellPage({
    super.key,
    required this.themeController,
  });

  @override
  State<StaffAlfaShellPage> createState() => _StaffAlfaShellPageState();
}

class _StaffAlfaShellPageState extends State<StaffAlfaShellPage> {
  int _currentIndex = 0;

  late final List<Widget> _pages = [
  const SchedulingPage(profileLevel: 'staff_alfa'),
  const ContactsPage(),
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
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Empresa',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}