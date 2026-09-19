import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../data/local/preferences_service.dart';
import '../../models/models.dart';
import 'ai_parser_helper.dart';
import 'ai_provider.dart';

class ClaudeProvider implements AiProvider {
  final http.Client _client = http.Client();

  @override
  String get id => 'claude';

  @override
  String get displayName => 'Anthropic Claude';

  @override
  List<String> get availableModels => [
        'claude-3-5-haiku-20241022',
        'claude-3-5-sonnet-20241022',
        'claude-3-opus-20240229',
      ];

  Future<String> _getEffectiveKey(String? overrideKey) async {
    if (overrideKey != null && overrideKey.trim().isNotEmpty) {
      return overrideKey.trim();
    }
    final savedKey = await PreferencesService.instance.getClaudeApiKey();
    return savedKey?.trim() ?? "";
  }

  Future<String> _getEffectiveModel(String? overrideModel) async {
    if (overrideModel != null && overrideModel.trim().isNotEmpty) {
      return overrideModel.trim();
    }
    return await PreferencesService.instance.getClaudeModel();
  }

  @override
  Future<bool> isConfigured() async {
    final key = await _getEffectiveKey(null);
    return key.isNotEmpty;
  }

  @override
  Future<Map<String, dynamic>> testConnection({String? apiKey, String? model}) async {
    final key = await _getEffectiveKey(apiKey);
    if (key.isEmpty) {
      return {'success': false, 'message': 'Claude API key is required.'};
    }
    final mod = await _getEffectiveModel(model);

    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    if (kDebugMode) {
      debugPrint('[AI] [Claude] Testing connection ($mod)...');
    }

    try {
      final res = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': key,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': mod,
          'max_tokens': 10,
          'messages': [
            {'role': 'user', 'content': 'ping'}
          ],
        }),
      ).timeout(const Duration(seconds: 12));

      if (kDebugMode) {
        debugPrint('[AI] [Claude] Test connection returned HTTP ${res.statusCode}');
      }

      if (res.statusCode == 200) {
        return {'success': true, 'message': 'Claude connected successfully.'};
      } else if (res.statusCode == 401) {
        return {'success': false, 'message': 'Invalid Claude API key or unauthorized (HTTP 401).'};
      } else if (res.statusCode == 429) {
        return {'success': false, 'message': 'Claude rate limit exceeded (HTTP 429).'};
      } else {
        return {'success': false, 'message': 'Claude returned status ${res.statusCode}.'};
      }
    } on SocketException {
      return {'success': false, 'message': 'Network connection failed. Check your internet connection.'};
    } on TimeoutException {
      return {'success': false, 'message': 'Claude test timed out. Check your internet connection.'};
    } catch (e) {
      return {'success': false, 'message': 'Connection test error: $e'};
    }
  }

  @override
  Future<String?> transcribeAudio(File audioFile, {String? language, String? model, String? apiKey}) async {
    // Claude does not currently support audio transcription. Return null to allow fallback.
    return null;
  }

  static String? _extractContentText(Map<String, dynamic> decoded) {
    try {
      final contentList = decoded['content'];
      if (contentList is List && contentList.isNotEmpty) {
        final firstItem = contentList[0];
        if (firstItem is Map && firstItem['text'] != null) {
          return firstItem['text'].toString();
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<NoteAiAnalysis> analyzeContent(String content, String title, {String? language, String? model, String? apiKey}) async {
    final key = await _getEffectiveKey(apiKey);
    final mod = await _getEffectiveModel(model);

    if (key.isEmpty) {
      if (kDebugMode) {
        debugPrint('[AI] [Claude] API key missing for content analysis.');
      }
      throw const AiConfigurationException("Please configure an AI provider in Settings → AI Providers.");
    }

    if (kDebugMode) {
      debugPrint('[AI] [Claude] Analyzing content ($mod)');
    }

    final systemPrompt = AiParserHelper.buildSystemPrompt(language: language);
    final userPrompt = '''
Note Title: "$title"
Content to analyze:
"""
$content
"""
''';

    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    try {
      final res = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': key,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': mod,
          'max_tokens': 2048,
          'system': systemPrompt,
          'messages': [
            {'role': 'user', 'content': userPrompt}
          ],
        }),
      ).timeout(const Duration(seconds: 40));

      if (kDebugMode) {
        debugPrint('[AI] [Claude] Analysis returned HTTP ${res.statusCode}');
      }

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final text = _extractContentText(decoded);
        if (text != null && text.trim().isNotEmpty) {
          return AiParserHelper.parseAiResponse(text, title);
        }
        throw const AiApiException("Claude returned an empty response.");
      } else if (res.statusCode == 401) {
        throw const AiApiException("Invalid Claude API key (HTTP 401). Check Settings → AI Providers.", statusCode: 401);
      } else if (res.statusCode == 429) {
        throw const AiApiException("Claude rate limit exceeded (HTTP 429).", statusCode: 429);
      } else {
        throw AiApiException("Claude returned HTTP ${res.statusCode}.", statusCode: res.statusCode);
      }
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('[AI] [Claude] Socket error: $e');
      throw const AiApiException("Network connection error connecting to Claude. Check your internet connection.");
    } on TimeoutException catch (e) {
      if (kDebugMode) debugPrint('[AI] [Claude] Timeout: $e');
      throw const AiApiException("Claude analysis request timed out. Check your internet connection.");
    } catch (e) {
      if (e is AiConfigurationException || e is AiApiException) rethrow;
      if (kDebugMode) debugPrint('[AI] [Claude] Analysis exception: $e');
      throw AiApiException("Claude analysis error: $e");
    }
  }

  @override
  Future<String> askAboutNote(String noteContext, String userQuestion, {String? model, String? apiKey}) async {
    final key = await _getEffectiveKey(apiKey);
    if (key.isEmpty) {
      throw const AiConfigurationException("Please configure an AI provider in Settings → AI Providers.");
    }
    final mod = await _getEffectiveModel(model);

    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    if (kDebugMode) {
      debugPrint('[AI] [Claude] In-Note Q&A ($mod)');
    }

    try {
      final res = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': key,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': mod,
          'max_tokens': 1024,
          'system': 'You are NoteFlow AI, an executive assistant. Answer grounded strictly in the provided note context. If not mentioned, state so clearly.',
          'messages': [
            {
              'role': 'user',
              'content': 'Note Context:\n"""\n$noteContext\n"""\n\nQuestion: $userQuestion'
            }
          ],
        }),
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final text = _extractContentText(decoded);
        if (text != null && text.isNotEmpty) {
          return text.trim();
        }
        return "No response from Claude.";
      } else if (res.statusCode == 401) {
        throw const AiApiException("Invalid Claude API key (HTTP 401).", statusCode: 401);
      } else if (res.statusCode == 429) {
        throw const AiApiException("Claude rate limit reached (HTTP 429).", statusCode: 429);
      } else {
        throw AiApiException("Claude returned HTTP ${res.statusCode}.", statusCode: res.statusCode);
      }
    } on SocketException {
      throw const AiApiException("Network connection error connecting to Claude.");
    } on TimeoutException {
      throw const AiApiException("Claude request timed out.");
    } catch (e) {
      if (e is AiConfigurationException || e is AiApiException) rethrow;
      throw AiApiException("Claude Q&A error: $e");
    }
  }

  @override
  Future<String> rewriteText(String text, String instruction, {String? model, String? apiKey}) async {
    final key = await _getEffectiveKey(apiKey);
    if (key.isEmpty) {
      throw const AiConfigurationException("Please configure an AI provider in Settings → AI Providers.");
    }
    final mod = await _getEffectiveModel(model);

    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    try {
      final res = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': key,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': mod,
          'max_tokens': 1024,
          'messages': [
            {'role': 'user', 'content': 'Instruction: $instruction\n\nText:\n$text'}
          ],
        }),
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final t = _extractContentText(decoded);
        if (t != null) return t.trim();
      } else {
        throw AiApiException("Claude rewrite failed with HTTP ${res.statusCode}.", statusCode: res.statusCode);
      }
    } catch (e) {
      if (e is AiConfigurationException || e is AiApiException) rethrow;
      throw AiApiException("Claude rewrite error: $e");
    }
    return text;
  }

  @override
  Future<String> translateText(String text, String targetLanguage, {String? model, String? apiKey}) async {
    return rewriteText(text, "Translate accurately to $targetLanguage, preserving meaning and nuances.", model: model, apiKey: apiKey);
  }
}
