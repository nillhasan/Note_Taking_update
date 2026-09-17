package com.example.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.model.SubscriptionTier
import com.example.data.model.UserProfile
import com.example.data.remote.AuthManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class AuthViewModel(val authManager: AuthManager) : ViewModel() {
    val currentUser: StateFlow<UserProfile?> = authManager.currentUser
    val isLoading: StateFlow<Boolean> = authManager.isLoading
    val authError: StateFlow<String?> = authManager.authError

    private val _otpSentMessage = MutableStateFlow<String?>(null)
    val otpSentMessage: StateFlow<String?> = _otpSentMessage.asStateFlow()

    fun signIn(email: String, pass: String, onSuccess: () -> Unit = {}) {
        viewModelScope.launch {
            val success = authManager.signInWithEmail(email, pass)
            if (success) onSuccess()
        }
    }

    fun signUp(name: String, email: String, pass: String, onSuccess: () -> Unit = {}) {
        viewModelScope.launch {
            val success = authManager.signUpWithEmail(name, email, pass)
            if (success) onSuccess()
        }
    }

    /**
     * Sign In with Google through Supabase Auth & PostgreSQL
     */
    fun signInWithGoogle(
        email: String = "alex.google@enterprise.com",
        displayName: String = "Alex Google Executive",
        onSuccess: () -> Unit = {}
    ) {
        viewModelScope.launch {
            val success = authManager.signInWithGoogle(email, displayName)
            if (success) onSuccess()
        }
    }

    /**
     * Sign In with iOS / Apple through Supabase Auth & PostgreSQL
     */
    fun signInWithApple(
        email: String = "elena.apple@privaterelay.appleid.com",
        displayName: String = "Elena Apple ID",
        onSuccess: () -> Unit = {}
    ) {
        viewModelScope.launch {
            val success = authManager.signInWithApple(email, displayName)
            if (success) onSuccess()
        }
    }

    /**
     * Dispatch Supabase Magic OTP link to user email
     */
    fun sendMagicOtp(email: String, onComplete: () -> Unit = {}) {
        viewModelScope.launch {
            val success = authManager.sendMagicOtp(email)
            if (success) {
                _otpSentMessage.value = "Supabase OTP code dispatched to $email"
                onComplete()
            }
        }
    }

    fun clearOtpMessage() {
        _otpSentMessage.value = null
    }

    fun updateSubscriptionTier(tier: SubscriptionTier) {
        authManager.updateSubscriptionTier(tier)
    }

    fun continueAsGuest() {
        authManager.continueAsGuest()
    }

    fun signOut() {
        authManager.signOut()
    }

    fun clearError() {
        authManager.clearError()
    }
}
