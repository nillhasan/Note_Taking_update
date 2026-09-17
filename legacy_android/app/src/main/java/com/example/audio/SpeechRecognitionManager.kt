package com.example.audio

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Locale

class SpeechRecognitionManager(private val context: Context) {

    private var speechRecognizer: SpeechRecognizer? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val _isListening = MutableStateFlow(false)
    val isListening: StateFlow<Boolean> = _isListening.asStateFlow()

    private val _liveTranscript = MutableStateFlow("")
    val liveTranscript: StateFlow<String> = _liveTranscript.asStateFlow()

    private val _partialText = MutableStateFlow("")
    val partialText: StateFlow<String> = _partialText.asStateFlow()

    private val _isAvailable = MutableStateFlow(SpeechRecognizer.isRecognitionAvailable(context))
    val isAvailable: StateFlow<Boolean> = _isAvailable.asStateFlow()

    private var shouldKeepListening = false

    fun startListening() {
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            Log.w("SpeechRecognition", "Speech recognition not available on this device/environment")
            _isAvailable.value = false
            return
        }

        shouldKeepListening = true
        mainHandler.removeCallbacksAndMessages(null)
        mainHandler.post {
            initAndStart()
        }
    }

    private fun initAndStart() {
        if (!shouldKeepListening) return
        try {
            destroyRecognizer()
            val recognizer = SpeechRecognizer.createSpeechRecognizer(context)
            recognizer.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    _isListening.value = true
                }

                override fun onBeginningOfSpeech() {}

                override fun onRmsChanged(rmsdB: Float) {}

                override fun onBufferReceived(buffer: ByteArray?) {}

                override fun onEndOfSpeech() {
                    _isListening.value = false
                }

                override fun onError(error: Int) {
                    _isListening.value = false
                    Log.d("SpeechRecognition", "Speech error code: $error")
                    // If still supposed to be listening (e.g. paused or silence timeout), restart cleanly with delay
                    if (shouldKeepListening && (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT || error == SpeechRecognizer.ERROR_NETWORK_TIMEOUT)) {
                        mainHandler.removeCallbacksAndMessages(null)
                        mainHandler.postDelayed({
                            if (shouldKeepListening) {
                                initAndStart()
                            }
                        }, 350)
                    }
                }

                override fun onResults(results: Bundle?) {
                    _isListening.value = false
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    if (!matches.isNullOrEmpty()) {
                        val heard = matches[0].trim()
                        if (heard.isNotBlank()) {
                            val current = _liveTranscript.value.trim()
                            _liveTranscript.value = if (current.isEmpty()) {
                                heard
                            } else {
                                "$current $heard"
                            }
                        }
                    }
                    _partialText.value = ""

                    // If recording is still ongoing, keep listening for next sentences
                    if (shouldKeepListening) {
                        mainHandler.removeCallbacksAndMessages(null)
                        mainHandler.postDelayed({
                            if (shouldKeepListening) {
                                initAndStart()
                            }
                        }, 250)
                    }
                }

                override fun onPartialResults(partialResults: Bundle?) {
                    val partialMatches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    if (!partialMatches.isNullOrEmpty()) {
                        _partialText.value = partialMatches[0]
                    }
                }

                override fun onEvent(eventType: Int, params: Bundle?) {}
            })

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            }

            recognizer.startListening(intent)
            speechRecognizer = recognizer
            _isListening.value = true
        } catch (e: Exception) {
            Log.e("SpeechRecognition", "Failed to start speech recognizer: ${e.message}")
            _isListening.value = false
        }
    }

    fun stopListening() {
        shouldKeepListening = false
        mainHandler.removeCallbacksAndMessages(null)
        mainHandler.post {
            try {
                speechRecognizer?.stopListening()
            } catch (e: Exception) {
                Log.w("SpeechRecognition", "Error stopping recognizer: ${e.message}")
            }
            _isListening.value = false
            _partialText.value = ""
        }
    }

    fun cancelListening() {
        shouldKeepListening = false
        mainHandler.removeCallbacksAndMessages(null)
        mainHandler.post {
            destroyRecognizer()
            _isListening.value = false
            _partialText.value = ""
        }
    }

    fun setTranscript(text: String) {
        _liveTranscript.value = text
    }

    fun appendText(text: String) {
        val current = _liveTranscript.value.trim()
        _liveTranscript.value = if (current.isEmpty()) {
            text.trim()
        } else {
            "$current\n${text.trim()}"
        }
    }

    fun clearTranscript() {
        _liveTranscript.value = ""
        _partialText.value = ""
    }

    private fun destroyRecognizer() {
        try {
            speechRecognizer?.destroy()
        } catch (e: Exception) {
            Log.w("SpeechRecognition", "Error destroying speech recognizer: ${e.message}")
        }
        speechRecognizer = null
    }
}
