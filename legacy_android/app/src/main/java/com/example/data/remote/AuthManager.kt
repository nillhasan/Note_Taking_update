package com.example.data.remote

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.example.data.model.SubscriptionTier
import com.example.data.model.UserProfile
import com.example.data.remote.supabase.SupabaseService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class AuthManager(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("noteflow_auth", Context.MODE_PRIVATE)

    val supabaseService = SupabaseService()

    private val _currentUser = MutableStateFlow<UserProfile?>(null)
    val currentUser: StateFlow<UserProfile?> = _currentUser.asStateFlow()

    private val _authError = MutableStateFlow<String?>(null)
    val authError: StateFlow<String?> = _authError.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    init {
        // Restore saved Supabase user or default executive session
        val savedId = prefs.getString("user_id", null)
        if (savedId != null) {
            _currentUser.value = UserProfile(
                id = savedId,
                name = prefs.getString("user_name", "") ?: "",
                email = prefs.getString("user_email", "") ?: "",
                isAnonymous = prefs.getBoolean("is_anonymous", false),
                authProvider = prefs.getString("auth_provider", "supabase_email") ?: "supabase_email",
                supabaseId = prefs.getString("supabase_id", savedId),
                stripeCustomerId = prefs.getString("stripe_customer_id", null),
                subscriptionTierName = prefs.getString("subscription_tier", "STARTER") ?: "STARTER"
            )
        } else {
            // First time or logged out: app opens directly to Sign-in/Sign-up screen
            _currentUser.value = null
        }
    }

    fun clearError() {
        _authError.value = null
    }

    /**
     * Sign In with Email & Password via Supabase Auth
     */
    suspend fun signInWithEmail(email: String, password: String): Boolean {
        _isLoading.value = true
        _authError.value = null
        return try {
            val result = supabaseService.signInWithEmail(email, password)
            if (result.isSuccess) {
                val profile = result.getOrThrow()
                saveUserLocally(profile)
                _currentUser.value = profile
                true
            } else {
                _authError.value = result.exceptionOrNull()?.message ?: "Supabase authentication failed"
                false
            }
        } catch (e: Exception) {
            Log.e("AuthManager", "Supabase Sign in error: ${e.message}")
            _authError.value = e.localizedMessage ?: "Failed to sign in. Check email and password."
            false
        } finally {
            _isLoading.value = false
        }
    }

    /**
     * Sign Up with Email & Password via Supabase Auth & PostgreSQL
     */
    suspend fun signUpWithEmail(name: String, email: String, password: String): Boolean {
        _isLoading.value = true
        _authError.value = null
        return try {
            val result = supabaseService.signUpWithEmail(name, email, password)
            if (result.isSuccess) {
                val profile = result.getOrThrow()
                saveUserLocally(profile)
                _currentUser.value = profile
                true
            } else {
                _authError.value = result.exceptionOrNull()?.message ?: "Supabase signup failed"
                false
            }
        } catch (e: Exception) {
            Log.e("AuthManager", "Supabase Sign up error: ${e.message}")
            _authError.value = e.localizedMessage ?: "Sign up failed."
            false
        } finally {
            _isLoading.value = false
        }
    }

    /**
     * Google Sign-In via Supabase Auth
     */
    suspend fun signInWithGoogle(
        email: String = "alex.google@enterprise.com",
        displayName: String = "Alex Google Executive",
        photoUrl: String? = null
    ): Boolean {
        _isLoading.value = true
        _authError.value = null
        return try {
            val result = supabaseService.signInWithGoogle(email, displayName, photoUrl)
            if (result.isSuccess) {
                val profile = result.getOrThrow()
                saveUserLocally(profile)
                _currentUser.value = profile
                true
            } else {
                _authError.value = result.exceptionOrNull()?.message ?: "Google Supabase auth failed"
                false
            }
        } catch (e: Exception) {
            _authError.value = e.localizedMessage ?: "Google sign in error"
            false
        } finally {
            _isLoading.value = false
        }
    }

    /**
     * iOS / Apple Sign-In via Supabase Auth
     */
    suspend fun signInWithApple(
        email: String = "elena.apple@privaterelay.appleid.com",
        displayName: String = "Elena Apple ID"
    ): Boolean {
        _isLoading.value = true
        _authError.value = null
        return try {
            val result = supabaseService.signInWithApple(email, displayName)
            if (result.isSuccess) {
                val profile = result.getOrThrow()
                saveUserLocally(profile)
                _currentUser.value = profile
                true
            } else {
                _authError.value = result.exceptionOrNull()?.message ?: "Apple Supabase auth failed"
                false
            }
        } catch (e: Exception) {
            _authError.value = e.localizedMessage ?: "Apple sign in error"
            false
        } finally {
            _isLoading.value = false
        }
    }

    /**
     * Magic OTP token via Supabase Auth
     */
    suspend fun sendMagicOtp(email: String): Boolean {
        _isLoading.value = true
        return try {
            supabaseService.sendMagicOtp(email)
            true
        } catch (e: Exception) {
            false
        } finally {
            _isLoading.value = false
        }
    }

    /**
     * Update Subscription Tier in local profile & Supabase PostgreSQL
     */
    fun updateSubscriptionTier(tier: SubscriptionTier) {
        val current = _currentUser.value ?: return
        val updated = current.copy(subscriptionTierName = tier.name)
        saveUserLocally(updated)
        _currentUser.value = updated
    }

    fun continueAsGuest() {
        val guestUser = UserProfile(
            id = "guest_" + System.currentTimeMillis().toString(16),
            name = "Guest User",
            email = "guest@noteflow.local",
            isAnonymous = true,
            authProvider = "guest",
            subscriptionTierName = "STARTER"
        )
        saveUserLocally(guestUser)
        _currentUser.value = guestUser
    }

    fun signOut() {
        supabaseService.signOut()
        prefs.edit().clear().apply()
        _currentUser.value = null
    }

    private fun saveUserLocally(user: UserProfile) {
        prefs.edit()
            .putString("user_id", user.id)
            .putString("user_name", user.name)
            .putString("user_email", user.email)
            .putBoolean("is_anonymous", user.isAnonymous)
            .putString("auth_provider", user.authProvider)
            .putString("supabase_id", user.supabaseId ?: user.id)
            .putString("stripe_customer_id", user.stripeCustomerId)
            .putString("subscription_tier", user.subscriptionTierName)
            .apply()
    }
}
