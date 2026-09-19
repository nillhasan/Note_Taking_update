import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../data/local/preferences_service.dart';
import '../../models/models.dart';
import 'ai_parser_helper.dart';
import 'ai_provider.dart';

class OpenAiProvider implements AiProvider {
  final http.Client _client = http.Client();

  @override
  String get id => 'openai';

  @override
  String get displayName => 'OpenAI';

  @override
  List<String> get availableModels => [
        'gpt-4o-mini',
        'gpt-4o',
        'gpt-3.5-turbo',
      ];

  Future<String> _getEffectiveKey(String? overrideKey) async {
    if (overrideKey != null && overrideKey.trim().isNotEmpty) {
      return overrideKey.trim();
    }
    final savedKey = await PreferencesService.instance.getOpenAiApiKey();
    return savedKey?.trim() ?? "";
  }

  Future<String> _getEffectiveModel(String? overrideModel) async {
    if (overrideModel != null && overrideModel.trim().isNotEmpty) {
      return overrideModel.trim();
    }
    return await PreferencesService.instance.getOpenAiModel();
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
      return {'success': false, 'message': 'OpenAI API key is required.'};
    }

    final url = Uri.parse('https://api.openai.com/v1/models');

    if (kDebugMode) {
      debugPrint('[AI] [OpenAI] Testing connection...');
    }

    try {
      final res = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $key',
        },
      ).timeout(const Duration(seconds: 12));

      if (kDebugMode) {
        debugPrint('[AI] [OpenAI] Test connection returned HTTP ${res.statusCode}');
      }

      if (res.statusCode == 200) {
        return {'success': true, 'message': 'OpenAI connected successfully.'};
      } else if (res.statusCode == 401) {
        return {'success': false, 'message': 'Invalid OpenAI API key or unauthorized (HTTP 401).'};
      } else if (res.statusCode == 429) {
        return {'success': false, 'message': 'OpenAI rate limit or quota exceeded (HTTP 429).'};
      } else {
        return {'success': false, 'message': 'OpenAI returned status ${res.statusCode}.'};
      }
    } on SocketException {
      return {'success': false, 'message': 'Network connection failed. Check your internet connection.'};
    } on TimeoutException {
      return {'success': false, 'message': 'OpenAI test timed out. Check your internet connection.'};
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

    if (kDebugMode) {
      debugPrint('[AI] [OpenAI] Transcribing audio with Whisper (${audioFile.lengthSync()} bytes)');
    }

    try {
      final url = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $key';
      request.fields['model'] = 'whisper-1';
      if (language != null && language != "Auto" && language.isNotEmpty) {
        request.fields['language'] = language.toLowerCase().substring(0, 2);
      }
      request.files.add(await http.MultipartFile.fromPath('file', audioFile.path));

      final streamedRes = await request.send().timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamedRes);

      if (kDebugMode) {
        debugPrint('[AI] [OpenAI] Whisper response HTTP ${res.statusCode}');
      }

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return decoded['text'] as String?;
      } else if (res.statusCode == 401) {
        throw const AiApiException("Invalid OpenAI API key for audio transcription (HTTP 401).", statusCode: 401);
      } else if (res.statusCode == 429) {
        throw const AiApiException("OpenAI Whisper quota or rate limit exceeded (HTTP 429).", statusCode: 429);
      } else {
        throw AiApiException("Whisper transcription error (HTTP ${res.statusCode}).", statusCode: res.statusCode);
      }
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('[AI] [OpenAI] Whisper socket error: $e');
      throw const AiApiException("Network connection error during OpenAI audio transcription.");
    } on TimeoutException catch (e) {
      if (kDebugMode) debugPrint('[AI] [OpenAI] Whisper timeout: $e');
      throw const AiApiException("OpenAI Whisper transcription timed out.");
    } catch (e) {
      if (e is AiConfigurationException || e is AiApiException) rethrow;
      if (kDebugMode) debugPrint('[AI] [OpenAI] Whisper error: $e');
      throw AiApiException("OpenAI transcription failed: $e");
    }
  }

  @override
  Future<NoteAiAnalysis> analyzeContent(String content, String title, {String? language, String? model, String? apiKey}) async {
    final key = await _getEffectiveKey(apiKey);
    final mod = await _getEffectiveModel(model);

    if (key.isEmpty) {
      if (kDebugMode) {
        debugPrint('[AI] [OpenAI] API key missing for content analysis.');
      }
      throw const AiConfigurationException("Please configure an AI provider in Settings → AI Providers.");
    }

    if (kDebugMode) {
      debugPrint('[AI] [OpenAI] Analyzing content with model: $mod');
    }

    final systemPrompt = AiParserHelper.buildSystemPrompt(language: language);
    final userPrompt = '''
Note Title: "$title"
Content:
"""
$content
"""
''';

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    try {
      final res = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key',
        },
        body: jsonEncode({
          'model': mod,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.3,
        }),
      ).timeout(const Duration(seconds: 40));

      if (kDebugMode) {
        debugPrint('[AI] [OpenAI] Analysis returned HTTP ${res.statusCode}');
      }

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final text = _extractChoiceText(decoded);
        if (text != null && text.trim().isNotEmpty) {
          return AiParserHelper.parseAiResponse(text, title);
        }
        throw const AiApiException("OpenAI returned an empty response.");
      } else if (res.statusCode == 401) {
        throw const AiApiException("Invalid OpenAI API key (HTTP 401). Please check Settings → AI Providers.", statusCode: 401);
      } else if (res.statusCode == 429) {
        throw const AiApiException("OpenAI rate limit or quota exceeded (HTTP 429). Check your billing plan.", statusCode: 429);
      } else {
        throw AiApiException("OpenAI server error (HTTP ${res.statusCode}).", statusCode: res.statusCode);
      }
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('[AI] [OpenAI] Socket error: $e');
      throw const AiApiException("Network connection error connecting to OpenAI. Check your internet connection.");
    } on TimeoutException catch (e) {
      if (kDebugMode) debugPrint('[AI] [OpenAI] Timeout: $e');
      throw const AiApiException("OpenAI analysis request timed out. Check your internet connection.");
    } catch (e) {
      if (e is AiConfigurationException || e is AiApiException) rethrow;
      if (kDebugMode) debugPrint('[AI] [OpenAI] Analysis exception: $e');
      throw AiApiException("OpenAI analysis error: $e");
    }
  }

  static String? _extractChoiceText(Map<String, dynamic> decoded) {
    try {
      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final firstChoice = choices[0];
        if (firstChoice is Map) {
          final message = firstChoice['message'];
          if (message is Map && message['content'] != null) {
            return message['content'].toString();
          }
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<String> askAboutNote(String noteContext, String userQuestion, {String? model, String? apiKey}) async {
    final key = await _getEffectiveKey(apiKey);
    if (key.isEmpty) {
      throw const AiConfigurationException("Please configure an AI provider in Settings → AI Providers.");
    }
    final mod = await _getEffectiveModel(model);

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    if (kDebugMode) {
      debugPrint('[AI] [OpenAI] In-Note Q&A ($mod)');
    }

    try {
      final res = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key',
        },
        body: jsonEncode({
          'model': mod,
          'messages': [
            {
              'role': 'system',
              'content': 'You are NoteFlow AI, an executive assistant. Answer questions strictly grounded in the provided note context. If not mentioned in the note, explicitly state so.'
            },
            {
              'role': 'user',
              'content': 'Note Context:\n"""\n$noteContext\n"""\n\nQuestion: $userQuestion'
            }
          ],
          'temperature': 0.2,
        }),
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final text = _extractChoiceText(decoded);
        if (text != null && text.isNotEmpty) {
          return text.trim();
        }
        return "No response from OpenAI.";
      } else if (res.statusCode == 401) {
        throw const AiApiException("Invalid OpenAI API key (HTTP 401).", statusCode: 401);
      } else if (res.statusCode == 429) {
        throw const AiApiException("OpenAI quota or rate limit reached (HTTP 429).", statusCode: 429);
      } else {
        throw AiApiException("OpenAI returned HTTP ${res.statusCode}.", statusCode: res.statusCode);
      }
    } on SocketException {
      throw const AiApiException("Network connection error connecting to OpenAI.");
    } on TimeoutException {
      throw const AiApiException("OpenAI request timed out.");
    } catch (e) {
      if (e is AiConfigurationException || e is AiApiException) rethrow;
      throw AiApiException("OpenAI Q&A error: $e");
    }
  }

  @override
  Future<String> rewriteText(String text, String instruction, {String? model, String? apiKey}) async {
    final key = await _getEffectiveKey(apiKey);
    if (key.isEmpty) {
      throw const AiConfigurationException("Please configure an AI provider in Settings → AI Providers.");
    }
    final mod = await _getEffectiveModel(model);

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    try {
      final res = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key',
        },
        body: jsonEncode({
          'model': mod,
          'messages': [
            {'role': 'system', 'content': 'You are a professional text editor.'},
            {'role': 'user', 'content': 'Instruction: $instruction\n\nText:\n$text'}
          ],
        }),
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final t = _extractChoiceText(decoded);
        if (t != null) return t.trim();
      } else {
        throw AiApiException("OpenAI rewrite failed with HTTP ${res.statusCode}.", statusCode: res.statusCode);
      }
    } catch (e) {
      if (e is AiConfigurationException || e is AiApiException) rethrow;
      throw AiApiException("OpenAI rewrite error: $e");
    }
    return text;
  }

  @override
  Future<String> translateText(String text, String targetLanguage, {String? model, String? apiKey}) async {
    return rewriteText(text, "Translate accurately to $targetLanguage, preserving meaning and nuances.", model: model, apiKey: apiKey);
  }
}
