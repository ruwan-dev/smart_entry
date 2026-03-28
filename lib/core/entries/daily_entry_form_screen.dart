import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DailyEntryFormScreen extends StatefulWidget {
  final DateTime selectedDate;

  const DailyEntryFormScreen({super.key, required this.selectedDate});

  @override
  State<DailyEntryFormScreen> createState() => _DailyEntryFormScreenState();
}

class _DailyEntryFormScreenState extends State<DailyEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  
  final TextEditingController _grossWeightController = TextEditingController();
  final TextEditingController _deductionController = TextEditingController(text: '0');
  
  bool _isLoading = false;

  Future<void> _saveEntry() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCustomerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('කරුණාකර පාරිභෝගිකයෙකු තෝරන්න')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        double grossWeight = double.parse(_grossWeightController.text.trim());
        double deductions = double.parse(_deductionController.text.trim());
        double netWeight = grossWeight - deductions;

        // Save to Firebase DailyEntries collection
        await FirebaseFirestore.instance.collection('DailyEntries').add({
          'customerId': _selectedCustomerId,
          'customerName': _selectedCustomerName,
          'date': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
          'timestamp': widget.selectedDate,
          'grossWeight': grossWeight,
          'deductions': deductions,
          'netWeight': netWeight,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pop(context); // සාර්ථක වූ පසු පෙර පිටුවට යාම
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('දෛනික සටහන සාර්ථකව සුරකින ලදි!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('දෝෂයක් මතු විය: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'දෛනික තේ දළු විස්තර ඇතුළත් කරන්න',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // Customer Dropdown
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('Customers').orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text('පාරිභෝගිකයින් නොමැත. කරුණාකර පළමුව ලියාපදිංචි කරන්න.', 
                      style: TextStyle(color: Colors.red));
                  }

                  List<DropdownMenuItem<String>> customerItems = snapshot.data!.docs.map((doc) {
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(doc['name']),
                    );
                  }).toList();

                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'පාරිභෝගිකයා තෝරන්න',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    value: _selectedCustomerId,
                    items: customerItems,
                    onChanged: (value) {
                      setState(() {
                        _selectedCustomerId = value;
                        var selectedDoc = snapshot.data!.docs.firstWhere((doc) => doc.id == value);
                        _selectedCustomerName = selectedDoc['name'];
                      });
                    },
                    validator: (value) => value == null ? 'අත්‍යවශ්‍යයි' : null,
                  );
                },
              ),
              const SizedBox(height: 20),
              
              // Gross Weight Field
              TextFormField(
                controller: _grossWeightController,
                decoration: const InputDecoration(
                  labelText: 'තේ දළු බර (Kg)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.scale),
                  suffixText: 'Kg',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'කරුණාකර බර ඇතුළත් කරන්න';
                  }
                  if (double.tryParse(value) == null) {
                    return 'නිවැරදි අගයක් ඇතුළත් කරන්න';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Deductions Field
              TextFormField(
                controller: _deductionController,
                decoration: const InputDecoration(
                  labelText: 'අඩු කිරීම් (Kg)',
                  hintText: 'වතුර හෝ ගෝනි බර',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.remove_circle_outline),
                  suffixText: 'Kg',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'අගයක් ඇතුළත් කරන්න (නැත්නම් 0 යොදන්න)';
                  }
                  if (double.tryParse(value) == null) {
                    return 'නිවැරදි අගයක් ඇතුළත් කරන්න';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('දත්ත සුරකින්න', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}