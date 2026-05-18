import 'package:flutter/material.dart';
import 'package:smart_entry/core/customer/customer_form_screen.dart';
import 'package:smart_entry/core/entries/daily_entries_screen.dart';

import '../settings/settings_screen.dart'; 
import 'overview_screen.dart'; 
import '../reports/reports_screen.dart'; 

// Network Service එක import කරගන්න
import '../../core/network_service.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0; 

  final List<Widget> _screens = [
    const OverviewScreen(),     // 0. Overview
    const CustomerFormScreen(), // 1. Customers
    const DailyEntriesScreen(), // 2. Daily Entries
    const ReportsScreen(),      // 3. Reports (PDF)
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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Smart Entry'),
            
            // Online/Offline Status එක Text සහ Dot එක සමඟ පෙන්වීම
            ValueListenableBuilder<bool>(
              valueListenable: NetworkService().connectionStatus,
              builder: (context, isOnline, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ඔයා කලින් කිව්ව විදිහටම සකස් කළ නිසල Dot එක
                    _StatusDot(isOnline: isOnline),
                    const SizedBox(width: 8),
                    // කිසිදු border එකක් නැතිව text එක පමණක් මෙතනින් පෙන්වයි
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isOnline ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
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
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard, color: Colors.green, size: 28), 
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people, color: Colors.red, size: 28),
            label: 'Customers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_document, color: Color.fromARGB(255, 7, 73, 1), size: 28),
            label: 'Entries',
          ),
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

// --- Signal Ripple Animation එක සහිත නිසල Dot Widget එක ---
class _StatusDot extends StatefulWidget {
  final bool isOnline;
  const _StatusDot({required this.isOnline});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), 
    )..repeat(); 
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = widget.isOnline ? Colors.greenAccent : Colors.redAccent;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 18, // Text එක අසලටම තිබීමට width එක අඩු කරන ලදී
          height: 18,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // පිටතට විහිදෙන රවුම (Ripple Effect)
              Container(
                width: 18 * _controller.value,
                height: 18 * _controller.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: statusColor.withOpacity(1 - _controller.value),
                    width: 2,
                  ),
                ),
              ),
              // මැද ස්ථාවරව පවතින Dot එක
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.4),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}