import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_entry/core/entries/daily_entry_form_screen.dart';


class DailyEntriesScreen extends StatefulWidget {
  const DailyEntriesScreen({super.key});

  @override
  State<DailyEntriesScreen> createState() => _DailyEntriesScreenState();
}

class _DailyEntriesScreenState extends State<DailyEntriesScreen> {
  DateTime _selectedMonth = DateTime.now();

  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + monthsToAdd,
        1,
      );
    });
  }

  int _getDaysInMonth(int year, int month) {
    if (month == 12) {
      return DateTime(year + 1, 1, 0).day;
    }
    return DateTime(year, month + 1, 0).day;
  }

  void _onDateTapped(int day) {
    DateTime selectedDate = DateTime(_selectedMonth.year, _selectedMonth.month, day);
    
    // Popup වෙනුවට Full Screen එකකට (අලුත් පිටුවකට) යාම
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyEntryFormScreen(selectedDate: selectedDate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int daysInMonth = _getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    String monthName = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => _changeMonth(-1),
                color: Theme.of(context).primaryColor,
              ),
              Text(
                monthName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: () => _changeMonth(1),
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, 
              crossAxisSpacing: 8,
              mainAxisSpacing: 10,
            ),
            itemCount: daysInMonth,
            itemBuilder: (context, index) {
              int day = index + 1;
              return InkWell(
                onTap: () => _onDateTapped(day),
                child: Center( 
                  child: Container(
                    width: 40, 
                    height: 40, 
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Theme.of(context).primaryColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        day.toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}