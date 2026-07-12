class AiCache {
  late String cacheKey;
  late String type;
  late String content;
  late DateTime generatedAt;

  AiCache({
    required this.cacheKey,
    required this.type,
    required this.content,
    required this.generatedAt,
  });

  factory AiCache.fromJson(Map<String, dynamic> json) {
    return AiCache(
      cacheKey: json['cache_key'] as String? ?? '',
      type: json['type'] as String? ?? '',
      content: json['content'] as String? ?? '',
      generatedAt: json['generated_at'] != null ? DateTime.parse(json['generated_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cache_key': cacheKey,
      'type': type,
      'content': content,
      'generated_at': generatedAt.toIso8601String(),
    };
  }
}
