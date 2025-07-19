import 'dart:convert';
import 'package:http/http.dart' as http;

class Message {
  final String sender;
  final String text;
  final DateTime timestamp;
  Message({required this.sender, required this.text, required this.timestamp});
}

class SisirService {
  static const String _geminiApiKey = 'AIzaSyCid1YKfdcCfeytaTkfMm1Qa_GekRh6vik';

  static Future<String> getSisirReply(List<Message> messages) async {
    // Send only the latest user message for best Gemini results
    final latestUserMsg = messages.lastWhere((m) => m.sender == 'user', orElse: () => Message(sender: 'user', text: '', timestamp: DateTime.now())).text;
    final prompt = latestUserMsg;
    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest:generateContent'),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _geminiApiKey,
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );
      print('Gemini API status: ${response.statusCode}');
      print('Gemini API body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          if (content != null && content['parts'] != null && content['parts'].isNotEmpty) {
            return content['parts'][0]['text']?.trim() ?? 'Sorry, I have no answer.';
          }
        }
      }
    } catch (e) {
      print('Gemini API error: ${e.toString()}');
    }
    // Fallback offline logic
    final last = messages.isNotEmpty ? messages.last.text.toLowerCase() : '';
    if (last.contains('lose fat')) {
      return 'Start with cutting sugar and walking 30 mins daily.';
    } else if (last.contains('lazy')) {
      return 'Start with 10 push-ups! Small wins build big results!';
    } else if (last.contains('protein')) {
      return 'Eggs, chicken, tofu, and lentils are great protein sources.';
    }
    return 'Let’s keep moving! Ask me anything about fitness or nutrition.';
  }
}

extension TakeLast<T> on List<T> {
  Iterable<T> takeLast(int n) => skip(length - n < 0 ? 0 : length - n);
} 