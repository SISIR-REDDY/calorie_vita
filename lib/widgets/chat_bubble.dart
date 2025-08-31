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
    final bubbleColor = isUser ? kPrimaryColor : kSurfaceColor;
    final textColor = isUser ? Colors.white : kTextPrimary;
    final senderColor = isUser ? Colors.white.withOpacity(0.8) : kTextSecondary;
    final timeColor = isUser ? Colors.white.withOpacity(0.6) : kTextTertiary;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () async {
          await Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Message copied!'),
              backgroundColor: kSuccessColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 20),
            ),
            boxShadow: isUser ? [
              BoxShadow(
                color: kPrimaryColor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ] : [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sender,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: senderColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 11,
                      color: timeColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 