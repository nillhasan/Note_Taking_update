import 'dart:io';
import '../../data/local/preferences_service.dart';
import '../../models/models.dart';
import 'ai_provider.dart';
import 'claude_provider.dart';
import 'gemini_provider.dart';
import 'openai_provider.dart';

class AiService {
  static final AiService instance = AiService._init();

  final GeminiProvider geminiProvider = GeminiProvider();
  final OpenAiProvider openAiProvider = OpenAiProvider();
  final ClaudeProvider claudeProvider = ClaudeProvider();

  AiService._init();

  AiProvider getProviderById(String id) {
    switch (id.toLowerCase()) {
      case 'openai':
        return openAiProvider;
      case 'claude':
        return claudeProvider;
      case 'gemini':
      default:
        return geminiProvider;
    }
  }

  Future<AiProvider> getActiveProvider() async {
    final providerId = await PreferencesService.instance.getAiProvider();
    return getProviderById(providerId);
  }

  Future<bool> isProviderConfigured(String providerId) async {
    final provider = getProviderById(providerId);
    return await provider.isConfigured();
  }

  Future<bool> isCurrentProviderConfigured() async {
    final provider = await getActiveProvider();
    return await provider.isConfigured();
  }

  Future<Map<String, dynamic>> testConnection(String providerId, {String? apiKey, String? model}) async {
    final provider = getProviderById(providerId);
    return await provider.testConnection(apiKey: apiKey, model: model);
  }

  /// Real Audio Transcription
  Future<String?> transcribeAudio(File audioFile) async {
    final provider = await getActiveProvider();
    final lang = await PreferencesService.instance.getAiLanguage();

    // Check if current provider is configured
    if (await provider.isConfigured()) {
      final transcript = await provider.transcribeAudio(audioFile, language: lang);
      if (transcript != null && transcript.trim().isNotEmpty) {
        return transcript.trim();
      }
    }

    // Fallback: If active was Claude or failed, try Gemini then OpenAI if they are configured
    if (provider.id != 'gemini' && await geminiProvider.isConfigured()) {
      final transcript = await geminiProvider.transcribeAudio(audioFile, language: lang);
      if (transcript != null && transcript.trim().isNotEmpty) {
        return transcript.trim();
      }
    }
    if (provider.id != 'openai' && await openAiProvider.isConfigured()) {
      final transcript = await openAiProvider.transcribeAudio(audioFile, language: lang);
      if (transcript != null && transcript.trim().isNotEmpty) {
        return transcript.trim();
      }
    }

    return null;
  }

  /// Real Content Synthesis (Summary, Bullets, Action Items, Minutes)
  Future<NoteAiAnalysis> analyzeContent(String content, String title) async {
    final provider = await getActiveProvider();
    if (!await provider.isConfigured()) {
      throw const AiConfigurationException("Please configure an AI provider in Settings → AI Providers.");
    }
    final lang = await PreferencesService.instance.getAiLanguage();
    return await provider.analyzeContent(content, title, language: lang);
  }

  /// Grounded In-Note Q&A
  Future<String> askAboutNote(String noteContext, String question) async {
    final provider = await getActiveProvider();
    if (!await provider.isConfigured()) {
      throw const AiConfigurationException("Please configure an AI provider in Settings → AI Providers.");
    }
    return await provider.askAboutNote(noteContext, question);
  }

  /// AI Generated Follow-Up Email
  Future<String> generateFollowUpEmail(String title, String summary, String items) async {
    final prompt = '''
Draft a professional, executive follow-up email based on the following meeting summary and action items:
Subject / Title: $title
Summary: $summary
Action Items: $items

Format the output cleanly with Subject line and Body.
''';
    final provider = await getActiveProvider();
    if (!await provider.isConfigured()) {
      throw const AiConfigurationException("Please configure an AI provider in Settings → AI Providers.");
    }
    return await provider.askAboutNote(prompt, "Draft the follow-up email.");
  }

  Future<String> rewriteText(String text, String instruction) async {
    final provider = await getActiveProvider();
    if (!await provider.isConfigured()) {
      throw const AiConfigurationException("Please configure an AI provider in Settings → AI Providers.");
    }
    return await provider.rewriteText(text, instruction);
  }

  Future<String> translateText(String text, String language) async {
    final provider = await getActiveProvider();
    if (!await provider.isConfigured()) {
      throw const AiConfigurationException("Please configure an AI provider in Settings → AI Providers.");
    }
    return await provider.translateText(text, language);
  }
}
