import 'package:flutter/material.dart';
import 'package:smart_entry/core/customer/customer_form_screen.dart';
import 'package:smart_entry/core/entries/daily_entries_screen.dart';

import '../settings/settings_screen.dart'; // අලුත් ගොනුව Import කිරීම

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const CustomerFormScreen(),
    const DailyEntriesScreen(), 
    const SettingsScreen(), // 3 වන තිරය එකතු කිරීම
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tea Collection App'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).primaryColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Customers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_document),
            label: 'Daily Entries',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings), // අලුත් අයිකනය
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}