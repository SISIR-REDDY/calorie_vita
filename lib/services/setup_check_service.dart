import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'google_fit_service.dart';

class SetupCheckService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if user has completed their setup
  static Future<bool> isSetupComplete() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Check if user has personal details
      final hasPersonalDetails = await _hasPersonalDetails(user.uid);
      
      // Check if user has goals set
      final hasGoals = await _hasGoals(user.uid);
      
      // Check if Google Fit is connected
      final hasGoogleFit = await _hasGoogleFitConnected();

      return hasPersonalDetails && hasGoals && hasGoogleFit;
    } catch (e) {
      print('Error checking setup completion: $e');
      return false;
    }
  }

  /// Check if user has personal details filled
  static Future<bool> _hasPersonalDetails(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      // Check for essential personal details
      final hasName = data['name'] != null && 
                     data['name'].toString().trim().isNotEmpty;
      final hasAge = data['age'] != null && 
                    data['age'] is int && 
                    data['age'] > 0;
      final hasGender = data['gender'] != null && 
                       data['gender'].toString().trim().isNotEmpty;
      final hasHeight = data['height'] != null && 
                       data['height'] is double && 
                       data['height'] > 0;
      final hasWeight = data['weight'] != null && 
                       data['weight'] is double && 
                       data['weight'] > 0;

      return hasName && hasAge && hasGender && hasHeight && hasWeight;
    } catch (e) {
      print('Error checking personal details: $e');
      return false;
    }
  }

  /// Check if user has goals set
  static Future<bool> _hasGoals(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_goals')
          .doc(userId)
          .get();

      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      // Check for essential goals
      final hasCalorieGoal = data['dailyCalorieGoal'] != null && 
                            data['dailyCalorieGoal'] is int && 
                            data['dailyCalorieGoal'] > 0;
      final hasWeightGoal = data['targetWeight'] != null && 
                           data['targetWeight'] is double && 
                           data['targetWeight'] > 0;

      return hasCalorieGoal && hasWeightGoal;
    } catch (e) {
      print('Error checking goals: $e');
      return false;
    }
  }

  /// Check if Google Fit is connected
  static Future<bool> _hasGoogleFitConnected() async {
    try {
      final googleFitService = GoogleFitService();
      return googleFitService.isAuthenticated;
    } catch (e) {
      print('Error checking Google Fit connection: $e');
      return false;
    }
  }

  /// Get setup completion status with details
  static Future<Map<String, dynamic>> getSetupStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'isComplete': false,
          'hasPersonalDetails': false,
          'hasGoals': false,
          'hasGoogleFit': false,
          'missingItems': ['Authentication'],
        };
      }

      final hasPersonalDetails = await _hasPersonalDetails(user.uid);
      final hasGoals = await _hasGoals(user.uid);
      final hasGoogleFit = await _hasGoogleFitConnected();

      final missingItems = <String>[];
      if (!hasPersonalDetails) missingItems.add('Personal Details');
      if (!hasGoals) missingItems.add('Fitness Goals');
      if (!hasGoogleFit) missingItems.add('Google Fit Connection');

      return {
        'isComplete': hasPersonalDetails && hasGoals && hasGoogleFit,
        'hasPersonalDetails': hasPersonalDetails,
        'hasGoals': hasGoals,
        'hasGoogleFit': hasGoogleFit,
        'missingItems': missingItems,
      };
    } catch (e) {
      print('Error getting setup status: $e');
      return {
        'isComplete': false,
        'hasPersonalDetails': false,
        'hasGoals': false,
        'hasGoogleFit': false,
        'missingItems': ['Error checking setup'],
      };
    }
  }
}
