import 'package:flutter/material.dart';
import '../ui/app_colors.dart';
import 'package:flutter/services.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final String sender;
  final DateTime timestamp;
  final bool isUser;
  const ChatBubble({required this.text, required this.sender, required this.timestamp, required this.isUser, super.key});

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isUser ? kAccentBlue : Colors.white;
    final textColor = isUser ? Colors.white : kTextDark;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () async {
          await Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Message copied!')),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(text, style: TextStyle(color: textColor, fontSize: 16)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(sender, style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.7))),
                  const SizedBox(width: 8),
                  Text('${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.5))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 