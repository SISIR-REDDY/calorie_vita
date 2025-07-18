import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class Message {
  final String sender;
  final String text;
  final DateTime timestamp;
  Message({required this.sender, required this.text, required this.timestamp});
}

class SisirService {
  static Future<String> getSisirReply(List<Message> messages) async {
    // Limit to last 5 messages
    final recent = messages.takeLast(5).toList();
    try {
      final response = await http.post(
        Uri.parse(openAIEndpoint),
        headers: {
          'Authorization': 'Bearer $openAIApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': recent.map((m) => {
            'role': m.sender == 'user' ? 'user' : 'assistant',
            'content': m.text,
          }).toList(),
          'max_tokens': 120,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content']?.trim() ?? 'Sorry, I have no answer.';
      }
    } catch (_) {}
    // Fallback offline logic
    final last = recent.isNotEmpty ? recent.last.text.toLowerCase() : '';
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