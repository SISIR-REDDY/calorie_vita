import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  // TODO: Replace with your actual Google Gemini API key
  static const String _geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

  /// Send a message to Gemini with user profile context
  static Future<String> getPersonalizedResponse({
    required String userQuery,
    required Map<String, dynamic> userProfile,
    required List<Map<String, dynamic>> conversationHistory,
  }) async {
    try {
      // Build context from user profile
      final profileContext = _buildProfileContext(userProfile);
      
      // Build conversation context
      final conversationContext = _buildConversationContext(conversationHistory);
      
      // Create the prompt
      final prompt = '''
You are Trainer Sisir, a friendly and knowledgeable fitness and nutrition coach for the Calorie Vita app.

User Profile:
$profileContext

Conversation History:
$conversationContext

Current User Query: $userQuery

Instructions:
- Address the user by their name from the profile
- Provide personalized advice based on their profile (age, weight, height, fitness goals, hobbies)
- Give specific, actionable recommendations
- Include motivational elements and emojis
- Keep responses concise but helpful (max 200 words)
- If BMI is high, suggest weight loss plans
- If user has specific hobbies like running, recommend related exercises
- If goal is muscle gain, suggest strength training and protein advice
- Always end with an encouraging message

Respond as Trainer Sisir:
''';

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_geminiApiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 300,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List?;
          
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text']?.toString().trim() ?? 
                   'Hey! I\'m here to help with your fitness journey. What would you like to know? 💪';
          }
        }
      } else {
        print('Gemini API error: ${response.statusCode} - ${response.body}');
        return _getFallbackResponse(userProfile);
      }
    } catch (e) {
      print('Gemini API exception: $e');
      return _getFallbackResponse(userProfile);
    }
    
    return _getFallbackResponse(userProfile);
  }

  /// Build profile context string from user data
  static String _buildProfileContext(Map<String, dynamic> profile) {
    final name = profile['name'] ?? 'there';
    final age = profile['age'] ?? 'not specified';
    final height = profile['height'] ?? 'not specified';
    final weight = profile['weight'] ?? 'not specified';
    final gender = profile['gender'] ?? 'not specified';
    final fitnessGoals = profile['fitnessGoals'] ?? 'not specified';
    final hobbies = profile['hobbies'] ?? 'not specified';
    final activityLevel = profile['activityLevel'] ?? 'not specified';

    // Calculate BMI if possible
    String bmiInfo = '';
    if (height != 'not specified' && weight != 'not specified') {
      try {
        final heightCm = double.parse(height.toString());
        final weightKg = double.parse(weight.toString());
        final bmi = weightKg / ((heightCm / 100) * (heightCm / 100));
        bmiInfo = '\nBMI: ${bmi.toStringAsFixed(1)}';
      } catch (e) {
        // Ignore BMI calculation errors
      }
    }

    return '''
Name: $name
Age: $age years
Height: $height cm
Weight: $weight kg$bmiInfo
Gender: $gender
Fitness Goals: $fitnessGoals
Hobbies: $hobbies
Activity Level: $activityLevel
''';
  }

  /// Build conversation context from chat history
  static String _buildConversationContext(List<Map<String, dynamic>> history) {
    if (history.isEmpty) return 'This is the start of our conversation.';
    
    final recentHistory = history.takeLast(6).toList(); // Last 6 messages
    final context = recentHistory.map((msg) {
      final sender = msg['sender'] == 'user' ? 'User' : 'Sisir';
      final text = msg['text'] ?? '';
      return '$sender: $text';
    }).join('\n');
    
    return context;
  }

  /// Fallback response when API fails
  static String _getFallbackResponse(Map<String, dynamic> profile) {
    final name = profile['name'] ?? 'there';
    final fitnessGoals = profile['fitnessGoals'] ?? 'general fitness';
    
    return 'Hey $name! 👋 I\'m here to help you with your $fitnessGoals journey. '
           'What specific question do you have about fitness or nutrition? 💪';
  }
}

extension TakeLast<T> on List<T> {
  Iterable<T> takeLast(int n) => skip(length - n < 0 ? 0 : length - n);
}
