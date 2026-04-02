import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_entry/core/entries/daily_entry_form_screen.dart'; 


class DailyEntriesScreen extends StatefulWidget {
  final String? initialCustomerId;
  final String? initialRefNumber;

  const DailyEntriesScreen({super.key, this.initialCustomerId, this.initialRefNumber});

  @override
  State<DailyEntriesScreen> createState() => _DailyEntriesScreenState();
}

class _DailyEntriesScreenState extends State<DailyEntriesScreen> {
  DateTime _selectedMonth = DateTime.now();
  String? _selectedCustomerId;
  final TextEditingController _refController = TextEditingController();
  List<DocumentSnapshot> _allCustomers = []; 

  @override
  void initState() {
    super.initState();
    // පිටතින් දත්ත ලැබී ඇත්නම් ඒවා Controller එකට සහ Variable එකට ඇතුළත් කිරීම
    if (widget.initialCustomerId != null) {
      _selectedCustomerId = widget.initialCustomerId;
      _refController.text = widget.initialRefNumber ?? '';
    }
  }

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + monthsToAdd, 1);
    });
  }

  void _onDateTapped(int day) {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('කරුණාකර පාරිභෝගිකයෙකු තෝරන්න 👤'), backgroundColor: Colors.orange),
      );
      return;
    }

    // තෝරාගත් පාරිභෝගිකයාගේ සම්පූර්ණ දත්ත ලබා ගැනීම
    var customer = _allCustomers.firstWhere((c) => c.id == _selectedCustomerId);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyEntryFormScreen(
          selectedDate: DateTime(_selectedMonth.year, _selectedMonth.month, day),
          customerId: _selectedCustomerId!,
          customerName: customer['name'],
          refNumber: customer['refNumber'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String monthName = DateFormat('MMMM yyyy').format(_selectedMonth);
    String monthPrefix = DateFormat('yyyy-MM').format(_selectedMonth);

    return Scaffold(
      appBar: AppBar(title: const Text('දෛනික සටහන්')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('Customers').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData) _allCustomers = snapshot.data!.docs;

                return Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _refController,
                        decoration: const InputDecoration(labelText: 'අංකය', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          final match = _allCustomers.where((c) => c['refNumber'] == value.trim()).toList();
                          setState(() {
                            _selectedCustomerId = match.isNotEmpty ? match.first.id : null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'නම', border: OutlineInputBorder()),
                        isExpanded: true,
                        value: _selectedCustomerId,
                        items: _allCustomers.map((doc) {
                          return DropdownMenuItem(value: doc.id, child: Text(doc['name']));
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCustomerId = val;
                            final customer = _allCustomers.firstWhere((c) => c.id == val);
                            _refController.text = customer['refNumber'];
                          });
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => _changeMonth(-1)),
                Text(monthName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.arrow_forward_ios), onPressed: () => _changeMonth(1)),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('DailyEntries')
                  .where('date', isGreaterThanOrEqualTo: '$monthPrefix-01')
                  .where('date', isLessThanOrEqualTo: '$monthPrefix-31')
                  .snapshots(),
              builder: (context, snapshot) {
                Map<int, double> totals = {};
                if (snapshot.hasData && _selectedCustomerId != null) {
                  for (var doc in snapshot.data!.docs) {
                    if (doc['customerId'] == _selectedCustomerId) {
                      try {
                        int day = int.parse(doc['date'].split('-')[2]);
                        totals[day] = (totals[day] ?? 0) + (doc['netWeight'] ?? 0);
                      } catch (e) { /* දෝෂ පාලනය */ }
                    }
                  }
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7, crossAxisSpacing: 8, mainAxisSpacing: 10, childAspectRatio: 0.75,
                  ),
                  itemCount: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day,
                  itemBuilder: (context, index) {
                    int day = index + 1;
                    double weight = totals[day] ?? 0;
                    return InkWell(
                      onTap: () => _onDateTapped(day),
                      child: Container(
                        decoration: BoxDecoration(
                          color: weight > 0 ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: weight > 0 ? Theme.of(context).primaryColor : Colors.grey.shade300),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(day.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (weight > 0)
                              FittedBox(child: Text('${weight.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 10))),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}