import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_keys.dart';

/// Direct Gemini REST calls using the AQ. key as a query parameter.
/// Works in Chrome/Edge (web). For Android, use Cloud Functions instead.
class GeminiService {
  static const _model = 'gemini-2.5-flash-lite';
  static const _base  =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  // ── Core call ──────────────────────────────────────────────────────────────
  static Future<String> _call({
    required String prompt,
    double temperature = 0.2,
    int maxTokens = 300,
  }) async {
    final uri = Uri.parse('$_base?key=${ApiKeys.gemini}');

    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [{'text': prompt}]
          }
        ],
        'generationConfig': {
          'temperature': temperature,
          'maxOutputTokens': maxTokens,
        },
      }),
    ).timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      throw Exception('Gemini HTTP ${resp.statusCode}: ${resp.body}');
    }

    final data    = jsonDecode(resp.body) as Map<String, dynamic>;
    final text    = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw Exception('Empty response from Gemini');
    }
    return text.trim();
  }

  // ── Classification ──────────────────────────────────────────────────────────
  static Future<Map<String, String>> classify({
    required String ticketId,
    required String message,
  }) async {
    const allowedCategories = ['billing', 'bug', 'question', 'complaint'];
    const allowedUrgencies  = ['low', 'medium', 'high'];
    const allowedSentiments = ['angry', 'neutral', 'happy'];

    final prompt =
        'You are a support ticket classifier. Classify the following '
        'customer support message. Respond ONLY with a valid JSON object, '
        'no markdown, no explanation, exactly in this format: '
        '{"category": "billing" or "bug" or "question" or "complaint", '
        '"urgency": "low" or "medium" or "high", '
        '"sentiment": "angry" or "neutral" or "happy"}. '
        'Message: $message';

    var raw = await _call(prompt: prompt, temperature: 0.1, maxTokens: 120);

    // Strip markdown fences if present
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(raw);
    if (fence != null) raw = fence.group(1)!.trim();

    final parsed    = jsonDecode(raw) as Map<String, dynamic>;
    final category  = parsed['category']  as String?;
    final urgency   = parsed['urgency']   as String?;
    final sentiment = parsed['sentiment'] as String?;

    if (!allowedCategories.contains(category) ||
        !allowedUrgencies.contains(urgency)   ||
        !allowedSentiments.contains(sentiment)) {
      throw Exception('Invalid classification values: $parsed');
    }

    debugPrint('GeminiService: classified ticket $ticketId → $parsed');
    return {
      'category' : category!,
      'urgency'  : urgency!,
      'sentiment': sentiment!,
    };
  }

  // ── Draft reply ─────────────────────────────────────────────────────────────
  static Future<String> generateDraft({
    required String ticketId,
    required String message,
    required String category,
    required String urgency,
    required String sentiment,
  }) async {
    final prompt =
        'You are a professional customer support agent. Write a helpful, '
        'empathetic reply to the following customer support message. '
        'The message has been classified as category: $category, '
        'urgency: $urgency, sentiment: $sentiment. '
        'Keep the reply concise (2-4 sentences), professional, and '
        'directly address the customer\'s concern. Do not use placeholders '
        'like [Name] or [Agent]. Sign off as \'The Support Team\'. '
        'Respond with ONLY the reply text, no explanation, no subject line, '
        'no formatting.';

    final draft = await _call(prompt: prompt, temperature: 0.7, maxTokens: 300);
    debugPrint('GeminiService: draft generated for ticket $ticketId (${draft.length} chars)');
    return draft;
  }
}
