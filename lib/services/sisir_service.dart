import 'dart:convert';
import 'package:http/http.dart' as http;

class Message {
  final String sender;
  final String text;
  final DateTime timestamp;

  Message({required this.sender, required this.text, required this.timestamp});
}

class SisirService {
  static const String _openRouterApiKey = 'YOUR_OPENROUTER_API_KEY_HERE'; // TODO: Replace with your actual OpenRouter API key

  static Future<String> getSisirReply(List<Message> messages) async {
    final latestUserMsg = messages.lastWhere((m) => m.sender == 'user', orElse: () => Message(sender: 'user', text: '', timestamp: DateTime.now())).text;
    final prompt = latestUserMsg;
    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openRouterApiKey',
        },
        body: jsonEncode({
          'model': 'mistralai/mistral-7b-instruct',
          'messages': [
            {'role': 'system', 'content': 'You are Trainer Sisir, a friendly and knowledgeable fitness and nutrition coach.'},
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 150,
          'temperature': 0.7,
        }),
      );
      print('OpenRouter API status: ${response.statusCode}');
      print('OpenRouter API body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'];
          if (message != null && message['content'] != null) {
            return message['content'].toString().trim();
          }
        }
      } else {
        final data = jsonDecode(response.body);
        return data['error']?['message'] ?? 'Sorry, there was a problem connecting to the AI service.';
      }
    } catch (e) {
      print('OpenRouter API error: ${e.toString()}');
    }
    return 'Let’s keep moving! Ask me anything about fitness or nutrition.';
  }
}

extension TakeLast<T> on List<T> {
  Iterable<T> takeLast(int n) => skip(length - n < 0 ? 0 : length - n);
}
