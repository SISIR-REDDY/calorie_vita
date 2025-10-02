import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';
import 'lib/services/firebase_setup_checker.dart';

/// Simple test script to check Firebase setup
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 Starting Firebase Setup Test...\n');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully\n');
    
    // Check all services
    final checker = FirebaseSetupChecker();
    final results = await checker.checkAllServices();
    
    // Get recommendations
    final recommendations = checker.getSetupRecommendations(results);
    
    if (recommendations.isNotEmpty) {
      print('\n📝 Setup Recommendations:');
      print('=' * 40);
      for (int i = 0; i < recommendations.length; i++) {
        print('${i + 1}. ${recommendations[i]}');
      }
      print('=' * 40);
    }
    
    // Final status
    final overallStatus = results['overall_status'];
    print('\n🎯 Final Status: $overallStatus');
    
    if (overallStatus.toString().contains('✅')) {
      print('🎉 Your Firebase setup is ready!');
    } else {
      print('⚠️  Please complete the setup recommendations above.');
    }
    
  } catch (e) {
    print('❌ Firebase setup test failed: $e');
    print('\n📝 Next Steps:');
    print('1. Make sure you have internet connection');
    print('2. Check if Firebase project "calorie-vita" exists');
    print('3. Verify Firebase services are enabled in Console');
  }
}
