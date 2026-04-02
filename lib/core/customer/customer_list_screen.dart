import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/entries/daily_entry_form_screen.dart';
import '../billing/monthly_bill_screen.dart';
import 'customer_form_screen.dart'; 

class CustomerListScreen extends StatelessWidget {
  const CustomerListScreen({super.key});

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer List'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CustomerFormScreen()),
          );
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Customers').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No customers found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              
              // ආරක්ෂිතව Data ලබාගැනීම (Crash වීම වැළැක්වීමට)
              var data = doc.data() as Map<String, dynamic>; 

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Text(
                      data['refNumber'] ?? '', // ආරක්ෂිතයි
                      style: TextStyle(
                        color: Theme.of(context).primaryColor, 
                        fontSize: 12, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                  title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${data['phone'] ?? ''}\n${data['address'] ?? ''}'),
                  isThreeLine: true,
                  
                  trailing: PopupMenuButton<int>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 0) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DailyEntryFormScreen(
                              selectedDate: DateTime.now(),
                              customerId: doc.id,
                              customerName: data['name'] ?? '',
                              refNumber: data['refNumber'] ?? '',
                            ),
                          ),
                        );
                      } else if (value == 1) {
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
                      } else if (value == 2) {
                        _deleteCustomer(context, doc.id, data['name'] ?? '');
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 0,
                        child: Row(
                          children: [
                            Icon(Icons.add_chart, color: Colors.green),
                            SizedBox(width: 8),
                            Text('දෛනික සටහන'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 1,
                        child: Row(
                          children: [
                            Icon(Icons.receipt_long, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('මාසික බිල්පත'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 2,
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Text('මකා දමන්න'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}