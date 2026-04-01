import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'bill_pdf_service.dart'; 

class MonthlyBillScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String refNumber;

  const MonthlyBillScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.refNumber,
  });

  @override
  State<MonthlyBillScreen> createState() => _MonthlyBillScreenState();
}

class _MonthlyBillScreenState extends State<MonthlyBillScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _monthlyBills = [];
  double fert1Price = 0, fert2Price = 0, teaPkt1Price = 0, teaPkt2Price = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      var globalDoc = await FirebaseFirestore.instance.collection('GlobalSettings').doc('prices').get();
      if (globalDoc.exists) {
        var data = globalDoc.data() as Map<String, dynamic>? ?? {};
        fert1Price = _parseDouble(data['fertilizer1Price']);
        fert2Price = _parseDouble(data['fertilizer2Price']);
        teaPkt1Price = _parseDouble(data['teaPacket1Price']);
        teaPkt2Price = _parseDouble(data['teaPacket2Price']);
      }

      var ratesSnap = await FirebaseFirestore.instance.collection('MonthlyRates').get();
      Map<String, Map<String, double>> monthlyRatesMap = {};
      for (var doc in ratesSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        monthlyRatesMap[doc.id] = {
          'teaRate': _parseDouble(data['teaRate']),
          'transportRate': _parseDouble(data['transportRate']),
        };
      }

      var entriesSnap = await FirebaseFirestore.instance
          .collection('DailyEntries')
          .where('customerId', isEqualTo: widget.customerId)
          .orderBy('date', descending: false) 
          .get();

      Map<String, List<QueryDocumentSnapshot>> entriesByMonth = {};
      for (var doc in entriesSnap.docs) {
        var data = doc.data() as Map<String, dynamic>? ?? {};
        String dateStr = data['date'] ?? ''; 
        if (dateStr.length >= 7) {
          String monthKey = dateStr.substring(0, 7); 
          if (!entriesByMonth.containsKey(monthKey)) {
            entriesByMonth[monthKey] = [];
          }
          entriesByMonth[monthKey]!.add(doc);
        }
      }

      List<Map<String, dynamic>> calculatedBills = [];
      double carriedForwardArrears = 0.0; 

      List<String> sortedMonthKeys = entriesByMonth.keys.toList()..sort();

      for (String monthKey in sortedMonthKeys) {
        List<QueryDocumentSnapshot> docs = entriesByMonth[monthKey]!;
        DateTime parsedDate = DateTime.parse('$monthKey-01');
        String monthName = DateFormat('MMMM').format(parsedDate); 
        String yearStr = parsedDate.year.toString();
        String rateDocId = '$yearStr-$monthName';

        double teaRate = monthlyRatesMap[rateDocId]?['teaRate'] ?? 0;
        double transportRate = monthlyRatesMap[rateDocId]?['transportRate'] ?? 0;

        double sumNetWeight = 0, sumAdvance = 0;
        double sumFert1 = 0, sumFert2 = 0, sumTeaPkt1 = 0, sumTeaPkt2 = 0;
        
        Map<String, Map<String, dynamic>> dailyData = {};

        for (var doc in docs) {
          var data = doc.data() as Map<String, dynamic>? ?? {};
          String date = (data['date'] ?? '').toString().substring(8);
          double netW = _parseDouble(data['netWeight']);
          double adv = _parseDouble(data['advanceAmount']);
          double f1 = _parseDouble(data['fertilizer1Qty']);
          double f2 = _parseDouble(data['fertilizer2Qty']);
          double tp1 = _parseDouble(data['teaPacket1Qty']);
          double tp2 = _parseDouble(data['teaPacket2Qty']);

          sumNetWeight += netW;
          sumAdvance += adv;
          sumFert1 += f1;
          sumFert2 += f2;
          sumTeaPkt1 += tp1;
          sumTeaPkt2 += tp2;

          if (!dailyData.containsKey(date)) {
            dailyData[date] = {'weight': 0.0, 'items': []};
          }
          
          dailyData[date]!['weight'] += netW;
          if (f1 > 0) dailyData[date]!['items'].add({'desc': 'පොහොර 01 (${f1.toStringAsFixed(0)})', 'amt': f1 * fert1Price});
          if (f2 > 0) dailyData[date]!['items'].add({'desc': 'පොහොර 02 (${f2.toStringAsFixed(0)})', 'amt': f2 * fert2Price});
          if (tp1 > 0) dailyData[date]!['items'].add({'desc': 'තේ පැකට් 01 (${tp1.toStringAsFixed(0)})', 'amt': tp1 * teaPkt1Price});
          if (tp2 > 0) dailyData[date]!['items'].add({'desc': 'තේ පැකට් 02 (${tp2.toStringAsFixed(0)})', 'amt': tp2 * teaPkt2Price});
          if (adv > 0) dailyData[date]!['items'].add({'desc': 'අත්තිකාරම්', 'amt': adv});
        }

        double grossIncome = sumNetWeight * teaRate;
        double transportCost = sumNetWeight * transportRate;
        double currentDeductions = (sumNetWeight * transportRate) + sumAdvance + (sumFert1 * fert1Price) + (sumFert2 * fert2Price) + (sumTeaPkt1 * teaPkt1Price) + (sumTeaPkt2 * teaPkt2Price);
        double previousArrears = carriedForwardArrears;
        double netPayable = grossIncome - (currentDeductions + previousArrears);

        if (netPayable < 0) carriedForwardArrears = netPayable.abs();
        else carriedForwardArrears = 0;

        List<String> sortedDates = dailyData.keys.toList()..sort();
        List<Map<String, dynamic>> tableRows = sortedDates.map((d) => {
          'date': d,
          'weight': dailyData[d]!['weight'],
          'items': dailyData[d]!['items']
        }).toList();

        calculatedBills.add({
          'displayMonth': '$monthName $yearStr',
          'teaRate': teaRate, // <--- Tea Rate එක මෙතන තියෙනවා
          'grossIncome': grossIncome,
          'totalDeductions': currentDeductions,
          'previousArrears': previousArrears,
          'netPayable': netPayable,
          'tableRows': tableRows,
          'transportCost': transportCost,
          'otherCosts': sumAdvance + (sumFert1 * fert1Price) + (sumFert2 * fert2Price) + (sumTeaPkt1 * teaPkt1Price) + (sumTeaPkt2 * teaPkt2Price),
        });
      }

      setState(() {
        _monthlyBills = calculatedBills.reversed.toList(); 
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(title: const Text('මාසික බිල්පත් වාර්තාව')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _monthlyBills.length,
            itemBuilder: (context, index) => _buildInvoiceCard(_monthlyBills[index]),
          ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> bill) {
    return Card(
      elevation: 4, margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        title: Text(bill['displayMonth'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text('ශුද්ධ ගෙවීම: Rs. ${bill['netPayable'].toStringAsFixed(2)}', style: TextStyle(color: bill['netPayable'] < 0 ? Colors.red : Colors.green.shade800, fontWeight: FontWeight.bold)),
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            child: Column(children: [
              const Text('NALEEN SURANGA', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Text('Tea Purchasing & Suppliers', style: TextStyle(fontSize: 10)),
              const Divider(height: 30),
              
              Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1), 2: FlexColumnWidth(3.5), 3: FlexColumnWidth(1.5)},
                children: [
                  TableRow(decoration: BoxDecoration(color: Colors.grey.shade100), children: const [_Cell('දිනය', b: true), _Cell('දළු (KG)', b: true), _Cell('විස්තරය', b: true), _Cell('මුදල', b: true)]),
                  ...(bill['tableRows'] as List).map((row) {
                    List<dynamic> items = row['items'];
                    return TableRow(
                      children: [
                        _Cell(row['date']),
                        _Cell(row['weight'] > 0 ? row['weight'].toStringAsFixed(1) : '-'),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: items.isEmpty 
                            ? [const _InternalCell('-')] 
                            : items.map((i) => _InternalCell(i['desc'], align: TextAlign.left)).toList(),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: items.isEmpty 
                            ? [const _InternalCell('-')] 
                            : items.map((i) => _InternalCell(i['amt'].toStringAsFixed(2), align: TextAlign.right, color: Colors.red)).toList(),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              
              const SizedBox(height: 25),
              // --- මෙතනට Tea Rate එක එකතු කළා ---
              _row('තේ දළු මිල (1kg)', 'Rs. ${bill['teaRate'].toStringAsFixed(2)}', b: false), 
              _row('මුළු දළු ආදායම', 'Rs. ${bill['grossIncome'].toStringAsFixed(2)}', b: true),
              _row('අඩු කිරීම් වල එකතුව', '- Rs. ${bill['totalDeductions'].toStringAsFixed(2)}', c: Colors.red, b: true),
              if (bill['previousArrears'] > 0) _row('පසුගිය හිඟ මුදල', '- Rs. ${bill['previousArrears'].toStringAsFixed(2)}', c: Colors.red),
              const Divider(thickness: 2),
              _row('ශුද්ධ ගෙවීම', 'Rs. ${bill['netPayable'].toStringAsFixed(2)}', b: true, fontSize: 18, c: bill['netPayable'] < 0 ? Colors.red : Colors.green.shade900),
              
              const Divider(height: 30),
              const Center(child: Text('Powered by OrbitView Innovations', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity, height: 50, 
                child: ElevatedButton.icon(
                  onPressed: () {
                    BillPdfService.generateMonthlyInvoice(
                      bill: bill,
                      customerName: widget.customerName,
                      refNumber: widget.refNumber,
                    );
                  }, 
                  icon: const Icon(Icons.print), 
                  label: const Text('INVOICE එක මුද්‍රණය කරන්න', style: TextStyle(fontWeight: FontWeight.bold)), 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white)
                )
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _row(String l, String v, {bool b = false, Color? c, double fontSize = 14}) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(fontSize: fontSize, fontWeight: b ? FontWeight.bold : FontWeight.normal)), Text(v, style: TextStyle(fontSize: fontSize, fontWeight: b ? FontWeight.bold : FontWeight.normal, color: c))]));
}

class _InternalCell extends StatelessWidget {
  final String text; final TextAlign align; final Color? color;
  const _InternalCell(this.text, {this.align = TextAlign.center, this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5))),
    child: Text(text, textAlign: align, style: TextStyle(fontSize: 11, color: color)),
  );
}

class _Cell extends StatelessWidget {
  final String text; final bool b;
  const _Cell(this.text, {this.b = false});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(10), child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: b ? FontWeight.bold : FontWeight.normal)));
}