class ChatMessage {
  String? id;
  late String text;
  late bool isUser;
  late DateTime timestamp;

  ChatMessage({
    this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String?,
      text: json['content'] as String? ?? '',
      isUser: (json['role'] as String?) == 'user',
      timestamp: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'role': isUser ? 'user' : 'assistant',
      'content': text,
      'created_at': timestamp.toIso8601String(),
    };
  }
}
