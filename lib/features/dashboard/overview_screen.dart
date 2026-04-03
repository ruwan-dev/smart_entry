import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

// අලුත් File එක Import කරගන්න (Path එක ඔයාගේ විදිහට වෙනස් කරන්න ඕනේ නම් කරන්න)
import 'outstanding_list_screen.dart'; 

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

  double fert1Price = 0, fert2Price = 0, teaPkt1Price = 0, teaPkt2Price = 0;

  List<Map<String, dynamic>> _topSuppliers = [];
  List<Map<String, dynamic>> _topArrears = [];
  List<Map<String, dynamic>> _allArrears = []; // <--- සම්පූර්ණ හිඟ ලැයිස්තුව තියාගන්න අලුත් List එක
  
  final List<String> _filterOptions = ['අද', 'මෙම සතිය', 'මෙම මාසය', 'පසුගිය මාසය', 'පසුගිය මාස 6'];

  String _chartFilter = 'දිනපතා';
  bool _isChartLoading = true;
  List<double> _chartValues = [0, 0, 0, 0, 0, 0, 0];
  List<String> _chartLabels = ["", "", "", "", "", "", ""];
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
        customerNames[doc.id] = doc.data()['name'] ?? 'නමක් නැත';
      }

      var filteredEntries = await FirebaseFirestore.instance
          .collection('DailyEntries')
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThanOrEqualTo: end)
          .get();

      double totalWeight = 0.0, totalAdvance = 0.0;
      double f1 = 0.0, f2 = 0.0, t1 = 0.0, t2 = 0.0;
      Map<String, double> supplierWeightMap = {};

      for (var doc in filteredEntries.docs) {
        var data = doc.data();
        String cId = data['customerId'] ?? '';
        double w = (data['netWeight'] ?? 0.0).toDouble();
        
        totalWeight += w;
        totalAdvance += (data['advanceAmount'] ?? 0.0).toDouble();
        f1 += (data['fertilizer1Qty'] ?? 0.0).toDouble();
        f2 += (data['fertilizer2Qty'] ?? 0.0).toDouble();
        t1 += (data['teaPacket1Qty'] ?? 0.0).toDouble();
        t2 += (data['teaPacket2Qty'] ?? 0.0).toDouble();

        if (cId.isNotEmpty) supplierWeightMap[cId] = (supplierWeightMap[cId] ?? 0.0) + w;
      }

      var sortedSuppliers = supplierWeightMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      List<Map<String, dynamic>> top5 = sortedSuppliers.take(5).map((e) => {'name': customerNames[e.key] ?? 'Unknown', 'weight': e.value}).toList();

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
        double income = w * rate;
        double deductions = adv + (qF1 * fert1Price) + (qF2 * fert2Price) + (qT1 * teaPkt1Price) + (qT2 * teaPkt2Price);

        customerIncomeMap[cId] = (customerIncomeMap[cId] ?? 0.0) + income;
        customerDeductionMap[cId] = (customerDeductionMap[cId] ?? 0.0) + deductions;
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

      var sortedArrears = arrearsMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      
      // සම්පූර්ණ ලැයිස්තුව හදාගන්නවා
      List<Map<String, dynamic>> allArrearsList = sortedArrears.map((e) => {
        'name': customerNames[e.key] ?? 'Unknown',
        'amount': e.value
      }).toList();
      
      // Top 5 විතරක් වෙනම අරගන්නවා
      List<Map<String, dynamic>> topArrears5 = allArrearsList.take(5).toList();

      if (mounted) {
        setState(() {
          _totalCustomers = customersSnapshot.docs.length;
          _totalWeight = totalWeight;
          _totalAdvance = totalAdvance;
          _totalFertilizer1 = f1; _totalFertilizer2 = f2;
          _totalTeaPacket1 = t1; _totalTeaPacket2 = t2;
          _topSuppliers = top5;
          _overallOutstandingAdvances = totalOverallOutstanding; 
          _topArrears = topArrears5; 
          _allArrears = allArrearsList; // <--- සම්පූර්ණ ලැයිස්තුව Save කරගන්නවා
          _isLoading = false;
        });
      }
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

 Future<void> _fetchChartData() async {
    setState(() => _isChartLoading = true);
    DateTime now = DateTime.now();
    DateTime start;

    if (_chartFilter == 'දිනපතා') {
      start = DateTime(now.year, now.month, now.day - 29);
    } else if (_chartFilter == 'සතිපතා') {
      start = DateTime(now.year, now.month, now.day - 27);
    } else {
      start = DateTime(now.year, now.month - 5, 1);
    }

    try {
      var entriesSnapshot = await FirebaseFirestore.instance
          .collection('DailyEntries')
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .get();

      List<double> tempValues = [];
      List<String> tempLabels = [];

      if (_chartFilter == 'දිනපතා') {
        tempValues = List.filled(30, 0.0);
        for (int i = 29; i >= 0; i--) {
          // මෙතන තමයි දවස සහ මාසය එකතු කරන්නේ (උදා: Apr 01)
          DateTime date = now.subtract(Duration(days: i));
          tempLabels.add(DateFormat('MMM dd').format(date)); 
        }
        for (var doc in entriesSnapshot.docs) {
          var data = doc.data();
          DateTime ts = (data['timestamp'] as Timestamp).toDate();
          int diff = DateTime(now.year, now.month, now.day)
              .difference(DateTime(ts.year, ts.month, ts.day))
              .inDays;
          if (diff >= 0 && diff < 30) tempValues[29 - diff] += (data['netWeight'] ?? 0.0).toDouble();
        }
      } else if (_chartFilter == 'සතිපතා') {
        tempValues = List.filled(4, 0.0);
        tempLabels = ['සති 4', 'සති 3', 'සති 2', 'මේ සතිය'];
        for (var doc in entriesSnapshot.docs) {
          var data = doc.data();
          DateTime ts = (data['timestamp'] as Timestamp).toDate();
          int diff = DateTime(now.year, now.month, now.day).difference(DateTime(ts.year, ts.month, ts.day)).inDays;
          if (diff >= 0 && diff < 28) tempValues[3 - (diff ~/ 7)] += (data['netWeight'] ?? 0.0).toDouble();
        }
      } else {
        tempValues = List.filled(6, 0.0);
        for (int i = 5; i >= 0; i--) tempLabels.add(DateFormat('MMM').format(DateTime(now.year, now.month - i, 1)));
        for (var doc in entriesSnapshot.docs) {
          var data = doc.data();
          DateTime ts = (data['timestamp'] as Timestamp).toDate();
          int diff = (now.year - ts.year) * 12 + now.month - ts.month;
          if (diff >= 0 && diff < 6) tempValues[5 - diff] += (data['netWeight'] ?? 0.0).toDouble();
        }
      }

      if (mounted) setState(() { _chartValues = tempValues; _chartLabels = tempLabels; _isChartLoading = false; });
    } catch (e) { if (mounted) setState(() => _isChartLoading = false); }
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBanner(),
              const SizedBox(height: 20),
              // මෙතනට context එක pass කළා Navigator එක පාවිච්චි කරන්න
              _buildFinancialRiskCard(context, currencyF), 
              const SizedBox(height: 24),
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
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                  SizedBox(width: 8),
                  Text('සමස්ත හිඟ මුදල් ඇති අය (All-Time)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
              const SizedBox(height: 12),
              _isLoading ? _loader() : _buildTopArrearsList(currencyF),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBanner() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.green.shade700, Colors.green.shade400]), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('මුළු ලියාපදිංචි පිරිස', style: TextStyle(color: Colors.white70, fontSize: 13)), Text('ගනුදෙනුකරුවන්', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
        Text(_totalCustomers.toString(), style: const TextStyle(color: Colors.white, fontSize: 35, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // --- අලුත් කරපු Clickable Tile එක ---
  Widget _buildFinancialRiskCard(BuildContext context, NumberFormat currency) {
    return InkWell(
      onTap: () {
        // Tile එක Click කරාම අලුත් Screen එකට යනවා
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OutstandingListScreen(arrearsList: _allArrears),
          ),
        );
      },
      borderRadius: BorderRadius.circular(15), // Click Effect එක ලස්සනට එන්න
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.red.shade100)),
        child: Row(children: [
          const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.account_balance_wallet, color: Colors.white)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('මුළු හිඟ මුදල් (All-Time Arrears)', style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text('Rs. ${currency.format(_overallOutstandingAdvances)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red))
            ]),
          ),
          // Click කරන්න පුළුවන් බව පෙන්වන ඊතලය
          const Icon(Icons.arrow_forward_ios, color: Colors.red, size: 18),
        ]),
      ),
    );
  }

  Widget _buildSummaryGrid(BuildContext context, NumberFormat weightF, NumberFormat currencyF) {
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 800 ? 4 : 2;
    double aspectRatio = screenWidth > 800 ? 1.8 : 1.1;

    return GridView.count(
      crossAxisCount: crossAxisCount, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: aspectRatio, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      children: [
        _summaryCard(title: 'මුළු දළු', value: '${weightF.format(_totalWeight)} Kg', icon: Icons.eco, color: Colors.green),
        _summaryCard(title: 'අත්තිකාරම්', value: 'Rs. ${currencyF.format(_totalAdvance)}', icon: Icons.payments, color: Colors.blue),
        _summaryCard(
          title: 'පොහොර', value: weightF.format(_totalFertilizer1 + _totalFertilizer2), icon: Icons.compost, color: const Color.fromARGB(255, 1, 64, 3),
          subItems: [ _buildSubItemIcon(Icons.compost, weightF.format(_totalFertilizer1), Colors.red), _buildSubItemIcon(Icons.compost, weightF.format(_totalFertilizer2), Colors.blue) ]
        ),
        _summaryCard(
          title: 'තේ පැකට්', value: weightF.format(_totalTeaPacket1 + _totalTeaPacket2), icon: Icons.local_cafe, color: Colors.orange,
          subItems: [ _buildSubItemIcon(Icons.local_cafe, weightF.format(_totalTeaPacket1), Colors.red), _buildSubItemIcon(Icons.local_cafe, weightF.format(_totalTeaPacket2), Colors.blue) ]
        ),
      ],
    );
  }

  Widget _summaryCard({required String title, required String value, required IconData icon, required Color color, List<Widget>? subItems}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5)]),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          if (subItems != null) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: subItems)),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSubItemIcon(IconData icon, String val, Color c) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Row(children: [Icon(icon, size: 10, color: c), const SizedBox(width: 2), Text(val, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))]));
  }

  Widget _buildTopSuppliersList(NumberFormat weightF) {
    if (_topSuppliers.isEmpty) return const Center(child: Text('දත්ත නොමැත', style: TextStyle(color: Colors.grey)));
    return Column(children: _topSuppliers.map((s) => Card(margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: ListTile(leading: CircleAvatar(backgroundColor: Colors.green.shade50, child: Text((_topSuppliers.indexOf(s) + 1).toString(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))), title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), trailing: Text('${weightF.format(s['weight'])} Kg', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))))).toList());
  }

  Widget _buildTopArrearsList(NumberFormat currencyF) {
    if (_topArrears.isEmpty) return const Center(child: Text('සියලු දෙනාගේ හිඟ මුදල් පියවා ඇත', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)));
    return Column(
      children: _topArrears.map((a) => Card(
        margin: const EdgeInsets.only(bottom: 8), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
        color: Colors.red.shade50,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.red.shade100, 
            child: Text((_topArrears.indexOf(a) + 1).toString(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ), 
          title: Text(a['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), 
          trailing: Text('Rs. ${currencyF.format(a['amount'])}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
        )
      )).toList()
    );
  }

Widget _buildChartContainer() {
    double maxVal = _chartValues.isNotEmpty ? _chartValues.reduce((a, b) => a > b ? a : b) : 100.0;
    if (maxVal == 0) maxVal = 100.0;
    
    return Container(
      height: 250, 
      padding: const EdgeInsets.only(top: 25, right: 25, left: 0, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
      ),
      child: LineChart(LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, 
            reservedSize: 35, // අකුරු වලට ඉඩ මදි නිසා සයිස් එක ටිකක් වැඩි කළා
            interval: _chartFilter == 'දිනපතා' ? 5 : 1, 
            getTitlesWidget: (v, m) {
              int idx = v.toInt();
              if (idx >= 0 && idx < _chartLabels.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    _chartLabels[idx], 
                    style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)
                  ),
                );
              }
              return const Text("");
            }
          )),
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, 
            reservedSize: 35,
            getTitlesWidget: (value, meta) {
              if (value == 0) return const SizedBox.shrink(); 
              return Text('${value.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold));
            }
          )),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxVal * 1.3, 
        lineTouchData: LineTouchData(
          enabled: true, 
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.green.shade800,
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) => LineTooltipItem('${spot.y.toStringAsFixed(1)} Kg', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(_chartValues.length, (i) => FlSpot(i.toDouble(), _chartValues[i])), 
            isCurved: true, color: Colors.green, barWidth: 3, dotData: const FlDotData(show: false), 
            belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.1)),
          )
        ],
      )),
    );
  }
  
  Widget _buildSectionHeader(String title, String value, List<String> options, Function(String?) onChanged) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), Container(padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)), child: DropdownButton<String>(value: value, underline: const SizedBox(), items: options.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(), onChanged: onChanged))]);
  }

  Widget _loader() => const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
}