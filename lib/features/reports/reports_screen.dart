import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// අලුතින් හදපු widget එක මෙතනට import කරගන්න
import 'widgets/monthly_closing_widget.dart'; 

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

  // --- PDF වාර්තා සැකසීමේ Logic එක ---
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
      double totalFertValue = 0, totalTeaValue = 0;
      double grandTotalDeductions = 0;

      bool showWeight = ['Daily All Data', 'Customer Wise', 'Tea Leaves Only'].contains(_selectedReportType);
      bool showAdvance = ['Daily All Data', 'Customer Wise', 'Advances & Items'].contains(_selectedReportType);
      bool showFertilizer = ['Daily All Data', 'Customer Wise', 'Advances & Items', 'Fertilizer Wise'].contains(_selectedReportType);
      bool showTeaPkt = ['Daily All Data', 'Customer Wise', 'Advances & Items', 'Tea Packet Wise'].contains(_selectedReportType);
      bool showTotalDed = ['Daily All Data', 'Customer Wise', 'Advances & Items'].contains(_selectedReportType);

      List<String> headers = ['Date', 'Customer Name'];
      Map<int, pw.Alignment> alignments = {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft};
      int colIndex = 2;
      if (showWeight) { headers.add('Weight\n(Kg)'); alignments[colIndex++] = pw.Alignment.centerRight; }
      if (showAdvance) { headers.add('Advance\n(Rs)'); alignments[colIndex++] = pw.Alignment.centerRight; }
      if (showFertilizer) { headers.add('Fert. 1'); alignments[colIndex++] = pw.Alignment.center; headers.add('Fert. 2'); alignments[colIndex++] = pw.Alignment.center; }
      if (showTeaPkt) { headers.add('Tea Pkt'); alignments[colIndex++] = pw.Alignment.center; }
      if (showTotalDed) { headers.add('Total Ded.'); alignments[colIndex++] = pw.Alignment.centerRight; }

      List<List<String>> tableData = entries.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        String date = DateFormat('MM-dd').format((data['timestamp'] as Timestamp).toDate());
        String cName = customerNames[data['customerId']] ?? '-';
        
        double w = (data['netWeight'] ?? 0).toDouble();
        double adv = (data['advanceAmount'] ?? 0).toDouble();
        double f1 = (data['fertilizer1Qty'] ?? 0).toDouble();
        double f2 = (data['fertilizer2Qty'] ?? 0).toDouble();
        double t1 = (data['teaPacket1Qty'] ?? 0).toDouble();
        double t2 = (data['teaPacket2Qty'] ?? 0).toDouble();
        double rowTotal = adv + (f1 * fert1Price) + (f2 * fert2Price) + (t1 * teaPkt1Price) + (t2 * teaPkt2Price);

        List<String> row = [date, cName];
        if (showWeight) row.add(w > 0 ? w.toStringAsFixed(1) : '-');
        if (showAdvance) row.add(adv > 0 ? adv.toStringAsFixed(0) : '-');
        if (showFertilizer) { row.add(f1 > 0 ? f1.toStringAsFixed(0) : '-'); row.add(f2 > 0 ? f2.toStringAsFixed(0) : '-'); }
        if (showTeaPkt) row.add(t1 > 0 || t2 > 0 ? '${t1.toInt()}/${t2.toInt()}' : '-');
        if (showTotalDed) row.add(rowTotal > 0 ? rowTotal.toStringAsFixed(0) : '-');
        return row;
      }).toList();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Powered by OrbitView Innovations', style: const pw.TextStyle(fontSize: 8)),
        ),
        build: (pw.Context context) => [
          pw.Header(level: 0, child: pw.Text('SMART ENTRY - SYSTEM REPORT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 10),
          pw.Text('Report: $_selectedReportType | Period: ${DateFormat('yyyy-MM-dd').format(_startDate)} to ${DateFormat('yyyy-MM-dd').format(_endDate)}'),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(headers: headers, data: tableData, cellAlignments: alignments, headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), cellStyle: const pw.TextStyle(fontSize: 8)),
        ],
      ));

      await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Report.pdf');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('වාර්තා සහ ගිණුම් පියවීම')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. මාසික ගිණුම් පියවීම (Closing Section) ---
            const Text('මාසික ගිණුම් අවසන් කිරීම (Closing)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const MonthlyClosingWidget(), // මෙතැනදී අලුත් component එක call කරනවා
            
            const SizedBox(height: 30),
            const Divider(thickness: 2),
            const SizedBox(height: 20),

            // --- 2. PDF වාර්තා ලබාගැනීමේ කොටස ---
            const Text('PDF වාර්තා ලබාගන්න', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            _buildDatePickerSection(),
            const SizedBox(height: 20),
            
            const Text('වාර්තා වර්ගය', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildReportTypeSelector(),

            if (_selectedReportType == 'Customer Wise') _buildCustomerSelector(),

            const SizedBox(height: 40),
            _buildPdfButton(),
          ],
        ),
      ),
    );
  }

  // --- UI Helper Widgets (කේතය පිරිසිදුව තබා ගැනීමට) ---

  Widget _buildDatePickerSection() {
    return Row(
      children: [
        Expanded(child: _dateTile('මුල', _startDate, true)),
        const SizedBox(width: 15),
        Expanded(child: _dateTile('අග', _endDate, false)),
      ],
    );
  }

  Widget _dateTile(String label, DateTime date, bool isStart) {
    return InkWell(
      onTap: () => _selectDate(context, isStart),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(DateFormat('yyyy-MM-dd').format(date), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTypeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedReportType,
          isExpanded: true,
          items: _reportTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) => setState(() { _selectedReportType = val!; if(val != 'Customer Wise') _selectedCustomerId = null; }),
        ),
      ),
    );
  }

  Widget _buildCustomerSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text('පාරිභෝගිකයා තෝරන්න', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
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
    );
  }

  Widget _buildPdfButton() {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _generatePdfReport,
        icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf),
        label: const Text('PDF වාර්තාව ලබාගන්න', style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
      ),
    );
  }
}