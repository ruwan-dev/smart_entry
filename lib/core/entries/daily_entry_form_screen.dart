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
  
  final TextEditingController _grossWeightController = TextEditingController();
  final TextEditingController _deductionController = TextEditingController(text: '0');
  
  bool _isLoading = false;

  Future<void> _saveEntry() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      try {
        double grossWeight = double.parse(_grossWeightController.text.trim());
        double deductions = double.parse(_deductionController.text.trim());
        double netWeight = grossWeight - deductions;

        await FirebaseFirestore.instance.collection('DailyEntries').add({
          'customerId': widget.customerId,
          'customerName': widget.customerName,
          'date': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
          'timestamp': widget.selectedDate,
          'grossWeight': grossWeight,
          'deductions': deductions,
          'netWeight': netWeight,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('yyyy MMM dd').format(widget.selectedDate);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text('$formattedDate දින සටහන'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- පාරිභෝගික විස්තර පෙන්වන නවීන Card එක ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.customerName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ref No: ${widget.refNumber}',
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // --- දත්ත ඇතුළත් කරන කොටස ---
              TextFormField(
                controller: _grossWeightController,
                decoration: InputDecoration(
                  labelText: 'තේ දළු ප්‍රමාණය(Kg)',
                  hintText: 'Gross Weight',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.scale),
                  suffixText: 'Kg',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'කරුණාකර බර ඇතුළත් කරන්න';
                  if (double.tryParse(value) == null) return 'නිවැරදි අගයක් ඇතුළත් කරන්න';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _deductionController,
                decoration: InputDecoration(
                  labelText: 'අඩු කිරීම් (Kg)',
                  hintText: 'Water/Sack Weight',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.remove_circle_outline),
                  suffixText: 'Kg',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'අගයක් ඇතුළත් කරන්න (නැත්නම් 0 යොදන්න)';
                  if (double.tryParse(value) == null) return 'නිවැරදි අගයක් ඇතුළත් කරන්න';
                  return null;
                },
              ),
              const SizedBox(height: 40),

              // --- දත්ත සුරකින බොත්තම ---
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
    );
  }
}