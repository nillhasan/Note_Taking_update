import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../data/local/preferences_service.dart';
import '../services/supabase_service.dart';

class AuthProvider with ChangeNotifier {
  UserProfile? _currentUser;
  UserProfile? get currentUser => _currentUser;

  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _authError;
  String? get authError => _authError;

  StreamSubscription<AuthState>? _authSubscription;

  AuthProvider() {
    _restoreUser();
    _initAuthListener();
  }

  void _initAuthListener() {
    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        _authSubscription = client.auth.onAuthStateChange.listen((data) async {
          final AuthChangeEvent event = data.event;
          final Session? session = data.session;

          if (event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.tokenRefreshed ||
              event == AuthChangeEvent.userUpdated) {
            if (session?.user != null) {
              final user = session!.user;
              SupabaseService.instance.sessionAccessToken = session.accessToken;
              SupabaseService.instance.currentSupabaseUserId = user.id;

              final provider = user.appMetadata['provider']?.toString() ?? 'google';
              final profile = SupabaseService.instance.userProfileFromSupabaseUser(
                user,
                authProvider: provider,
              );
              _currentUser = profile;
              _isLoading = false;
              _authError = null;
              await PreferencesService.instance.saveUser(profile);
              await SupabaseService.instance.upsertProfileToDatabase(profile);
              notifyListeners();
            }
          } else if (event == AuthChangeEvent.signedOut) {
            if (_currentUser != null && !_currentUser!.isAnonymous) {
              _currentUser = null;
              _isLoading = false;
              await PreferencesService.instance.clearUser();
              notifyListeners();
            }
          }
        }, onError: (err) {
          _isLoading = false;
          _authError = err.toString();
          notifyListeners();
        });
      }
    } catch (_) {}
  }

  Future<void> _restoreUser() async {
    final saved = await PreferencesService.instance.getSavedUser();
    if (saved != null && (saved.email == 'user@gmail.com' || saved.email == 'user@icloud.com')) {
      await PreferencesService.instance.clearUser();
      _currentUser = null;
    } else {
      _currentUser = saved;
    }
    _isInitializing = false;
    notifyListeners();
  }

  void clearError() {
    _authError = null;
    notifyListeners();
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      final profile = await SupabaseService.instance.signInWithEmail(email, password);
      _currentUser = profile;
      await PreferencesService.instance.saveUser(profile);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _authError = e.toString().replaceFirst("Exception: ", "");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUpWithEmail(String name, String email, String password) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      final profile = await SupabaseService.instance.signUpWithEmail(name, email, password);
      _currentUser = profile;
      await PreferencesService.instance.saveUser(profile);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _authError = e.toString().replaceFirst("Exception: ", "");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      final profile = await SupabaseService.instance.signInWithGoogle();
      if (profile == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _currentUser = profile;
      await PreferencesService.instance.saveUser(profile);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _authError = e.toString().replaceFirst("Exception: ", "");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInAsGuest() async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      const guestId = "guest_user_pro";
      final profile = UserProfile(
        id: guestId,
        name: "Test User (Pro)",
        email: "guest@noteflow.ai",
        isAnonymous: false,
        authProvider: "guest",
        supabaseId: guestId,
        subscriptionTierName: "EXECUTIVE_PRO",
      );

      _currentUser = profile;
      await PreferencesService.instance.saveUser(profile);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _authError = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithApple() async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      final profile = await SupabaseService.instance.signInWithApple();
      if (profile == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _currentUser = profile;
      await PreferencesService.instance.saveUser(profile);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _authError = e.toString().replaceFirst("Exception: ", "");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();
    try {
      await SupabaseService.instance.sendPasswordReset(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _authError = e.toString().replaceFirst("Exception: ", "");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendMagicOtp(String email) async {
    _isLoading = true;
    notifyListeners();
    try {
      await SupabaseService.instance.sendMagicOtp(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfileName(String newName) async {
    if (_currentUser == null) return false;
    final updated = _currentUser!.copyWith(name: newName);
    _currentUser = updated;
    await PreferencesService.instance.saveUser(updated);
    await SupabaseService.instance.upsertProfileToDatabase(updated);
    notifyListeners();
    return true;
  }

  void continueAsGuest() {
    final guestUser = UserProfile(
      id: "guest_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}",
      name: "Guest User",
      email: "guest@noteflow.local",
      isAnonymous: true,
      authProvider: "guest",
      subscriptionTierName: "STARTER",
    );
    _currentUser = guestUser;
    PreferencesService.instance.saveUser(guestUser);
    notifyListeners();
  }

  void updateSubscriptionTier(SubscriptionTier tier) {
    if (_currentUser == null) return;
    final updated = _currentUser!.copyWith(subscriptionTierName: tier.name);
    _currentUser = updated;
    PreferencesService.instance.saveUser(updated);
    notifyListeners();
  }

  Future<void> signOut() async {
    await SupabaseService.instance.signOut();
    await PreferencesService.instance.clearUser();
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    _isLoading = true;
    notifyListeners();
    try {
      await signOut();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _authError = e.toString().replaceFirst("Exception: ", "");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
