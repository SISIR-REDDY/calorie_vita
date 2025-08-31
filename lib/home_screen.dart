import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'ui/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateFormat('EEEE, MMM d').format(now);
    final greeting = _getGreeting(now.hour);
    
    // Mock data
    final int caloriesGoal = 2000;
    final int caloriesConsumed = 1200;
    final int caloriesBurned = 300;
    final int streak = 5;
    final int waterGlasses = 4;
    final int waterGoal = 8;
    
    final List<Map<String, dynamic>> meals = [
      {'name': 'Oatmeal', 'calories': 250, 'time': '8:00 AM', 'icon': Icons.breakfast_dining, 'color': kAccentColor, 'type': 'Breakfast'},
      {'name': 'Chicken Salad', 'calories': 400, 'time': '1:00 PM', 'icon': Icons.lunch_dining, 'color': kSecondaryColor, 'type': 'Lunch'},
      {'name': 'Apple', 'calories': 80, 'time': '4:00 PM', 'icon': Icons.local_grocery_store, 'color': kSuccessColor, 'type': 'Snack'},
      {'name': 'Grilled Fish', 'calories': 470, 'time': '7:00 PM', 'icon': Icons.dinner_dining, 'color': kInfoColor, 'type': 'Dinner'},
    ];
    
    final List<String> healthTips = [
      'Drink green tea after lunch to boost metabolism',
      'Take a 10-minute walk after meals',
      'Include protein in every meal for satiety',
      'Stay hydrated throughout the day',
      'Get 7-8 hours of quality sleep',
    ];
    final String healthTip = healthTips[now.day % healthTips.length];

    return Scaffold(
      backgroundColor: kSurfaceLight,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: kSurfaceColor,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: kPrimaryGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Row(
                      children: [
                        // Profile Avatar
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$greeting, Tinku 🌅',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                today,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_none,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Main Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Calendar Row
                  _buildCalendarRow(now),
                  const SizedBox(height: 24),
                  
                  // Streak Section
                  _buildStreakSection(streak),
                  const SizedBox(height: 24),
                  
                  // Stats Cards
                  _buildStatsSection(caloriesConsumed, caloriesBurned, caloriesGoal - caloriesConsumed + caloriesBurned),
                  const SizedBox(height: 24),
                  
                  // Circular Progress
                  _buildCircularProgress(caloriesConsumed, caloriesGoal),
                  const SizedBox(height: 24),
                  
                  // Health Tip
                  _buildHealthTip(healthTip),
                  const SizedBox(height: 32),
                  
                  // Today's Meals
                  _buildMealsSection(meals),
                  const SizedBox(height: 24),
                  
                  // Water Tracker
                  _buildWaterTracker(waterGlasses, waterGoal),
                  const SizedBox(height: 100), // For FAB spacing
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: kElevatedShadow,
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            // TODO: Navigate to add food screen
          },
          icon: const Icon(Icons.add, size: 24),
          label: const Text(
            'Add Food',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildCalendarRow(DateTime now) {
    final days = List.generate(7, (index) {
      final date = now.subtract(Duration(days: 3 - index));
      final isToday = date.day == now.day;
      final isSelected = index == 3;
      
      return Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isToday ? kPrimaryColor : (isSelected ? kPrimaryColor.withValues(alpha: 0.1) : kSurfaceColor),
                borderRadius: BorderRadius.circular(24),
                boxShadow: isToday ? [
                  BoxShadow(
                    color: kPrimaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ] : kCardShadow,
                border: isSelected && !isToday ? Border.all(color: kPrimaryColor, width: 2) : null,
              ),
              child: Center(
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isToday ? Colors.white : (isSelected ? kPrimaryColor : kTextSecondary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('E').format(date),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isToday ? kPrimaryColor : kTextTertiary,
              ),
            ),
          ],
        ),
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.calendar_today,
                color: kPrimaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'This Week',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: days),
        ),
      ],
    );
  }

  Widget _buildStreakSection(int streak) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: kAccentGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: kElevatedShadow,
      ),
      child: Row(
        children: [
          // Circular Progress Ring
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              children: [
                // Background circle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                // Progress arc
                CustomPaint(
                  size: const Size(80, 80),
                  painter: StreakProgressPainter(
                    progress: streak / 10, // Assuming 10 is max streak
                    color: Colors.white,
                  ),
                ),
                // Center content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$streak',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'days',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🔥 Keep the Fire Burning!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'re on a $streak-day streak! Consistency is key to achieving your health goals.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(int consumed, int burned, int remaining) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Consumed',
            consumed,
            kAccentColor,
            Icons.restaurant,
            'kcal',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Burned',
            burned,
            kSecondaryColor,
            Icons.fitness_center,
            'kcal',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Remaining',
            remaining,
            kPrimaryColor,
            Icons.trending_up,
            'kcal',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, Color color, IconData icon, String unit) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCardShadow,
        border: Border.all(
          color: color.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCircularProgress(int consumed, int goal) {
    final progress = consumed / goal;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.track_changes,
                  color: kPrimaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Daily Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Circular Progress
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              children: [
                // Background circle
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kBorderColor,
                  ),
                ),
                // Progress arc
                CustomPaint(
                  size: const Size(120, 120),
                  painter: CircularProgressPainter(
                    progress: progress,
                    color: kPrimaryColor,
                    strokeWidth: 8,
                  ),
                ),
                // Center content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary,
                        ),
                      ),
                      Text(
                        '$consumed/$goal',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTip(String tip) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kInfoColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: kInfoColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kInfoColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lightbulb,
              color: kInfoColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: kTextPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealsSection(List<Map<String, dynamic>> meals) {
    final mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];
    final mealIcons = [Icons.breakfast_dining, Icons.lunch_dining, Icons.dinner_dining, Icons.local_grocery_store];
    final mealColors = [kAccentColor, kSecondaryColor, kInfoColor, kSuccessColor];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.restaurant_menu,
                color: kPrimaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Today\'s Meals',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Meal Slots Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: mealTypes.length,
          itemBuilder: (context, index) {
            final mealType = mealTypes[index];
            final meal = meals.firstWhere(
              (m) => m['type'] == mealType,
              orElse: () => {'name': '', 'calories': 0, 'time': '', 'icon': mealIcons[index], 'color': mealColors[index], 'type': mealType},
            );
            
            return _buildMealSlot(mealType, meal, mealIcons[index], mealColors[index]);
          },
        ),
      ],
    );
  }

  Widget _buildMealSlot(String mealType, Map<String, dynamic> meal, IconData icon, Color color) {
    final hasMeal = meal['name'] != null && meal['name'].isNotEmpty;
    
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: kCardShadow,
        border: Border.all(
          color: hasMeal ? color.withValues(alpha: 0.2) : kBorderColor,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const Spacer(),
                if (hasMeal)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${meal['calories']} kcal',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              mealType,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            if (hasMeal) ...[
              Text(
                meal['name'],
                style: const TextStyle(
                  fontSize: 12,
                  color: kTextSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                meal['time'],
                style: const TextStyle(
                  fontSize: 10,
                  color: kTextTertiary,
                ),
              ),
            ] else ...[
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // TODO: Navigate to add meal screen
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '+ Add Meal',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWaterTracker(int glasses, int goal) {
    final progress = glasses / goal;
    
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
                  color: kInfoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.water_drop,
                  color: kInfoColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Water Tracker',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$glasses/$goal glasses',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kInfoColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Water glasses row
          Row(
            children: List.generate(goal, (index) {
              final isFilled = index < glasses;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isFilled ? kInfoColor : kBorderColor,
                  borderRadius: BorderRadius.circular(16),
                  border: isFilled ? null : Border.all(color: kBorderColor, width: 1),
                ),
                child: Icon(
                  Icons.water_drop,
                  color: isFilled ? Colors.white : kTextTertiary,
                  size: 16,
                ),
              );
            }),
          ),
          
          const SizedBox(height: 12),
          
          // Progress bar
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: kBorderColor,
            valueColor: AlwaysStoppedAnimation<Color>(kInfoColor),
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

// Custom Painters for circular progress
class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    // Background circle
    final backgroundPaint = Paint()
      ..color = kBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -90 * (3.14159 / 180), // Start from top
      progress * 2 * 3.14159, // Progress in radians
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class StreakProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  StreakProgressPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -90 * (3.14159 / 180), // Start from top
      progress * 2 * 3.14159, // Progress in radians
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 