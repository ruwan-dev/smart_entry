import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  String _selectedReportType = 'Daily All Data'; 
  String? _selectedCustomerId;
  
  List<DocumentSnapshot> _customers = [];
  bool _isLoading = false;

  final List<String> _reportTypes = [
    'Daily All Data',
    'Customer Wise',
    'Tea Leaves Only',
    'Fertilizer Wise',
    'Tea Packet Wise',
    'Advances & Items'
  ];

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    var snap = await FirebaseFirestore.instance.collection('Customers').orderBy('name').get();
    setState(() {
      _customers = snap.docs;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _generatePdfReport() async {
    if (_selectedReportType == 'Customer Wise' && _selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('කරුණාකර පාරිභෝගිකයෙකු තෝරන්න')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      double fert1Price = 0, fert2Price = 0, teaPkt1Price = 0, teaPkt2Price = 0;
      var priceDoc = await FirebaseFirestore.instance.collection('GlobalSettings').doc('prices').get();
      if (priceDoc.exists) {
        var pData = priceDoc.data()!;
        fert1Price = (pData['fertilizer1Price'] ?? 0.0).toDouble();
        fert2Price = (pData['fertilizer2Price'] ?? 0.0).toDouble();
        teaPkt1Price = (pData['teaPacket1Price'] ?? 0.0).toDouble();
        teaPkt2Price = (pData['teaPacket2Price'] ?? 0.0).toDouble();
      }

      DateTime endOfDay = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

      var query = FirebaseFirestore.instance
          .collection('DailyEntries')
          .where('timestamp', isGreaterThanOrEqualTo: _startDate)
          .where('timestamp', isLessThanOrEqualTo: endOfDay);

      var snap = await query.get();
      List<QueryDocumentSnapshot> entries = snap.docs;

      if (_selectedReportType == 'Customer Wise') {
        entries = entries.where((doc) => doc['customerId'] == _selectedCustomerId).toList();
      } else if (_selectedReportType == 'Tea Leaves Only') {
        entries = entries.where((doc) => (doc['netWeight'] ?? 0) > 0).toList();
      } else if (_selectedReportType == 'Fertilizer Wise') {
        entries = entries.where((doc) => (doc['fertilizer1Qty'] ?? 0) > 0 || (doc['fertilizer2Qty'] ?? 0) > 0).toList();
      } else if (_selectedReportType == 'Tea Packet Wise') {
        entries = entries.where((doc) => (doc['teaPacket1Qty'] ?? 0) > 0 || (doc['teaPacket2Qty'] ?? 0) > 0).toList();
      } else if (_selectedReportType == 'Advances & Items') {
        entries = entries.where((doc) => 
          (doc['advanceAmount'] ?? 0) > 0 || 
          (doc['fertilizer1Qty'] ?? 0) > 0 || 
          (doc['fertilizer2Qty'] ?? 0) > 0 || 
          (doc['teaPacket1Qty'] ?? 0) > 0 || 
          (doc['teaPacket2Qty'] ?? 0) > 0
        ).toList();
      }

      entries.sort((a, b) => (a['timestamp'] as Timestamp).compareTo(b['timestamp'] as Timestamp));

      Map<String, String> customerNames = {};
      for (var c in _customers) {
        customerNames[c.id] = c['name'] ?? 'Unknown';
      }

      final pdf = pw.Document();
      
      double totalWeight = 0, totalAdvance = 0;
      
      double totalF1Qty = 0, totalF2Qty = 0;
      double totalT1Qty = 0, totalT2Qty = 0;
      
      double totalFertValue = 0, totalTeaValue = 0;
      double grandTotalDeductions = 0;

      bool showWeight = ['Daily All Data', 'Customer Wise', 'Tea Leaves Only'].contains(_selectedReportType);
      bool showAdvance = ['Daily All Data', 'Customer Wise', 'Advances & Items'].contains(_selectedReportType);
      bool showFertilizer = ['Daily All Data', 'Customer Wise', 'Advances & Items', 'Fertilizer Wise'].contains(_selectedReportType);
      bool showTeaPkt = ['Daily All Data', 'Customer Wise', 'Advances & Items', 'Tea Packet Wise'].contains(_selectedReportType);
      bool showTotalDed = ['Daily All Data', 'Customer Wise', 'Advances & Items'].contains(_selectedReportType);

      List<String> headers = ['Date', 'Customer Name'];
      Map<int, pw.Alignment> alignments = {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
      };
      
      int colIndex = 2;
      if (showWeight) { headers.add('Weight\n(Kg)'); alignments[colIndex++] = pw.Alignment.centerRight; }
      if (showAdvance) { headers.add('Advance\n(Rs)'); alignments[colIndex++] = pw.Alignment.centerRight; }
      
      if (showFertilizer) { 
        headers.add('Fert. 1\nQty (Val)'); alignments[colIndex++] = pw.Alignment.center; 
        headers.add('Fert. 2\nQty (Val)'); alignments[colIndex++] = pw.Alignment.center; 
      }
      
      if (showTeaPkt) { headers.add('Tea Pkt\nBreakdown'); alignments[colIndex++] = pw.Alignment.center; }
      if (showTotalDed) { headers.add('Total Ded.\n(Rs)'); alignments[colIndex++] = pw.Alignment.centerRight; }

      List<List<String>> tableData = [];
      for (var doc in entries) {
        var data = doc.data() as Map<String, dynamic>;
        DateTime ts = (data['timestamp'] as Timestamp).toDate();
        String cName = customerNames[data['customerId']] ?? '-';
        
        double w = (data['netWeight'] ?? 0).toDouble();
        double adv = (data['advanceAmount'] ?? 0).toDouble();
        
        double f1Qty = (data['fertilizer1Qty'] ?? 0).toDouble();
        double f2Qty = (data['fertilizer2Qty'] ?? 0).toDouble();
        double t1Qty = (data['teaPacket1Qty'] ?? 0).toDouble();
        double t2Qty = (data['teaPacket2Qty'] ?? 0).toDouble();

        double fertValue = (f1Qty * fert1Price) + (f2Qty * fert2Price);
        double teaValue = (t1Qty * teaPkt1Price) + (t2Qty * teaPkt2Price);
        
        double rowTotalDed = adv + fertValue + teaValue;

        totalWeight += w;
        totalAdvance += adv;
        totalF1Qty += f1Qty; totalF2Qty += f2Qty;
        totalT1Qty += t1Qty; totalT2Qty += t2Qty;
        totalFertValue += fertValue;
        totalTeaValue += teaValue;
        grandTotalDeductions += rowTotalDed;

        String f1Str = f1Qty > 0 ? '${f1Qty.toInt()}\n(Rs.${NumberFormat('#,##0').format(f1Qty * fert1Price)})' : '-';
        String f2Str = f2Qty > 0 ? '${f2Qty.toInt()}\n(Rs.${NumberFormat('#,##0').format(f2Qty * fert2Price)})' : '-';

        String teaStr = '-';
        if (t1Qty > 0 || t2Qty > 0) {
          List<String> tParts = [];
          if (t1Qty > 0) tParts.add('T1: ${t1Qty.toInt()}');
          if (t2Qty > 0) tParts.add('T2: ${t2Qty.toInt()}');
          teaStr = '${tParts.join(', ')}\n(Rs.${NumberFormat('#,##0').format(teaValue)})';
        }

        List<String> row = [
          DateFormat('yyyy-MM-dd').format(ts),
          cName,
        ];
        
        if (showWeight) row.add(w > 0 ? w.toStringAsFixed(1) : '-');
        if (showAdvance) row.add(adv > 0 ? NumberFormat('#,##0.00').format(adv) : '-');
        
        if (showFertilizer) {
          row.add(f1Str);
          row.add(f2Str);
        }

        if (showTeaPkt) row.add(teaStr);
        if (showTotalDed) row.add(rowTotalDed > 0 ? NumberFormat('#,##0.00').format(rowTotalDed) : '-');

        tableData.add(row);
      }

      String totalF1Str = totalF1Qty > 0 ? '${totalF1Qty.toInt()}\n(Rs.${NumberFormat('#,##0').format(totalF1Qty * fert1Price)})' : '-';
      String totalF2Str = totalF2Qty > 0 ? '${totalF2Qty.toInt()}\n(Rs.${NumberFormat('#,##0').format(totalF2Qty * fert2Price)})' : '-';

      String totalTeaStr = '-';
      if (totalT1Qty > 0 || totalT2Qty > 0) {
        List<String> tParts = [];
        if (totalT1Qty > 0) tParts.add('T1: ${totalT1Qty.toInt()}');
        if (totalT2Qty > 0) tParts.add('T2: ${totalT2Qty.toInt()}');
        totalTeaStr = '${tParts.join(', ')}\n(Rs.${NumberFormat('#,##0').format(totalTeaValue)})';
      }

      List<String> totalRow = ['TOTAL', ''];
      if (showWeight) totalRow.add(totalWeight > 0 ? totalWeight.toStringAsFixed(1) : '-');
      if (showAdvance) totalRow.add(NumberFormat('#,##0.00').format(totalAdvance));
      
      if (showFertilizer) {
        totalRow.add(totalF1Str);
        totalRow.add(totalF2Str);
      }

      if (showTeaPkt) totalRow.add(totalTeaStr);
      if (showTotalDed) totalRow.add(NumberFormat('#,##0.00').format(grandTotalDeductions));
      
      tableData.add(totalRow);

      String cNameForTitle = _selectedReportType == 'Customer Wise' 
          ? (customerNames[_selectedCustomerId] ?? '') 
          : 'All Customers';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24), 
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('SMART ENTRY - SYSTEM REPORT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                    pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ]
                )
              ),
              pw.SizedBox(height: 5),
              pw.Text('Report Type: $_selectedReportType', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text('Period: ${DateFormat('yyyy-MM-dd').format(_startDate)} to ${DateFormat('yyyy-MM-dd').format(_endDate)}', style: const pw.TextStyle(fontSize: 11)),
              if (_selectedReportType == 'Customer Wise')
                pw.Text('Customer: $cNameForTitle', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.SizedBox(height: 15),
              
              pw.TableHelper.fromTextArray(
                context: context,
                headers: headers,
                data: tableData,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: alignments,
              ),

              pw.SizedBox(height: 20),

              if (showTotalDed || showFertilizer || showTeaPkt)
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('SUMMARY (DEDUCTIONS & ITEMS)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Divider(color: PdfColors.grey400),
                      pw.SizedBox(height: 5),
                      
                      if (showAdvance)
                        _buildSummaryRow('Total Advances Issued:', 'Rs. ${NumberFormat('#,##0.00').format(totalAdvance)}'),
                      
                      // මෙතන අර අවුල් ගිය අයිකන් එක (Bullet point) වෙනුවට සාමාන්‍ය ඉරක් (-) දැම්මා
                      if (showFertilizer) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('Fertilizer Breakdown:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                        if (totalF1Qty > 0) _buildSummaryRow('  - Fertilizer Type 1 (${totalF1Qty.toInt()} Items):', 'Rs. ${NumberFormat('#,##0.00').format(totalF1Qty * fert1Price)}'),
                        if (totalF2Qty > 0) _buildSummaryRow('  - Fertilizer Type 2 (${totalF2Qty.toInt()} Items):', 'Rs. ${NumberFormat('#,##0.00').format(totalF2Qty * fert2Price)}'),
                        _buildSummaryRow('  Total Fertilizer Value:', 'Rs. ${NumberFormat('#,##0.00').format(totalFertValue)}', isBold: true),
                      ],

                      if (showTeaPkt) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('Tea Packet Breakdown:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                        if (totalT1Qty > 0) _buildSummaryRow('  - Tea Packet Type 1 (${totalT1Qty.toInt()} Items):', 'Rs. ${NumberFormat('#,##0.00').format(totalT1Qty * teaPkt1Price)}'),
                        if (totalT2Qty > 0) _buildSummaryRow('  - Tea Packet Type 2 (${totalT2Qty.toInt()} Items):', 'Rs. ${NumberFormat('#,##0.00').format(totalT2Qty * teaPkt2Price)}'),
                        _buildSummaryRow('  Total Tea Packets Value:', 'Rs. ${NumberFormat('#,##0.00').format(totalTeaValue)}', isBold: true),
                      ],
                      
                      if (showTotalDed) ...[
                        pw.Divider(color: PdfColors.grey400),
                        _buildSummaryRow('GRAND TOTAL DEDUCTIONS:', 'Rs. ${NumberFormat('#,##0.00').format(grandTotalDeductions)}', isBold: true),
                      ]
                    ]
                  )
                )
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Report_${_selectedReportType.replaceAll(' ', '')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  pw.Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('වාර්තා (Reports)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('කාල සීමාව තෝරන්න', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('මුල (From)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(DateFormat('yyyy-MM-dd').format(_startDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('අග (To)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(DateFormat('yyyy-MM-dd').format(_endDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            const Text('වාර්තා වර්ගය', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedReportType,
                  isExpanded: true,
                  items: _reportTypes.map((e) {
                    String display = e;
                    if (e == 'Daily All Data') display = 'දිනපතා සියලු දත්ත (Daily All Data)';
                    if (e == 'Customer Wise') display = 'පාරිභෝගිකයා අනුව (Customer Wise)';
                    if (e == 'Tea Leaves Only') display = 'දළු පමණක් (Tea Leaves Only)';
                    if (e == 'Fertilizer Wise') display = 'පොහොර ගත් අය (Fertilizer Wise)';
                    if (e == 'Tea Packet Wise') display = 'තේ පැකට් ගත් අය (Tea Pkt Wise)';
                    if (e == 'Advances & Items') display = 'අත්තිකාරම් සහ බඩු (Advances & Items)'; 
                    return DropdownMenuItem(value: e, child: Text(display));
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedReportType = val!;
                      if (val != 'Customer Wise') _selectedCustomerId = null;
                    });
                  },
                ),
              ),
            ),

            if (_selectedReportType == 'Customer Wise') ...[
              const SizedBox(height: 24),
              const Text('පාරිභෝගිකයා තෝරන්න', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCustomerId,
                    hint: const Text('පාරිභෝගිකයෙකු තෝරන්න'),
                    isExpanded: true,
                    items: _customers.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name'] ?? ''))).toList(),
                    onChanged: (val) => setState(() => _selectedCustomerId = val),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _generatePdfReport,
                icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: Text(_isLoading ? 'සකසමින් පවතී...' : 'PDF වාර්තාව ලබාගන්න', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}