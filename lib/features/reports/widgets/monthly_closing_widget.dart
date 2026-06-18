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

      int prevMonth = _selectedMonth - 1;
      int prevYear = _currentYear;
      if (prevMonth == 0) {
        prevMonth = 12;
        prevYear = _currentYear - 1;
      }
      String prevMonthName = DateFormat('MMMM').format(DateTime(prevYear, prevMonth));
      String prevMonthKey = "$prevYear-$prevMonthName"; 

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

        double lastMonthArrears = 0.0;
        var prevBillDoc = await FirebaseFirestore.instance
            .collection('FinalizedBills')
            .doc("${customer.id}_$prevMonthKey")
            .get();

        if (prevBillDoc.exists) {
          var prevBillData = prevBillDoc.data()?['billData'] ?? {};
          double prevNetPayable = (prevBillData['netPayable'] ?? 0.0).toDouble();
          if (prevNetPayable < 0) {
            lastMonthArrears = prevNetPayable.abs();
          }
        }

        double gross = totalW * teaRate;
        double trans = totalW * transRate;
        double other = totalAdv + (f1Q * (pData['fertilizer1Price'] ?? 0)) + (f2Q * (pData['fertilizer2Price'] ?? 0)) + (t1Q * (pData['teaPacket1Price'] ?? 0)) + (t2Q * (pData['teaPacket2Price'] ?? 0));

        results.add({
          'customerId': customer.id, 'name': customer['name'], 'ref': customer['refNumber'],
          'bill': {
            'displayMonth': displayMonth, 'teaRate': teaRate, 'grossIncome': gross,
            'transportCost': trans, 'otherCosts': other, 
            'arrears': lastMonthArrears, 
            'totalDeductions': trans + other + lastMonthArrears, 
            'netPayable': gross - (trans + other + lastMonthArrears), 
            'tableRows': rows,
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

    try {
      String monthName = DateFormat('MMMM').format(DateTime(_currentYear, _selectedMonth));
      String ratesDocId = "$_currentYear-$monthName";

      double totalWeight = 0, totalGross = 0, totalAdvance = 0;
      double totalF1Qty = 0, totalF1Amt = 0, totalF2Qty = 0, totalF2Amt = 0;
      double totalT1Qty = 0, totalT1Amt = 0, totalT2Qty = 0, totalT2Amt = 0;
      double totalTransport = 0, totalPositiveNet = 0, totalNegativeNet = 0, totalNet = 0;

      for (var item in _billingList) {
        var b = item['bill'];
        
        if (item['isFinalized'] == false) {
          String monthKey = b['displayMonth'].toString().replaceAll(' ', '-');
          await FirebaseFirestore.instance.collection('FinalizedBills').doc("${item['customerId']}_$monthKey").set({
            'customerId': item['customerId'], 'customerName': item['name'], 'refNumber': item['ref'],
            'billData': b, 'finalizedAt': FieldValue.serverTimestamp(),
          });
        }
        
        double tw = 0;
        for (var r in b['tableRows']) tw += (r['weight'] ?? 0);
        totalWeight += tw;
        totalGross += (b['grossIncome'] ?? 0);
        totalAdvance += (b['advTotal'] ?? 0);
        totalF1Qty += (b['f1Qty'] ?? 0); totalF1Amt += (b['f1Total'] ?? 0);
        totalF2Qty += (b['f2Qty'] ?? 0); totalF2Amt += (b['f2Total'] ?? 0);
        totalT1Qty += (b['t1Qty'] ?? 0); totalT1Amt += (b['t1Total'] ?? 0);
        totalT2Qty += (b['t2Qty'] ?? 0); totalT2Amt += (b['t2Total'] ?? 0);
        totalTransport += (b['transportCost'] ?? 0);
        
        double net = (b['netPayable'] ?? 0);
        totalNet += net;
        if (net > 0) totalPositiveNet += net;
        else totalNegativeNet += net.abs();

        pdf.addPage(
          pw.Page(
            // 💡 Landscape ලෙස ලබා දීම: පළල 21.07 CM, උස 13.08 CM
            pageFormat: PdfPageFormat(21.07 * PdfPageFormat.cm, 13.08 * PdfPageFormat.cm), 
            // 💡 උඩ සහ යට margin එක තවත් අඩු කර ඇත.
            margin: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 10), 
            build: (pw.Context context) => _buildPdfBill(item, font),
          ),
        );
      }

      if (!_isAlreadyFinalized) {
        await FirebaseFirestore.instance.collection('MonthlySummaries').doc(ratesDocId).set({
          'month': ratesDocId,
          'totalWeight': totalWeight,
          'totalGross': totalGross,
          'totalAdvance': totalAdvance,
          'totalF1Qty': totalF1Qty, 'totalF1Amt': totalF1Amt,
          'totalF2Qty': totalF2Qty, 'totalF2Amt': totalF2Amt,
          'totalT1Qty': totalT1Qty, 'totalT1Amt': totalT1Amt,
          'totalT2Qty': totalT2Qty, 'totalT2Amt': totalT2Amt,
          'totalTransport': totalTransport,
          'totalPositiveNet': totalPositiveNet,
          'totalNegativeNet': totalNegativeNet,
          'totalNet': totalNet,
          'finalizedAt': FieldValue.serverTimestamp(),
        });
      }

      String customFileName = "${_currentYear}_${monthName}_Monthly_Bills.pdf";
      await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: customFileName);
      
      _checkStatusAndCalculate();
    } catch (e) { 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); 
    } finally { 
      setState(() => _isCalculating = false); 
    }
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

  // ===========================================================================
  // 🌟 FULLY OPTIMIZED LANDSCAPE PDF LAYOUT (Width 21.07cm x Height 13.08cm)
  // ===========================================================================
  pw.Widget _buildPdfBill(Map<String, dynamic> item, pw.Font font) {
    var b = item['bill'];

    Map<int, double> dailyWeights = {};
    List<String> advanceRecords = [];
    double totalW = 0;

    for (var row in b['tableRows']) {
      int day = int.parse(row['date'].toString().split('-').last);
      double w = (row['weight'] ?? 0.0).toDouble();
      if (w > 0) {
        dailyWeights[day] = (dailyWeights[day] ?? 0.0) + w;
        totalW += w;
      }

      List items = row['items'] ?? [];
      for (var it in items) {
        if (it['desc'] == 'Advance' && it['amt'] > 0) {
          advanceRecords.add('D${day.toString().padLeft(2, '0')}: Rs.${it['amt'].toStringAsFixed(0)}');
        }
      }
    }

    final gridRows = <pw.TableRow>[];
    
    gridRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          for (int i = 0; i < 8; i++) ...[
            _pdfCell('Day', font, bold: true),
            _pdfCell('Kg', font, bold: true),
          ]
        ]
      )
    );

    for (int r = 0; r < 4; r++) { 
      final rowChildren = <pw.Widget>[];
      for (int c = 0; c < 8; c++) { 
        int day = (r * 8) + c + 1; 
        if (day > 31) {
          rowChildren.addAll([_pdfCell('', font), _pdfCell('', font)]);
        } else {
          double w = dailyWeights[day] ?? 0.0;
          rowChildren.addAll([
            _pdfCell(day.toString(), font),
            _pdfCell(w > 0 ? w.toStringAsFixed(1) : '-', font),
          ]);
        }
      }
      gridRows.add(pw.TableRow(children: rowChildren));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // --- HEADER ---
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('NALEEN SURANGA', style: pw.TextStyle(font: font, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('Authorized Green Dealer - Gangoda, Rakwana', style: pw.TextStyle(font: font, fontSize: 8)),
                pw.Text('Tel: 0713444934 / 0758258544', style: pw.TextStyle(font: font, fontSize: 8)),
              ]
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Name: ${item['name']} | Ref: ${item['ref'].toString().padLeft(3, '0')}', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('Month: ${b['displayMonth']}', style: pw.TextStyle(font: font, fontSize: 9)),
              ]
            )
          ]
        ),
        pw.SizedBox(height: 5),

        // --- 1 to 31 GRID ---
        pw.Table(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey700),
          // 💡 Table එකට 100% පළල ලබා ගැනීම.
          defaultColumnWidth: const pw.FlexColumnWidth(), 
          children: gridRows,
        ),
        pw.SizedBox(height: 10),

        // --- SUMMARY & DEDUCTIONS ---
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 1, // 💡 තීරු දෙකටම සමාන ඉඩක් (Flex 1) ලබා දී ඇත.
              child: pw.Container(
                padding: const pw.EdgeInsets.only(right: 15),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Deductions Breakdown:', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                    pw.SizedBox(height: 5),
                    
                    if (b['advTotal'] > 0) ...[
                      pw.Text('Advances (Total: Rs.${b['advTotal'].toStringAsFixed(2)})', style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Wrap(
                        spacing: 8, runSpacing: 2,
                        children: advanceRecords.map((e) => pw.Text(e, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey800))).toList(),
                      ),
                      pw.SizedBox(height: 4),
                    ],

                    if (b['f1Qty'] > 0) pw.Text('Fertilizer 01 : ${b['f1Qty']} x Rs.${(b['f1Total']/b['f1Qty']).toStringAsFixed(2)} = Rs.${b['f1Total'].toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 8)),
                    if (b['f2Qty'] > 0) pw.Text('Fertilizer 02 : ${b['f2Qty']} x Rs.${(b['f2Total']/b['f2Qty']).toStringAsFixed(2)} = Rs.${b['f2Total'].toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 8)),
                    if (b['t1Qty'] > 0) pw.Text('Tea Pkt 01    : ${b['t1Qty']} x Rs.${(b['t1Total']/b['t1Qty']).toStringAsFixed(2)} = Rs.${b['t1Total'].toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 8)),
                    if (b['t2Qty'] > 0) pw.Text('Tea Pkt 02    : ${b['t2Qty']} x Rs.${(b['t2Total']/b['t2Qty']).toStringAsFixed(2)} = Rs.${b['t2Total'].toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 8)),
                    
                    pw.SizedBox(height: 4),
                    pw.Text('Transport (${totalW.toStringAsFixed(1)}kg) : Rs.${b['transportCost'].toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 8)),
                    
                    if ((b['arrears'] ?? 0) > 0) ...[
                      pw.SizedBox(height: 2),
                      pw.Text('Last Month Arrears : Rs.${b['arrears'].toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.red800)),
                    ]
                  ]
                )
              )
            ),

            pw.Expanded(
              flex: 1, // 💡 තීරු දෙකටම සමාන ඉඩක් (Flex 1) ලබා දී ඇත.
              child: pw.Container(
                padding: const pw.EdgeInsets.all(5),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5, color: PdfColors.grey700)),
                child: pw.Column(
                  children: [
                    _pdfSummaryRow('Total Weight', '${totalW.toStringAsFixed(1)} Kg', font, bold: true),
                    _pdfSummaryRow('Tea Rate (1Kg)', 'Rs. ${b['teaRate'].toStringAsFixed(2)}', font), 
                    pw.Divider(thickness: 0.5),
                    _pdfSummaryRow('Gross Income', 'Rs. ${b['grossIncome'].toStringAsFixed(2)}', font, bold: true),
                    pw.SizedBox(height: 5),
                    
                    _pdfSummaryRow('Advances Total', '-${b['advTotal'].toStringAsFixed(2)}', font),
                    _pdfSummaryRow('Fert. & Tea Pkt', '-${(b['f1Total'] + b['f2Total'] + b['t1Total'] + b['t2Total']).toStringAsFixed(2)}', font),
                    _pdfSummaryRow('Transport', '-${b['transportCost'].toStringAsFixed(2)}', font),
                    if ((b['arrears'] ?? 0) > 0)
                      _pdfSummaryRow('Arrears', '-${b['arrears'].toStringAsFixed(2)}', font),
                    
                    pw.Divider(thickness: 0.5),
                    _pdfSummaryRow('Total Deduct.', '-${b['totalDeductions'].toStringAsFixed(2)}', font, bold: true),
                    pw.Divider(thickness: 1.5),
                    _pdfSummaryRow('NET PAYABLE', 'Rs. ${b['netPayable'].toStringAsFixed(2)}', font, bold: true),
                    pw.Divider(thickness: 1.5),
                  ]
                )
              )
            )
          ]
        ),

        pw.Spacer(), 
        pw.Divider(thickness: 0.5),
        pw.Center(
          child: pw.Text('Thank You! | Powered by OrbitView Innovations', style: pw.TextStyle(font: font, fontSize: 7, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700))
        )
      ]
    );
  }

  // 💡 යටට යන එක නවත්වන්න cell වල Padding (හිඩැස) අඩු කර ඇත
  pw.Widget _pdfCell(String text, pw.Font font, {bool bold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  // 💡 Summary එකෙත් Padding අඩු කර ඇත
  pw.Widget _pdfSummaryRow(String label, String value, pw.Font font, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}