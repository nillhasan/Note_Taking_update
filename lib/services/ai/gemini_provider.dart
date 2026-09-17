import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../data/local/preferences_service.dart';
import '../../models/models.dart';
import 'ai_parser_helper.dart';
import 'ai_provider.dart';

class GeminiProvider implements AiProvider {
  final http.Client _client = http.Client();

  @override
  String get id => 'gemini';

  @override
  String get displayName => 'Google Gemini';

  @override
  List<String> get availableModels => [
        'gemini-2.5-flash',
        'gemini-1.5-flash',
        'gemini-1.5-pro',
      ];

  Future<String> _getEffectiveKey(String? overrideKey) async {
    if (overrideKey != null && overrideKey.trim().isNotEmpty) {
      return overrideKey.trim();
    }
    final savedKey = await PreferencesService.instance.getCustomGeminiApiKey();
    return savedKey?.trim() ?? "";
  }

  Future<String> _getEffectiveModel(String? overrideModel) async {
    if (overrideModel != null && overrideModel.trim().isNotEmpty) {
      return overrideModel.trim();
    }
    return await PreferencesService.instance.getGeminiModel();
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
      return {'success': false, 'message': 'Gemini API key is required.'};
    }
    final mod = await _getEffectiveModel(model);

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$mod:generateContent?key=$key',
    );

    if (kDebugMode) {
      debugPrint('[AI] [Gemini] Testing connection with model: $mod');
    }

    try {
      final res = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'ping'}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 12));

      if (kDebugMode) {
        debugPrint('[AI] [Gemini] Connection test returned HTTP ${res.statusCode}');
      }

      if (res.statusCode == 200) {
        return {'success': true, 'message': 'Gemini connected successfully.'};
      } else if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
        return {'success': false, 'message': 'Invalid Gemini API key or unauthorized (HTTP ${res.statusCode}).'};
      } else if (res.statusCode == 429) {
        return {'success': false, 'message': 'Gemini rate limit or quota exceeded (HTTP 429).'};
      } else {
        return {'success': false, 'message': 'Gemini server returned HTTP ${res.statusCode}.'};
      }
    } on SocketException {
      return {'success': false, 'message': 'Network connection failed. Check your internet connection.'};
    } on TimeoutException {
      return {'success': false, 'message': 'Connection test timed out. Check your internet connection.'};
    } catch (e) {
      return {'success': false, 'message': 'Connection test error: $e'};
    }
  }

  @override
  Future<String?> transcribeAudio(File audioFile, {String? language, String? model, String? apiKey}) async {
    final key = await _getEffectiveKey(apiKey);
    if (key.isEmpty) {
      throw const AiConfigurationException("Please configure an AI provider in Settings → AI Providers.");
    }
    if (!audioFile.existsSync() || audioFile.lengthSync() == 0) {
      return null;
    }
    final mod = await _getEffectiveModel(model);

    if (kDebugMode) {
      debugPrint('[AI] [Gemini] Transcribing audio file (${audioFile.lengthSync()} bytes) with $mod');
    }

    try {
      final bytes = await audioFile.readAsBytes();
      final base64Audio = base64Encode(bytes);

      // Determine mime type
      final ext = audioFile.path.toLowerCase().split('.').last;
      String mimeType = 'audio/mp4';
      if (ext == 'wav') mimeType = 'audio/wav';
      if (ext == 'mp3') mimeType = 'audio/mp3';
      if (ext == 'ogg') mimeType = 'audio/ogg';
      if (ext == 'aac') mimeType = 'audio/aac';

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$mod:generateContent?key=$key',
      );

      final prompt = '''
Listen to this audio recording carefully.
Transcribe every word accurately.
Support English, Bengali (বাংলা), or mixed bilingual speech.
If the audio has no audible speech, reply with [NO_SPEECH].
Provide ONLY the transcribed text with no preamble or explanations.
''';

      final res = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
                {
                  'inline_data': {
                    'mime_type': mimeType,
                    'data': base64Audio,
                  }
                }
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 50));

      if (kDebugMode) {
        debugPrint('[AI] [Gemini] Audio transcription response HTTP ${res.statusCode}');
      }

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final candidates = decoded['candidates'] as List?;
        final text = candidates?.firstOrNull?['content']?['parts']?.firstOrNull?['text'] as String?;
        if (text != null) {
          final trimmed = text.trim();
          return trimmed.contains("[NO_SPEECH]") ? "" : trimmed;
        }
        return null;
      } else if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
        throw AiApiException("Invalid Gemini API key for audio transcription (HTTP ${res.statusCode}).", statusCode: res.statusCode);
      } else if (res.statusCode == 429) {
        throw AiApiException("Gemini transcription quota or rate limit exceeded (HTTP 429).", statusCode: 429);
      } else {
        throw AiApiException("Gemini transcription error (HTTP ${res.statusCode}).", statusCode: res.statusCode);
      }
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('[AI] [Gemini] Audio socket error: $e');
      throw const AiApiException("Network error during audio transcription. Please check your internet connection.");
    } on TimeoutException catch (e) {
      if (kDebugMode) debugPrint('[AI] [Gemini] Audio timeout: $e');
      throw const AiApiException("Audio transcription request timed out. Check your internet connection.");
    } catch (e) {
      if (e is AiConfigurationException || e is AiApiException) rethrow;
      if (kDebugMode) debugPrint('[AI] [Gemini] Audio exception: $e');
      throw AiApiException("Audio transcription failed: $e");
    }
  }

  @override
  Future<NoteAiAnalysis> analyzeContent(String content, String title, {String? language, String? model, String? apiKey}) async {
    final key = await _getEffectiveKey(apiKey);
    final mod = await _getEffectiveModel(model);

    if (key.isEmpty) {
      if (kDebugMode) {
        debugPrint('[AI] [Gemini] API key missing for content analysis.');
      }
      throw const AiConfigurationException("Please configure an AI provider in Settings → AI Providers.");
    }

    if (kDebugMode) {
      debugPrint('[AI] [Gemini] Analyzing content ($mod), content length: ${content.length}');
    }

    final systemPrompt = AiParserHelper.buildSystemPrompt(language: language);
    final userPrompt = '''
$systemPrompt

Note Title: "$title"
Content to analyze:
"""
$content
"""
''';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$mod:generateContent?key=$key',
    );

    try {
      final res = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': userPrompt}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 40));

      if (kDebugMode) {
        debugPrint('[AI] [Gemini] Analysis returned HTTP ${res.statusCode}');
      }

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final candidates = decoded['candidates'] as List?;
        final text = candidates?.firstOrNull?['content']?['parts']?.firstOrNull?['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          return AiParserHelper.parseAiResponse(text, title);
        }
        throw const AiApiException("Gemini returned an empty analysis response.");
      } else if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
        throw AiApiException("Invalid Gemini API key or unauthorized (HTTP ${res.statusCode}). Please verify in Settings → AI Providers.", statusCode: res.statusCode);
      } else if (res.statusCode == 429) {
        throw AiApiException("Gemini rate limit or quota exceeded (HTTP 429). Please try again shortly or check your Google AI account.", statusCode: 429);
      } else {
        throw AiApiException("Gemini returned error (HTTP ${res.statusCode}).", statusCode: res.statusCode);
      }
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('[AI] [Gemini] Analysis socket error: $e');
      throw const AiApiException("Network connection error connecting to Gemini AI. Check your internet connection.");
    } on TimeoutException catch (e) {
      if (kDebugMode) debugPrint('[AI] [Gemini] Analysis timeout: $e');
      throw const AiApiException("Gemini analysis request timed out. Check your internet connection.");
    } catch (e) {
      if (e is AiConfigurationException || e is AiApiException) rethrow;
      if (kDebugMode) debugPrint('[AI] [Gemini] Analysis exception: $e');
      throw AiApiException("Gemini analysis error: $e");
    }
  }

  @override
  Future<String> askAboutNote(String noteContext, String userQuestion, {String? model, String? apiKey}) async {
    final key = await _getEffectiveKey(apiKey);
    if (key.isEmpty) {
      throw const AiConfigurationException("Please configure an AI provider in Settings → AI Providers.");
    }
    final mod = await _getEffectiveModel(model);

    final prompt = '''
You are NoteFlow AI, a focused executive productivity assistant.
Answer the user's question grounded STRICTLY in the following note details.
If the information is not contained in the note, clearly state that it is not mentioned.
Preserve Bengali (বাংলা) or English as requested.

Note Context:
"""
$noteContext
"""

User Question: $userQuestion
''';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$mod:generateContent?key=$key',
    );

    if (kDebugMode) {
      debugPrint('[AI] [Gemini] In-Note Q&A with model: $mod');
    }

    try {
      final res = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final candidates = decoded['candidates'] as List?;
        final text = candidates?.firstOrNull?['content']?['parts']?.firstOrNull?['text'] as String?;
        if (text != null && text.isNotEmpty) {
          return text.trim();
        }
        return "No content received from Gemini.";
      } else if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
        throw AiApiException("Invalid Gemini API key (HTTP ${res.statusCode}). Check Settings → AI Providers.", statusCode: res.statusCode);
      } else if (res.statusCode == 429) {
        throw AiApiException("Gemini rate limit or quota exceeded (HTTP 429).", statusCode: 429);
      } else {
        throw AiApiException("Gemini returned HTTP ${res.statusCode}.", statusCode: res.statusCode);
      }
    } on SocketException {
      throw const AiApiException("Network connection error connecting to Gemini.");
    } on TimeoutException {
      throw const AiApiException("Gemini request timed out.");
    } catch (e) {
      if (e is AiConfigurationException || e is AiApiException) rethrow;
      throw AiApiException("Gemini Q&A error: $e");
    }
  }

  @override
  Future<String> rewriteText(String text, String instruction, {String? model, String? apiKey}) async {
    final key = await _getEffectiveKey(apiKey);
    if (key.isEmpty) {
      throw const AiConfigurationException("Please configure an AI provider in Settings → AI Providers.");
    }
    final mod = await _getEffectiveModel(model);

    final prompt = 'Rewrite the following text according to this instruction: "$instruction".\n\nText:\n$text';
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$mod:generateContent?key=$key',
    );

    try {
      final res = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 25));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final candidates = decoded['candidates'] as List?;
        final t = candidates?.firstOrNull?['content']?['parts']?.firstOrNull?['text'] as String?;
        if (t != null) return t.trim();
      } else {
        throw AiApiException("Gemini rewrite failed with HTTP ${res.statusCode}", statusCode: res.statusCode);
      }
    } catch (e) {
      if (e is AiConfigurationException || e is AiApiException) rethrow;
      throw AiApiException("Gemini rewrite error: $e");
    }
    return text;
  }

  @override
  Future<String> translateText(String text, String targetLanguage, {String? model, String? apiKey}) async {
    return rewriteText(text, "Translate accurately to $targetLanguage, preserving meaning and nuances.", model: model, apiKey: apiKey);
  }
}
