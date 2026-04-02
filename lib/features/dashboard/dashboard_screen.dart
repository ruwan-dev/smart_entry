import 'package:flutter/material.dart';
import 'package:smart_entry/core/customer/customer_form_screen.dart';
import 'package:smart_entry/core/entries/daily_entries_screen.dart';

import '../settings/settings_screen.dart'; 
import 'overview_screen.dart'; // අලුත් Overview ගොනුව Import කිරීම

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0; // App එක open වෙද්දි මුලින්ම පෙන්වන්නේ 0 වෙනි තිරයයි (Overview)

  final List<Widget> _screens = [
    const OverviewScreen(),     // 1. අලුතින් එකතු කළ Overview තිරය
    const CustomerFormScreen(), // 2. Customers
    const DailyEntriesScreen(), // 3. Daily Entries
    const SettingsScreen(),     // 4. Settings
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Tea Collection App'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, 
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey, 
        items: const [
          BottomNavigationBarItem(
           icon: Icon(
            Icons.eco,
              color: Colors.red, 
              size: 30
                      ), // Default icon
           label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people, color: Colors.blue, size: 30),
            label: 'Customers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_document, color: Color.fromARGB(255, 7, 73, 1), size: 30),
            label: 'Daily Entries',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings, color: Color.fromARGB(255, 104, 2, 99), size: 30),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}