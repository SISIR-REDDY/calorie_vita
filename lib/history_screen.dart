import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ui/app_colors.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final user = FirebaseAuth.instance.currentUser;

  Stream<QuerySnapshot<Map<String, dynamic>>> get _weightsStream {
    if (user == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('weights')
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> _addWeight() async {
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Weight Entry'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Weight (kg)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null && user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('weights')
          .add({'weight': result, 'date': DateTime.now()});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weight History')),
      body: Container(
        decoration: kAppBackground,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _weightsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('No weight entries yet.', style: TextStyle(fontSize: 16)));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final data = docs[i].data();
                final date = (data['date'] as Timestamp).toDate();
                final weight = data['weight'];
                return Container(
                  decoration: BoxDecoration(
                    color: kAccentBlue.withOpacity(0.35),
                    border: Border.all(color: kAccentBlue.withOpacity(0.7), width: 2),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.monitor_weight, color: kAccentBlue),
                    title: Text('$weight kg', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: kTextDark)),
                    subtitle: Text(
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                      style: GoogleFonts.poppins(color: kTextGrey),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addWeight,
        child: const Icon(Icons.add),
        backgroundColor: kAccentBlue,
        foregroundColor: kTextDark,
        shape: const CircleBorder(),
      ),
    );
  }
} 