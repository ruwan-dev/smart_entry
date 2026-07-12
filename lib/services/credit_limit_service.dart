import 'package:cloud_firestore/cloud_firestore.dart';

class CreditLimitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // පසුගිය මාස 3ක සාමාන්‍ය Net Weight දළු ප්‍රමාණය ලබා ගැනීම
  Future<double> getAverageTeaLeaves(String customerId) async {
    try {
      // අද සිට දින 90 කට පෙර දිනය
      DateTime threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));

      // 'tea_entries' collection එකෙන් අදාළ පාරිභෝගිකයාගේ පසුගිය මාස 3ක දත්ත ලබා ගැනීම
      QuerySnapshot snapshot = await _firestore
          .collection('tea_entries') 
          .where('customerId', isEqualTo: customerId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(threeMonthsAgo))
          .get();

      if (snapshot.docs.isEmpty) {
        return 0.0; // දත්ත නොමැති නම් 0 ක් return කරයි
      }

      double totalNetWeight = 0.0;

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // 'netWeight' යනු දළු කිලෝ ගණන save වන field එකයි
        // int හෝ double ලෙස දත්ත පැමිණිය හැකි බැවින් ආරක්ෂිතව .toDouble() භාවිතා කිරීම
        totalNetWeight += (data['netWeight'] ?? 0).toDouble(); 
      }

      // මාස 3 ක සාමාන්‍යය සෙවීමට 3 න් බෙදීම
      double monthlyAverage = totalNetWeight / 3;
      return monthlyAverage;

    } catch (e) {
      throw Exception('දත්ත ලබා ගැනීමේදී දෝෂයක් මතු විය: $e');
    }
  }
}