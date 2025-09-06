import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void testFirestoreConnection() async {
  try {
    print('Testing Firestore connection...');
    
    // Test basic connection
    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    
    print('Current user: ${auth.currentUser?.uid}');
    
    // Test a simple query
    final querySnapshot = await firestore
        .collection('weightLogs')
        .where('userId', isEqualTo: auth.currentUser?.uid ?? 'test')
        .limit(1)
        .get();
    
    print('Query successful! Found ${querySnapshot.docs.length} documents');
    
  } catch (e) {
    print('Firestore error: $e');
  }
}
