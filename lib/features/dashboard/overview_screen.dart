import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; 

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  // --- ප්‍රධාන සාරාංශය (Summary) සඳහා විචල්‍යයන් ---
  String _selectedFilter = 'අද'; 
  bool _isLoading = true;

  double _totalWeight = 0.0;
  double _totalAdvance = 0.0;
  double _totalFertilizer1 = 0.0;
  double _totalFertilizer2 = 0.0;
  double _totalTeaPacket1 = 0.0;
  double _totalTeaPacket2 = 0.0;
  int _totalCustomers = 0; 

  final List<String> _filterOptions = [
    'අද', 'මෙම සතිය', 'මෙම මාසය', 'පසුගිය මාසය', 'පසුගිය මාස 6'
  ];

  // --- ප්‍රස්ථාරය (Chart) සඳහා විචල්‍යයන් ---
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

  // 1. ප්‍රධාන සාරාංශ කාඩ්පත් සඳහා දත්ත ලබා ගැනීම
  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);

    DateTime now = DateTime.now();
    DateTime start;
    DateTime end;

    if (_selectedFilter == 'අද') {
      start = DateTime(now.year, now.month, now.day);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedFilter == 'මෙම සතිය') {
      start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      end = DateTime(now.year, now.month, now.day, 23, 59, 59).add(Duration(days: 7 - now.weekday));
    } else if (_selectedFilter == 'මෙම මාසය') {
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else if (_selectedFilter == 'පසුගිය මාසය') {
      start = DateTime(now.year, now.month - 1, 1);
      end = DateTime(now.year, now.month, 0, 23, 59, 59);
    } else { 
      start = DateTime(now.year, now.month - 5, 1);
      end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    }

    try {
      var customersSnapshot = await FirebaseFirestore.instance.collection('Customers').get();
      Set<String> activeCustomerIds = customersSnapshot.docs.map((doc) => doc.id).toSet();
      int customers = activeCustomerIds.length;

      var entriesSnapshot = await FirebaseFirestore.instance
          .collection('DailyEntries')
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThanOrEqualTo: end)
          .get();

      double weight = 0.0, advance = 0.0;
      double f1 = 0.0, f2 = 0.0, t1 = 0.0, t2 = 0.0;

      for (var doc in entriesSnapshot.docs) {
        var data = doc.data();
        if (activeCustomerIds.contains(data['customerId'])) {
          weight += (data['netWeight'] ?? 0).toDouble();
          advance += (data['advanceAmount'] ?? 0).toDouble();
          f1 += (data['fertilizer1Qty'] ?? 0).toDouble();
          f2 += (data['fertilizer2Qty'] ?? 0).toDouble();
          t1 += (data['teaPacket1Qty'] ?? 0).toDouble();
          t2 += (data['teaPacket2Qty'] ?? 0).toDouble();
        }
      }

      if (mounted) {
        setState(() {
          _totalCustomers = customers; 
          _totalWeight = weight;
          _totalAdvance = advance;
          _totalFertilizer1 = f1;  _totalFertilizer2 = f2;
          _totalTeaPacket1 = t1;   _totalTeaPacket2 = t2;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. ප්‍රස්ථාරය (Line Chart) සඳහා අදාළ දත්ත ලබා ගැනීම
  Future<void> _fetchChartData() async {
    setState(() => _isChartLoading = true);
    
    DateTime now = DateTime.now();
    DateTime start;

    if (_chartFilter == 'දිනපතා') {
      start = DateTime(now.year, now.month, now.day - 6); 
    } else if (_chartFilter == 'සතිපතා') {
      start = DateTime(now.year, now.month, now.day - 27); 
    } else {
      start = DateTime(now.year, now.month - 5, 1); 
    }

    try {
      var customersSnapshot = await FirebaseFirestore.instance.collection('Customers').get();
      Set<String> activeCustomerIds = customersSnapshot.docs.map((doc) => doc.id).toSet();

      var entriesSnapshot = await FirebaseFirestore.instance
          .collection('DailyEntries')
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThanOrEqualTo: DateTime(now.year, now.month, now.day, 23, 59, 59))
          .get();

      List<double> tempValues = [];
      List<String> tempLabels = [];

      if (_chartFilter == 'දිනපතා') {
        tempValues = List.filled(7, 0.0);
        // දවසේ නම් වෙනුවට දිනය (Date) ලබා ගැනීමට වෙනස් කරන ලදී
        for (int i = 6; i >= 0; i--) {
          tempLabels.add(now.subtract(Duration(days: i)).day.toString()); // උදා: 1, 2, 15, 28
        }
        
        for (var doc in entriesSnapshot.docs) {
          var data = doc.data();
          if (activeCustomerIds.contains(data['customerId'])) {
            DateTime ts = (data['timestamp'] as Timestamp).toDate();
            int diff = DateTime(now.year, now.month, now.day).difference(DateTime(ts.year, ts.month, ts.day)).inDays;
            if (diff >= 0 && diff < 7) tempValues[6 - diff] += (data['netWeight'] ?? 0).toDouble();
          }
        }
      } else if (_chartFilter == 'සතිපතා') {
        tempValues = List.filled(4, 0.0);
        tempLabels = ['සති 4', 'සති 3', 'සති 2', 'මේ සතිය'];
        
        for (var doc in entriesSnapshot.docs) {
          var data = doc.data();
          if (activeCustomerIds.contains(data['customerId'])) {
            DateTime ts = (data['timestamp'] as Timestamp).toDate();
            int diff = DateTime(now.year, now.month, now.day).difference(DateTime(ts.year, ts.month, ts.day)).inDays;
            if (diff >= 0 && diff < 28) tempValues[3 - (diff ~/ 7)] += (data['netWeight'] ?? 0).toDouble();
          }
        }
      } else if (_chartFilter == 'මාසිකව') {
        tempValues = List.filled(6, 0.0);
        for (int i = 5; i >= 0; i--) tempLabels.add(DateFormat('MMM').format(DateTime(now.year, now.month - i, 1)));
        
        for (var doc in entriesSnapshot.docs) {
          var data = doc.data();
          if (activeCustomerIds.contains(data['customerId'])) {
            DateTime ts = (data['timestamp'] as Timestamp).toDate();
            int diff = (now.year - ts.year) * 12 + now.month - ts.month;
            if (diff >= 0 && diff < 6) tempValues[5 - diff] += (data['netWeight'] ?? 0).toDouble();
          }
        }
      }

      if (mounted) {
        setState(() {
          _chartValues = tempValues;
          _chartLabels = tempLabels;
          _isChartLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isChartLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final NumberFormat weightFormat = NumberFormat('#,##0.##', 'en_US');
    final NumberFormat qtyFormat = NumberFormat('#,##0.##', 'en_US');

    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 900 ? 4 : (screenWidth > 600 ? 3 : 2); 

    double totalFertilizer = _totalFertilizer1 + _totalFertilizer2;
    double totalTeaPackets = _totalTeaPacket1 + _totalTeaPacket2;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          // --- 1. මුළු ගනුදෙනුකරුවන් ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('මුළු ලියාපදිංචි', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    SizedBox(height: 4),
                    Text('ගනුදෙනුකරුවන්', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      _isLoading ? '--' : _totalCustomers.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.people_alt, color: Colors.white, size: 40),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),

          // --- 2. ප්‍රධාන සාරාංශය (Filter සහ Cards) ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('දෛනික සාරාංශය', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButton<String>(
                  value: _selectedFilter,
                  underline: const SizedBox(), 
                  icon: Icon(Icons.calendar_month, color: Theme.of(context).primaryColor),
                  items: _filterOptions.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)))).toList(),
                  onChanged: (newValue) {
                    if (newValue != null && newValue != _selectedFilter) {
                      setState(() => _selectedFilter = newValue);
                      _fetchDashboardData(); 
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _isLoading 
            ? const Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator()))
            : GridView.count(
                crossAxisCount: crossAxisCount, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.95, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildSummaryCard(title: 'තේ දළු (ශුද්ධ)', value: '${weightFormat.format(_totalWeight)} Kg', icon: Icons.eco, color: Colors.green),
                  _buildSummaryCard(title: 'අත්තිකාරම්', value: 'Rs. ${currencyFormat.format(_totalAdvance)}', icon: Icons.money, color: Colors.blue),
                  _buildSummaryCard(
                    title: 'පොහොර මලු', value: qtyFormat.format(totalFertilizer), 
                    subItems: ['වර්ගය 1: ${qtyFormat.format(_totalFertilizer1)}', 'වර්ගය 2: ${qtyFormat.format(_totalFertilizer2)}'], icon: Icons.eco, color: Colors.brown,
                  ),
                  _buildSummaryCard(
                    title: 'තේ පැකට්', value: qtyFormat.format(totalTeaPackets), 
                    subItems: ['පැකට් 1: ${qtyFormat.format(_totalTeaPacket1)}', 'පැකට් 2: ${qtyFormat.format(_totalTeaPacket2)}'], icon: Icons.local_cafe, color: Colors.orange,
                  ),
                ],
              ),
          
          const SizedBox(height: 30),

          // --- 3. Line Chart එක ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('තේ දළු එකතුව (Kg)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                height: 35,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _chartFilter,
                  underline: const SizedBox(), 
                  icon: Icon(Icons.show_chart, color: Theme.of(context).primaryColor, size: 20),
                  items: _chartFilterOptions.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)))).toList(),
                  onChanged: (newValue) {
                    if (newValue != null && newValue != _chartFilter) {
                      setState(() => _chartFilter = newValue);
                      _fetchChartData(); 
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _isChartLoading 
            ? const Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator()))
            : Container(
                width: double.infinity,
                height: 250, 
                padding: const EdgeInsets.only(top: 24, bottom: 12, left: 8, right: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(_chartValues.length, (index) => FlSpot(index.toDouble(), _chartValues[index])),
                        isCurved: true, 
                        color: Theme.of(context).primaryColor,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true), 
                        belowBarData: BarAreaData(
                          show: true,
                          color: Theme.of(context).primaryColor.withOpacity(0.15), 
                        ),
                      ),
                    ],
                    minY: 0,
                    maxY: _chartValues.isEmpty ? 100 : (_chartValues.reduce((a, b) => a > b ? a : b) * 1.3).clamp(10.0, double.infinity),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (group) => Colors.blueGrey.shade800,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) => LineTooltipItem('${spot.y.toStringAsFixed(1)} Kg', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))).toList();
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            if (index >= 0 && index < _chartLabels.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(_chartLabels[index], style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 45,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox();
                            return Text(value.toInt().toString(), style: const TextStyle(fontSize: 11, color: Colors.grey));
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({required String title, required String value, List<String>? subItems, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(6), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 24, color: color), 
          ),
          const SizedBox(height: 8), 
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (subItems != null && subItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Column(
                children: subItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(item, style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                )).toList(),
              ),
            ),
          const SizedBox(height: 2), 
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}