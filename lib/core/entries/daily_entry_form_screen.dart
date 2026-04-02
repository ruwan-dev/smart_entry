import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DailyEntryFormScreen extends StatefulWidget {
  final DateTime selectedDate;
  final String customerId;
  final String customerName;
  final String refNumber;

  const DailyEntryFormScreen({
    super.key, 
    required this.selectedDate,
    required this.customerId,
    required this.customerName,
    required this.refNumber,
  });

  @override
  State<DailyEntryFormScreen> createState() => _DailyEntryFormScreenState();
}

class _DailyEntryFormScreenState extends State<DailyEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _grossWeightController = TextEditingController();
  final TextEditingController _deductionController = TextEditingController(text: '0');
  final TextEditingController _advanceController = TextEditingController();
  final TextEditingController _fertilizer1Controller = TextEditingController();
  final TextEditingController _fertilizer2Controller = TextEditingController();
  final TextEditingController _teaPacket1Controller = TextEditingController();
  final TextEditingController _teaPacket2Controller = TextEditingController();
  
  bool _isLoading = false;

  // Settings වල ඇති මිල ගණන් ගබඩා කරගැනීමට Variables
  double _fert1Price = 0.0;
  double _fert2Price = 0.0;
  double _teaPkt1Price = 0.0;
  double _teaPkt2Price = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchGlobalPrices(); // ආරම්භයේදීම මිල ගණන් ලබා ගනී
  }

  // Firestore හි GlobalSettings වලින් මිල ගණන් ලබාගැනීම
  Future<void> _fetchGlobalPrices() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('GlobalSettings').doc('prices').get();
      if (doc.exists && mounted) {
        var data = doc.data() as Map<String, dynamic>;
        setState(() {
          _fert1Price = (data['fertilizer1Price'] ?? 0.0).toDouble();
          _fert2Price = (data['fertilizer2Price'] ?? 0.0).toDouble();
          _teaPkt1Price = (data['teaPacket1Price'] ?? 0.0).toDouble();
          _teaPkt2Price = (data['teaPacket2Price'] ?? 0.0).toDouble();
        });
      }
    } catch (e) {
      debugPrint("මිල ගණන් ලබාගැනීමේදී දෝෂයක්: $e");
    }
  }

  // අවම වශයෙන් එක field එකක් හෝ පුරවා ඇත්දැයි බැලීමට අලුත් Validation එක
  String? _validateInput(String? value) {
    bool isAllEmpty = _grossWeightController.text.trim().isEmpty &&
        (_deductionController.text.trim().isEmpty || _deductionController.text.trim() == '0') &&
        _advanceController.text.trim().isEmpty &&
        _fertilizer1Controller.text.trim().isEmpty &&
        _fertilizer2Controller.text.trim().isEmpty &&
        _teaPacket1Controller.text.trim().isEmpty &&
        _teaPacket2Controller.text.trim().isEmpty;

    if (isAllEmpty) {
      return 'අවශ්‍ය වේ';
    }

    // දත්තයක් ඇතුළත් කර ඇත්නම් එය නිවැරදි අංකයක් දැයි පරීක්ෂා කිරීම
    if (value != null && value.trim().isNotEmpty && value.trim() != '0') {
      if (double.tryParse(value.trim()) == null) {
        return 'නිවැරදි අගයක් ඇතුළත් කරන්න';
      }
    }
    return null;
  }

  Future<void> _saveEntry() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      try {
        // හිස්ව ඇති විට හෝ වැරදි අගයක් ඇති විට 0.0 ලෙස ගනී
        double grossWeight = double.tryParse(_grossWeightController.text.trim()) ?? 0.0;
        double deductions = double.tryParse(_deductionController.text.trim()) ?? 0.0;
        double netWeight = grossWeight - deductions;

        double advance = double.tryParse(_advanceController.text.trim()) ?? 0.0;
        double fertilizer1Qty = double.tryParse(_fertilizer1Controller.text.trim()) ?? 0.0;
        double fertilizer2Qty = double.tryParse(_fertilizer2Controller.text.trim()) ?? 0.0;
        double teaPacket1Qty = double.tryParse(_teaPacket1Controller.text.trim()) ?? 0.0;
        double teaPacket2Qty = double.tryParse(_teaPacket2Controller.text.trim()) ?? 0.0;

        await FirebaseFirestore.instance.collection('DailyEntries').add({
          'customerId': widget.customerId,
          'customerName': widget.customerName,
          'date': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
          'timestamp': widget.selectedDate,
          
          'grossWeight': grossWeight,
          'deductions': deductions,
          'netWeight': netWeight,
          
          'advanceAmount': advance,
          'fertilizer1Qty': fertilizer1Qty,
          'fertilizer2Qty': fertilizer2Qty,
          'teaPacket1Qty': teaPacket1Qty,
          'teaPacket2Qty': teaPacket2Qty,
          
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('දෛනික සටහන සාර්ථකව සුරකින ලදි!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) { setState(() { _isLoading = false; }); }
      }
    }
  }

  @override
  void dispose() {
    _grossWeightController.dispose();
    _deductionController.dispose();
    _advanceController.dispose();
    _fertilizer1Controller.dispose();
    _fertilizer2Controller.dispose();
    _teaPacket1Controller.dispose();
    _teaPacket2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('yyyy MMM dd').format(widget.selectedDate);

    // Keyboard එකේ උස (height) ලබාගැනීම
    double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text('$formattedDate දින සටහන', style: const TextStyle(fontSize: 18)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        // SizedBox.expand මගින් Screen එකේ හිස් තැන් වල touch කළත් keyboard එක වැසීමට පහසුකම් සලසයි
        child: SizedBox.expand(
          child: SingleChildScrollView(
            // තිරයේ ඉඩ මදි වුණොත් හෝ Keyboard එක ආවොත් පමණක් Scroll වීමට Dynamic Padding එකක් යොදා ඇත
            padding: EdgeInsets.only(
              left: 16.0, 
              right: 16.0, 
              top: 16.0, 
              bottom: bottomInset > 0 ? bottomInset + 24.0 : 24.0, // Keyboard එක ආවොත් පමණක් පෑඩිං වැඩි වේ
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // --- පාරිභෝගික විස්තර පෙන්වන Card එක ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      'No: ${widget.refNumber} - ${widget.customerName}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  const Text('තේ දළු විස්තර', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _grossWeightController,
                    decoration: InputDecoration(
                      labelText: 'මුළු තේ දළු ප්‍රමාණය (Gross Weight)',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.scale),
                      suffixText: 'Kg',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: _validateInput, // යාවත්කාලීන කරන ලදී
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _deductionController,
                    decoration: InputDecoration(
                      labelText: 'අඩු කිරීම් (වතුර/මළු බර)',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.remove_circle_outline),
                      suffixText: 'Kg',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: _validateInput, // යාවත්කාලීන කරන ලදී
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Divider(),
                  ),

                  const Text('අමතර සටහන් සහ අඩු කිරීම්', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _advanceController,
                    decoration: InputDecoration(
                      labelText: 'අත්තිකාරම් මුදල (Advance)',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.money),
                      prefixText: 'Rs. ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: _validateInput, // යාවත්කාලීන කරන ලදී
                  ),
                  const SizedBox(height: 20),

                  // --- පොහොර ---
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _fertilizer1Controller,
                          decoration: InputDecoration(
                            labelText: 'පොහොර 01 (Rs. $_fert1Price)',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.eco),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: _validateInput, // යාවත්කාලීන කරන ලදී
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _fertilizer2Controller,
                          decoration: InputDecoration(
                            labelText: 'පොහොර 02 (Rs. $_fert2Price)',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.eco),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: _validateInput, // යාවත්කාලීන කරන ලදී
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- තේ කොළ පැකට් ---
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _teaPacket1Controller,
                          decoration: InputDecoration(
                            labelText: 'තේ පැකට් 01 (Rs. $_teaPkt1Price)',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.local_cafe),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: _validateInput, // යාවත්කාලීන කරන ලදී
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _teaPacket2Controller,
                          decoration: InputDecoration(
                            labelText: 'තේ පැකට් 02 (Rs. $_teaPkt2Price)',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.local_cafe),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: _validateInput, // යාවත්කාලීන කරන ලදී
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveEntry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        elevation: 2,
                      ),
                      child: _isLoading 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('දත්ත සුරකින්න', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}