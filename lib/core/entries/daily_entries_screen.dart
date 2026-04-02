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
                
                Map<int, Map<String, double>> totals = {};
                
                if (snapshot.hasData && _selectedCustomerId != null) {
                  for (var doc in snapshot.data!.docs) {
                    if (doc['customerId'] == _selectedCustomerId) {
                      try {
                        int day = int.parse(doc['date'].split('-')[2]);
                        
                        if (!totals.containsKey(day)) {
                          totals[day] = {'weight': 0.0, 'advance': 0.0, 'fert': 0.0, 'tea': 0.0};
                        }
                        
                        totals[day]!['weight'] = totals[day]!['weight']! + (doc['netWeight'] ?? 0).toDouble();
                        totals[day]!['advance'] = totals[day]!['advance']! + (doc['advanceAmount'] ?? 0).toDouble();
                        
                        double f1 = (doc['fertilizer1Qty'] ?? 0).toDouble();
                        double f2 = (doc['fertilizer2Qty'] ?? 0).toDouble();
                        totals[day]!['fert'] = totals[day]!['fert']! + f1 + f2;
                        
                        double t1 = (doc['teaPacket1Qty'] ?? 0).toDouble();
                        double t2 = (doc['teaPacket2Qty'] ?? 0).toDouble();
                        totals[day]!['tea'] = totals[day]!['tea']! + t1 + t2;
                        
                      } catch (e) { }
                    }
                  }
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7, 
                    crossAxisSpacing: 4, 
                    mainAxisSpacing: 6, 
                    childAspectRatio: 0.55, 
                  ),
                  itemCount: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day,
                  itemBuilder: (context, index) {
                    int day = index + 1;
                    
                    var dayData = totals[day] ?? {'weight': 0.0, 'advance': 0.0, 'fert': 0.0, 'tea': 0.0};
                    double weight = dayData['weight']!;
                    double advance = dayData['advance']!;
                    double fert = dayData['fert']!;
                    double tea = dayData['tea']!;
                    
                    bool hasData = weight > 0 || advance > 0 || fert > 0 || tea > 0;

                    return InkWell(
                      onTap: () => _onDateTapped(day),
                      child: Container(
                        padding: const EdgeInsets.all(2.0),
                        decoration: BoxDecoration(
                          color: hasData ? Theme.of(context).primaryColor.withOpacity(0.08) : Colors.white,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: hasData ? Theme.of(context).primaryColor : Colors.grey.shade300),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(day.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: hasData ? Colors.black87 : Colors.grey)),
                            const Spacer(),
                            
                            // දත්ත තීරු (Columns) දෙකකට align කර පෙන්වීම
                            if (weight > 0) 
                              _buildAlignedRow(Icons.eco, Colors.green, weight.toStringAsFixed(1)),
                            if (advance > 0) 
                              _buildAlignedRow(Icons.money, Colors.blue, NumberFormat.compact().format(advance)),
                            if (fert > 0) 
                              // පොහොර සඳහා වඩාත් සුරක්ෂිත අයිකනයක් භාවිතා කිරීම
                              _buildAlignedRow(Icons.eco, const Color.fromARGB(255, 60, 6, 6), fert.toStringAsFixed(0)), 
                            if (tea > 0) 
                              _buildAlignedRow(Icons.local_cafe, Colors.orange, tea.toStringAsFixed(0)),
                              
                            const SizedBox(height: 2),
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

  // අයිකන් එක සහ අගය තීරු දෙකකට වෙන්කර (Align කර) පෙන්වන Function එක
  Widget _buildAlignedRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerRight,
              child: Icon(icon, size: 12, color: color),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 6,
            child: Text(
              text,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}