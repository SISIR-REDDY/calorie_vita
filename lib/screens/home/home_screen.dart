import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/food_entry.dart';
import 'dart:ui';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _goal;
  int _consumed = 0;
  int _burned = 300;   // TODO: Replace with real calculation from Firestore
  bool _savingGoal = false;
  int _currentStreak = 0;

  Stream<int> get _todayCaloriesStream {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream<int>.empty();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('entries')
        .where('timestamp', isGreaterThanOrEqualTo: todayStart)
        .where('timestamp', isLessThan: todayEnd)
        .snapshots()
        .map((snapshot) => snapshot.docs.fold<int>(0, (sum, doc) {
              final data = doc.data() as Map<String, dynamic>;
              return sum + ((data['calories'] ?? 0) as num).toInt();
            }));
  }

  @override
  void initState() {
    super.initState();
    _loadGoal();
    _fetchCurrentStreak();
  }

  Future<void> _loadGoal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    setState(() {
      _goal = doc.data()?['goal'] ?? 2000;
    });
  }

  Future<void> _fetchCurrentStreak() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final streaks = doc.data()?['streaks'] ?? [];
    final List<DateTime> streakDays = streaks.map<DateTime>((e) => DateTime.fromMillisecondsSinceEpoch(e)).toList();
    int streak = 0;
    DateTime day = DateTime.now();
    while (streakDays.any((d) => d.year == day.year && d.month == day.month && d.day == day.day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    setState(() {
      _currentStreak = streak;
    });
  }

  Future<void> _setGoalDialog() async {
    final controller = TextEditingController(text: _goal?.toString() ?? '2000');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Calorie Goal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Calories'),
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
    if (result != null && result > 0) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() { _savingGoal = true; _goal = result; }); // Optimistic update
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'goal': result}, SetOptions(merge: true));
          await _loadGoal();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Goal updated to $result calories!')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update goal. Please try again.'), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) setState(() { _savingGoal = false; });
        }
      }
    }
  }

  void _showMealDetail(FoodEntry entry) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(entry.imageUrl!, height: 120),
              ),
            const SizedBox(height: 16),
            Text(entry.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
            Text('${entry.calories} kcal', style: GoogleFonts.poppins(fontSize: 16)),
            Text(DateFormat.yMMMd().add_Hm().format(entry.timestamp), style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  onPressed: () {/* TODO: Implement edit */},
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('entries').doc(entry.id).delete();
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStreakDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Streak History'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔥 $_currentStreak-day streak!', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Text('"Every meal is a chance to nourish!"', style: GoogleFonts.poppins(fontSize: 14, color: Colors.deepPurple)),
            const SizedBox(height: 12),
            const Text('Keep logging your meals to maintain your streak!'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showAccountSheet(User? user, BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black54,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 8),
          child: Center(
            child: Container(
              width: 340,
              decoration: BoxDecoration(
                color: kSoftWhite,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 24, offset: Offset(0, 12))],
                border: Border.all(color: Colors.black12.withOpacity(0.08), width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kAccentTeal.withOpacity(0.7),
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.transparent,
                      backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                      child: user?.photoURL == null ? Icon(Icons.person, size: 40, color: kTextGrey) : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(user?.displayName ?? 'User', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, color: kTextDark)),
                  const SizedBox(height: 6),
                  Text(user?.email ?? 'No email', style: GoogleFonts.poppins(fontSize: 15, color: kTextGrey, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentGold,
                        foregroundColor: kTextDark,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final width = MediaQuery.of(context).size.width;
    void _onAccountTap() => _showAccountSheet(user, context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ListView(
              padding: EdgeInsets.symmetric(horizontal: width > 500 ? width * 0.15 : 20, vertical: 20),
              children: [
                _premiumGreeting(user, context, onAccountTap: _onAccountTap),
                if (uid != null)
                  _StreakCalendar(uid: uid)
                else
                  const SizedBox(height: 16),
                const SizedBox(height: 8),
                // Streak Card
                GestureDetector(
                  onTap: _showStreakDialog,
                  child: _StreakCard(currentStreak: _currentStreak),
                ),
                const SizedBox(height: 24),
                // Calorie Summary Cards
                _CalorieSummaryRow(goal: _goal ?? 2000, onSetGoal: _setGoalDialog),
                const SizedBox(height: 32),
                if (_goal != null)
                  StreamBuilder<int>(
                    stream: _todayCaloriesStream,
                    builder: (context, snapshot) {
                      final consumed = snapshot.data ?? 0;
                      return _TargetProgressCard(
                        target: _goal!,
                        consumed: consumed,
                        onSetGoal: _setGoalDialog,
                        saving: _savingGoal,
                      );
                    },
                  ),
                const SizedBox(height: 16),
                Text('Today\'s Meals', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (uid != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('entries')
                        .where('timestamp', isGreaterThanOrEqualTo: todayStart)
                        .where('timestamp', isLessThan: todayEnd)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return _EmptyMealsState();
                      }
                      final entries = docs.map((d) => FoodEntry.fromFirestore(d)).toList();
                      return _premiumMealList(entries, _showMealDetail);
                    },
                  )
                else
                  _EmptyMealsState(),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Define premium accent colors (no pink/purple)
const Color kAccentBlue = Color(0xFFB3E5FC); // Burned card
const Color kAccentGreen = Color(0xFFC8E6C9); // Remaining card
const Color kAccentGold = Color(0xFFFFF9C4); // Consumed card
const Color kAccentTeal = Color(0xFFB2DFDB); // Streak card
const Color kSoftWhite = Color(0xFFF9F9F9); // Card backgrounds
const Color kTextDark = Color(0xFF222222);
const Color kTextGrey = Color(0xFF888888);

// --- Greeting/AppBar ---
Widget _premiumGreeting(User? user, BuildContext context, {required VoidCallback onAccountTap}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Container(
      decoration: BoxDecoration(
        color: kSoftWhite,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 6))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${user?.displayName ?? 'User'} 👋',
                  style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 0.2, color: kTextDark),
                ),
                const SizedBox(height: 6),
                Text(
                  'Track your calories and stay healthy',
                  style: GoogleFonts.poppins(fontSize: 15, color: kTextGrey, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onAccountTap,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kAccentTeal.withOpacity(0.18), width: 2),
                boxShadow: [BoxShadow(color: kAccentTeal.withOpacity(0.10), blurRadius: 12)],
              ),
              child: CircleAvatar(
                radius: 32,
                backgroundColor: kAccentTeal.withOpacity(0.08),
                backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                child: user?.photoURL == null ? Icon(Icons.person, color: kTextGrey, size: 32) : null,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// --- Streak Card ---
class _StreakCard extends StatelessWidget {
  final int currentStreak;
  const _StreakCard({required this.currentStreak});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: kAccentTeal,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 6))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kAccentTeal.withOpacity(0.7),
              ),
              child: Icon(Icons.local_fire_department, color: kTextGrey, size: 38),
            ),
            const SizedBox(width: 18),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: currentStreak),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, value, child) => Text(
                      '🔥 $value-day streak!',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: kTextDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('"Every meal is a chance to nourish!"', style: GoogleFonts.poppins(fontSize: 14, color: kTextGrey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Calorie Summary Row ---
class _CalorieSummaryRow extends StatelessWidget {
  final int goal;
  final VoidCallback onSetGoal;
  const _CalorieSummaryRow({required this.goal, required this.onSetGoal});
  @override
  Widget build(BuildContext context) {
    // Mock data for now
    final consumed = 1200;
    final burned = 300;
    final remaining = goal - consumed + burned;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _PremiumSummaryCard(label: 'Consumed', value: consumed, icon: Icons.restaurant, color: kAccentGold, iconColor: kTextDark, onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Consumed Foods'),
              content: const Text('Show all foods consumed today (future feature).'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
            ),
          );
        }),
        _PremiumSummaryCard(label: 'Burned', value: burned, icon: Icons.directions_run, color: kAccentBlue, iconColor: kTextDark, onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Calories Burned'),
              content: const Text('Show activity log (future feature).'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
            ),
          );
        }),
        _PremiumSummaryCard(label: 'Remaining', value: remaining, icon: Icons.local_fire_department, color: kAccentGreen, iconColor: kTextDark, onTap: null),
      ],
    );
  }
}

class _PremiumSummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;
  const _PremiumSummaryCard({required this.label, required this.value, required this.icon, required this.color, required this.iconColor, this.onTap});
  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.7),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: value),
            duration: const Duration(milliseconds: 700),
            builder: (context, val, child) => Text('$val', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, color: kTextDark)),
          ),
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: kTextGrey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
    return Expanded(
      child: onTap != null ? GestureDetector(onTap: onTap, child: card) : card,
    );
  }
}

// --- Target Progress Card ---
class _TargetProgressCard extends StatelessWidget {
  final int target;
  final int consumed;
  final VoidCallback onSetGoal;
  final bool saving;

  const _TargetProgressCard({
    required this.target,
    required this.consumed,
    required this.onSetGoal,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = target - consumed;
    final progress = (consumed.toDouble() / target.toDouble()).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: kSoftWhite,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 6))],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('Target Progress', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: kTextDark)),
            const SizedBox(height: 18),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 900),
              builder: (context, value, child) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 16,
                  backgroundColor: kAccentBlue.withOpacity(0.15),
                  color: kAccentGreen,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: consumed),
                  duration: const Duration(milliseconds: 700),
                  builder: (context, val, child) => Text('Consumed: $val kcal', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: kTextDark)),
                ),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: remaining),
                  duration: const Duration(milliseconds: 700),
                  builder: (context, val, child) => Text('Remaining: $val kcal', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: kTextDark)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onSetGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentGreen,
                foregroundColor: kTextDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              ),
              child: Text(saving ? 'Saving...' : 'Set New Goal'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Premium Meal List ---
Widget _premiumMealList(List<FoodEntry> entries, void Function(FoodEntry) onTap) {
  return Column(
    children: entries.map((entry) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: kSoftWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: ListTile(
          onTap: () => onTap(entry),
          leading: entry.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(entry.imageUrl!, width: 54, height: 54, fit: BoxFit.cover),
                )
              : CircleAvatar(child: Icon(Icons.fastfood, color: kTextGrey)),
          title: Text(entry.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: kTextDark)),
          subtitle: Row(
            children: [
              Icon(Icons.local_fire_department, color: kAccentGold, size: 18),
              const SizedBox(width: 4),
              Text('${entry.calories} kcal • ${DateFormat.Hm().format(entry.timestamp)}', style: GoogleFonts.poppins(fontSize: 13, color: kTextGrey)),
            ],
          ),
        ),
      ),
    )).toList(),
  );
}

class _EmptyMealsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: const ValueKey('empty'),
        margin: const EdgeInsets.symmetric(vertical: 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(Icons.fastfood, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No meals logged today!', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Start tracking your meals by taking a quick picture.', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

class _StreakCalendar extends StatelessWidget {
  final String uid;
  const _StreakCalendar({required this.uid});

  Future<List<bool>> _fetchStreaks() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final streaks = doc.data()?['streaks'] ?? [];
    final List<DateTime> streakDays = streaks.map<DateTime>((e) => DateTime.fromMillisecondsSinceEpoch(e)).toList();
    final List<bool> result = List.filled(7, false);
    for (int i = 0; i < 7; i++) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      for (final day in streakDays) {
        if (day.year == d.year && day.month == d.month && day.day == d.day) {
          result[i] = true;
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.7),
                  Colors.purple.withOpacity(0.10),
                  Colors.blue.withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.08),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
              child: FutureBuilder<List<bool>>(
                future: _fetchStreaks(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading streaks', style: TextStyle(color: Colors.red)));
                  }
                  final streaks = snapshot.data ?? List.filled(7, false);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(7, (index) {
                      final day = DateTime.now().subtract(Duration(days: 6 - index));
                      final isToday = index == 6;
                      return Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                          child: _DayTile(
                            key: ValueKey('${day.day}-${streaks[index]}'),
                            day: day,
                            isStreak: streaks[index],
                            isToday: isToday,
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final DateTime day;
  final bool isStreak;
  final bool isToday;
  const _DayTile({Key? key, required this.day, required this.isStreak, required this.isToday}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.transparent;
    Color textColor = kTextGrey;
    BoxBorder? border;
    List<BoxShadow> boxShadow = [];
    Widget dayCircle;
    if (isToday) {
      bgColor = kAccentGold;
      textColor = kTextDark;
      boxShadow = [
        BoxShadow(
          color: kAccentGold.withOpacity(0.45),
          blurRadius: 18,
          spreadRadius: 2,
        ),
      ];
      dayCircle = AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: boxShadow,
          border: Border.all(color: kAccentTeal, width: 2),
        ),
        child: Center(
          child: Text(day.day.toString(), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, color: textColor)),
        ),
      );
    } else if (isStreak) {
      bgColor = kAccentGreen.withOpacity(0.85);
      textColor = kTextDark;
      border = Border.all(color: kAccentGreen, width: 2);
      boxShadow = [
        BoxShadow(
          color: kAccentGreen.withOpacity(0.10),
          blurRadius: 6,
        ),
      ];
      dayCircle = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: border,
          boxShadow: boxShadow,
        ),
        child: Center(
          child: Text(day.day.toString(), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
        ),
      );
    } else {
      bgColor = kSoftWhite;
      textColor = kTextGrey.withOpacity(0.5);
      boxShadow = [
        BoxShadow(
          color: kTextGrey.withOpacity(0.08),
          blurRadius: 4,
        ),
      ];
      dayCircle = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: boxShadow,
        ),
        child: Center(
          child: Text(day.day.toString(), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat.E().format(day),
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: kTextGrey,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        dayCircle,
      ],
    );
  }
} 