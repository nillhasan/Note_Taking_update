import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SecureStorageService provides hardware-backed encryption (Android Keystore / iOS Keychain)
/// for user-provided API keys (Gemini, OpenAI, Claude).
///
/// Keys are NEVER stored in plaintext JSON, Git, logs, or unencrypted storage.
class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._init();

  late final FlutterSecureStorage _storage;
  bool _isMigrated = false;

  static const String _keyGemini = 'sec_gemini_api_key';
  static const String _keyOpenAi = 'sec_openai_api_key';
  static const String _keyClaude = 'sec_claude_api_key';

  SecureStorageService._init() {
    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
  }

  /// Migrates legacy keys from SharedPreferences into secure hardware storage once.
  Future<void> _migrateLegacyKeysIfNeeded() async {
    if (_isMigrated) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Gemini
      final legacyGemini = prefs.getString('custom_gemini_api_key');
      if (legacyGemini != null && legacyGemini.isNotEmpty) {
        final existingSec = await _storage.read(key: _keyGemini);
        if (existingSec == null || existingSec.isEmpty) {
          await _storage.write(key: _keyGemini, value: legacyGemini.trim());
        }
        await prefs.remove('custom_gemini_api_key');
      }

      // OpenAI
      final legacyOpenAi = prefs.getString('openai_api_key');
      if (legacyOpenAi != null && legacyOpenAi.isNotEmpty) {
        final existingSec = await _storage.read(key: _keyOpenAi);
        if (existingSec == null || existingSec.isEmpty) {
          await _storage.write(key: _keyOpenAi, value: legacyOpenAi.trim());
        }
        await prefs.remove('openai_api_key');
      }

      // Claude
      final legacyClaude = prefs.getString('claude_api_key');
      if (legacyClaude != null && legacyClaude.isNotEmpty) {
        final existingSec = await _storage.read(key: _keyClaude);
        if (existingSec == null || existingSec.isEmpty) {
          await _storage.write(key: _keyClaude, value: legacyClaude.trim());
        }
        await prefs.remove('claude_api_key');
      }

      _isMigrated = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SecureStorage] Migration warning: $e');
      }
    }
  }

  // --- Gemini API Key ---
  Future<String?> getGeminiApiKey() async {
    await _migrateLegacyKeysIfNeeded();
    try {
      return await _storage.read(key: _keyGemini);
    } catch (e) {
      if (kDebugMode) debugPrint('[SecureStorage] Error reading Gemini key: $e');
      return null;
    }
  }

  Future<void> saveGeminiApiKey(String key) async {
    try {
      final trimmed = key.trim();
      if (trimmed.isEmpty) {
        await _storage.delete(key: _keyGemini);
      } else {
        await _storage.write(key: _keyGemini, value: trimmed);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SecureStorage] Error saving Gemini key: $e');
    }
  }

  // --- OpenAI API Key ---
  Future<String?> getOpenAiApiKey() async {
    await _migrateLegacyKeysIfNeeded();
    try {
      return await _storage.read(key: _keyOpenAi);
    } catch (e) {
      if (kDebugMode) debugPrint('[SecureStorage] Error reading OpenAI key: $e');
      return null;
    }
  }

  Future<void> saveOpenAiApiKey(String key) async {
    try {
      final trimmed = key.trim();
      if (trimmed.isEmpty) {
        await _storage.delete(key: _keyOpenAi);
      } else {
        await _storage.write(key: _keyOpenAi, value: trimmed);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SecureStorage] Error saving OpenAI key: $e');
    }
  }

  // --- Claude API Key ---
  Future<String?> getClaudeApiKey() async {
    await _migrateLegacyKeysIfNeeded();
    try {
      return await _storage.read(key: _keyClaude);
    } catch (e) {
      if (kDebugMode) debugPrint('[SecureStorage] Error reading Claude key: $e');
      return null;
    }
  }

  Future<void> saveClaudeApiKey(String key) async {
    try {
      final trimmed = key.trim();
      if (trimmed.isEmpty) {
        await _storage.delete(key: _keyClaude);
      } else {
        await _storage.write(key: _keyClaude, value: trimmed);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SecureStorage] Error saving Claude key: $e');
    }
  }

  // --- Generic Provider Access ---
  Future<String?> getApiKeyForProvider(String providerId) async {
    switch (providerId.toLowerCase()) {
      case 'openai':
        return await getOpenAiApiKey();
      case 'claude':
        return await getClaudeApiKey();
      case 'gemini':
      default:
        return await getGeminiApiKey();
    }
  }

  Future<void> saveApiKeyForProvider(String providerId, String key) async {
    switch (providerId.toLowerCase()) {
      case 'openai':
        await saveOpenAiApiKey(key);
        break;
      case 'claude':
        await saveClaudeApiKey(key);
        break;
      case 'gemini':
      default:
        await saveGeminiApiKey(key);
        break;
    }
  }

  Future<void> clearApiKeyForProvider(String providerId) async {
    switch (providerId.toLowerCase()) {
      case 'openai':
        await _storage.delete(key: _keyOpenAi);
        break;
      case 'claude':
        await _storage.delete(key: _keyClaude);
        break;
      case 'gemini':
      default:
        await _storage.delete(key: _keyGemini);
        break;
    }
  }
}
