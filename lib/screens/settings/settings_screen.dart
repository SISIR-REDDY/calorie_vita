import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../ui/app_colors.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../profile_screen.dart';
import '../../history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildViewportChrome(BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }
}

class _SettingsScreenState extends State<SettingsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String? name;
  int? age;
  bool addBurnedCalories = false;
  bool loading = true;
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTheme();
  }

  Future<void> _loadUserData() async {
    if (user == null) {
      setState(() {
        loading = false;
      });
      return;
    }
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    setState(() {
      name = doc.data()?['name'] ?? user!.displayName ?? '';
      age = doc.data()?['age'] ?? 0;
      addBurnedCalories = doc.data()?['addBurnedCalories'] ?? false;
      loading = false;
    });
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = value;
    });
    await prefs.setBool('isDarkMode', value);
    // Notify the app to change theme (you may want to use a provider or similar in a real app)
    // For now, use a callback or setState in main if needed
    // You can add a callback to parent widget if you want to propagate theme change
  }

  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: name);
    final ageController = TextEditingController(text: age?.toString() ?? '');
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: ageController,
              decoration: const InputDecoration(labelText: 'Age'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'name': nameController.text,
                'age': int.tryParse(ageController.text) ?? 0,
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'name': result['name'],
        'age': result['age'],
      }, SetOptions(merge: true));
      setState(() {
        name = result['name'];
        age = result['age'];
      });
    }
  }

  Future<void> _setAddBurnedCalories(bool value) async {
    if (user == null) return;
    setState(() { addBurnedCalories = value; });
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'addBurnedCalories': value,
    }, SetOptions(merge: true));
  }

  void _openLargeFeature(String title) {
    if (title == 'Personal Details') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
    } else if (title == 'Weight History') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
    } else if (title == 'Adjust Macronutrients') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MacronutrientsScreen()));
    } else if (title == 'Goal & Current Weight') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalWeightScreen()));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(title)), body: Center(child: Text('$title screen coming soon!', style: GoogleFonts.poppins(fontSize: 18))))));
    }
  }

  void _showDialog(String title, String content) {
    if (title == 'Delete Account') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete Account', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red)),
          content: Text('Are you sure you want to delete your account? This action cannot be undone.', style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                await _deleteAccount();
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      );
    } else {
      showDialog(context: context, builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ));
    }
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Delete user data from Firestore
    await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
    // Delete user authentication
    await user.delete();
    // Navigate to root (pop all routes)
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (user == null) {
      return Center(
        child: Text('Not logged in', style: GoogleFonts.poppins(fontSize: 20, color: kTextDark)),
      );
    }
    return ScrollConfiguration(
      behavior: _NoGlowScrollBehavior(),
      child: Container(
        decoration: kAppBackground,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Settings', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: kTextDark)),
              const SizedBox(height: 24),
              // Profile Card
              PremiumCard(
                child: ListTile(
                  leading: const Icon(Icons.person, color: kAccentBlue, size: 40),
                  title: Text(name ?? 'Enter your name', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 20, color: kTextDark)),
                  subtitle: Text('${age ?? ''} years old', style: GoogleFonts.poppins(color: kTextGrey)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: kTextGrey),
                    onPressed: _editProfile,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Personal Details & Goals
              PremiumCard(
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.badge_outlined,
                      label: 'Personal details',
                      onTap: () => _openLargeFeature('Personal Details'),
                    ),
                    Divider(height: 1, thickness: 1, color: kAccentBlue.withOpacity(0.3)),
                    _SettingsTile(
                      icon: Icons.sync_alt,
                      label: 'Adjust macronutrients',
                      onTap: () => _openLargeFeature('Adjust Macronutrients'),
                    ),
                    Divider(height: 1, thickness: 1, color: kAccentBlue.withOpacity(0.3)),
                    _SettingsTile(
                      icon: Icons.flag,
                      label: 'Goal & current weight',
                      onTap: () => _openLargeFeature('Goal & Current Weight'),
                    ),
                    Divider(height: 1, thickness: 1, color: kAccentBlue.withOpacity(0.3)),
                    _SettingsTile(
                      icon: Icons.history,
                      label: 'Weight history',
                      onTap: () => _openLargeFeature('Weight History'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Preferences
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune, color: kTextDark),
                        const SizedBox(width: 10),
                        Text('Preferences', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: kTextDark)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.dark_mode, color: kAccentBlue),
                      title: Text('Dark Mode', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: kTextDark)),
                      subtitle: Text('Enable dark theme', style: GoogleFonts.poppins(color: kTextGrey)),
                      value: isDarkMode,
                      onChanged: _setDarkMode,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.local_fire_department, color: kAccentBlue),
                      title: Text('Add Burned Calories', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: kTextDark)),
                      subtitle: Text('Add burned calories to daily goal', style: GoogleFonts.poppins(color: kTextGrey)),
                      value: addBurnedCalories,
                      onChanged: _setAddBurnedCalories,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Legal & Support
              PremiumCard(
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.description,
                      label: 'Terms and Conditions',
                      onTap: () => _showDialog('Terms and Conditions', 'Terms and Conditions content goes here.'),
                    ),
                    Divider(height: 1, thickness: 1, color: kAccentBlue.withOpacity(0.3)),
                    _SettingsTile(
                      icon: Icons.privacy_tip,
                      label: 'Privacy Policy',
                      onTap: () => _showDialog('Privacy Policy', 'Privacy Policy content goes here.'),
                    ),
                    Divider(height: 1, thickness: 1, color: kAccentBlue.withOpacity(0.3)),
                    _SettingsTile(
                      icon: Icons.email,
                      label: 'Support Email',
                      onTap: () => _showDialog('Support Email', 'Contact us at support@example.com'),
                    ),
                    Divider(height: 1, thickness: 1, color: kAccentBlue.withOpacity(0.3)),
                    _SettingsTile(
                      icon: Icons.person_remove,
                      label: 'Delete Account?',
                      onTap: () => _showDialog('Delete Account', 'Delete account feature coming soon.'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SettingsTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: kTextDark),
      title: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: kTextDark)),
      onTap: onTap,
      horizontalTitleGap: 12,
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 0,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: kAccentBlue);
  }
}

class PremiumCard extends StatelessWidget {
  final Widget child;
  const PremiumCard({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kAccentBlue.withOpacity(0.35),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kAccentBlue.withOpacity(0.7), width: 2),
        boxShadow: [
          BoxShadow(
            color: kAccentBlue.withOpacity(0.07),
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

class MacronutrientsScreen extends StatefulWidget {
  const MacronutrientsScreen({super.key});
  @override
  State<MacronutrientsScreen> createState() => _MacronutrientsScreenState();
}
class _MacronutrientsScreenState extends State<MacronutrientsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  int? carbs;
  int? protein;
  int? fat;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  Future<void> _loadData() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    setState(() {
      carbs = doc.data()?['carbs'] ?? 0;
      protein = doc.data()?['protein'] ?? 0;
      fat = doc.data()?['fat'] ?? 0;
      loading = false;
    });
  }
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (user == null) return;
    setState(() { loading = true; });
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
    }, SetOptions(merge: true));
    setState(() { loading = false; });
    if (mounted) Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adjust Macronutrients')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: kAppBackground,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      elevation: 8,
                      color: Colors.white.withOpacity(0.85),
                      child: Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Macronutrient Goals', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark)),
                              const SizedBox(height: 24),
                              TextFormField(
                                initialValue: carbs?.toString(),
                                decoration: const InputDecoration(labelText: 'Carbohydrates (g)'),
                                keyboardType: TextInputType.number,
                                validator: (v) => v == null || int.tryParse(v) == null ? 'Enter a valid number' : null,
                                onSaved: (v) => carbs = int.tryParse(v ?? ''),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                initialValue: protein?.toString(),
                                decoration: const InputDecoration(labelText: 'Protein (g)'),
                                keyboardType: TextInputType.number,
                                validator: (v) => v == null || int.tryParse(v) == null ? 'Enter a valid number' : null,
                                onSaved: (v) => protein = int.tryParse(v ?? ''),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                initialValue: fat?.toString(),
                                decoration: const InputDecoration(labelText: 'Fat (g)'),
                                keyboardType: TextInputType.number,
                                validator: (v) => v == null || int.tryParse(v) == null ? 'Enter a valid number' : null,
                                onSaved: (v) => fat = int.tryParse(v ?? ''),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kAccentBlue,
                                    foregroundColor: kTextDark,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  onPressed: _save,
                                  child: const Text('Save'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class GoalWeightScreen extends StatefulWidget {
  const GoalWeightScreen({super.key});
  @override
  State<GoalWeightScreen> createState() => _GoalWeightScreenState();
}
class _GoalWeightScreenState extends State<GoalWeightScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  int? goalWeight;
  int? currentWeight;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  Future<void> _loadData() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    setState(() {
      goalWeight = doc.data()?['goalWeight'] ?? 0;
      currentWeight = doc.data()?['currentWeight'] ?? 0;
      loading = false;
    });
  }
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (user == null) return;
    setState(() { loading = true; });
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'goalWeight': goalWeight,
      'currentWeight': currentWeight,
    }, SetOptions(merge: true));
    setState(() { loading = false; });
    if (mounted) Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goal & Current Weight')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: kAppBackground,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      elevation: 8,
                      color: Colors.white.withOpacity(0.85),
                      child: Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Goal & Current Weight', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark)),
                              const SizedBox(height: 24),
                              TextFormField(
                                initialValue: goalWeight?.toString(),
                                decoration: const InputDecoration(labelText: 'Goal Weight (kg)'),
                                keyboardType: TextInputType.number,
                                validator: (v) => v == null || int.tryParse(v) == null ? 'Enter a valid number' : null,
                                onSaved: (v) => goalWeight = int.tryParse(v ?? ''),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                initialValue: currentWeight?.toString(),
                                decoration: const InputDecoration(labelText: 'Current Weight (kg)'),
                                keyboardType: TextInputType.number,
                                validator: (v) => v == null || int.tryParse(v) == null ? 'Enter a valid number' : null,
                                onSaved: (v) => currentWeight = int.tryParse(v ?? ''),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kAccentBlue,
                                    foregroundColor: kTextDark,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  onPressed: _save,
                                  child: const Text('Save'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
} 