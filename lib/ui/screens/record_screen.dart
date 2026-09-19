import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audio_manager.dart';
import '../../state/notes_provider.dart';
import '../../theme/app_theme.dart';
import '../components/waveform_visualizer.dart';
import 'note_detail_screen.dart';

class RecordScreen extends StatefulWidget {
  final bool initialIsMeeting;

  const RecordScreen({super.key, this.initialIsMeeting = false});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final AudioRecorderManager _recorder = AudioRecorderManager();
  final AudioPlayerManager _player = AudioPlayerManager();

  late bool _isMeeting;
  final TextEditingController _titleController = TextEditingController();

  StreamSubscription? _durationSub;
  StreamSubscription? _amplitudesSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _playerSub;

  int _durationSec = 0;
  List<double> _amplitudes = [];
  RecordingStatus _status = RecordingStatus.IDLE;
  bool _isProcessing = false;
  String? _permissionError;

  RecordingValidationResult? _savedResult;
  bool _isPlayingPreview = false;

  @override
  void initState() {
    super.initState();
    _isMeeting = widget.initialIsMeeting;
    _titleController.text = _isMeeting ? "Meeting Note" : "Voice Note";

    _durationSub = _recorder.durationStream.listen((sec) {
      if (mounted) setState(() => _durationSec = sec);
    });

    _amplitudesSub = _recorder.amplitudesStream.listen((amps) {
      if (mounted) setState(() => _amplitudes = amps);
    });

    _statusSub = _recorder.statusStream.listen((status) {
      if (mounted) setState(() => _status = status);
    });

    _playerSub = _player.playerStateStream.listen((isPlaying) {
      if (mounted) {
        setState(() {
          _isPlayingPreview = isPlaying;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRecording();
    });
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _amplitudesSub?.cancel();
    _statusSub?.cancel();
    _playerSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _permissionError = null;
      _savedResult = null;
    });
    final success = await _recorder.startRecording();
    if (!success && mounted) {
      setState(() {
        _permissionError = _recorder.errorMessage ?? "Microphone permission is required to record a voice note.";
      });
    }
  }

  String _formatTimer(int sec) {
    final mins = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return "$mins:$s";
  }

  Future<void> _stopAndReview() async {
    final result = await _recorder.stopAndValidate();
    if (!mounted) return;

    if (!result.isValid || result.file == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.mic_off_outlined, color: AppColors.recordingRed, size: 22),
              SizedBox(width: 8),
              Text("Recording Issue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            result.errorMessage ?? "Microphone input was empty. Please check permissions or test on a physical device.",
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text("Close", style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _startRecording();
              },
              child: const Text("Record Again"),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _savedResult = result;
    });
  }

  Future<void> _processSavedAudioWithAi() async {
    if (_savedResult == null || _savedResult!.file == null) return;
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    setState(() => _isProcessing = true);

    try {
      final newNote = await notesProvider.processFinishedAudio(
        file: _savedResult!.file!,
        durationSec: _savedResult!.durationSec > 0 ? _savedResult!.durationSec : 5,
        isMeeting: _isMeeting,
        customTitle: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : "Voice Note",
      );

      if (mounted) {
        final errorMsg = notesProvider.lastAiError;
        setState(() => _isProcessing = false);
        Navigator.pop(context); // Close recording sheet
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NoteDetailScreen(noteId: newNote.id),
          ),
        );
        if (errorMsg != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Note saved locally. AI Notice: $errorMsg"),
              backgroundColor: AppColors.accentDark,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error processing recording: $e"), backgroundColor: AppColors.recordingRed),
        );
        Navigator.pop(context);
      }
    }
  }

  void _togglePreviewPlayback() async {
    if (_savedResult == null || _savedResult!.file == null) return;
    if (_isPlayingPreview) {
      await _player.pause();
    } else {
      await _player.play(_savedResult!.file!.path);
    }
  }

  void _cancel() async {
    await _recorder.cancelRecording();
    await _player.stop();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final notesProvider = Provider.of<NotesProvider>(context);

    // Processing / AI Summarization State
    if (_isProcessing) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: AppColors.accentDark,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Transcribing & Analyzing",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  notesProvider.processingStatusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Permission Error State
    if (_permissionError != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mic_off_outlined, size: 56, color: AppColors.recordingRed),
                const SizedBox(height: 20),
                const Text(
                  "Microphone Access Needed",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                Text(
                  _permissionError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: _startRecording,
                  child: const Text("Try Again"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Post-Recording Review Card State (Requirement 27)
    if (_savedResult != null) {
      final kbSize = (_savedResult!.fileSizeBytes / 1024).toStringAsFixed(1);
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
            onPressed: _cancel,
          ),
          centerTitle: true,
          title: const Text(
            "Recording Saved",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                const Spacer(),
                // Icon / Checkmark
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Icon(Icons.mic, size: 36, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Recording saved",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  "Duration: ${_formatTimer(_savedResult!.durationSec)}  •  $kbSize KB",
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 32),

                // Audio Playback Preview Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isPlayingPreview ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          size: 40,
                          color: AppColors.accentDark,
                        ),
                        onPressed: _togglePreviewPlayback,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isPlayingPreview ? "Playing recording..." : "Tap to listen",
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            Text(
                              "Preview captured microphone audio",
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Actions: Process with AI / Record Again
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _processSavedAudioWithAi,
                    child: const Text("Process with AI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _startRecording,
                  child: const Text(
                    "Record Again",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      );
    }

    // Active Recording State
    final isPaused = _status == RecordingStatus.PAUSED;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: _cancel,
        ),
        centerTitle: true,
        title: Text(
          _isMeeting ? "Meeting Recording" : "New Recording",
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // Title Field
              TextField(
                controller: _titleController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: "Enter title...",
                ),
              ),

              const Spacer(),

              // Timer
              Text(
                _formatTimer(_durationSec),
                style: const TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textPrimary,
                  letterSpacing: -1.0,
                  fontFeatures: [],
                ),
              ),
              const SizedBox(height: 8),

              // Recording Status Text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isPaused ? AppColors.textMuted : AppColors.recordingRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPaused ? "Paused" : "Recording...",
                    style: TextStyle(
                      fontSize: 14,
                      color: isPaused ? AppColors.textMuted : AppColors.recordingRed,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Waveform Visualizer
              SizedBox(
                height: 70,
                width: double.infinity,
                child: WaveformVisualizer(
                  amplitudes: _amplitudes,
                  isRecording: !isPaused,
                ),
              ),

              const Spacer(),

              // Mode switch (Voice Note vs Meeting)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeButton("Voice Note", !_isMeeting, () {
                      setState(() {
                        _isMeeting = false;
                        _titleController.text = "Voice Note";
                      });
                    }),
                    _buildModeButton("Meeting Mode", _isMeeting, () {
                      setState(() {
                        _isMeeting = true;
                        _titleController.text = "Meeting Note";
                      });
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Controls: Pause / Resume & Stop
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pause / Resume
                  IconButton(
                    iconSize: 44,
                    icon: Icon(
                      isPaused ? Icons.play_circle_outline : Icons.pause_circle_outline,
                      color: AppColors.iconColor,
                    ),
                    onPressed: () {
                      if (isPaused) {
                        _recorder.resumeRecording();
                      } else {
                        _recorder.pauseRecording();
                      }
                    },
                    tooltip: isPaused ? "Resume" : "Pause",
                  ),
                  const SizedBox(width: 32),

                  // Stop & Review Button
                  GestureDetector(
                    onTap: _stopAndReview,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppColors.accentDark,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.stop_rounded, color: Colors.white, size: 36),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),

                  // Discard Button
                  IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.delete_outline, color: AppColors.textMuted),
                    onPressed: _cancel,
                    tooltip: "Discard",
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentDark : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
