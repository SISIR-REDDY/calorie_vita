import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../ui/app_colors.dart';
import '../models/daily_summary.dart';
import '../models/macro_breakdown.dart';
import '../models/user_achievement.dart';
import '../services/analytics_service.dart';

class RealTimeAnalyticsWidget extends StatefulWidget {
  final String period;
  final bool showComparison;
  final VoidCallback? onPeriodChanged;
  final VoidCallback? onComparisonToggled;

  const RealTimeAnalyticsWidget({
    super.key,
    required this.period,
    this.showComparison = false,
    this.onPeriodChanged,
    this.onComparisonToggled,
  });

  @override
  State<RealTimeAnalyticsWidget> createState() => _RealTimeAnalyticsWidgetState();
}

class _RealTimeAnalyticsWidgetState extends State<RealTimeAnalyticsWidget>
    with TickerProviderStateMixin {
  final AnalyticsService _analyticsService = AnalyticsService();
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAnalytics();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    
    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _initializeAnalytics() async {
    final days = widget.period == 'Daily' ? 1 : widget.period == 'Weekly' ? 7 : 30;
    await _analyticsService.initializeRealTimeAnalytics(days: days);
  }

  @override
  void didUpdateWidget(RealTimeAnalyticsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      final days = widget.period == 'Daily' ? 1 : widget.period == 'Weekly' ? 7 : 30;
      _analyticsService.updatePeriod(days);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            _buildSummaryCards(),
            const SizedBox(height: 24),
            _buildCaloriesChart(),
            const SizedBox(height: 24),
            _buildMacroBreakdown(),
            const SizedBox(height: 24),
            _buildProgressTracker(),
            const SizedBox(height: 24),
            _buildAIInsights(),
            const SizedBox(height: 24),
            _buildPersonalizedRecommendations(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return StreamBuilder<List<DailySummary>>(
      stream: _analyticsService.dailySummariesStream,
      builder: (context, snapshot) {
        final summaries = snapshot.data ?? _analyticsService.cachedDailySummaries;
        final totalCalories = summaries.fold(0, (sum, day) => sum + day.caloriesConsumed);
        final totalSteps = summaries.fold(0, (sum, day) => sum + day.steps);
        final totalWorkouts = summaries.length > 0 ? (summaries.length * 0.3).round() : 0;

        return Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Calories',
                totalCalories.toString(),
                'kcal',
                Icons.local_fire_department,
                kAccentColor,
                _getCalorieChange(summaries),
                _getCalorieChangeColor(summaries),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Steps',
                totalSteps.toString(),
                'steps',
                Icons.directions_walk,
                kInfoColor,
                _getStepsChange(summaries),
                _getStepsChangeColor(summaries),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Workouts',
                totalWorkouts.toString(),
                'sessions',
                Icons.fitness_center,
                kSecondaryColor,
                '+2',
                kSuccessColor,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, String value, String unit, IconData icon, Color color, String change, Color changeColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Text(
                change,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: changeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: kTextSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCaloriesChart() {
    return StreamBuilder<List<DailySummary>>(
      stream: _analyticsService.dailySummariesStream,
      builder: (context, snapshot) {
        final summaries = snapshot.data ?? _analyticsService.cachedDailySummaries;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.all(Radius.circular(20)),
            boxShadow: kCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Calories Trend',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                    ),
                  ),
                  if (widget.showComparison)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kInfoColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'vs Last Week',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: kInfoColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 200,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: kBorderColor,
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            final index = value.toInt() % 7;
                            return Text(
                              days[index],
                              style: const TextStyle(
                                color: kTextSecondary,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 200,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}',
                              style: const TextStyle(
                                color: kTextSecondary,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            );
                          },
                          reservedSize: 40,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 6,
                    minY: 0,
                    maxY: 2000,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _getCalorieSpots(summaries),
                        isCurved: true,
                        gradient: const LinearGradient(
                          colors: [kPrimaryColor, kPrimaryLight],
                        ),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              kPrimaryColor.withValues(alpha: 0.3),
                              kPrimaryColor.withValues(alpha: 0.1),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      if (widget.showComparison)
                        LineChartBarData(
                          spots: _getComparisonSpots(),
                          isCurved: true,
                          color: kTextTertiary,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMacroBreakdown() {
    return StreamBuilder<MacroBreakdown>(
      stream: _analyticsService.macroBreakdownStream,
      builder: (context, snapshot) {
        final macros = snapshot.data ?? _analyticsService.cachedMacroBreakdown;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.all(Radius.circular(20)),
            boxShadow: kCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Macronutrient Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 400) {
                    return Column(
                      children: [
                        SizedBox(
                          height: 200,
                          child: _buildPieChart(macros),
                        ),
                        const SizedBox(height: 20),
                        _buildMacroLegend(macros),
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 200,
                            child: _buildPieChart(macros),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildMacroLegend(macros),
                        ),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPieChart(MacroBreakdown macros) {
    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            // Handle pie chart touch
          },
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: [
          PieChartSectionData(
            color: kAccentColor,
            value: macros.carbsPercentage * 100,
            title: '${(macros.carbsPercentage * 100).toStringAsFixed(0)}%',
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            color: kSecondaryColor,
            value: macros.proteinPercentage * 100,
            title: '${(macros.proteinPercentage * 100).toStringAsFixed(0)}%',
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            color: kInfoColor,
            value: macros.fatPercentage * 100,
            title: '${(macros.fatPercentage * 100).toStringAsFixed(0)}%',
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroLegend(MacroBreakdown macros) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMacroLegendItem('Carbs', macros.carbs, 'g', kAccentColor),
        const SizedBox(height: 12),
        _buildMacroLegendItem('Protein', macros.protein, 'g', kSecondaryColor),
        const SizedBox(height: 12),
        _buildMacroLegendItem('Fat', macros.fat, 'g', kInfoColor),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: macros.isWithinRecommended 
                ? kSuccessColor.withValues(alpha: 0.1)
                : kWarningColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                macros.isWithinRecommended 
                    ? Icons.check_circle 
                    : Icons.warning,
                color: macros.isWithinRecommended 
                    ? kSuccessColor 
                    : kWarningColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  macros.isWithinRecommended 
                      ? 'Balanced' 
                      : 'Needs adjustment',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: macros.isWithinRecommended 
                        ? kSuccessColor 
                        : kWarningColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMacroLegendItem(String label, double value, String unit, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: kTextPrimary,
            ),
          ),
        ),
        Text(
          '${value.toStringAsFixed(0)}$unit',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressTracker() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progress Tracker',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 20),
          
          _buildProgressItem(
            'Weight Goal',
            'Current: 75.2 kg',
            'Target: 70.0 kg',
            0.7,
            kSecondaryColor,
            Icons.monitor_weight,
          ),
          const SizedBox(height: 16),
          
          _buildProgressItem(
            'BMI',
            'Current: 24.1',
            'Target: 22.0',
            0.6,
            kInfoColor,
            Icons.height,
          ),
          const SizedBox(height: 16),
          
          _buildProgressItem(
            'Weekly Goal',
            '5,200 / 7,000 kcal',
            '74% Complete',
            0.74,
            kAccentColor,
            Icons.local_fire_department,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String title, String current, String target, double progress, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                    ),
                  ),
                  Text(
                    current,
                    style: const TextStyle(
                      fontSize: 12,
                      color: kTextSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Flexible(
              child: Text(
                target,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
      ],
    );
  }

  Widget _buildAIInsights() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _analyticsService.insightsStream,
      builder: (context, snapshot) {
        final insights = snapshot.data ?? _analyticsService.cachedInsights;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.all(Radius.circular(20)),
            boxShadow: kCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kAccentPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: kAccentPurple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'AI-Generated Insights',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (insights.isEmpty)
                _buildInsightItem(
                  '📊 No Data Yet',
                  'Start logging your meals to get personalized insights and recommendations.',
                  kInfoColor,
                )
              else
                ...insights.map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildInsightItem(
                    insight['title'] ?? 'Insight',
                    insight['message'] ?? 'No message available',
                    _getInsightColor(insight['color']),
                  ),
                )).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInsightItem(String title, String description, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: kTextSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizedRecommendations() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _analyticsService.recommendationsStream,
      builder: (context, snapshot) {
        final recommendations = snapshot.data ?? _analyticsService.cachedRecommendations;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.all(Radius.circular(20)),
            boxShadow: kCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kSecondaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.lightbulb,
                      color: kSecondaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Personalized Recommendations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (recommendations.isEmpty)
                _buildRecommendationItem(
                  'Start logging meals',
                  'Begin tracking your food intake to get personalized recommendations',
                  Icons.restaurant,
                  kInfoColor,
                )
              else
                ...recommendations.map((recommendation) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildRecommendationItem(
                    recommendation['title'] ?? 'Recommendation',
                    recommendation['description'] ?? 'No description available',
                    _getRecommendationIcon(recommendation['icon']),
                    _getRecommendationColor(recommendation['color']),
                  ),
                )).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecommendationItem(String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: kTextSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _getCalorieChange(List<DailySummary> summaries) {
    if (summaries.length < 2) return '+0%';
    final current = summaries.last.caloriesConsumed;
    final previous = summaries[summaries.length - 2].caloriesConsumed;
    final change = ((current - previous) / previous * 100).round();
    return '${change > 0 ? '+' : ''}$change%';
  }

  Color _getCalorieChangeColor(List<DailySummary> summaries) {
    final change = _getCalorieChange(summaries);
    if (change.startsWith('+')) return kSuccessColor;
    if (change.startsWith('-')) return kWarningColor;
    return kInfoColor;
  }

  String _getStepsChange(List<DailySummary> summaries) {
    if (summaries.length < 2) return '+0%';
    final current = summaries.last.steps;
    final previous = summaries[summaries.length - 2].steps;
    final change = ((current - previous) / previous * 100).round();
    return '${change > 0 ? '+' : ''}$change%';
  }

  Color _getStepsChangeColor(List<DailySummary> summaries) {
    final change = _getStepsChange(summaries);
    if (change.startsWith('+')) return kSuccessColor;
    if (change.startsWith('-')) return kWarningColor;
    return kInfoColor;
  }

  List<FlSpot> _getCalorieSpots(List<DailySummary> summaries) {
    if (summaries.isEmpty) {
      return List.generate(7, (index) => FlSpot(index.toDouble(), 0));
    }
    return summaries.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.caloriesConsumed.toDouble());
    }).toList();
  }

  List<FlSpot> _getComparisonSpots() {
    return [
      const FlSpot(0, 1100),
      const FlSpot(1, 1400),
      const FlSpot(2, 1600),
      const FlSpot(3, 1500),
      const FlSpot(4, 1700),
      const FlSpot(5, 1600),
      const FlSpot(6, 1750),
    ];
  }

  Color _getInsightColor(String? colorType) {
    switch (colorType) {
      case 'success':
        return kSuccessColor;
      case 'warning':
        return kWarningColor;
      case 'error':
        return kErrorColor;
      default:
        return kInfoColor;
    }
  }

  IconData _getRecommendationIcon(String? iconString) {
    switch (iconString) {
      case '🍎':
        return Icons.apple;
      case '🚶':
        return Icons.directions_walk;
      case '💧':
        return Icons.water_drop;
      case '💪':
        return Icons.fitness_center;
      case '👤':
        return Icons.person;
      case '⚠️':
        return Icons.warning;
      default:
        return Icons.lightbulb;
    }
  }

  Color _getRecommendationColor(String? colorType) {
    switch (colorType) {
      case 'success':
        return kSuccessColor;
      case 'warning':
        return kWarningColor;
      case 'error':
        return kErrorColor;
      default:
        return kInfoColor;
    }
  }
}
