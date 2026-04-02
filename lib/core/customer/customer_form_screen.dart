import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_entry/core/entries/daily_entries_screen.dart';
import '../billing/monthly_bill_screen.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _refNumberController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isLoading = false;
  String _searchQuery = '';

  Future<void> _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      try {
        String refNumber = _refNumberController.text.trim();
        String name = _nameController.text.trim();

        var querySnapshot = await FirebaseFirestore.instance
            .collection('Customers')
            .where('refNumber', isEqualTo: refNumber)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('මෙම යොමු අංකය දැනටමත් භාවිතයේ පවතී'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() { _isLoading = false; });
          }
          return; 
        }

        DocumentReference docRef = await FirebaseFirestore.instance.collection('Customers').add({
          'refNumber': refNumber,
          'name': name,
          'address': _addressController.text.trim(),
          'phone': _phoneController.text.trim(),
          'registeredAt': FieldValue.serverTimestamp(),
        });

        _refNumberController.clear();
        _nameController.clear();
        _addressController.clear();
        _phoneController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('පාරිභෝගිකයා සාර්ථකව සුරකින ලදී')),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DailyEntriesScreen(
                initialCustomerId: docRef.id,
                initialRefNumber: refNumber,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('දෝෂයකි: $e')));
        }
      } finally {
        if (mounted) { setState(() { _isLoading = false; }); }
      }
    }
  }

  Future<void> _deleteCustomer(BuildContext context, String docId, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('පාරිභෝගිකයා ඉවත් කරන්නද?'),
        content: Text('ඔබ ස්ථිරවම $name සහ ඔහුට/ඇයට අදාළ සියලුම තේ දළු හා අත්තිකාරම් සටහන් පද්ධතියෙන් ඉවත් කිරීමට අවශ්‍යද?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('නැත'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ඔව්, ඉවත් කරන්න', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      // Deletion progress එකක් පෙන්වීමට
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // 1. පාරිභෝගිකයාට අදාළ සියලුම Daily Entries (දෛනික සටහන්) ලබාගැනීම
        var entriesSnapshot = await FirebaseFirestore.instance
            .collection('DailyEntries')
            .where('customerId', isEqualTo: docId)
            .get();

        // 2. ලබාගත් සියලුම දෛනික සටහන් එකින් එක මකා දැමීම (Batch delete)
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in entriesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit(); // එකවර සියල්ල මකා දමයි

        // 3. අවසානයේ පාරිභෝගිකයාව මකා දැමීම
        await FirebaseFirestore.instance.collection('Customers').doc(docId).delete();

        if (context.mounted) {
          Navigator.pop(context); // Progress circle එක වැසීම
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('පාරිභෝගිකයා සහ අදාළ සියලුම සටහන් සාර්ථකව ඉවත් කරන ලදී'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Progress circle එක වැසීම
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('දෝෂයකි: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _refNumberController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('පාරිභෝගික ලියාපදිංචිය')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('අලුත් පාරිභෝගිකයෙකු ලියාපදිංචි කිරීම', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _refNumberController,
                    decoration: const InputDecoration(labelText: 'යොමු අංකය (Reference Number)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers)),
                    validator: (value) => value == null || value.isEmpty ? 'අවශ්‍ය වේ' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'නම', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                    validator: (value) => value == null || value.isEmpty ? 'අවශ්‍ය වේ' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'ලිපිනය', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
                    validator: (value) => value == null || value.isEmpty ? 'අවශ්‍ය වේ' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'දුරකථන අංකය', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                    keyboardType: TextInputType.phone,
                    validator: (value) => value == null || value.isEmpty ? 'අවශ්‍ය වේ' : null,
                  ),
                  const SizedBox(height: 24),
                  SLongButton(
                    onPressed: _isLoading ? null : _saveCustomer,
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('පාරිභෝගිකයා සුරකින්න', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 20),

            const Text('පාරිභෝගික ලැයිස්තුව', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'නම හෝ අංකය මගින් සොයන්න',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('Customers').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                var filteredDocs = snapshot.data!.docs.where((doc) {
                  // ආරක්ෂිතව Data ලබාගැනීම (Crash වීම වැළැක්වීමට)
                  var data = doc.data() as Map<String, dynamic>; 
                  String name = (data['name'] ?? '').toString().toLowerCase();
                  String ref = (data['refNumber'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || ref.contains(_searchQuery);
                }).toList();

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.0),
                      1: FlexColumnWidth(2.0),
                      2: FlexColumnWidth(1.6),
                      3: FlexColumnWidth(2.2),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade200)),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey.shade100),
                        children: [
                          _buildHeader('යොමුව'),
                          _buildHeader('නම'),
                          _buildHeader('දුරකථනය'),
                          _buildHeader('ක්‍රියා'),
                        ],
                      ),
                      ...filteredDocs.map((doc) {
                        // ආරක්ෂිතව Data ලබාගැනීම (Crash වීම වැළැක්වීමට)
                        var data = doc.data() as Map<String, dynamic>; 
                        
                        return TableRow(
                          children: [
                            _buildCell(data['refNumber'] ?? ''),
                            _buildCell(data['name'] ?? ''),
                            _buildCell(data['phone'] ?? ''),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.add_chart, color: Colors.green, size: 20),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DailyEntriesScreen(
                                            initialCustomerId: doc.id,
                                            initialRefNumber: data['refNumber'] ?? '',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.receipt_long, color: Colors.blue, size: 20),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => MonthlyBillScreen(
                                            customerId: doc.id,
                                            customerName: data['name'] ?? '',
                                            refNumber: data['refNumber'] ?? '',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    onPressed: () => _deleteCustomer(context, doc.id, data['name'] ?? ''),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }),
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

  Widget _buildHeader(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
    child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
  );

  Widget _buildCell(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
    child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
  );
}

class SLongButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const SLongButton({super.key, required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        ),
        child: child,
      ),
    );
  }
}