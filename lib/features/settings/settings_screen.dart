import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // මාසික ගාස්තු සඳහා Controllers
  final _monthlyFormKey = GlobalKey<FormState>();
  final TextEditingController _teaRateController = TextEditingController();
  final TextEditingController _transportRateController = TextEditingController();

  // ස්ථිර (Global) අමතර භාණ්ඩ මිල සඳහා Controllers
  final _globalFormKey = GlobalKey<FormState>();
  final TextEditingController _fert1PriceController = TextEditingController();
  final TextEditingController _fert2PriceController = TextEditingController();
  final TextEditingController _teaPkt1PriceController = TextEditingController();
  final TextEditingController _teaPkt2PriceController = TextEditingController();

  late String _selectedMonth;
  late String _selectedYear;

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  
  late List<String> _years;
  bool _isLoadingMonthly = false;
  bool _isLoadingGlobal = false;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    _selectedMonth = _months[now.month - 1];
    _selectedYear = now.year.toString();
    _years = List.generate(5, (index) => (now.year - 1 + index).toString());
    
    // ආරම්භයේදීම Global මිල ගණන් load කිරීම
    _loadGlobalPrices();
  }

  // --- Global මිල ගණන් Load කිරීම ---
  Future<void> _loadGlobalPrices() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('GlobalSettings').doc('prices').get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        setState(() {
          _fert1PriceController.text = (data['fertilizer1Price'] ?? '').toString();
          _fert2PriceController.text = (data['fertilizer2Price'] ?? '').toString();
          _teaPkt1PriceController.text = (data['teaPacket1Price'] ?? '').toString();
          _teaPkt2PriceController.text = (data['teaPacket2Price'] ?? '').toString();
        });
      }
    } catch (e) {
      // Ignore error initially
    }
  }

  // --- මාසික ගාස්තු සුරැකීම ---
  Future<void> _saveMonthlyRates() async {
    if (_monthlyFormKey.currentState!.validate()) {
      setState(() { _isLoadingMonthly = true; });
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('මාසික ගාස්තු සාර්ථකව සුරකින ලදි!')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('දෝෂයක් මතු විය: $e')));
      } finally {
        if (mounted) setState(() { _isLoadingMonthly = false; });
      }
    }
  }

  // --- ස්ථිර (Global) අමතර භාණ්ඩ මිල සුරැකීම ---
  Future<void> _saveGlobalPrices() async {
    if (_globalFormKey.currentState!.validate()) {
      setState(() { _isLoadingGlobal = true; });
      try {
        await FirebaseFirestore.instance.collection('GlobalSettings').doc('prices').set({
          'fertilizer1Price': double.parse(_fert1PriceController.text.trim()),
          'fertilizer2Price': double.parse(_fert2PriceController.text.trim()),
          'teaPacket1Price': double.parse(_teaPkt1PriceController.text.trim()),
          'teaPacket2Price': double.parse(_teaPkt2PriceController.text.trim()),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('අමතර භාණ්ඩ මිල ගණන් සාර්ථකව යාවත්කාලීන විය!')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('දෝෂයක් මතු විය: $e')));
      } finally {
        if (mounted) setState(() { _isLoadingGlobal = false; });
      }
    }
  }

  // --- මාසික දත්ත මකා දැමීම ---
  Future<void> _deleteRate(String docId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('මකා දමන්නද?'),
        content: const Text('ඔබට විශ්වාසද මෙම මාසයේ ගාස්තු විස්තර මකා දැමිය යුතුයි කියා?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('නැහැ')),
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ගාස්තු සාර්ථකව මකා දමන ලදි!')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('දෝෂයක්: $e')));
      }
    }
  }

  @override
  void dispose() {
    _teaRateController.dispose();
    _transportRateController.dispose();
    _fert1PriceController.dispose();
    _fert2PriceController.dispose();
    _teaPkt1PriceController.dispose();
    _teaPkt2PriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 100.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // ============================================
            // කොටස 01: ස්ථිර භාණ්ඩ මිල ගණන් (Global Settings)
            // ============================================
            const Text('අමතර භාණ්ඩ මිල ගණන් (ස්ථිර)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Form(
              key: _globalFormKey,
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _fert1PriceController,
                              decoration: const InputDecoration(labelText: 'පොහොර 1 (Rs)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.eco, size: 20)),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) => val!.isEmpty ? 'මිල දෙන්න' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _fert2PriceController,
                              decoration: const InputDecoration(labelText: 'පොහොර 2 (Rs)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.eco, size: 20)),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) => val!.isEmpty ? 'මිල දෙන්න' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _teaPkt1PriceController,
                              decoration: const InputDecoration(labelText: 'තේ පැකට් 1 (Rs)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.local_cafe, size: 20)),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) => val!.isEmpty ? 'මිල දෙන්න' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _teaPkt2PriceController,
                              decoration: const InputDecoration(labelText: 'තේ පැකට් 2 (Rs)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.local_cafe, size: 20)),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) => val!.isEmpty ? 'මිල දෙන්න' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoadingGlobal ? null : _saveGlobalPrices,
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: _isLoadingGlobal 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('මිල ගණන් යාවත්කාලීන කරන්න', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // ============================================
            // කොටස 02: මාසික ගාස්තු සැකසුම් (Monthly Rates)
            // ============================================
            const Text('මාසික ගාස්තු සැකසුම්', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Form(
              key: _monthlyFormKey,
              child: Card(
                elevation: 3,
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
                          const SizedBox(width: 12),
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
                              decoration: const InputDecoration(labelText: 'තේ දළු මිල', border: OutlineInputBorder(), prefixText: 'Rs. '),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) => val!.isEmpty ? 'මිල ඇතුළත් කරන්න' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _transportRateController,
                              decoration: const InputDecoration(labelText: 'ප්‍රවාහන ගාස්තුව', border: OutlineInputBorder(), prefixText: 'Rs. '),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) => val!.isEmpty ? 'ගාස්තුව ඇතුළත් කරන්න' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoadingMonthly ? null : _saveMonthlyRates,
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: _isLoadingMonthly 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('මාසික ගාස්තු සුරකින්න', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // ============================================
            // කොටස 03: මාසික ගාස්තු ලැයිස්තුව (Monthly Rates List)
            // ============================================
            const Text('සුරැකි මාසික ගාස්තු ලැයිස්තුව', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('MonthlyRates').orderBy('sortValue', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('දැනට කිසිදු ගාස්තුවක් ඇතුළත් කර නොමැත.'));

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  clipBehavior: Clip.antiAlias, 
                  child: Table(
                    columnWidths: const { 0: FlexColumnWidth(2.2), 1: FlexColumnWidth(1.5), 2: FlexColumnWidth(1.5), 3: FlexColumnWidth(1.0) },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1)),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1)),
                        children: [
                          _buildTableHeader('මාසය'), _buildTableHeader('තේ දළු\n(Rs)'), _buildTableHeader('ප්‍රවාහනය\n(Rs)'), _buildTableHeader(''),
                        ],
                      ),
                      ...snapshot.data!.docs.map((doc) {
                        return TableRow(
                          children: [
                            _buildTableCell('${doc['year']}\n${doc['month']}', isBold: true),
                            _buildTableCell(doc['teaRate'].toStringAsFixed(2)),
                            _buildTableCell(doc['transportRate'].toStringAsFixed(2)),
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteRate(doc.id)),
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

  Widget _buildTableHeader(String text) => Padding(padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0), child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 13)));
  Widget _buildTableCell(String text, {bool isBold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0), child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 13)));
}