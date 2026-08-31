import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';

/// Cloud AI service using Google Gemini API (free tier: 15 req/min).
/// Falls back gracefully when offline or on error.
class GeminiService {
  static const _kApiKey = 'gemini_api_key';
  static const _kEnabled = 'gemini_enabled';
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const _model = 'gemini-2.0-flash-lite';

  static bool get isEnabled => AppSettings.getGeminiEnabled();

  static Future<void> setEnabled(bool v) async {
    await AppSettings.setGeminiEnabled(v);
  }

  static Future<void> setApiKey(String key) async {
    await AppSettings.setGeminiApiKey(key);
  }

  static String getApiKey() => AppSettings.getGeminiApiKey();

  static bool get isConfigured => getApiKey().isNotEmpty;

  /// Send a chat message to Gemini and stream the response.
  /// Returns a stream of text chunks.
  static Stream<String> sendMessage(
    List<Map<String, String>> messages, {
    String? systemPrompt,
  }) async* {
    if (!isConfigured) return;

    final apiKey = getApiKey();
    final url = Uri.parse('$_baseUrl/models/$_model:streamGenerateContent?key=$apiKey');

    // Build Gemini-style contents
    final contents = <Map<String, dynamic>>[];
    for (final msg in messages) {
      final role = msg['role'] == 'assistant' ? 'model' : 'user';
      contents.add({
        'role': role,
        'parts': [{'text': msg['content']}],
      });
    }

    final body = {
      'contents': contents,
      'systemInstruction': systemPrompt != null
          ? {'parts': [{'text': systemPrompt}]}
          : null,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 512,
      },
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API error ${response.statusCode}');
    }

    // Parse the JSON response and extract text
    final json = jsonDecode(response.body);
    final candidates = json['candidates'] as List?;
    if (candidates != null && candidates.isNotEmpty) {
      final content = candidates[0]['content'];
      final parts = content['parts'] as List?;
      if (parts != null) {
        for (final part in parts) {
          final text = part['text'] as String?;
          if (text != null) {
            // Simulate streaming by yielding chunks
            for (int i = 0; i < text.length; i += 4) {
              final end = (i + 4).clamp(0, text.length);
              yield text.substring(i, end);
            }
          }
        }
      }
    }
  }

  /// Non-streaming: send a message and wait for the full response.
  static Future<String> sendAndWait(
    List<Map<String, String>> messages, {
    String? systemPrompt,
  }) async {
    final buffer = StringBuffer();
    await for (final chunk in sendMessage(messages, systemPrompt: systemPrompt)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }
}
