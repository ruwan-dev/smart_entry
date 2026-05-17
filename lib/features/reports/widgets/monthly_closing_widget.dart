import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MonthlyClosingWidget extends StatefulWidget {
  const MonthlyClosingWidget({super.key});

  @override
  State<MonthlyClosingWidget> createState() => _MonthlyClosingWidgetState();
}

class _MonthlyClosingWidgetState extends State<MonthlyClosingWidget> {
  final int _currentYear = DateTime.now().year;
  late int _selectedMonth;

  bool _isCalculating = false;
  bool _isAlreadyFinalized = false;
  bool _ratesMissing = false;
  List<Map<String, dynamic>> _billingList = [];
  Map<String, dynamic>? _monthlySummaryData;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now().month;
    _checkStatusAndCalculate();
  }

  Future<void> _checkStatusAndCalculate() async {
    setState(() {
      _isCalculating = true;
      _billingList = [];
      _isAlreadyFinalized = false;
      _ratesMissing = false;
      _monthlySummaryData = null;
    });

    try {
      String monthName = DateFormat('MMMM').format(DateTime(_currentYear, _selectedMonth));
      String displayMonth = "$_currentYear $monthName";
      String ratesDocId = "$_currentYear-$monthName";

      var ratesDoc = await FirebaseFirestore.instance.collection('MonthlyRates').doc(ratesDocId).get();
      if (!ratesDoc.exists) {
        setState(() { _ratesMissing = true; _isCalculating = false; });
        return;
      }

      var summaryDoc = await FirebaseFirestore.instance.collection('MonthlySummaries').doc(ratesDocId).get();
      if (summaryDoc.exists) {
        _isAlreadyFinalized = true;
        _monthlySummaryData = summaryDoc.data();
      }

      var priceDoc = await FirebaseFirestore.instance.collection('GlobalSettings').doc('prices').get();
      var pData = priceDoc.data() ?? {};
      
      double teaRate = (ratesDoc.data()?['teaRate'] ?? 0).toDouble();
      double transRate = (ratesDoc.data()?['transportRate'] ?? 0).toDouble();

      var customers = await FirebaseFirestore.instance.collection('Customers').get();
      List<Map<String, dynamic>> results = [];

      String searchKey = "$_currentYear-${_selectedMonth.toString().padLeft(2, '0')}";
      for (var customer in customers.docs) {
        var entries = await FirebaseFirestore.instance.collection('DailyEntries')
            .where('customerId', isEqualTo: customer.id).get();
        
        var monthlyEntries = entries.docs.where((doc) => doc['date'].toString().startsWith(searchKey)).toList();
        if (monthlyEntries.isEmpty) continue;

        // **දින අනුපිළිවෙලට (Ascending) සෝට් කිරීම**
        monthlyEntries.sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));

        double totalW = 0, totalAdv = 0, f1Q = 0, f2Q = 0, t1Q = 0, t2Q = 0;
        List<Map<String, dynamic>> rows = [];
        for (var doc in monthlyEntries) {
          var d = doc.data();
          double w = (d['netWeight'] ?? 0).toDouble();
          double adv = (d['advanceAmount'] ?? 0).toDouble();
          double f1q = (d['fertilizer1Qty'] ?? 0).toDouble();
          double f2q = (d['fertilizer2Qty'] ?? 0).toDouble();
          double t1q = (d['teaPacket1Qty'] ?? 0).toDouble();
          double t2q = (d['teaPacket2Qty'] ?? 0).toDouble();

          totalW += w; totalAdv += adv;
          f1Q += f1q; f2Q += f2q; t1Q += t1q; t2Q += t2q;

          List<Map<String, dynamic>> items = [];
          if (adv > 0) items.add({'desc': 'Advance', 'qty': 0, 'uPrice': 0, 'amt': adv});
          if (f1q > 0) items.add({'desc': 'Fert 01', 'qty': f1q, 'uPrice': (pData['fertilizer1Price'] ?? 0).toDouble(), 'amt': f1q * (pData['fertilizer1Price'] ?? 0)});
          if (f2q > 0) items.add({'desc': 'Fert 02', 'qty': f2q, 'uPrice': (pData['fertilizer2Price'] ?? 0).toDouble(), 'amt': f2q * (pData['fertilizer2Price'] ?? 0)});
          if (t1q > 0) items.add({'desc': 'Tea Pkt 01', 'qty': t1q, 'uPrice': (pData['teaPacket1Price'] ?? 0).toDouble(), 'amt': t1q * (pData['teaPacket1Price'] ?? 0)});
          if (t2q > 0) items.add({'desc': 'Tea Pkt 02', 'qty': t2q, 'uPrice': (pData['teaPacket2Price'] ?? 0).toDouble(), 'amt': t2q * (pData['teaPacket2Price'] ?? 0)});

          rows.add({'date': d['date'], 'weight': w, 'items': items});
        }

        double gross = totalW * teaRate;
        double trans = totalW * transRate;
        double other = totalAdv + (f1Q * (pData['fertilizer1Price'] ?? 0)) + (f2Q * (pData['fertilizer2Price'] ?? 0)) + (t1Q * (pData['teaPacket1Price'] ?? 0)) + (t2Q * (pData['teaPacket2Price'] ?? 0));

        results.add({
          'customerId': customer.id, 'name': customer['name'], 'ref': customer['refNumber'],
          'bill': {
            'displayMonth': displayMonth, 'teaRate': teaRate, 'grossIncome': gross,
            'transportCost': trans, 'otherCosts': other, 'totalDeductions': trans + other,
            'netPayable': gross - (trans + other), 'tableRows': rows,
            'advTotal': totalAdv, 'f1Qty': f1Q, 'f1Total': f1Q * (pData['fertilizer1Price'] ?? 0),
            'f2Qty': f2Q, 'f2Total': f2Q * (pData['fertilizer2Price'] ?? 0),
            't1Qty': t1Q, 't1Total': t1Q * (pData['teaPacket1Price'] ?? 0),
            't2Qty': t2Q, 't2Total': t2Q * (pData['teaPacket2Price'] ?? 0),
          },
          'isFinalized': _isAlreadyFinalized,
        });
      }

      results.sort((a, b) => (int.tryParse(a['ref'].toString()) ?? 0).compareTo(int.tryParse(b['ref'].toString()) ?? 0));
      setState(() { _billingList = results; _isCalculating = false; });
    } catch (e) { setState(() => _isCalculating = false); }
  }

  Future<void> _finalizeAndGeneratePDF() async {
    if (_billingList.isEmpty) return;
    setState(() => _isCalculating = true);
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.courierPrimeRegular();

    double grandWeight = 0, grandGross = 0, grandTrans = 0, grandAdv = 0, grandF1Q = 0, grandF1A = 0, grandF2Q = 0, grandF2A = 0, grandT1Q = 0, grandT1A = 0, grandT2Q = 0, grandT2A = 0, grandNet = 0;
    double grandPositiveNet = 0, grandNegativeNet = 0;

    try {
      for (var item in _billingList) {
        var b = item['bill'];
        double net = b['netPayable'];
        if (net > 0) grandPositiveNet += net; else grandNegativeNet += net.abs();

        grandGross += b['grossIncome']; grandTrans += b['transportCost']; grandNet += net;
        grandAdv += b['advTotal']; grandF1Q += b['f1Qty']; grandF1A += b['f1Total'];
        grandF2Q += b['f2Qty']; grandF2A += b['f2Total']; grandT1Q += b['t1Qty']; grandT1A += b['t1Total'];
        grandT2Q += b['t2Qty']; grandT2A += b['t2Total'];
        for (var r in b['tableRows']) grandWeight += r['weight'];

        if (item['isFinalized'] == false) {
          String monthKey = b['displayMonth'].toString().replaceAll(' ', '-');
          await FirebaseFirestore.instance.collection('FinalizedBills').doc("${item['customerId']}_$monthKey").set({
            'customerId': item['customerId'], 'customerName': item['name'], 'refNumber': item['ref'],
            'billData': b, 'finalizedAt': FieldValue.serverTimestamp(),
          });
        }
        pdf.addPage(pw.Page(build: (pw.Context context) => _buildPdfBill(item, font)));
      }

      String summaryId = "$_currentYear-${DateFormat('MMMM').format(DateTime(_currentYear, _selectedMonth))}";
      await FirebaseFirestore.instance.collection('MonthlySummaries').doc(summaryId).set({
        'totalWeight': grandWeight, 'totalGross': grandGross, 'totalTransport': grandTrans,
        'totalAdvance': grandAdv, 'totalF1Qty': grandF1Q, 'totalF1Amt': grandF1A,
        'totalF2Qty': grandF2Q, 'totalF2Amt': grandF2A, 'totalT1Qty': grandT1Q, 'totalT1Amt': grandT1A,
        'totalT2Qty': grandT2Q, 'totalT2Amt': grandT2A, 'totalNet': grandNet,
        'totalPositiveNet': grandPositiveNet, 'totalNegativeNet': grandNegativeNet,
        'finalizedAt': FieldValue.serverTimestamp(),
      });

      await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Monthly_Bills.pdf');
      _checkStatusAndCalculate();
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
    finally { setState(() => _isCalculating = false); }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildMonthSelector(),
          const SizedBox(height: 12),
          _buildActionCard(),
          if (_isAlreadyFinalized && _monthlySummaryData != null) _buildSummaryCard(),
        ],
      ),
    );
  }

  // --- UI Components ---
  Widget _buildMonthSelector() {
    List<String> months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, size: 20, color: Colors.indigo),
            const SizedBox(width: 15),
            Text("$_currentYear", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(width: 10),
            const Text("|", style: TextStyle(color: Colors.grey)),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedMonth,
                  isExpanded: true,
                  items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(months[i]))),
                  onChanged: (val) { setState(() => _selectedMonth = val!); _checkStatusAndCalculate(); },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard() {
    bool hasData = _billingList.isNotEmpty;
    Color color = _isAlreadyFinalized ? Colors.green.shade800 : (_ratesMissing ? Colors.orange.shade800 : Colors.indigo.shade900);
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_isAlreadyFinalized ? Icons.verified : (_ratesMissing ? Icons.warning : Icons.account_balance_wallet), color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isAlreadyFinalized ? "ගිණුම් පියවා අවසන්. වාර්තා නැවත නැරඹිය හැක." : (_ratesMissing ? "Rates ඇතුළත් කර නැත." : "මාසික ගිණුම් පියවා වාර්තා සකසන්න."),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isCalculating)
            const Column(children: [CircularProgressIndicator(color: Colors.white), SizedBox(height: 10), Text("දත්ත සකසමින් පවතිනවා...", style: TextStyle(color: Colors.white, fontSize: 12))])
          else
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: (!hasData && !_isAlreadyFinalized) ? null : _finalizeAndGeneratePDF,
                icon: Icon(_isAlreadyFinalized ? Icons.picture_as_pdf : Icons.save_alt, size: 20),
                label: Text(_isAlreadyFinalized ? "VIEW ALL BILLS PDF" : "FINALIZE & SAVE ALL"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    var s = _monthlySummaryData!;
    return Container(
      margin: const EdgeInsets.all(15), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("මාසික ව්‍යාපාරික සාරාංශය", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
          const Divider(height: 20),
          _row("මුළු දළු බර (Total Weight)", "${(s['totalWeight'] ?? 0).toStringAsFixed(1)} Kg"),
          _row("මුළු ආදායම (Gross Income)", "Rs. ${(s['totalGross'] ?? 0).toStringAsFixed(2)}"),
          const SizedBox(height: 12),
          const Row(children: [
            Expanded(flex: 4, child: Text("Breakdown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.redAccent))),
            Expanded(flex: 2, child: Text("Qty", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.redAccent))),
            Expanded(flex: 3, child: Text("Amount", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.redAccent))),
          ]),
          const Divider(),
          _itemRow("Advance", "-", s['totalAdvance']),
          _itemRow("Fertilizer 01", s['totalF1Qty'], s['totalF1Amt']),
          _itemRow("Fertilizer 02", s['totalF2Qty'], s['totalF2Amt']),
          _itemRow("Tea Pkt 01", s['totalT1Qty'], s['totalT1Amt']),
          _itemRow("Tea Pkt 02", s['totalT2Qty'], s['totalT2Amt']),
          _itemRow("Transport", "-", s['totalTransport']),
          const Divider(height: 25),
          const Text("Payments Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)),
          _row("ගෙවීමට ඇති (+) ", "Rs. ${(s['totalPositiveNet'] ?? 0).toStringAsFixed(2)}", color: Colors.blue.shade900),
          _row("අයවීමට ඇති (-) ", "Rs. ${(s['totalNegativeNet'] ?? 0).toStringAsFixed(2)}", color: Colors.red.shade900),
          const Divider(height: 20),
          _row("ශුද්ධ ලාභ/අලාභය", "Rs. ${(s['totalNet'] ?? 0).toStringAsFixed(2)}", isBold: true),
        ],
      ),
    );
  }

  Widget _row(String label, String val, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? (isBold ? Colors.green.shade900 : Colors.black))),
        ],
      ),
    );
  }

  Widget _itemRow(String label, dynamic qty, dynamic amt) {
    String qtyStr = (qty is String) ? qty : (qty > 0 ? qty.toStringAsFixed(0) : "-");
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(flex: 4, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(flex: 2, child: Text(qtyStr, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
        Expanded(flex: 3, child: Text("Rs. ${(amt ?? 0).toStringAsFixed(2)}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
      ]),
    );
  }

  // --- PDF Build Logic (Width 67 - NAILED ALIGNMENT) ---
  pw.Widget _buildPdfBill(Map<String, dynamic> item, pw.Font font) {
    var b = item['bill'];
    double totalW = 0;
    for (var r in b['tableRows']) totalW += (r['weight'] ?? 0);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(child: pw.Text('NALEEN SURANGA', style: pw.TextStyle(font: font, fontSize: 14, fontWeight: pw.FontWeight.bold))),
        pw.Center(child: pw.Text('Authorized Green Dealer - Gangoda, Rakwana', style: pw.TextStyle(font: font, fontSize: 9))),
        pw.Center(child: pw.Text('Tel: 0713444934 / 0758258544', style: pw.TextStyle(font: font, fontSize: 9))),
        pw.Text('=' * 67, style: pw.TextStyle(font: font)),
        pw.Text('Name : ${item['name'].toString().padRight(35)} Ref: ${item['ref']}', style: pw.TextStyle(font: font, fontSize: 10)),
        pw.Text('Month: ${b['displayMonth']}', style: pw.TextStyle(font: font, fontSize: 10)),
        pw.Text('=' * 67, style: pw.TextStyle(font: font)),
        // Header: Day(5), Description(22), Qty(12), Price(14), Total(14) = 67
        pw.Text('Day  Description            Qty          Price            Total', style: pw.TextStyle(font: font, fontSize: 9)),
        pw.Text('---  --------------------  ----------  ------------  --------------', style: pw.TextStyle(font: font, fontSize: 9)),
        ... (b['tableRows'] as List).map((row) {
          String day = row['date'].toString().split('-').last;
          double w = (row['weight'] ?? 0.0).toDouble();
          List items = row['items'] ?? [];
          if (w <= 0 && items.isEmpty) return pw.SizedBox();
          
          return pw.Column(children: [
            if (w > 0) 
              pw.Text('${day.padRight(5)}${'Tea Leaves'.padRight(22)}${(w.toStringAsFixed(1) + " Kg").padLeft(12)}${b['teaRate'].toStringAsFixed(2).padLeft(14)}${(w * b['teaRate']).toStringAsFixed(2).padLeft(14)}', style: pw.TextStyle(font: font, fontSize: 9)),
            
            ... items.map((it) => pw.Text(
              '${(w > 0 ? "" : day).padRight(5)}${it['desc'].toString().padRight(22)}${(it['qty'] > 0 ? it['qty'].toStringAsFixed(0) : "-").padLeft(12)}${(it['uPrice'] > 0 ? it['uPrice'].toStringAsFixed(2) : "-").padLeft(14)}${it['amt'].toStringAsFixed(2).padLeft(14)}', 
              style: pw.TextStyle(font: font, fontSize: 9)
            )),
            pw.Text('-' * 67, style: pw.TextStyle(font: font, fontSize: 8)),
          ]);
        }).toList(),
        pw.SizedBox(height: 5),
        // Summary Row: Label(53) + Value(14) = 67 (දැන් උඩ Table එකේ Total Column එකට හරියටම Align වෙනවා)
        _pdfSumRow('Total Tea Leaves Weight', '${totalW.toStringAsFixed(1)} Kg', font),
        _pdfSumRow('Gross Income (Tea)', b['grossIncome'].toStringAsFixed(2), font),
        _pdfSumRow('Transport Deductions', '-${b['transportCost'].toStringAsFixed(2)}', font),
        _pdfSumRow('Other Deductions', '-${b['otherCosts'].toStringAsFixed(2)}', font),
        pw.Text(' ' * 53 + '-' * 14, style: pw.TextStyle(font: font)),
        _pdfSumRow('NET PAYABLE (Rs.)', b['netPayable'].toStringAsFixed(2), font, bold: true),
        pw.Text('=' * 67, style: pw.TextStyle(font: font)),
      ],
    );
  }

  pw.Widget _pdfSumRow(String label, String val, pw.Font font, {bool bold = false}) {
    return pw.Text(label.padRight(53) + val.padLeft(14), style: pw.TextStyle(font: font, fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal));
  }
}