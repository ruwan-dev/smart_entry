import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OutstandingListScreen extends StatelessWidget {
  final List<Map<String, dynamic>> arrearsList;

  const OutstandingListScreen({super.key, required this.arrearsList});

  @override
  Widget build(BuildContext context) {
    final currencyF = NumberFormat('#,##0.00', 'en_US');

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('සම්පූර්ණ හිඟ මුදල් ලැයිස්තුව', style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
      ),
      body: arrearsList.isEmpty
          ? const Center(
              child: Text('කිසිදු හිඟ මුදලක් නොමැත 🎉', style: TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: arrearsList.length,
              itemBuilder: (context, index) {
                var arrear = arrearsList[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade50,
                      child: Text('${index + 1}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(arrear['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    trailing: Text(
                      'Rs. ${currencyF.format(arrear['amount'])}',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                );
              },
            ),
    );
  }
}