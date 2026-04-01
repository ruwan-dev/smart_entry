import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _teaRateController = TextEditingController();
  final TextEditingController _transportRateController = TextEditingController();

  late String _selectedMonth;
  late String _selectedYear;

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  
  late List<String> _years;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    _selectedMonth = _months[now.month - 1];
    _selectedYear = now.year.toString();
    _years = List.generate(5, (index) => (now.year - 1 + index).toString());
  }

  Future<void> _saveRates() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });
      try {
        String docId = '$_selectedYear-$_selectedMonth';
        String sortValue = '$_selectedYear-${(_months.indexOf(_selectedMonth) + 1).toString().padLeft(2, '0')}';

        await FirebaseFirestore.instance.collection('MonthlyRates').doc(docId).set({
          'year': _selectedYear,
          'month': _selectedMonth,
          'teaRate': double.parse(_teaRateController.text.trim()),
          'transportRate': double.parse(_transportRateController.text.trim()),
          'updatedAt': FieldValue.serverTimestamp(),
          'sortValue': sortValue,
        });

        _teaRateController.clear();
        _transportRateController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ගාස්තු සාර්ථකව සුරකින ලදි!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('දෝෂයක් මතු විය: $e')),
          );
        }
      } finally {
        if (mounted) { setState(() { _isLoading = false; }); }
      }
    }
  }

  Future<void> _deleteRate(String docId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('මකා දමන්නද?'),
        content: const Text('ඔබට විශ්වාසද මෙම මාසයේ ගාස්තු විස්තර මකා දැමිය යුතුයි කියා?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('නැහැ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ඔව්, මකන්න', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance.collection('MonthlyRates').doc(docId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ගාස්තු සාර්ථකව මකා දමන ලදි!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('මකා දැමීමේදී දෝෂයක් මතු විය: $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _teaRateController.dispose();
    _transportRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keyboard Bug fix එක සඳහා මුළු screen එකම GestureDetector එකකින් wrap කර ඇත
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('මාසික ගාස්තු සැකසුම්', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // Data Entry Form
            Form(
              key: _formKey,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedYear,
                              decoration: const InputDecoration(labelText: 'වර්ෂය', border: OutlineInputBorder()),
                              items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                              onChanged: (val) => setState(() => _selectedYear = val!),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedMonth,
                              decoration: const InputDecoration(labelText: 'මාසය', border: OutlineInputBorder()),
                              items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                              onChanged: (val) => setState(() => _selectedMonth = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _teaRateController,
                              decoration: const InputDecoration(
                                labelText: 'තේ දළු මිල', 
                                border: OutlineInputBorder(),
                                prefixText: 'Rs. ',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) => val!.isEmpty ? 'මිල ඇතුළත් කරන්න' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _transportRateController,
                              decoration: const InputDecoration(
                                labelText: 'ප්‍රවාහන ගාස්තුව', 
                                border: OutlineInputBorder(),
                                prefixText: 'Rs. ',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) => val!.isEmpty ? 'ගාස්තුව ඇතුළත් කරන්න' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveRates,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isLoading 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('ගාස්තු සුරකින්න', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            const Text('සුරැකි ගාස්තු ලැයිස්තුව', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
  
            // StreamBuilder සහ Table එක ඇතුළත් කොටස
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('MonthlyRates')
                  .orderBy('sortValue', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('දැනට කිසිදු ගාස්තුවක් ඇතුළත් කර නොමැත.'));
                }

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias, 
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2.2),
                      1: FlexColumnWidth(1.5),
                      2: FlexColumnWidth(1.5),
                      3: FlexColumnWidth(1.0),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    border: TableBorder(
                      horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                    ),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                        ),
                        children: [
                          _buildTableHeader('මාසය'),
                          _buildTableHeader('තේ දළු\n(Rs)'),
                          _buildTableHeader('ප්‍රවාහනය\n(Rs)'),
                          _buildTableHeader(''),
                        ],
                      ),
                      ...snapshot.data!.docs.map((doc) {
                        return TableRow(
                          children: [
                            _buildTableCell('${doc['year']}\n${doc['month']}', isBold: true),
                            _buildTableCell(doc['teaRate'].toStringAsFixed(2)),
                            _buildTableCell(doc['transportRate'].toStringAsFixed(2)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteRate(doc.id),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }
}