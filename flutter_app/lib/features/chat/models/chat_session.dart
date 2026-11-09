import 'chat_message.dart';

class ChatSession {
  const ChatSession({
    required this.id,
    required this.scope,
    required this.scopeId,
    required this.messages,
  });

  final String id;
  final String scope;
  final String scopeId;
  final List<ChatMessage> messages;

  DateTime get lastActivity => messages.last.timestamp;

  String get contextLabel {
    if (scope == 'subject') return 'Môn $scopeId';
    final parts = scopeId.split(':');
    if (parts.length < 2) return 'Chương trình ${parts.first}';
    final context = parts.last;
    if (context.startsWith('semester-')) {
      return 'Học kỳ ${context.substring(9)} · ${parts.first}';
    }
    const labels = {
      'home': 'Trang chủ',
      'roadmap': 'Lộ trình học',
      'graph': 'Sơ đồ môn học',
      'transcript': 'Bảng điểm',
      'settings': 'Mục tiêu học tập',
    };
    return '${labels[context] ?? context} · ${parts.first}';
  }

  String get title {
    for (final message in messages) {
      if (message.sender == ChatSender.user) {
        final firstLine = message.text.split('\n').first;
        return firstLine.length > 55
            ? '${firstLine.substring(0, 55)}…'
            : firstLine;
      }
    }
    return 'Phiên mới';
  }

  String get category {
    final question = title.toLowerCase();
    if (question.contains('tiên quyết') || question.contains('điều kiện')) {
      return 'Điều kiện học';
    }
    if (question.contains('điểm') || question.contains('gpa')) {
      return 'Điểm và GPA';
    }
    if (question.contains('tư vấn') || question.contains('cách học')) {
      return 'Chiến lược học';
    }
    return scope == 'subject' ? 'Môn học $scopeId' : 'Tổng quan chương trình';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'scope': scope,
    'scope_id': scopeId,
    'messages': messages.map((message) => message.toJson()).toList(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'] as String,
    scope: json['scope'] as String,
    scopeId: json['scope_id'] as String,
    messages: (json['messages'] as List<dynamic>)
        .map((row) => ChatMessage.fromJson(row as Map<String, dynamic>))
        .toList(),
  );
}
