import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // New controller for the Reference Number
  final TextEditingController _refNumberController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isLoading = false;

  Future<void> _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String refNumber = _refNumberController.text.trim();

        // 1. Check if the Reference Number already exists in the database
        var querySnapshot = await FirebaseFirestore.instance
            .collection('Customers')
            .where('refNumber', isEqualTo: refNumber)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // If a document with this number exists, show an error and stop saving
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('මෙම ලියාපදිංචි අංකය දැනටමත් භාවිත කර ඇත! කරුණාකර වෙනත් අංකයක් ලබා දෙන්න.'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() {
              _isLoading = false;
            });
          }
          return; // Stop execution here
        }

        // 2. If the number is unique, save the data to Firestore
        await FirebaseFirestore.instance.collection('Customers').add({
          'refNumber': refNumber,
          'name': _nameController.text.trim(),
          'address': _addressController.text.trim(),
          'phone': _phoneController.text.trim(),
          'registeredAt': FieldValue.serverTimestamp(),
        });

        // Clear the form after successful save
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
    _refNumberController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            const Text(
              'නව පාරිභෝගිකයෙකු ලියාපදිංචි කරන්න',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Reference Number Field (New)
            TextFormField(
              controller: _refNumberController,
              decoration: const InputDecoration(
                labelText: 'ලියාපදිංචි අංකය (Ref Number)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'කරුණාකර ලියාපදිංචි අංකයක් ලබා දෙන්න';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Name Field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'පාරිභෝගිකයාගේ නම',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'කරුණාකර නම ඇතුළත් කරන්න';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Address Field
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'ලිපිනය',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'කරුණාකර ලිපිනය ඇතුළත් කරන්න';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Phone Field
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'දුරකථන අංකය',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'කරුණාකර දුරකථන අංකය ඇතුළත් කරන්න';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            // Save Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveCustomer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('දත්ත සුරකින්න', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}