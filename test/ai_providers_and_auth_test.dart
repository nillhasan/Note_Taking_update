import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:noteflow_ai/services/ai/ai_provider.dart';
import 'package:noteflow_ai/services/ai/ai_service.dart';
import 'package:noteflow_ai/services/ai/gemini_provider.dart';
import 'package:noteflow_ai/services/ai/openai_provider.dart';
import 'package:noteflow_ai/services/ai/claude_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AI Provider Pre-flight & Configuration Tests', () {
    test('GeminiProvider reports not configured when key is empty', () async {
      final gemini = GeminiProvider();
      final configured = await gemini.isConfigured();
      expect(configured, isFalse);
    });

    test('OpenAiProvider reports not configured when key is empty', () async {
      final openAi = OpenAiProvider();
      final configured = await openAi.isConfigured();
      expect(configured, isFalse);
    });

    test('ClaudeProvider reports not configured when key is empty', () async {
      final claude = ClaudeProvider();
      final configured = await claude.isConfigured();
      expect(configured, isFalse);
    });

    test('GeminiProvider testConnection requires API key', () async {
      final gemini = GeminiProvider();
      final res = await gemini.testConnection(apiKey: '');
      expect(res['success'], isFalse);
      expect(res['message'], contains('API key is required'));
    });

    test('OpenAiProvider testConnection requires API key', () async {
      final openAi = OpenAiProvider();
      final res = await openAi.testConnection(apiKey: '');
      expect(res['success'], isFalse);
      expect(res['message'], contains('API key is required'));
    });

    test('ClaudeProvider testConnection requires API key', () async {
      final claude = ClaudeProvider();
      final res = await claude.testConnection(apiKey: '');
      expect(res['success'], isFalse);
      expect(res['message'], contains('API key is required'));
    });

    test('GeminiProvider throws AiConfigurationException on analyzeContent when key is missing', () async {
      final gemini = GeminiProvider();
      expect(
        () async => await gemini.analyzeContent("Some note content", "Title"),
        throwsA(isA<AiConfigurationException>()),
      );
    });

    test('OpenAiProvider throws AiConfigurationException on analyzeContent when key is missing', () async {
      final openAi = OpenAiProvider();
      expect(
        () async => await openAi.analyzeContent("Some note content", "Title"),
        throwsA(isA<AiConfigurationException>()),
      );
    });

    test('ClaudeProvider throws AiConfigurationException on analyzeContent when key is missing', () async {
      final claude = ClaudeProvider();
      expect(
        () async => await claude.analyzeContent("Some note content", "Title"),
        throwsA(isA<AiConfigurationException>()),
      );
    });

    test('AiService throws AiConfigurationException on analyzeContent when no provider configured', () async {
      final aiService = AiService.instance;
      expect(
        () async => await aiService.analyzeContent("Test note", "Test Title"),
        throwsA(isA<AiConfigurationException>()),
      );
    });

    test('AiService throws AiConfigurationException on askAboutNote when no provider configured', () async {
      final aiService = AiService.instance;
      expect(
        () async => await aiService.askAboutNote("Test context", "What is this?"),
        throwsA(isA<AiConfigurationException>()),
      );
    });

    test('AiService getProviderById correctly returns configured provider instances', () {
      final aiService = AiService.instance;
      expect(aiService.getProviderById('gemini'), isA<GeminiProvider>());
      expect(aiService.getProviderById('openai'), isA<OpenAiProvider>());
      expect(aiService.getProviderById('claude'), isA<ClaudeProvider>());
      expect(aiService.getProviderById('unknown'), isA<GeminiProvider>());
    });
  });
}
