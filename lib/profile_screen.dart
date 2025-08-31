import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ui/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  int? age;
  String? gender;
  String? hobbies;
  String? profession;
  String? activityLevel;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    setState(() {
      age = doc.data()?['age'] ?? 0;
      gender = doc.data()?['gender'] ?? '';
      hobbies = doc.data()?['hobbies'] ?? '';
      profession = doc.data()?['profession'] ?? '';
      activityLevel = doc.data()?['activityLevel'] ?? '';
      loading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (user == null) return;
    setState(() { loading = true; });
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'age': age,
      'gender': gender,
      'hobbies': hobbies,
      'profession': profession,
      'activityLevel': activityLevel,
    }, SetOptions(merge: true));
    setState(() { loading = false; });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personal Details')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: kAppBackground,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      elevation: 8,
                      color: kAccentBlue.withOpacity(0.35),
                      shadowColor: kAccentBlue.withOpacity(0.08),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: kAccentBlue.withOpacity(0.7), width: 2),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(28.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Personal Details', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark)),
                                const SizedBox(height: 24),
                                DropdownButtonFormField<String>(
                                  value: gender?.isNotEmpty == true ? gender : null,
                                  decoration: const InputDecoration(labelText: 'Gender'),
                                  items: const [
                                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                                  ],
                                  onChanged: (v) => setState(() => gender = v),
                                  onSaved: (v) => gender = v,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  initialValue: age?.toString(),
                                  decoration: const InputDecoration(labelText: 'Age'),
                                  keyboardType: TextInputType.number,
                                  validator: (v) => v == null || int.tryParse(v) == null ? 'Enter a valid age' : null,
                                  onSaved: (v) => age = int.tryParse(v ?? ''),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  initialValue: hobbies,
                                  decoration: const InputDecoration(labelText: 'Hobbies'),
                                  onSaved: (v) => hobbies = v,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  initialValue: profession,
                                  decoration: const InputDecoration(labelText: 'Profession'),
                                  onSaved: (v) => profession = v,
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: activityLevel?.isNotEmpty == true ? activityLevel : null,
                                  decoration: const InputDecoration(labelText: 'Activity Level'),
                                  items: const [
                                    DropdownMenuItem(value: 'Sedentary', child: Text('Sedentary')),
                                    DropdownMenuItem(value: 'Lightly Active', child: Text('Lightly Active')),
                                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                                    DropdownMenuItem(value: 'Very Active', child: Text('Very Active')),
                                  ],
                                  onChanged: (v) => setState(() => activityLevel = v),
                                  onSaved: (v) => activityLevel = v,
                                ),
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kAccentBlue,
                                      foregroundColor: Colors.white,
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
            ),
    );
  }
} 