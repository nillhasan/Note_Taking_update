import 'package:flutter/material.dart';
import '../../data/local/preferences_service.dart';
import '../../services/ai/ai_service.dart';
import '../../theme/app_theme.dart';

class AiProvidersScreen extends StatefulWidget {
  const AiProvidersScreen({super.key});

  @override
  State<AiProvidersScreen> createState() => _AiProvidersScreenState();
}

class _AiProvidersScreenState extends State<AiProvidersScreen> {
  final PreferencesService _prefs = PreferencesService.instance;
  final AiService _aiService = AiService.instance;

  String _selectedProvider = 'gemini';
  late TextEditingController _apiKeyController;
  String _selectedModel = 'gemini-2.5-flash';
  String _selectedLanguage = 'Auto';

  bool _isTesting = false;
  String? _testResultMessage;
  bool? _testResultSuccess;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final provider = await _prefs.getAiProvider();
    final lang = await _prefs.getAiLanguage();

    String key = '';
    String model = '';

    if (provider == 'openai') {
      key = (await _prefs.getOpenAiApiKey()) ?? '';
      model = await _prefs.getOpenAiModel();
    } else if (provider == 'claude') {
      key = (await _prefs.getClaudeApiKey()) ?? '';
      model = await _prefs.getClaudeModel();
    } else {
      key = (await _prefs.getCustomGeminiApiKey()) ?? '';
      model = await _prefs.getGeminiModel();
    }

    if (mounted) {
      setState(() {
        _selectedProvider = provider;
        _selectedLanguage = lang;
        _apiKeyController.text = key;
        _selectedModel = model;
      });
    }
  }

  Future<void> _onProviderChanged(String newProvider) async {
    setState(() {
      _selectedProvider = newProvider;
      _testResultMessage = null;
      _testResultSuccess = null;
    });
    await _prefs.setAiProvider(newProvider);

    String key = '';
    String model = '';
    if (newProvider == 'openai') {
      key = (await _prefs.getOpenAiApiKey()) ?? '';
      model = await _prefs.getOpenAiModel();
    } else if (newProvider == 'claude') {
      key = (await _prefs.getClaudeApiKey()) ?? '';
      model = await _prefs.getClaudeModel();
    } else {
      key = (await _prefs.getCustomGeminiApiKey()) ?? '';
      model = await _prefs.getGeminiModel();
    }

    if (mounted) {
      setState(() {
        _apiKeyController.text = key;
        _selectedModel = model;
      });
    }
  }

  Future<void> _saveSettings() async {
    final key = _apiKeyController.text.trim();
    await _prefs.setAiProvider(_selectedProvider);
    if (_selectedProvider == 'openai') {
      await _prefs.setOpenAiApiKey(key);
      await _prefs.setOpenAiModel(_selectedModel);
    } else if (_selectedProvider == 'claude') {
      await _prefs.setClaudeApiKey(key);
      await _prefs.setClaudeModel(_selectedModel);
    } else {
      await _prefs.saveCustomGeminiApiKey(key);
      await _prefs.setGeminiModel(_selectedModel);
    }

    await _prefs.setAiLanguage(_selectedLanguage);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("AI settings saved successfully."),
          backgroundColor: AppColors.accentDark,
        ),
      );
    }
  }

  Future<void> _runConnectionTest() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _testResultSuccess = false;
        _testResultMessage = "Please enter an API key first.";
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResultMessage = null;
      _testResultSuccess = null;
    });

    final res = await _aiService.testConnection(
      _selectedProvider,
      apiKey: key,
      model: _selectedModel,
    );

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResultSuccess = res['success'] == true;
        _testResultMessage = res['message'] ?? (res['success'] == true ? "Connection successful." : "Test failed.");
      });
    }
  }

  List<String> _getModelsForProvider(String provider) {
    switch (provider) {
      case 'openai':
        return ['gpt-4o-mini', 'gpt-4o', 'gpt-3.5-turbo'];
      case 'claude':
        return ['claude-3-5-haiku-20241022', 'claude-3-5-sonnet-20241022', 'claude-3-opus-20240229'];
      case 'gemini':
      default:
        return ['gemini-2.5-flash', 'gemini-1.5-flash', 'gemini-1.5-pro'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final models = _getModelsForProvider(_selectedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "AI Providers",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider Tab Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  _buildProviderTab('gemini', 'Gemini'),
                  _buildProviderTab('openai', 'OpenAI'),
                  _buildProviderTab('claude', 'Claude'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Provider Configuration Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("API Key", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureApiKey,
                    decoration: InputDecoration(
                      hintText: "Enter your $_selectedProvider API key",
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureApiKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Your API key is stored securely on this device.",
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 20),

                  // Model Selection
                  const Text("Model", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: models.contains(_selectedModel) ? _selectedModel : models.first,
                        isExpanded: true,
                        items: models.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedModel = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Output Language
                  const Text("AI Output Language", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLanguage,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: "Auto", child: Text("Auto Detect")),
                          DropdownMenuItem(value: "English", child: Text("English")),
                          DropdownMenuItem(value: "Bengali", child: Text("Bengali (বাংলা)")),
                          DropdownMenuItem(value: "Spanish", child: Text("Spanish")),
                          DropdownMenuItem(value: "Hindi", child: Text("Hindi")),
                          DropdownMenuItem(value: "French", child: Text("French")),
                          DropdownMenuItem(value: "German", child: Text("German")),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedLanguage = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Connection Test Status Message
                  if (_testResultMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: _testResultSuccess == true
                            ? AppColors.successGreen.withValues(alpha: 0.1)
                            : AppColors.recordingRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _testResultSuccess == true ? Icons.check_circle : Icons.error_outline,
                            size: 18,
                            color: _testResultSuccess == true ? AppColors.successGreen : AppColors.recordingRed,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testResultMessage!,
                              style: TextStyle(
                                fontSize: 13,
                                color: _testResultSuccess == true ? AppColors.successGreen : AppColors.recordingRed,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Action Buttons: Test Connection & Save
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.cardBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _isTesting ? null : _runConnectionTest,
                          child: _isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                                )
                              : const Text("Test Connection"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentDark,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _saveSettings,
                          child: const Text("Save Settings"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderTab(String key, String label) {
    final isSelected = _selectedProvider == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onProviderChanged(key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentDark : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
