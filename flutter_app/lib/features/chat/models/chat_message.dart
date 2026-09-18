enum ChatSender { user, ai }

enum MessageStatus { sending, success, error, offlineFallback }

class ChatMessage {
  final String id;
  final String text;
  final ChatSender sender;
  final DateTime timestamp;
  final MessageStatus status;
  final List<String>? sources;
  final String? errorMessage;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.status = MessageStatus.success,
    this.sources,
    this.errorMessage,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    ChatSender? sender,
    DateTime? timestamp,
    MessageStatus? status,
    List<String>? sources,
    String? errorMessage,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      sources: sources ?? this.sources,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'sender': sender.name,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'sources': sources,
      'errorMessage': errorMessage,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      sender: ChatSender.values.firstWhere(
        (e) => e.name == json['sender'],
        orElse: () => ChatSender.ai,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.success,
      ),
      sources: (json['sources'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
