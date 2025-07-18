import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../ui/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/food_service.dart';
import '../../models/food_entry.dart';
import 'dart:math';
import 'dart:ui';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final FoodService _foodService = FoodService();
  User? _user;
  String? _userId;
  int weightGoal = 109;
  int currentWeight = 119;
  double bmi = 19.8;
  String bmiStatus = 'Healthy';
  Color bmiStatusColor = kAccentBlue;
  int streak = 0;
  double goalProgress = 0.0;
  int selectedTimeRange = 0; // 0: 90 Days, 1: 6 Months, 2: 1 Year, 3: All time
  int selectedNutritionTab = 0; // 0: This Week, 1: Last Week, ...

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _userId = _user?.uid;
  }

  // Helper to fetch user document
  Stream<DocumentSnapshot<Map<String, dynamic>>> get _userDocStream {
    if (_userId == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance.collection('users').doc(_userId).snapshots();
  }

  // Helper to get latest weight (could be a field or from entries)
  int _getCurrentWeight(Map<String, dynamic>? userData) {
    if (userData == null) return 0;
    // Prefer 'currentWeight' field, fallback to last weight log if available
    return userData['currentWeight'] ?? 0;
  }

  double _getHeight(Map<String, dynamic>? userData) {
    if (userData == null) return 1.7; // default 1.7m
    return (userData['height'] ?? 1.7).toDouble();
  }

  int _getGoal(Map<String, dynamic>? userData) {
    if (userData == null) return 2000;
    return userData['goal'] ?? 2000;
  }

  int _getStreak(Map<String, dynamic>? userData) {
    if (userData == null) return 0;
    final streaks = userData['streaks'] ?? [];
    final List<DateTime> streakDays = streaks.map<DateTime>((e) => DateTime.fromMillisecondsSinceEpoch(e)).toList();
    int streak = 0;
    DateTime day = DateTime.now();
    while (streakDays.any((d) => d.year == day.year && d.month == day.month && d.day == day.day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  double _calculateBMI(int weight, double height) {
    if (weight == 0 || height == 0) return 0.0;
    return weight / (height * height);
  }

  String _bmiStatus(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Healthy';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Color _bmiStatusColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return kAccentBlue;
    if (bmi < 30) return Colors.yellow[700]!;
    return Colors.red;
  }

  Future<void> _showUpdateGoalDialog(int currentGoal) async {
    final controller = TextEditingController(text: currentGoal.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Weight Goal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Weight Goal (lbs)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result > 0 && _userId != null) {
      await FirebaseFirestore.instance.collection('users').doc(_userId).set({'goal': result}, SetOptions(merge: true));
      setState(() {}); // Refresh UI
    }
  }

  Future<void> _showLogWeightDialog(int currentWeight) async {
    final controller = TextEditingController(text: currentWeight.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Current Weight'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Current Weight (lbs)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result > 0 && _userId != null) {
      await FirebaseFirestore.instance.collection('users').doc(_userId).set({'currentWeight': result}, SetOptions(merge: true));
      setState(() {}); // Refresh UI
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: kAppBackground,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text('Analytics', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: kTextDark)),
                const SizedBox(height: 10),
                // Weight Goal & Current Weight
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _userDocStream,
                  builder: (context, snapshot) {
                    final userData = snapshot.data?.data();
                    final weightGoalKg = (userData != null && userData['goal'] != null) ? userData['goal'] as int : 0;
                    final currentWeightKg = (userData != null && userData['currentWeight'] != null) ? userData['currentWeight'] as int : 0;
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _PremiumCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: kAccentBlue.withOpacity(0.35),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: kAccentBlue.withOpacity(0.7), width: 2),
                                      boxShadow: [BoxShadow(color: kAccentBlue.withOpacity(0.08), blurRadius: 16, offset: Offset(0, 8))],
                                    ),
                                    padding: EdgeInsets.all(10),
                                    child: Icon(Icons.emoji_events, color: Color(0xFFFFC107), size: 28),
                                  ),
                                  const SizedBox(height: 10),
                                  Text('Weight Goal', style: TextStyle(fontSize: 15, color: kTextDark, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      TweenAnimationBuilder<double>(
                                        tween: Tween<double>(begin: 0, end: weightGoalKg.toDouble()),
                                        duration: Duration(milliseconds: 800),
                                        builder: (context, value, child) => Text(
                                          value.toStringAsFixed(1),
                                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFFFFC107), fontFamily: 'Poppins'),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text('kg', style: TextStyle(fontSize: 13, color: Color(0xFFFFC107), fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Stay motivated to reach your goal!', style: TextStyle(fontSize: 12, color: kTextGrey, fontWeight: FontWeight.w500)),
                                  const Spacer(),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kAccentBlue,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        elevation: 4,
                                        shadowColor: Colors.black.withOpacity(0.15),
                                      ),
                                      onPressed: () async {
                                        final controller = TextEditingController(text: weightGoalKg.toString());
                                        final result = await showDialog<int>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Set Weight Goal'),
                                            content: TextField(
                                              controller: controller,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(labelText: 'Weight Goal (kg)'),
                                            ),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
                                                child: const Text('Save'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (result != null && result > 0 && _userId != null) {
                                          await FirebaseFirestore.instance.collection('users').doc(_userId).set({'goal': result}, SetOptions(merge: true));
                                        }
                                      },
                                      child: const Text('Update', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PremiumCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: kAccentBlue.withOpacity(0.35),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: kAccentBlue.withOpacity(0.7), width: 2),
                                      boxShadow: [BoxShadow(color: kAccentBlue.withOpacity(0.08), blurRadius: 16, offset: Offset(0, 8))],
                                    ),
                                    padding: EdgeInsets.all(10),
                                    child: Icon(Icons.monitor_weight, color: Color(0xFF1976D2), size: 28),
                                  ),
                                  const SizedBox(height: 10),
                                  Text('Current Weight', style: TextStyle(fontSize: 15, color: kTextDark, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      TweenAnimationBuilder<double>(
                                        tween: Tween<double>(begin: 0, end: currentWeightKg.toDouble()),
                                        duration: Duration(milliseconds: 800),
                                        builder: (context, value, child) => Text(
                                          value.toStringAsFixed(1),
                                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1976D2), fontFamily: 'Poppins'),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text('kg', style: TextStyle(fontSize: 13, color: Color(0xFF1976D2), fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Try to update once a week so we can adjust your plan to ensure you hit your goal.', style: TextStyle(fontSize: 12, color: kTextGrey, fontWeight: FontWeight.w500)),
                                  const Spacer(),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kAccentBlue,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        elevation: 4,
                                        shadowColor: Colors.black.withOpacity(0.15),
                                      ),
                                      onPressed: () async {
                                        final controller = TextEditingController(text: currentWeightKg.toString());
                                        final result = await showDialog<int>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Log Current Weight'),
                                            content: TextField(
                                              controller: controller,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(labelText: 'Current Weight (kg)'),
                                            ),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
                                                child: const Text('Save'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (result != null && result > 0 && _userId != null) {
                                          await FirebaseFirestore.instance.collection('users').doc(_userId).set({'currentWeight': result}, SetOptions(merge: true));
                                        }
                                      },
                                      child: const Text('Log weight', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                // BMI Section
                Text('Your BMI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
                const SizedBox(height: 10),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _userDocStream,
                  builder: (context, snapshot) {
                    final userData = snapshot.data?.data();
                    final weightKg = (userData != null && userData['currentWeight'] != null) ? (userData['currentWeight'] as int).toDouble() : 0.0;
                    final heightM = (userData != null && userData['height'] != null) ? (userData['height'] as num).toDouble() : 0.0;
                    final bmi = (weightKg > 0 && heightM > 0) ? weightKg / (heightM * heightM) : 0.0;
                    String bmiStatus;
                    Color bmiStatusColor;
                    if (bmi < 18.5) {
                      bmiStatus = 'Underweight';
                      bmiStatusColor = Colors.blue;
                    } else if (bmi < 25) {
                      bmiStatus = 'Healthy';
                      bmiStatusColor = kAccentBlue;
                    } else if (bmi < 30) {
                      bmiStatus = 'Overweight';
                      bmiStatusColor = Colors.yellow[700]!;
                    } else {
                      bmiStatus = 'Obese';
                      bmiStatusColor = Colors.red;
                    }
                    return _PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: bmiStatusColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('Your weight is $bmiStatus', style: TextStyle(fontSize: 12, color: kTextDark, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: Icon(Icons.info_outline, color: kTextGrey, size: 18),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('BMI Disclaimer'),
                                      content: const Text(
                                        'BMI (Body Mass Index) is a general guideline and may not accurately reflect your individual health.\n\n'
                                        '- BMI does not account for muscle mass, bone density, age, gender, or overall body composition.\n'
                                        '- Always consult a healthcare professional for personalized health advice.'
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('OK'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: bmi),
                                duration: const Duration(milliseconds: 800),
                                builder: (context, val, child) => Text(val.toStringAsFixed(1), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: kTextDark)),
                              ),
                              const SizedBox(width: 8),
                              Text('BMI', style: TextStyle(fontSize: 16, color: kTextGrey)),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: Size(36, 32),
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                  side: BorderSide(color: kTextGrey.withOpacity(0.3)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () async {
                                  await showDialog<void>(
                                    context: context,
                                    builder: (context) {
                                      String selectedUnit = 'm';
                                      double initialHeight = heightM > 0 ? heightM : 0.0;
                                      final controller = TextEditingController(
                                        text: initialHeight > 0
                                          ? initialHeight.toStringAsFixed(3)
                                          : ''
                                      );
                                      return StatefulBuilder(
                                        builder: (context, setState) {
                                          void updateControllerText(String newUnit) {
                                            double val = double.tryParse(controller.text) ?? 0.0;
                                            if (controller.text.isEmpty) {
                                              setState(() => selectedUnit = newUnit);
                                              return;
                                            }
                                            if (newUnit == selectedUnit) return;
                                            if (newUnit == 'cm' && selectedUnit == 'm') {
                                              controller.text = (val * 100).toStringAsFixed(1);
                                            } else if (newUnit == 'm' && selectedUnit == 'cm') {
                                              controller.text = (val / 100).toStringAsFixed(3);
                                            }
                                            setState(() => selectedUnit = newUnit);
                                          }
                                          return AlertDialog(
                                            title: const Text('Update Height'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                TextField(
                                                  controller: controller,
                                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                                  decoration: InputDecoration(labelText: 'Height (${selectedUnit == 'm' ? 'meters' : 'centimeters'})'),
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    ChoiceChip(
                                                      label: Text('Meters'),
                                                      selected: selectedUnit == 'm',
                                                      onSelected: (selected) {
                                                        if (selected) updateControllerText('m');
                                                      },
                                                    ),
                                                    const SizedBox(width: 8),
                                                    ChoiceChip(
                                                      label: Text('Centimeters'),
                                                      selected: selectedUnit == 'cm',
                                                      onSelected: (selected) {
                                                        if (selected) updateControllerText('cm');
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                              ElevatedButton(
                                                onPressed: () {
                                                  double val = double.tryParse(controller.text) ?? 0.0;
                                                  if (val > 0 && _userId != null) {
                                                    double meters = selectedUnit == 'cm' ? val / 100.0 : val;
                                                    FirebaseFirestore.instance.collection('users').doc(_userId).set({'height': meters}, SetOptions(merge: true));
                                                  }
                                                  Navigator.pop(context);
                                                },
                                                child: const Text('Save'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                                child: Text('Edit', style: TextStyle(fontSize: 13, color: kTextGrey)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _BmiBarSegment(color: Colors.blue, label: 'Underweight'),
                              _BmiBarSegment(color: kAccentBlue, label: 'Healthy'),
                              _BmiBarSegment(color: Colors.yellow[700]!, label: 'Overweight'),
                              _BmiBarSegment(color: Colors.red, label: 'Obese'),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                // Goal Progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Goal Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
                    // We'll calculate real progress below
                    StreamBuilder<List<FoodEntry>>(
                      stream: _userId != null ? _foodService.getWeeklyFoodEntries(_userId!) : const Stream.empty(),
                      builder: (context, snapshot) {
                        final entries = snapshot.data ?? [];
                        final total = entries.fold<int>(0, (sum, e) => sum + e.calories);
                        final progress = weightGoal > 0 ? min(total / weightGoal, 1.0) : 0.0;
                        return Text('${(progress * 100).toStringAsFixed(1)}% Goal achieved', style: TextStyle(fontSize: 14, color: kTextGrey));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Time Range Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      children: List.generate(4, (i) {
                        final labels = ['90 Days', '6 Months', '1 Year', 'All time'];
                        final selected = selectedTimeRange == i;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 90),
                            child: ChoiceChip(
                              label: Text(labels[i], style: TextStyle(color: selected ? Colors.white : kTextDark, fontWeight: FontWeight.w600)),
                              selected: selected,
                              onSelected: (_) => setState(() => selectedTimeRange = i),
                              selectedColor: kTextDark,
                              backgroundColor: kSoftWhite,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Animated Line Chart for weight progress (mocked for now, can be replaced with real weight logs)
                _PremiumCard(
                  child: SizedBox(
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        StreamBuilder<List<FoodEntry>>(
                          stream: _userId != null ? _foodService.getWeeklyFoodEntries(_userId!) : const Stream.empty(),
                          builder: (context, snapshot) {
                            final entries = snapshot.data ?? [];
                            final List<FlSpot> lineSpots = entries.isNotEmpty
                              ? entries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.calories.toDouble())).toList()
                              : <FlSpot>[];
                            return SizedBox(
                              height: 180,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  LineChart(
                                    LineChartData(
                                      minY: 0,
                                      maxY: 100,
                                      lineBarsData: lineSpots.isNotEmpty
                                        ? [
                                            LineChartBarData(
                                              spots: lineSpots,
                                              isCurved: true,
                                              color: kAccentBlue,
                                              barWidth: 5,
                                              isStrokeCapRound: true,
                                              belowBarData: BarAreaData(
                                                show: true,
                                                gradient: LinearGradient(
                                                  colors: [kAccentBlue.withOpacity(0.3), Colors.transparent],
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                ),
                                              ),
                                              dotData: FlDotData(
                                                show: true,
                                                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                                  radius: 6,
                                                  color: kAccentBlue,
                                                  strokeWidth: 2,
                                                  strokeColor: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ]
                                        : [],
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 40,
                                            getTitlesWidget: (value, meta) => Text(
                                              value.toInt().toString(),
                                              style: TextStyle(color: kTextGrey, fontWeight: FontWeight.w600, fontSize: 12),
                                            ),
                                            interval: 20,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, meta) => Padding(
                                              padding: const EdgeInsets.only(top: 6),
                                              child: Text('Day ${(value + 1).toInt()}', style: TextStyle(color: kTextGrey, fontWeight: FontWeight.w600, fontSize: 12)),
                                            ),
                                            interval: 1,
                                          ),
                                        ),
                                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      ),
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: false,
                                        horizontalInterval: 20,
                                        getDrawingHorizontalLine: (value) => FlLine(
                                          color: kAccentBlue.withOpacity(0.08),
                                          strokeWidth: 1,
                                        ),
                                      ),
                                      borderData: FlBorderData(show: false),
                                    ),
                                  ),
                                  if (lineSpots.isEmpty)
                                    Text(
                                      'No data to display',
                                      style: TextStyle(
                                        color: kTextDark,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Nutrition Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Nutrition', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
                    Text('This week vs previous week', style: TextStyle(fontSize: 14, color: kTextGrey)),
                  ],
                ),
                const SizedBox(height: 12),
                // Nutrition Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      children: List.generate(4, (i) {
                        final labels = ['This Week', 'Last Week', '2 wks. ago', '3 wks. ago'];
                        final selected = selectedNutritionTab == i;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 90),
                            child: ChoiceChip(
                              label: Text(labels[i], style: TextStyle(color: selected ? Colors.white : kTextDark, fontWeight: FontWeight.w600)),
                              selected: selected,
                              onSelected: (_) => setState(() => selectedNutritionTab = i),
                              selectedColor: kTextDark,
                              backgroundColor: kSoftWhite,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Animated Bar Chart for weekly calories
                _PremiumCard(
                  child: SizedBox(
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        StreamBuilder<List<FoodEntry>>(
                          stream: _userId != null ? _foodService.getWeeklyFoodEntries(_userId!) : const Stream.empty(),
                          builder: (context, snapshot) {
                            final barEntries = snapshot.data ?? [];
                            final caloriesByDay = {};
                            for (var e in barEntries) {
                              final weekday = e.timestamp.weekday % 7; // 0=Sun, 6=Sat
                              caloriesByDay[weekday] = (caloriesByDay[weekday] ?? 0) + e.calories;
                            }
                            final barGroups = List.generate(7, (i) =>
                              barEntries.isNotEmpty
                                ? BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: (caloriesByDay[i] ?? 0).toDouble(),
                                        width: 18,
                                        borderRadius: BorderRadius.circular(8),
                                        gradient: LinearGradient(
                                          colors: [kAccentBlue.withOpacity(0.5), kAccentBlue.withOpacity(0.7)],
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                        ),
                                        rodStackItems: [],
                                      ),
                                    ],
                                    showingTooltipIndicators: [0],
                                  )
                                : BarChartGroupData(x: i, barRods: []));
                            return SizedBox(
                              height: 180,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  BarChart(
                                    BarChartData(
                                      barGroups: barGroups,
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, meta) {
                                              const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 6),
                                                child: Text(days[value.toInt() % 7], style: TextStyle(color: kTextGrey, fontWeight: FontWeight.w600, fontSize: 12)),
                                              );
                                            },
                                            interval: 1,
                                          ),
                                        ),
                                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      ),
                                      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1, getDrawingHorizontalLine: (value) => FlLine(color: kAccentBlue.withOpacity(0.08), strokeWidth: 1)),
                                      borderData: FlBorderData(show: false),
                                      barTouchData: BarTouchData(
                                        enabled: true,
                                        touchTooltipData: BarTouchTooltipData(
                                          tooltipBgColor: Colors.black.withOpacity(0.7),
                                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                            return BarTooltipItem(
                                              '${rod.toY.toInt()} kcal',
                                              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (barEntries.isEmpty)
                                    Text(
                                      'No data to display',
                                      style: TextStyle(
                                        color: kTextDark,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final Widget child;
  const _PremiumCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _BmiBarSegment extends StatelessWidget {
  final Color color;
  final String label;
  const _BmiBarSegment({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: kTextGrey)),
        ],
      ),
    );
  }
}

// Shimmer loader widget
class _ShimmerLoader extends StatelessWidget {
  final double height;
  final double width;
  const _ShimmerLoader({this.height = 20, this.width = double.infinity});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.3, end: 1.0),
        duration: const Duration(seconds: 1),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: child,
        ),
        child: Container(color: Colors.grey[200]),
      ),
    );
  }
} 