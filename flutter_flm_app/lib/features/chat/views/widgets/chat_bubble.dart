import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == ChatSender.user;
    final timeStr = DateFormat('HH:mm').format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: message.status == MessageStatus.offlineFallback
                  ? Colors.amber.shade700
                  : const Color(0xFF1E88E5),
              child: Icon(
                message.status == MessageStatus.offlineFallback
                    ? Icons.offline_bolt
                    : Icons.smart_toy,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 580),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF1976D2)
                    : (message.status == MessageStatus.offlineFallback
                        ? Colors.amber.shade50
                        : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: !isUser
                    ? Border.all(
                        color: message.status == MessageStatus.offlineFallback
                            ? Colors.amber.shade300
                            : Colors.grey.shade300,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Offline Fallback Header Notice
                  if (message.status == MessageStatus.offlineFallback) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off, size: 14, color: Colors.brown),
                          SizedBox(width: 6),
                          Text(
                            'Phản hồi Ngoại tuyến (Resilience Mode)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Message Content Body
                  if (message.status == MessageStatus.sending)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Đang kết nối & tra cứu dữ liệu FLM...',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    )
                  else
                    SelectableText(
                      message.text,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.4,
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),

                  // Sources Section (If AI message has sources)
                  if (message.sources != null &&
                      message.sources!.isNotEmpty &&
                      message.status != MessageStatus.sending) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        const Text(
                          '📚 Nguồn:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        ...message.sources!.map(
                          (src) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? Colors.blue.shade800
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isUser
                                    ? Colors.blue.shade400
                                    : Colors.blue.shade200,
                              ),
                            ),
                            child: Text(
                              src,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isUser
                                    ? Colors.white
                                    : Colors.blue.shade800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Footer: Timestamp + Copy Button
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isUser ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: message.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép nội dung tin nhắn!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.copy,
                          size: 13,
                          color: isUser ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF1565C0),
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}
