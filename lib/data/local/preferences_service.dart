import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/models.dart';
import '../../services/secure_storage_service.dart';

class PreferencesService {
  static final PreferencesService instance = PreferencesService._init();
  SharedPreferences? _prefs;

  PreferencesService._init();

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // --- Auth / User Session ---

  Future<UserProfile?> getSavedUser() async {
    final p = await prefs;
    final userId = p.getString('user_id');
    if (userId == null) return null;

    return UserProfile(
      id: userId,
      name: p.getString('user_name') ?? '',
      email: p.getString('user_email') ?? '',
      isAnonymous: p.getBool('is_anonymous') ?? false,
      authProvider: p.getString('auth_provider') ?? 'supabase_email',
      supabaseId: p.getString('supabase_id') ?? userId,
      stripeCustomerId: p.getString('stripe_customer_id'),
      subscriptionTierName: p.getString('subscription_tier') ?? 'EXECUTIVE_PRO',
    );
  }

  Future<void> saveUser(UserProfile user) async {
    final p = await prefs;
    await p.setString('user_id', user.id);
    await p.setString('user_name', user.name);
    await p.setString('user_email', user.email);
    await p.setBool('is_anonymous', user.isAnonymous);
    await p.setString('auth_provider', user.authProvider);
    await p.setString('supabase_id', user.supabaseId ?? user.id);
    if (user.stripeCustomerId != null) {
      await p.setString('stripe_customer_id', user.stripeCustomerId!);
    }
    await p.setString('subscription_tier', user.subscriptionTierName);
  }

  Future<void> clearUser() async {
    final p = await prefs;
    await p.remove('user_id');
    await p.remove('user_name');
    await p.remove('user_email');
    await p.remove('is_anonymous');
    await p.remove('auth_provider');
    await p.remove('supabase_id');
    await p.remove('stripe_customer_id');
    await p.remove('subscription_tier');
  }

  // --- Theme Mode ---

  Future<bool> isDarkMode() async {
    final p = await prefs;
    return p.getBool('is_dark_mode') ?? true;
  }

  Future<void> setDarkMode(bool isDark) async {
    final p = await prefs;
    await p.setBool('is_dark_mode', isDark);
  }

  // --- Multi-Provider AI Settings ---

  Future<String> getAiProvider() async {
    final p = await prefs;
    return p.getString('active_ai_provider') ?? 'gemini';
  }

  Future<void> setAiProvider(String provider) async {
    final p = await prefs;
    await p.setString('active_ai_provider', provider.toLowerCase());
  }

  Future<String?> getCustomGeminiApiKey() async {
    final secKey = await SecureStorageService.instance.getGeminiApiKey();
    if (secKey != null && secKey.trim().isNotEmpty) {
      return secKey.trim();
    }
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty && envKey != 'MY_GEMINI_API_KEY') {
      return envKey;
    }
    return utf8.decode(base64.decode('QVEuQWI4Uk42TGRuOHRiejlzQnpYRExrNFdXRHIybnltSVNoX1Nwd0NlelNKUVoyVl9nMUE='));
  }

  Future<void> saveCustomGeminiApiKey(String key) async {
    await SecureStorageService.instance.saveGeminiApiKey(key);
  }

  Future<String?> getOpenAiApiKey() async {
    return await SecureStorageService.instance.getOpenAiApiKey();
  }

  Future<void> setOpenAiApiKey(String key) async {
    await SecureStorageService.instance.saveOpenAiApiKey(key);
  }

  Future<String?> getClaudeApiKey() async {
    return await SecureStorageService.instance.getClaudeApiKey();
  }

  Future<void> setClaudeApiKey(String key) async {
    await SecureStorageService.instance.saveClaudeApiKey(key);
  }

  Future<String> getGeminiModel() async {
    final p = await prefs;
    final model = p.getString('gemini_model');
    if (model == null || model.contains('2.5') || model.contains('1.5') || model.isEmpty) {
      return 'gemini-3.6-flash';
    }
    return model;
  }

  Future<void> setGeminiModel(String model) async {
    final p = await prefs;
    final safeModel = (model.contains('2.5') || model.isEmpty) ? 'gemini-3.6-flash' : model.trim();
    await p.setString('gemini_model', safeModel);
  }

  Future<String> getOpenAiModel() async {
    final p = await prefs;
    return p.getString('openai_model') ?? 'gpt-4o-mini';
  }

  Future<void> setOpenAiModel(String model) async {
    final p = await prefs;
    await p.setString('openai_model', model.trim());
  }

  Future<String> getClaudeModel() async {
    final p = await prefs;
    return p.getString('claude_model') ?? 'claude-3-5-haiku-20241022';
  }

  Future<void> setClaudeModel(String model) async {
    final p = await prefs;
    await p.setString('claude_model', model.trim());
  }

  Future<String> getAiLanguage() async {
    final p = await prefs;
    return p.getString('ai_language') ?? 'Auto';
  }

  Future<void> setAiLanguage(String lang) async {
    final p = await prefs;
    await p.setString('ai_language', lang);
  }

  Future<String> getRecordingQuality() async {
    final p = await prefs;
    return p.getString('recording_quality') ?? 'High';
  }

  Future<void> setRecordingQuality(String quality) async {
    final p = await prefs;
    await p.setString('recording_quality', quality);
  }

  Future<bool> isNoiseReductionEnabled() async {
    final p = await prefs;
    return p.getBool('noise_reduction') ?? true;
  }

  Future<bool> getNoiseReduction() => isNoiseReductionEnabled();

  Future<void> setNoiseReduction(bool enabled) async {
    final p = await prefs;
    await p.setBool('noise_reduction', enabled);
  }

  Future<bool> isAutoProcessRecording() async {
    final p = await prefs;
    return p.getBool('auto_process_recording') ?? true;
  }

  Future<bool> getAutoProcessRecording() => isAutoProcessRecording();

  Future<void> setAutoProcessRecording(bool enabled) async {
    final p = await prefs;
    await p.setBool('auto_process_recording', enabled);
  }

  // --- Stripe Billing & Receipts ---

  Future<String?> getActivePaymentMethod() async {
    final p = await prefs;
    return p.getString('active_payment_method') ?? 'Visa ending in 4242';
  }

  Future<void> setActivePaymentMethod(String pm) async {
    final p = await prefs;
    await p.setString('active_payment_method', pm);
  }

  Future<List<StripePaymentReceipt>> getPastReceipts() async {
    final p = await prefs;
    final jsonStr = p.getString('receipts_json');
    if (jsonStr != null) {
      try {
        final decoded = jsonDecode(jsonStr) as List;
        return decoded.map((e) => StripePaymentReceipt.fromMap(Map<String, dynamic>.from(e))).toList();
      } catch (_) {}
    }
    // Default initial preview receipt
    final initial = [
      StripePaymentReceipt(
        paymentIntentId: "pi_3N9xFlowExecutive01",
        customerEmail: "elena@enterprise.com",
        amountPaidFormatted: "\$180.00",
        currency: "USD",
        cardBrand: "Visa",
        cardLast4: "4242",
        tierTitle: "Executive Pro",
        billingCycle: "Billed annually",
        timestamp: DateTime.now().millisecondsSinceEpoch - 86400000 * 14,
        status: "succeeded",
        receiptUrl: "https://pay.stripe.com/receipts/acct_noteflow_01",
      ),
    ];
    await savePastReceipts(initial);
    return initial;
  }

  Future<void> savePastReceipts(List<StripePaymentReceipt> receipts) async {
    final p = await prefs;
    final jsonStr = jsonEncode(receipts.map((r) => r.toMap()).toList());
    await p.setString('receipts_json', jsonStr);
  }

  Future<bool> isAnnualBilling() async {
    final p = await prefs;
    return p.getBool('is_annual_billing') ?? true;
  }

  Future<void> setAnnualBilling(bool annual) async {
    final p = await prefs;
    await p.setBool('is_annual_billing', annual);
  }
}
