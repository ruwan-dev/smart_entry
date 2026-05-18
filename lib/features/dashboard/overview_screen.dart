import 'package:flutter/gestures.dart'; // Mouse drag එක සඳහා අවශ්‍යයි
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'outstanding_list_screen.dart'; 

// Windows/Desktop වල mouse එකෙන් අදින්න පුළුවන් වෙන්න හදන Behavior එක
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse, // Mouse එකෙන් scroll කිරීමට ඉඩ දෙයි
      };
}

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  String _selectedFilter = 'මෙම මාසය';
  bool _isLoading = true;

  double _totalWeight = 0.0;
  double _totalAdvance = 0.0;
  double _totalFertilizer1 = 0.0;
  double _totalFertilizer2 = 0.0;
  double _totalTeaPacket1 = 0.0;
  double _totalTeaPacket2 = 0.0;
  int _totalCustomers = 0;
  
  double _overallOutstandingAdvances = 0.0;
  
  Map<String, dynamic>? _latestSummaryData;
  String? _latestSummaryId;
  Map<String, dynamic>? _previousSummaryData; // පසුගිය මාසයේ දත්ත සඳහා

  double fert1Price = 0, fert2Price = 0, teaPkt1Price = 0, teaPkt2Price = 0;

  List<Map<String, dynamic>> _topSuppliers = [];
  List<Map<String, dynamic>> _topArrears = [];
  List<Map<String, dynamic>> _allArrears = []; 
  
  final List<String> _filterOptions = ['අද', 'මෙම සතිය', 'මෙම මාසය', 'පසුගිය මාසය', 'පසුගිය මාස 6'];

  String _chartFilter = 'දිනපතා';
  bool _isChartLoading = true;
  List<double> _chartValues = [];
  List<String> _chartLabels = [];
  final List<String> _chartFilterOptions = ['දිනපතා', 'සතිපතා', 'මාසිකව'];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _fetchChartData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    DateTime now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (_selectedFilter == 'අද') start = DateTime(now.year, now.month, now.day);
    else if (_selectedFilter == 'මෙම සතිය') {
      start = now.subtract(Duration(days: now.weekday - 1));
      start = DateTime(start.year, start.month, start.day);
    } else if (_selectedFilter == 'මෙම මාසය') start = DateTime(now.year, now.month, 1);
    else if (_selectedFilter == 'පසුගිය මාසය') {
      start = DateTime(now.year, now.month - 1, 1);
      end = DateTime(now.year, now.month, 0, 23, 59, 59);
    } else start = DateTime(now.year, now.month - 5, 1);

    try {
      // මාස 2ක දත්ත ලබා ගනී (වත්මන් සහ පෙර මාසය සැසඳීමට)
      var latestSummarySnap = await FirebaseFirestore.instance
          .collection('MonthlySummaries')
          .orderBy('finalizedAt', descending: true)
          .limit(2) 
          .get();

      if (latestSummarySnap.docs.isNotEmpty) {
        _latestSummaryData = latestSummarySnap.docs.first.data();
        _latestSummaryId = latestSummarySnap.docs.first.id; 
        
        if (latestSummarySnap.docs.length > 1) {
          _previousSummaryData = latestSummarySnap.docs[1].data();
        } else {
          _previousSummaryData = null;
        }
      } else {
        _latestSummaryData = null;
        _latestSummaryId = null;
        _previousSummaryData = null;
      }

      var priceDoc = await FirebaseFirestore.instance.collection('GlobalSettings').doc('prices').get();
      if (priceDoc.exists) {
        var pData = priceDoc.data()!;
        fert1Price = (pData['fertilizer1Price'] ?? 0.0).toDouble();
        fert2Price = (pData['fertilizer2Price'] ?? 0.0).toDouble();
        teaPkt1Price = (pData['teaPacket1Price'] ?? 0.0).toDouble();
        teaPkt2Price = (pData['teaPacket2Price'] ?? 0.0).toDouble();
      }

      var ratesSnap = await FirebaseFirestore.instance.collection('MonthlyRates').get();
      Map<String, double> ratesMap = {};
      for (var doc in ratesSnap.docs) {
        ratesMap[doc.id] = (doc.data()['teaRate'] ?? 0.0).toDouble();
      }

      var customersSnapshot = await FirebaseFirestore.instance.collection('Customers').get();
      Map<String, String> customerNames = {};
      for (var doc in customersSnapshot.docs) {
        customerNames[doc.id] = doc.data()['name'] ?? 'Unknown';
      }

      var filteredEntries = await FirebaseFirestore.instance
          .collection('DailyEntries')
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThanOrEqualTo: end)
          .get();

      double tw = 0.0, ta = 0.0, f1 = 0, f2 = 0, t1 = 0, t2 = 0;
      Map<String, double> supplierWeightMap = {};

      for (var doc in filteredEntries.docs) {
        var d = doc.data();
        double w = (d['netWeight'] ?? 0.0).toDouble();
        tw += w;
        ta += (d['advanceAmount'] ?? 0.0).toDouble();
        f1 += (d['fertilizer1Qty'] ?? 0.0).toDouble();
        f2 += (d['fertilizer2Qty'] ?? 0.0).toDouble();
        t1 += (d['teaPacket1Qty'] ?? 0.0).toDouble();
        t2 += (d['teaPacket2Qty'] ?? 0.0).toDouble();
        String cId = d['customerId'] ?? '';
        if (cId.isNotEmpty) supplierWeightMap[cId] = (supplierWeightMap[cId] ?? 0.0) + w;
      }

      var sortedSuppliers = supplierWeightMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      _topSuppliers = sortedSuppliers.take(5).map((e) => {'name': customerNames[e.key] ?? 'Unknown', 'weight': e.value}).toList();

      var allEntriesSnapshot = await FirebaseFirestore.instance.collection('DailyEntries').get();
      Map<String, double> customerIncomeMap = {};
      Map<String, double> customerDeductionMap = {};

      for (var doc in allEntriesSnapshot.docs) {
        var data = doc.data();
        String cId = data['customerId'] ?? '';
        if (cId.isEmpty) continue;
        DateTime ts = (data['timestamp'] as Timestamp).toDate();
        String monthKey = "${ts.year}-${DateFormat('MMMM').format(ts)}";
        double w = (data['netWeight'] ?? 0.0).toDouble();
        double adv = (data['advanceAmount'] ?? 0.0).toDouble();
        double qF1 = (data['fertilizer1Qty'] ?? 0.0).toDouble();
        double qF2 = (data['fertilizer2Qty'] ?? 0.0).toDouble();
        double qT1 = (data['teaPacket1Qty'] ?? 0.0).toDouble();
        double qT2 = (data['teaPacket2Qty'] ?? 0.0).toDouble();
        double rate = ratesMap[monthKey] ?? 0.0;
        customerIncomeMap[cId] = (customerIncomeMap[cId] ?? 0.0) + (w * rate);
        customerDeductionMap[cId] = (customerDeductionMap[cId] ?? 0.0) + (adv + (qF1 * fert1Price) + (qF2 * fert2Price) + (qT1 * teaPkt1Price) + (qT2 * teaPkt2Price));
      }

      double totalOverallOutstanding = 0.0;
      Map<String, double> arrearsMap = {};
      for (String cId in customerDeductionMap.keys) {
        double income = customerIncomeMap[cId] ?? 0.0;
        double deduction = customerDeductionMap[cId] ?? 0.0;
        if (deduction > income) {
          double arrear = deduction - income;
          arrearsMap[cId] = arrear;
          totalOverallOutstanding += arrear; 
        }
      }

      _allArrears = arrearsMap.entries.toList().map((e) => {
        'name': customerNames[e.key] ?? 'Unknown', 
        'amount': e.value
      }).toList()..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
      
      _topArrears = _allArrears.take(5).toList();

      setState(() {
        _totalCustomers = customersSnapshot.docs.length;
        _totalWeight = tw;
        _totalAdvance = ta;
        _totalFertilizer1 = f1; _totalFertilizer2 = f2;
        _totalTeaPacket1 = t1; _totalTeaPacket2 = t2;
        _overallOutstandingAdvances = totalOverallOutstanding;
        _isLoading = false;
      });
    } catch (e) { setState(() => _isLoading = false); }
  }

  Future<void> _fetchChartData() async {
    setState(() => _isChartLoading = true);
    DateTime now = DateTime.now();
    DateTime start;
    if (_chartFilter == 'දිනපතා') start = DateTime(now.year, now.month, now.day - 29);
    else if (_chartFilter == 'සතිපතා') start = DateTime(now.year, now.month, now.day - 27);
    else start = DateTime(now.year, now.month - 5, 1);

    try {
      var snapshot = await FirebaseFirestore.instance.collection('DailyEntries').where('timestamp', isGreaterThanOrEqualTo: start).get();
      List<double> tv = []; List<String> tl = [];
      if (_chartFilter == 'දිනපතා') {
        tv = List.filled(30, 0.0);
        for (int i = 29; i >= 0; i--) tl.add(DateFormat('MMM dd').format(now.subtract(Duration(days: i))));
        for (var doc in snapshot.docs) {
          DateTime ts = (doc.data()['timestamp'] as Timestamp).toDate();
          int diff = DateTime(now.year, now.month, now.day).difference(DateTime(ts.year, ts.month, ts.day)).inDays;
          if (diff >= 0 && diff < 30) tv[29 - diff] += (doc.data()['netWeight'] ?? 0.0).toDouble();
        }
      } else {
         // සතිපතා සහ මාසිකව සඳහා කලින් තිබූ logic එක...
      }
      if (mounted) setState(() { _chartValues = tv; _chartLabels = tl; _isChartLoading = false; });
    } catch (e) { if (mounted) setState(() => _isChartLoading = false); }
  }

  Widget _buildChartContainer() {
    double mv = _chartValues.isNotEmpty ? _chartValues.reduce((a, b) => a > b ? a : b) : 100.0;
    double chartWidth = _chartFilter == 'දිනපතා' ? 1400 : MediaQuery.of(context).size.width - 32;

    return Container(
      height: 320,
      padding: const EdgeInsets.only(top: 25, bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)]),
      child: ScrollConfiguration(
        behavior: MyCustomScrollBehavior(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: SizedBox(
            width: chartWidth,
            child: AbsorbPointer(
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true, reservedSize: 60, interval: 1, 
                      getTitlesWidget: (v, m) {
                        int idx = v.toInt();
                        if (idx >= 0 && idx < _chartLabels.length) {
                          return Padding(padding: const EdgeInsets.only(top: 15.0), 
                            child: Transform.rotate(angle: -0.8, child: Text(_chartLabels[idx], style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)))
                          );
                        }
                        return const Text("");
                      }
                    )),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => v == 0 ? const SizedBox() : Text('${v.toInt()}', style: const TextStyle(fontSize: 9, color: Colors.grey)))),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0, maxY: (mv == 0 ? 100 : mv) * 1.3,
                  lineBarsData: [LineChartBarData(
                    spots: List.generate(_chartValues.length, (i) => FlSpot(i.toDouble(), _chartValues[i])),
                    isCurved: true, color: Colors.green, barWidth: 3, dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.1))
                  )],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyF = NumberFormat('#,##0.00', 'en_US');
    final weightF = NumberFormat('#,##0.##', 'en_US');
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: RefreshIndicator(
        onRefresh: () async { await _fetchDashboardData(); await _fetchChartData(); },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _isLoading ? _loader() : _buildCombinedHeader(context, currencyF),
            const SizedBox(height: 20),
            _isLoading ? _loader() : _buildDbBusinessSummary(currencyF, weightF),
            _buildSectionHeader('සාරාංශය', _selectedFilter, _filterOptions, (val) { setState(() => _selectedFilter = val!); _fetchDashboardData(); }),
            const SizedBox(height: 16),
            _isLoading ? _loader() : _buildSummaryGrid(context, weightF, currencyF),
            const SizedBox(height: 32),
            _buildSectionHeader('දළු එකතුව (Kg)', _chartFilter, _chartFilterOptions, (val) { setState(() => _chartFilter = val!); _fetchChartData(); }),
            const SizedBox(height: 16),
            _isChartLoading ? _loader() : _buildChartContainer(),
            const SizedBox(height: 32),
            const Text('වැඩිම දළු සැපයුම්කරුවන්', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _isLoading ? _loader() : _buildTopSuppliersList(weightF),
            const SizedBox(height: 32),
            const Text('හිඟ මුදල් ඇති අය (Top 5)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 12),
            _isLoading ? _loader() : _buildTopArrearsList(currencyF),
            const SizedBox(height: 50),
          ]),
        ),
      ),
    );
  }

  // --- Main Header Tiles ---
  Widget _buildCombinedHeader(BuildContext context, NumberFormat currencyF) { 
    return LayoutBuilder(
      builder: (context, constraints) {
        double w = constraints.maxWidth;
        bool isMobile = w < 550; // කුඩා තිර සඳහා Check කිරීම
        double cardWidth = isMobile ? w : (w - 12) / 2; // කුඩා නම් සම්පූර්ණ පළල, නැත්නම් දෙකට බෙදයි

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth, 
              child: _statHeaderCard(
                title: 'පාරිභෝගිකයින්', 
                value: '$_totalCustomers', 
                icon: Icons.people_alt, 
                color: Colors.green, 
                onTap: () {}
              )
            ), 
            SizedBox(
              width: cardWidth, 
              child: _statHeaderCard(
                title: 'හිඟ මුදල', 
                value: 'Rs. ${currencyF.format(_overallOutstandingAdvances)}', 
                icon: Icons.account_balance_wallet, 
                color: Colors.red, 
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OutstandingListScreen(arrearsList: _allArrears)))
              )
            )
          ]
        );
      }
    ); 
  }

  // පාරිභෝගිකයින් සහ හිඟ මුදල සඳහා වර්ණ පාලනය කරන සහ ස්ථිර උසක් ඇති පොදු Card Widget එක
  Widget _statHeaderCard({required String title, required String value, required IconData icon, required Color color, required VoidCallback onTap}) { 
    Color bgColor = color == Colors.green ? Colors.green.shade50 : (color == Colors.red ? Colors.red.shade50 : Colors.white);
    Color borderColor = color == Colors.green ? Colors.green.shade200 : (color == Colors.red ? Colors.red.shade200 : Colors.transparent);

    return InkWell(
      onTap: onTap, 
      borderRadius: BorderRadius.circular(15), 
      child: Container(
        height: 115, // Tile දෙකම එකම ප්‍රමාණයේ තිබීම සඳහා ස්ථිර උසක් ලබා දීම
        padding: const EdgeInsets.all(16), 
        decoration: BoxDecoration(
          color: bgColor, 
          borderRadius: BorderRadius.circular(15), 
          border: Border.all(color: borderColor)
        ), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center, // ඇතුලත අන්තර්ගතය මැදට ගැනීම සඳහා
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18), 
                const SizedBox(width: 8), 
                Text(title, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600))
              ]
            ), 
            const SizedBox(height: 12), 
            Text(value, style: TextStyle(color: color, fontSize: color == Colors.red ? 14 : 22, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis))
          ]
        )
      )
    ); 
  }
  
  Widget _buildDbBusinessSummary(NumberFormat currencyF, NumberFormat weightF) { 
    if (_latestSummaryData == null || _latestSummaryId == null) return const SizedBox(); 
    String displayDate = _latestSummaryId!; 
    String monthName = "";
    try { 
      List<String> parts = _latestSummaryId!.split('-'); 
      if (parts.length >= 2) {
        displayDate = "${parts[1]} ${parts[0]}"; 
        monthName = parts[1]; 
      }
    } catch (e) {} 
    
    String summaryTitle = monthName.isNotEmpty ? "$monthName මාසික ව්‍යාපාරික සාරාංශය" : "මාසික ව්‍යාපාරික සාරාංශය";

    var s = _latestSummaryData!; 
    
    double cWeight = (s['totalWeight'] ?? 0).toDouble();
    double cGross = (s['totalGross'] ?? 0).toDouble();
    double cAdv = (s['totalAdvance'] ?? 0).toDouble();
    double cTrans = (s['totalTransport'] ?? 0).toDouble();
    
    double cF1Amt = (s['totalF1Amt'] ?? 0).toDouble();
    double cF2Amt = (s['totalF2Amt'] ?? 0).toDouble();
    double cFertAmt = cF1Amt + cF2Amt;
    if (cFertAmt == 0) cFertAmt = (s['totalFertilizer'] ?? 0).toDouble();

    double cT1Amt = (s['totalT1Amt'] ?? 0).toDouble();
    double cT2Amt = (s['totalT2Amt'] ?? 0).toDouble();
    double cTeaAmt = cT1Amt + cT2Amt;
    if (cTeaAmt == 0) cTeaAmt = (s['totalTeaPacket'] ?? 0).toDouble();

    double cNegNet = (s['totalNegativeNet'] ?? 0).toDouble().abs();
    double cPosNet = (s['totalPositiveNet'] ?? 0).toDouble();
    double cNet = (s['totalNet'] ?? 0).toDouble();

    double? pWeight = _previousSummaryData != null ? (_previousSummaryData!['totalWeight'] ?? 0).toDouble() : null;
    double? pGross = _previousSummaryData != null ? (_previousSummaryData!['totalGross'] ?? 0).toDouble() : null;
    double? pAdv = _previousSummaryData != null ? (_previousSummaryData!['totalAdvance'] ?? 0).toDouble() : null;
    double? pTrans = _previousSummaryData != null ? (_previousSummaryData!['totalTransport'] ?? 0).toDouble() : null;

    double? pFertAmt;
    if (_previousSummaryData != null) {
      pFertAmt = (_previousSummaryData!['totalF1Amt'] ?? 0).toDouble() + (_previousSummaryData!['totalF2Amt'] ?? 0).toDouble();
      if (pFertAmt == 0) pFertAmt = (_previousSummaryData!['totalFertilizer'] ?? 0).toDouble();
    }

    double? pTeaAmt;
    if (_previousSummaryData != null) {
      pTeaAmt = (_previousSummaryData!['totalT1Amt'] ?? 0).toDouble() + (_previousSummaryData!['totalT2Amt'] ?? 0).toDouble();
      if (pTeaAmt == 0) pTeaAmt = (_previousSummaryData!['totalTeaPacket'] ?? 0).toDouble();
    }

    double? pNegNet = _previousSummaryData != null ? (_previousSummaryData!['totalNegativeNet'] ?? 0).toDouble().abs() : null;
    double? pPosNet = _previousSummaryData != null ? (_previousSummaryData!['totalPositiveNet'] ?? 0).toDouble() : null;
    double? pNet = _previousSummaryData != null ? (_previousSummaryData!['totalNet'] ?? 0).toDouble() : null;

    double f1Qty = (s['totalF1Qty'] ?? 0).toDouble();
    double f2Qty = (s['totalF2Qty'] ?? 0).toDouble();
    double t1Qty = (s['totalT1Qty'] ?? 0).toDouble();
    double t2Qty = (s['totalT2Qty'] ?? 0).toDouble();

    return Container(
      width: double.infinity, 
      padding: const EdgeInsets.all(20), 
      margin: const EdgeInsets.only(bottom: 24), 
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10, spreadRadius: 5)]
      ), 
      child: LayoutBuilder(
        builder: (context, constraints) {
          double w = constraints.maxWidth;
          bool isMobile = w < 550;
          bool isTablet = w < 900; 

          double w2 = isMobile ? w : (w - 13) / 2; 
          double w3 = isMobile ? w : (isTablet ? (w - 13) / 2 : (w - 26) / 3);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  Text(summaryTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)), 
                  Text(displayDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green))
                ]
              ), 
              const Divider(height: 30), 
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: w2, child: _miniTile(label: "මුළු දළු බර", value: "${weightF.format(cWeight)} Kg", icon: Icons.scale, color: Colors.orange, currentVal: cWeight, prevVal: pWeight)), 
                  SizedBox(width: w2, child: _miniTile(label: "මුළු ආදායම", value: "Rs. ${currencyF.format(cGross)}", icon: Icons.trending_up, color: Colors.green, currentVal: cGross, prevVal: pGross)), 
                  
                  SizedBox(width: w2, child: _miniTile(label: "අත්තිකාරම් මුදල්", value: "Rs. ${currencyF.format(cAdv)}", icon: Icons.payments, color: Colors.blue, currentVal: cAdv, prevVal: pAdv, invertTrend: true)), 
                  SizedBox(width: w2, child: _miniTile(label: "ප්‍රවාහන වියදම", value: "Rs. ${currencyF.format(cTrans)}", icon: Icons.local_shipping, color: Colors.redAccent, currentVal: cTrans, prevVal: pTrans, invertTrend: true)), 
                  
                  SizedBox(width: w2, child: _miniTile(
                    label: "පොහොර වියදම", value: "Rs. ${currencyF.format(cFertAmt)}", icon: Icons.compost, color: const Color.fromARGB(255, 1, 64, 3), currentVal: cFertAmt, prevVal: pFertAmt, invertTrend: true,
                    extraDetails: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("වර්ගය 1: ${weightF.format(f1Qty)} | Rs. ${currencyF.format(cF1Amt)}", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        Text("වර්ගය 2: ${weightF.format(f2Qty)} | Rs. ${currencyF.format(cF2Amt)}", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                      ],
                    )
                  )), 
                  SizedBox(width: w2, child: _miniTile(
                    label: "තේ පැකට් වියදම", value: "Rs. ${currencyF.format(cTeaAmt)}", icon: Icons.local_cafe, color: Colors.brown, currentVal: cTeaAmt, prevVal: pTeaAmt, invertTrend: true,
                    extraDetails: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("වර්ගය 1: ${weightF.format(t1Qty)} | Rs. ${currencyF.format(cT1Amt)}", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        Text("වර්ගය 2: ${weightF.format(t2Qty)} | Rs. ${currencyF.format(cT2Amt)}", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                      ],
                    )
                  )), 
                  
                  SizedBox(width: w3, child: _miniTile(label: "අයවියයුතු මුදල", value: "Rs. ${currencyF.format(cNegNet)}", icon: Icons.arrow_circle_down, color: Colors.redAccent, currentVal: cNegNet, prevVal: pNegNet, invertTrend: true)), 
                  SizedBox(width: w3, child: _miniTile(label: "ලබා දිය යුතු මුදල", value: "Rs. ${currencyF.format(cPosNet)}", icon: Icons.arrow_circle_up, color: Colors.teal, currentVal: cPosNet, prevVal: pPosNet)), 
                  SizedBox(width: w3, child: _miniTile(label: "ශුද්ධ ශේෂය", value: "Rs. ${currencyF.format(cNet)}", icon: Icons.account_balance, color: Colors.blue, currentVal: cNet, prevVal: pNet)),
                ]
              )
            ]
          );
        }
      )
    ); 
  }
  
  Widget _miniTile({
    required String label, 
    required String value, 
    required IconData icon, 
    required Color color, 
    Widget? extraDetails,
    double? currentVal,
    double? prevVal,
    bool invertTrend = false,
  }) {
    Widget trendWidget = const SizedBox();
    
    if (currentVal != null && prevVal != null) {
      double change = 0;
      if (prevVal != 0) {
        change = ((currentVal - prevVal) / prevVal.abs()) * 100;
      } else if (currentVal != 0) {
        change = currentVal > 0 ? 100.0 : -100.0;
      }

      if (prevVal != 0 || currentVal != 0) {
        bool isUp = change > 0;
        bool isSame = change == 0;
        
        Color tColor = isSame ? Colors.grey : (isUp ? (invertTrend ? Colors.red : Colors.green) : (invertTrend ? Colors.green : Colors.red));
        IconData tIcon = isSame ? Icons.horizontal_rule : (isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down);
        String tText = isSame ? "0%" : "${change.abs().toStringAsFixed(1)}%";
        
        trendWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tIcon, color: tColor, size: 18),
            Text(tText, style: TextStyle(color: tColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ]
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(12), 
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.1))), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20), 
              const SizedBox(width: 6), 
              Expanded(
                child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)
              ),
            ]
          ),
          const SizedBox(height: 6), 
          Row(
            children: [
              Expanded(
                child: Text(value, style: TextStyle(color: color.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis))
              ),
              if (trendWidget is! SizedBox) ...[
                const SizedBox(width: 4),
                trendWidget
              ]
            ]
          ),
          if (extraDetails != null) ...[
            const SizedBox(height: 6),
            extraDetails
          ]
        ]
      )
    );
  }

  // --- Summary 4 Tiles ---
  Widget _buildSummaryGrid(BuildContext context, NumberFormat weightF, NumberFormat currencyF) { 
    return LayoutBuilder(
      builder: (context, constraints) {
        double w = constraints.maxWidth;
        bool isMobile = w < 550; 
        bool isTablet = w < 900;
        
        double cardW = isMobile ? w : (isTablet ? (w - 12) / 2 : (w - 36) / 4);

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(width: cardW, child: _summaryCard(title: 'මුළු දළු', value: '${weightF.format(_totalWeight)} Kg', icon: Icons.eco, color: Colors.green)),
            SizedBox(width: cardW, child: _summaryCard(title: 'අත්තිකාරම්', value: 'Rs. ${currencyF.format(_totalAdvance)}', icon: Icons.payments, color: Colors.blue)),
            SizedBox(width: cardW, child: _summaryCard(title: 'පොහොර', value: weightF.format(_totalFertilizer1 + _totalFertilizer2), icon: Icons.compost, color: const Color.fromARGB(255, 1, 64, 3), subItems: [_buildSubItemIcon(Icons.compost, weightF.format(_totalFertilizer1), Colors.red), _buildSubItemIcon(Icons.compost, weightF.format(_totalFertilizer2), Colors.blue)])),
            SizedBox(width: cardW, child: _summaryCard(title: 'තේ පැකට්', value: weightF.format(_totalTeaPacket1 + _totalTeaPacket2), icon: Icons.local_cafe, color: Colors.orange, subItems: [_buildSubItemIcon(Icons.local_cafe, weightF.format(_totalTeaPacket1), Colors.red), _buildSubItemIcon(Icons.local_cafe, weightF.format(_totalTeaPacket2), Colors.blue)])),
          ]
        );
      }
    );
  }
  
  // කාඩ්පත් 4ටම ස්ථිර උසක් සහ සමාන Alignment එකක් ලබා දීම
  Widget _summaryCard({required String title, required String value, required IconData icon, required Color color, List<Widget>? subItems}) => Container(
    height: 135, // කාඩ්පත් 4ම එකම උසකට ගෙන ඒම
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), 
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5)]), 
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center, 
      children: [
        Icon(icon, color: color, size: 26), 
        const SizedBox(height: 8), 
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)), 
        const SizedBox(height: 4),
        // Sub items නැති වුනත් හිස් ඉඩක් වෙන් කර තබයි (Alignment එක සමාන වීමට)
        SizedBox(
          height: 16, 
          child: subItems != null ? Row(mainAxisAlignment: MainAxisAlignment.center, children: subItems) : null
        ), 
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600))
      ]
    )
  );

  Widget _buildSubItemIcon(IconData icon, String val, Color c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Row(children: [Icon(icon, size: 10, color: c), const SizedBox(width: 2), Text(val, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))]));
  Widget _buildTopSuppliersList(NumberFormat weightF) { if (_topSuppliers.isEmpty) return const Center(child: Text('දත්ත නොමැත', style: TextStyle(color: Colors.grey))); return Column(children: _topSuppliers.map((s) => Card(margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: ListTile(leading: CircleAvatar(backgroundColor: Colors.green.shade50, child: Text((_topSuppliers.indexOf(s) + 1).toString(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))), title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), trailing: Text('${weightF.format(s['weight'])} Kg', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))))).toList()); }
  Widget _buildTopArrearsList(NumberFormat currencyF) { if (_topArrears.isEmpty) return const Center(child: Text('හිඟ මුදල් පියවා ඇත', style: TextStyle(color: Colors.green))); return Column(children: _topArrears.map((a) => Card(margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), color: Colors.red.shade50, child: ListTile(leading: CircleAvatar(backgroundColor: Colors.red.shade100, child: Text((_topArrears.indexOf(a) + 1).toString(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))), title: Text(a['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), trailing: Text('Rs. ${currencyF.format(a['amount'])}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))))).toList()); }
  Widget _buildSectionHeader(String title, String value, List<String> options, Function(String?) onChanged) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), Container(padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)), child: DropdownButton<String>(value: value, underline: const SizedBox(), items: options.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(), onChanged: onChanged))]);
  Widget _loader() => const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
}