import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Search සහ Pagination සඳහා අවශ්‍ය විචල්‍යයන්
  String _searchQuery = '';
  int _currentPage = 0;
  final int _rowsPerPage = 5;

  Future<void> _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      try {
        String refNumber = _refNumberController.text.trim();

        var querySnapshot = await FirebaseFirestore.instance
            .collection('Customers')
            .where('refNumber', isEqualTo: refNumber)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('මෙම ලියාපදිංචි අංකය දැනටමත් භාවිත කර ඇත!'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() { _isLoading = false; });
          }
          return; 
        }

        await FirebaseFirestore.instance.collection('Customers').add({
          'refNumber': refNumber,
          'name': _nameController.text.trim(),
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
            const SnackBar(content: Text('පාරිභෝගිකයා සාර්ථකව සුරකින ලදි!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('දෝෂයක්: $e')));
        }
      } finally {
        if (mounted) { setState(() { _isLoading = false; }); }
      }
    }
  }

  Future<void> _deleteCustomer(String docId, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('මකා දමන්නද?'),
        content: Text('$name පාරිභෝගිකයාව මකා දැමීමට ඔබට විශ්වාසද?'),
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
        await FirebaseFirestore.instance.collection('Customers').doc(docId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('සාර්ථකව මකා දමන ලදි!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('දෝෂයක්: $e')));
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('නව පාරිභෝගිකයෙකු ලියාපදිංචි කරන්න', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _refNumberController,
                  decoration: const InputDecoration(labelText: 'ලියාපදිංචි අංකය', border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers)),
                  validator: (value) => value == null || value.isEmpty ? 'අංකයක් ලබා දෙන්න' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'නම', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                  validator: (value) => value == null || value.isEmpty ? 'නම ඇතුළත් කරන්න' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'ලිපිනය', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
                  validator: (value) => value == null || value.isEmpty ? 'ලිපිනය ඇතුළත් කරන්න' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'දුරකථන අංකය', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                  keyboardType: TextInputType.phone,
                  validator: (value) => value == null || value.isEmpty ? 'දුරකථන අංකය ඇතුළත් කරන්න' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveCustomer,
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('දත්ත සුරකින්න', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 20),

          // Search Bar
          TextField(
            decoration: InputDecoration(
              labelText: 'පාරිභෝගිකයින් සොයන්න (නම හෝ අංකය)',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
                _currentPage = 0; // සෙවුමක් කළ විට නැවත පළමු පිටුවට යාම
              });
            },
          ),
          const SizedBox(height: 16),

          // Customer Table with Pagination
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('Customers').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('දැනට පාරිභෝගිකයින් නොමැත.')));
              }

              // 1. Search (Filter Data)
              var allDocs = snapshot.data!.docs;
              var filteredDocs = allDocs.where((doc) {
                String name = (doc['name'] ?? '').toString().toLowerCase();
                String ref = (doc['refNumber'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) || ref.contains(_searchQuery);
              }).toList();

              // 2. Pagination Logic
              int totalPages = (filteredDocs.length / _rowsPerPage).ceil();
              
              // පිටුවක් මකා දැමූ විට හිස් පිටුවක සිරවීම වැළැක්වීමට
              if (_currentPage >= totalPages && totalPages > 0) {
                _currentPage = totalPages - 1;
              }

              int startIndex = _currentPage * _rowsPerPage;
              int endIndex = startIndex + _rowsPerPage;
              if (endIndex > filteredDocs.length) {
                endIndex = filteredDocs.length;
              }

              var paginatedDocs = filteredDocs.isEmpty ? [] : filteredDocs.sublist(startIndex, endIndex);

              return Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.0),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.2), 
                        1: FlexColumnWidth(2.5), 
                        2: FlexColumnWidth(2.5), 
                        3: FlexColumnWidth(1.0), 
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1)),
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1)),
                          children: [
                            _buildTableHeader('අංකය'),
                            _buildTableHeader('නම'),
                            _buildTableHeader('දුරකථනය'),
                            _buildTableHeader(''),
                          ],
                        ),
                        if (paginatedDocs.isEmpty)
                          TableRow(
                            children: [
                              const SizedBox(),
                              const Padding(padding: EdgeInsets.all(16.0), child: Text('ගැළපෙන දත්ත නොමැත', textAlign: TextAlign.center)),
                              const SizedBox(),
                              const SizedBox(),
                            ]
                          ),
                        ...paginatedDocs.map((doc) {
                          return TableRow(
                            children: [
                              _buildTableCell(doc['refNumber'] ?? '', isBold: true, color: Theme.of(context).primaryColor),
                              _buildTableCell(doc['name']),
                              _buildTableCell(doc['phone']),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () => _deleteCustomer(doc.id, doc['name']),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  
                  // Pagination Controls (Next / Prev Buttons)
                  if (totalPages > 1) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, size: 16),
                          onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                        ),
                        Text(
                          'පිටුව ${_currentPage + 1} / $totalPages',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, size: 16),
                          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 13)),
    );
  }

  Widget _buildTableCell(String text, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 13, color: color)),
    );
  }
}