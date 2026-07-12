/// Abstract contract for all AI backends used by Pulse AI.
/// Implementations: [GroqProvider], (future: OpenAI, Gemini, Claude)
abstract class AIProvider {
  /// Generates a response from a system prompt + single user message.
  Future<String> generateContent({
    required String systemPrompt,
    required String userPrompt,
  });

  /// Generates a response from a full OpenAI-style messages array.
  /// Used by the AI coach to preserve conversation history.
  /// Each message is a map: {'role': 'system'|'user'|'assistant', 'content': '...'}
  Future<String> generateContentWithMessages(
      List<Map<String, String>> messages);

  /// Streams a response — used by chat interfaces for streaming output.
  Stream<String> generateContentStream({
    required String systemPrompt,
    required String userPrompt,
  });
}
