import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerListScreen extends StatelessWidget {
  const CustomerListScreen({super.key});

  Future<void> _deleteCustomer(BuildContext context, String docId, String name) async {
    // මකා දැමීමට පෙර තහවුරු කිරීමක් ලබා ගැනීම
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('මකා දමන්නද?'),
        content: Text('$name පාරිභෝගිකයාව මකා දැමීමට ඔබට විශ්වාසද?'),
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
        await FirebaseFirestore.instance.collection('Customers').doc(docId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('පාරිභෝගිකයාව සාර්ථකව මකා දමන ලදි!')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('දෝෂයක් මතු විය: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('පාරිභෝගික ලැයිස්තුව'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Customers').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('දැනට පාරිභෝගිකයින් කිසිවෙකු නොමැත.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Text(
                      doc['refNumber'] ?? '',
                      style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(doc['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${doc['phone']}\n${doc['address']}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteCustomer(context, doc.id, doc['name']),
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