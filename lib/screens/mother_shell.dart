import 'package:flutter/material.dart';

import 'history_screen.dart';
import 'meds_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';

class MotherShell extends StatefulWidget {
  const MotherShell({super.key});

  @override
  State<MotherShell> createState() => _MotherShellState();
}

class _MotherShellState extends State<MotherShell> {
  int _index = 0;

  static const _pages = [TodayScreen(), MedsScreen(), HistoryScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'النهارده'),
          NavigationDestination(
              icon: Icon(Icons.medication_outlined),
              selectedIcon: Icon(Icons.medication),
              label: 'الأدوية'),
          NavigationDestination(icon: Icon(Icons.history), label: 'السجل'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'الإعدادات'),
        ],
      ),
    );
  }
}
