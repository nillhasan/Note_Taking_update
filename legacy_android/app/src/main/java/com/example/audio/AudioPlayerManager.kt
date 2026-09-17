package com.example.audio

import android.content.Context
import android.media.MediaPlayer
import android.net.Uri
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.File

class AudioPlayerManager(private val context: Context, private val scope: CoroutineScope) {
    private var mediaPlayer: MediaPlayer? = null
    private var progressJob: Job? = null

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _currentPositionMs = MutableStateFlow(0)
    val currentPositionMs: StateFlow<Int> = _currentPositionMs.asStateFlow()

    private val _durationMs = MutableStateFlow(0)
    val durationMs: StateFlow<Int> = _durationMs.asStateFlow()

    private var isSimulatedPlayback = false

    fun playAudio(filePath: String?, fallbackDurationSec: Int = 0) {
        stopAudio()

        val file = filePath?.let { File(it) }
        val hasRealFile = file != null && file.exists() && file.length() > 500L

        if (hasRealFile && file != null) {
            try {
                val player = MediaPlayer().apply {
                    setDataSource(context, Uri.fromFile(file))
                    prepare()
                    start()
                    setOnCompletionListener {
                        _isPlaying.value = false
                        _currentPositionMs.value = 0
                        progressJob?.cancel()
                    }
                }
                mediaPlayer = player
                _isPlaying.value = true
                _durationMs.value = if (player.duration > 0) player.duration else maxOf(fallbackDurationSec * 1000, 10000)
                isSimulatedPlayback = false
                startProgressTracker()
                return
            } catch (e: Exception) {
                Log.w("AudioPlayerManager", "Real audio playback failed, falling back to simulated playback: ${e.message}")
            }
        }

        // Simulated playback fallback for emulators or silent files
        val totalMs = if (fallbackDurationSec > 0) fallbackDurationSec * 1000 else 15000
        _durationMs.value = totalMs
        _currentPositionMs.value = 0
        _isPlaying.value = true
        isSimulatedPlayback = true
        startSimulatedProgressTracker(totalMs)
    }

    fun pauseAudio() {
        if (isSimulatedPlayback) {
            _isPlaying.value = false
            progressJob?.cancel()
            return
        }
        try {
            if (mediaPlayer?.isPlaying == true) {
                mediaPlayer?.pause()
                _isPlaying.value = false
                progressJob?.cancel()
            }
        } catch (e: Exception) {
            Log.e("AudioPlayerManager", "Error pausing audio: ${e.message}")
        }
    }

    fun resumeAudio() {
        if (isSimulatedPlayback) {
            _isPlaying.value = true
            startSimulatedProgressTracker(_durationMs.value)
            return
        }
        try {
            mediaPlayer?.let {
                it.start()
                _isPlaying.value = true
                startProgressTracker()
            }
        } catch (e: Exception) {
            Log.e("AudioPlayerManager", "Error resuming audio: ${e.message}")
        }
    }

    fun seekTo(positionMs: Int) {
        _currentPositionMs.value = positionMs
        if (!isSimulatedPlayback) {
            try {
                mediaPlayer?.seekTo(positionMs)
            } catch (e: Exception) {
                Log.e("AudioPlayerManager", "Error seeking audio: ${e.message}")
            }
        }
    }

    fun stopAudio() {
        progressJob?.cancel()
        try {
            mediaPlayer?.apply {
                if (isPlaying) stop()
                release()
            }
        } catch (e: Exception) {
            Log.w("AudioPlayerManager", "Error releasing player: ${e.message}")
        } finally {
            mediaPlayer = null
            _isPlaying.value = false
            _currentPositionMs.value = 0
            isSimulatedPlayback = false
        }
    }

    private fun startProgressTracker() {
        progressJob?.cancel()
        progressJob = scope.launch(Dispatchers.Default) {
            while (isActive && _isPlaying.value) {
                try {
                    val pos = mediaPlayer?.currentPosition ?: 0
                    _currentPositionMs.value = pos
                } catch (e: Exception) {
                    // Ignore transient polling errors
                }
                delay(200)
            }
        }
    }

    private fun startSimulatedProgressTracker(totalDurationMs: Int) {
        progressJob?.cancel()
        progressJob = scope.launch(Dispatchers.Default) {
            while (isActive && _isPlaying.value) {
                delay(200)
                val nextPos = _currentPositionMs.value + 200
                if (nextPos >= totalDurationMs) {
                    _currentPositionMs.value = totalDurationMs
                    _isPlaying.value = false
                    break
                } else {
                    _currentPositionMs.value = nextPos
                }
            }
        }
    }
}
