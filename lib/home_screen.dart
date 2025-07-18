import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'ui/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());
    // Mock data
    final int caloriesGoal = 2000;
    final int caloriesConsumed = 1200;
    final int caloriesBurned = 300;
    final int streak = 5; // days
    final List<Map<String, dynamic>> meals = [
      {'name': 'Oatmeal', 'calories': 250, 'time': '8:00 AM', 'icon': Icons.breakfast_dining},
      {'name': 'Chicken Salad', 'calories': 400, 'time': '1:00 PM', 'icon': Icons.lunch_dining},
      {'name': 'Apple', 'calories': 80, 'time': '4:00 PM', 'icon': Icons.local_grocery_store},
      {'name': 'Grilled Fish', 'calories': 470, 'time': '7:00 PM', 'icon': Icons.dinner_dining},
    ];
    final List<String> tips = [
      'Drink more water today!',
      'Try to walk 10,000 steps.',
      'Eat more fiber-rich foods.',
      'Remember to log your snacks!',
      'Great job keeping your streak!'
    ];
    final String tip = tips[DateTime.now().day % tips.length];
    final String aiCoach = 'Based on your recent meals, try adding more protein at lunch for sustained energy!';

    return Container(
      decoration: kAppBackground,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: kSoftWhite,
                child: Icon(Icons.person, color: kAccentBlue),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hi, User!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
                  Text(today, style: const TextStyle(fontSize: 14, color: kTextGrey)),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_none, color: kAccentBlue),
              onPressed: () {},
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI Coach Card
                _AICoachCard(aiCoach: aiCoach),
                const SizedBox(height: 16),
                // Streak Indicator
                Row(
                  children: [
                    Icon(Icons.local_fire_department, color: Colors.orange[700]),
                    const SizedBox(width: 6),
                    Text('Streak: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[700])),
                    Text('$streak days', style: TextStyle(color: Colors.orange[700])),
                  ],
                ),
                const SizedBox(height: 16),
                // Daily Summary Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Today\'s Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _SummaryItem(label: 'Consumed', value: caloriesConsumed, color: Colors.orange),
                            _SummaryItem(label: 'Burned', value: caloriesBurned, color: Colors.green),
                            _SummaryItem(label: 'Remaining', value: caloriesGoal - caloriesConsumed + caloriesBurned, color: Colors.blue),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: caloriesConsumed / caloriesGoal,
                          minHeight: 10,
                          backgroundColor: Colors.grey[200],
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('0'),
                            Text('$caloriesGoal kcal'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Animated Motivational Banner
                _AnimatedTipBanner(tip: tip),
                const SizedBox(height: 24),
                // Recent Meals
                const Text('Today\'s Meals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...meals.map((meal) => Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(meal['icon'], color: Colors.deepPurple, size: 32),
                    title: Text(meal['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(meal['time']),
                    trailing: Text('${meal['calories']} kcal', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )),
                if (meals.isEmpty)
                  const Center(child: Text('No meals logged yet.')),
                const SizedBox(height: 100), // For FAB spacing
              ],
            ),
          ),
        ),
        floatingActionButton: SizedBox(
          width: 180,
          height: 56,
          child: FloatingActionButton.extended(
            onPressed: () {
              // TODO: Navigate to add food screen
            },
            icon: const Icon(Icons.add, size: 28),
            label: const Text('Add Food', style: TextStyle(fontSize: 18)),
            backgroundColor: Colors.deepPurple,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 6,
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _SummaryItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 15, color: Colors.grey)),
      ],
    );
  }
}

class _AICoachCard extends StatelessWidget {
  final String aiCoach;
  const _AICoachCard({required this.aiCoach});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      color: Colors.deepPurple[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.smart_toy, color: Colors.deepPurple, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                aiCoach,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.deepPurple),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedTipBanner extends StatefulWidget {
  final String tip;
  const _AnimatedTipBanner({required this.tip});

  @override
  State<_AnimatedTipBanner> createState() => _AnimatedTipBannerState();
}

class _AnimatedTipBannerState extends State<_AnimatedTipBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: kAccentBlue.withOpacity(0.25),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb, color: kAccentBlue),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.tip, style: const TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }
} 