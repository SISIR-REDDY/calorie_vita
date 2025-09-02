import 'package:flutter/material.dart';
import '../widgets/chat_bubble.dart';
import '../services/sisir_service.dart';
import '../ui/app_colors.dart';

class AITrainerScreen extends StatefulWidget {
  const AITrainerScreen({super.key});

  @override
  State<AITrainerScreen> createState() => _AITrainerScreenState();
}

class _AITrainerScreenState extends State<AITrainerScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isDark = false;
  bool isLoading = false;
  List<Message> messages = [
    Message(sender: 'Sisir', text: 'Hi! I am Trainer Sisir. Ask me anything about fitness or nutrition!', timestamp: DateTime.now()),
    Message(sender: 'user', text: 'How to lose fat?', timestamp: DateTime.now()),
    Message(sender: 'Sisir', text: 'Start with cutting sugar and walking 30 mins daily.', timestamp: DateTime.now()),
  ];

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add(Message(sender: 'user', text: text, timestamp: DateTime.now()));
      isLoading = true;
      _controller.clear();
    });
    await Future.delayed(const Duration(milliseconds: 300));
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 100,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    String reply;
    try {
      reply = await SisirService.getSisirReply(messages);
    } catch (e) {
      reply = 'Sorry, there was a problem connecting to the AI service.';
    }
    setState(() {
      messages.add(Message(sender: 'Sisir', text: reply, timestamp: DateTime.now()));
      isLoading = false;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 100,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = isDark ? ThemeData.dark() : ThemeData.light();
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : kSoftWhite,
        appBar: AppBar(
          backgroundColor: isDark ? Colors.grey[900] : kSoftWhite,
          elevation: 0,
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: kAccentBlue,
                child: Icon(Icons.directions_run, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('Trainer Sisir', style: TextStyle(fontWeight: FontWeight.bold, color: kTextDark)),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: kAccentBlue),
              tooltip: 'New Chat',
              onPressed: () {
                setState(() {
                  messages = [
                    Message(sender: 'Sisir', text: 'Hi! I am Trainer Sisir. Ask me anything about fitness or nutrition!', timestamp: DateTime.now()),
                  ];
                });
              },
            ),
            IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: kAccentBlue),
              onPressed: () => setState(() => isDark = !isDark),
              tooltip: isDark ? 'Light mode' : 'Dark mode',
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                itemCount: messages.length + (isLoading ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == messages.length && isLoading) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    );
                  }
                  final msg = messages[i];
                  return ChatBubble(
                    text: msg.text,
                    sender: msg.sender == 'user' ? 'You' : 'Sisir',
                    timestamp: msg.timestamp,
                    isUser: msg.sender == 'user',
                  );
                },
              ),
            ),
            Container(
              color: isDark ? Colors.grey[850] : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.mic_none, color: kAccentBlue),
                    onPressed: () {},
                    tooltip: 'Voice (coming soon)',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Ask Trainer Sisir... ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : kAccentBlue.withOpacity(0.08),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: kAccentBlue,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                      tooltip: 'Send',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 