import 'package:flutter/material.dart';
import 'package:smart_entry/core/customer/customer_form_screen.dart';
import 'package:smart_entry/core/entries/daily_entries_screen.dart';

import '../settings/settings_screen.dart'; 
import 'overview_screen.dart'; 
// අලුත් Reports ගොනුව Import කිරීම (Path එක ඔයාගේ ෆෝල්ඩර් වලට ගැලපෙන විදිහට හරියටම දෙන්න)
import '../reports/reports_screen.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0; 

  // Tabs 5ට අදාළ Screens ටික මෙතන තියෙනවා
  final List<Widget> _screens = [
    const OverviewScreen(),     // 0. Overview
    const CustomerFormScreen(), // 1. Customers
    const DailyEntriesScreen(), // 2. Daily Entries
    const ReportsScreen(),      // 3. අලුතින් එකතු කළ Reports (PDF)
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
        type: BottomNavigationBarType.fixed, // Tabs 4කට වඩා තියෙන නිසා fixed කිරීම අනිවාර්යයි
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey, 
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.eco, color: Colors.green, size: 28), 
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people, color: Colors.blue, size: 28),
            label: 'Customers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_document, color: Color.fromARGB(255, 7, 73, 1), size: 28),
            label: 'Entries',
          ),
          // --- අලුතින් එකතු කළ Reports Tab එක ---
          BottomNavigationBarItem(
            icon: Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 28),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings, color: Color.fromARGB(255, 104, 2, 99), size: 28),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}