import 'dart:io';
import '../../models/models.dart';

class AiConfigurationException implements Exception {
  final String message;
  const AiConfigurationException([this.message = "Please configure an AI provider in Settings → AI Providers."]);

  @override
  String toString() => message;
}

class AiApiException implements Exception {
  final String message;
  final int? statusCode;
  const AiApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

abstract class AiProvider {
  String get id;
  String get displayName;
  List<String> get availableModels;

  /// Check whether the provider has credentials configured
  Future<bool> isConfigured();

  /// Test connection with real minimal API call
  Future<Map<String, dynamic>> testConnection({String? apiKey, String? model});

  /// Real transcription of an audio file
  Future<String?> transcribeAudio(File audioFile, {String? language, String? model, String? apiKey});

  /// Structured synthesis of note content
  Future<NoteAiAnalysis> analyzeContent(String content, String title, {String? language, String? model, String? apiKey});

  /// Grounded Q&A against note context
  Future<String> askAboutNote(String noteContext, String userQuestion, {String? model, String? apiKey});

  /// Rewrite note text (e.g. professional, concise, expanded)
  Future<String> rewriteText(String text, String instruction, {String? model, String? apiKey});

  /// Translate note text
  Future<String> translateText(String text, String targetLanguage, {String? model, String? apiKey});
}
