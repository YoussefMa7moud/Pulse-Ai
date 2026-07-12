import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'ai_provider.dart';

/// Groq API implementation of [AIProvider].
/// Uses the OpenAI-compatible Groq chat completions endpoint.
class GroqProvider implements AIProvider {
  final String model;

  GroqProvider({this.model = 'llama-3.3-70b-versatile'});

  @override
  Future<String> generateContent({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    return generateContentWithMessages([
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ]);
  }

  @override
  Future<String> generateContentWithMessages(
      List<Map<String, String>> messages) async {
    final apiKey = dotenv.env['GROQ_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      return 'Error: GROQ_API_KEY is not set in .env';
    }

    final url =
        Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      } else {
        try {
          final err = jsonDecode(response.body);
          return 'API Error: ${err['error']['message'] ?? 'Unknown error'}';
        } catch (_) {
          return 'AI Service is currently unavailable. (${response.statusCode})';
        }
      }
    } catch (e) {
      return 'AI Service is currently unavailable. Network error: $e';
    }
  }

  @override
  Stream<String> generateContentStream({
    required String systemPrompt,
    required String userPrompt,
  }) async* {
    // For simplicity, yields the complete response as a single chunk.
    // A production implementation would use HTTP streaming (SSE).
    yield await generateContent(
        systemPrompt: systemPrompt, userPrompt: userPrompt);
  }
}
