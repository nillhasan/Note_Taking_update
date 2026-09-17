import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

enum RecordingStatus {
  IDLE,
  RECORDING,
  PAUSED,
  STOPPED,
}

class RecordingValidationResult {
  final bool isValid;
  final File? file;
  final int durationSec;
  final int fileSizeBytes;
  final String? errorMessage;
  final bool isSimulatorIssue;

  RecordingValidationResult.success({
    required this.file,
    required this.durationSec,
    required this.fileSizeBytes,
  })  : isValid = true,
        errorMessage = null,
        isSimulatorIssue = false;

  RecordingValidationResult.failure({
    required this.errorMessage,
    this.isSimulatorIssue = false,
  })  : isValid = false,
        file = null,
        durationSec = 0,
        fileSizeBytes = 0;
}

class AudioRecorderManager {
  final AudioRecorder _audioRecorder = AudioRecorder();

  RecordingStatus _status = RecordingStatus.IDLE;
  RecordingStatus get status => _status;

  int _durationSec = 0;
  int get durationSec => _durationSec;

  double _currentAmplitude = 0.0;
  double get currentAmplitude => _currentAmplitude;

  List<double> _amplitudesList = [];
  List<double> get amplitudesList => List.unmodifiable(_amplitudesList);

  File? _currentOutputFile;
  File? get currentOutputFile => _currentOutputFile;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Timer? _tickerTimer;
  final StreamController<RecordingStatus> _statusController = StreamController<RecordingStatus>.broadcast();
  Stream<RecordingStatus> get statusStream => _statusController.stream;

  final StreamController<int> _durationController = StreamController<int>.broadcast();
  Stream<int> get durationStream => _durationController.stream;

  final StreamController<List<double>> _amplitudesController = StreamController<List<double>>.broadcast();
  Stream<List<double>> get amplitudesStream => _amplitudesController.stream;

  Future<bool> checkPermission() async {
    try {
      return await _audioRecorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  Future<bool> startRecording({String? preferredQuality}) async {
    try {
      await stopRecording();
      _errorMessage = null;

      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        _errorMessage = "Microphone permission is required to record a voice note.";
        return false;
      }

      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory(p.join(dir.path, 'recordings'));
      if (!recordingsDir.existsSync()) {
        await recordingsDir.create(recursive: true);
      }

      final fileName = "recording_${DateTime.now().millisecondsSinceEpoch}.m4a";
      final filePath = p.join(recordingsDir.path, fileName);

      int bitRate = 128000;
      int sampleRate = 44100;
      if (preferredQuality == 'Low') {
        bitRate = 64000;
        sampleRate = 22050;
      } else if (preferredQuality == 'High') {
        bitRate = 192000;
        sampleRate = 48000;
      }

      final recordConfig = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: bitRate,
        sampleRate: sampleRate,
        numChannels: 1,
      );

      await _audioRecorder.start(recordConfig, path: filePath);
      _currentOutputFile = File(filePath);

      _status = RecordingStatus.RECORDING;
      _statusController.add(_status);
      _durationSec = 0;
      _durationController.add(_durationSec);
      _amplitudesList = [];

      _startTicker();
      return true;
    } catch (e) {
      _errorMessage = "Could not start recording: $e";
      _status = RecordingStatus.IDLE;
      _statusController.add(_status);
      return false;
    }
  }

  Future<void> pauseRecording() async {
    if (_status == RecordingStatus.RECORDING) {
      try {
        await _audioRecorder.pause();
        _status = RecordingStatus.PAUSED;
        _statusController.add(_status);
      } catch (_) {}
    }
  }

  Future<void> resumeRecording() async {
    if (_status == RecordingStatus.PAUSED) {
      try {
        await _audioRecorder.resume();
        _status = RecordingStatus.RECORDING;
        _statusController.add(_status);
      } catch (_) {}
    }
  }

  Future<RecordingValidationResult> stopAndValidate() async {
    _tickerTimer?.cancel();
    _tickerTimer = null;

    try {
      final recordedPath = await _audioRecorder.stop();
      _status = RecordingStatus.IDLE;
      _statusController.add(_status);

      if (recordedPath != null && recordedPath.isNotEmpty) {
        final f = File(recordedPath);
        if (f.existsSync()) {
          final size = f.lengthSync();
          if (size > 100) {
            _currentOutputFile = f;
            return RecordingValidationResult.success(
              file: f,
              durationSec: _durationSec > 0 ? _durationSec : 1,
              fileSizeBytes: size,
            );
          } else {
            return RecordingValidationResult.failure(
              errorMessage: "Audio recording was empty (0 bytes). If running on an iOS Simulator, please ensure host microphone input is enabled, or test voice recording on a physical device.",
              isSimulatorIssue: true,
            );
          }
        }
      }
    } catch (e) {
      _errorMessage = "Failed to finalize audio recording: $e";
      return RecordingValidationResult.failure(errorMessage: "Failed to finalize audio recording: $e");
    }

    _status = RecordingStatus.IDLE;
    _statusController.add(_status);
    return RecordingValidationResult.failure(errorMessage: "Recording file was not created.");
  }

  Future<File?> stopRecording() async {
    final res = await stopAndValidate();
    return res.file;
  }

  Future<void> cancelRecording() async {
    _tickerTimer?.cancel();
    _tickerTimer = null;
    try {
      await _audioRecorder.cancel();
      if (_currentOutputFile != null && _currentOutputFile!.existsSync()) {
        await _currentOutputFile!.delete();
      }
    } catch (_) {}
    _currentOutputFile = null;
    _durationSec = 0;
    _amplitudesList = [];
    _status = RecordingStatus.IDLE;
    _statusController.add(_status);
    _durationController.add(_durationSec);
    _amplitudesController.add(_amplitudesList);
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    int counter = 0;
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (_status == RecordingStatus.RECORDING) {
        counter++;
        if (counter % 10 == 0) {
          _durationSec += 1;
          _durationController.add(_durationSec);
        }

        try {
          final amp = await _audioRecorder.getAmplitude();
          // Decibel range is typically -160 to 0 dB.
          // Map -50 dB..0 dB to 0.05..1.0 for visualizer
          final currentDb = amp.current;
          double normalized = 0.08;
          if (currentDb > -60) {
            normalized = ((currentDb + 60) / 60.0).clamp(0.08, 1.0);
          }
          _currentAmplitude = normalized;
          _amplitudesList = [..._amplitudesList, normalized];
          if (_amplitudesList.length > 40) {
            _amplitudesList = _amplitudesList.sublist(_amplitudesList.length - 40);
          }
          _amplitudesController.add(_amplitudesList);
        } catch (_) {}
      }
    });
  }

  void dispose() {
    _tickerTimer?.cancel();
    _audioRecorder.dispose();
    _statusController.close();
    _durationController.close();
    _amplitudesController.close();
  }
}

class AudioPlayerManager {
  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  int _currentPositionMs = 0;
  int get currentPositionMs => _currentPositionMs;

  int _durationMs = 0;
  int get durationMs => _durationMs;

  String? _currentAudioPath;
  String? get currentAudioPath => _currentAudioPath;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  Stream<bool> get playingStream => _playingController.stream;

  final StreamController<int> _positionController = StreamController<int>.broadcast();
  Stream<int> get positionStream => _positionController.stream;

  final StreamController<int> _durationController = StreamController<int>.broadcast();
  Stream<int> get durationStream => _durationController.stream;

  AudioPlayerManager() {
    _initListeners();
  }

  void _initListeners() {
    _posSub = _player.onPositionChanged.listen((pos) {
      _currentPositionMs = pos.inMilliseconds;
      _positionController.add(_currentPositionMs);
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      _durationMs = dur.inMilliseconds;
      _durationController.add(_durationMs);
    });

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      _playingController.add(_isPlaying);
      if (state == PlayerState.completed) {
        _currentPositionMs = 0;
        _positionController.add(0);
      }
    });
  }

  Future<void> playAudio(String? filePath, {int fallbackDurationSec = 0}) async {
    if (filePath == null || filePath.isEmpty) return;

    try {
      if (_currentAudioPath == filePath && _player.state == PlayerState.paused) {
        await _player.resume();
        return;
      }

      await _player.stop();
      _currentAudioPath = filePath;

      if (fallbackDurationSec > 0 && _durationMs == 0) {
        _durationMs = fallbackDurationSec * 1000;
        _durationController.add(_durationMs);
      }

      if (filePath.startsWith("http://") || filePath.startsWith("https://")) {
        await _player.play(UrlSource(filePath));
      } else {
        final file = File(filePath);
        if (file.existsSync()) {
          await _player.play(DeviceFileSource(filePath));
        }
      }
    } catch (_) {}
  }

  Future<void> pauseAudio() async {
    try {
      await _player.pause();
    } catch (_) {}
  }

  Future<void> resumeAudio() async {
    try {
      if (_currentPositionMs >= _durationMs && _durationMs > 0) {
        await _player.seek(Duration.zero);
      }
      await _player.resume();
    } catch (_) {}
  }

  Future<void> seekTo(int positionMs) async {
    try {
      final safeMs = positionMs.clamp(0, _durationMs > 0 ? _durationMs : positionMs);
      _currentPositionMs = safeMs;
      _positionController.add(_currentPositionMs);
      await _player.seek(Duration(milliseconds: safeMs));
    } catch (_) {}
  }

  Future<void> stopAudio() async {
    try {
      await _player.stop();
      _isPlaying = false;
      _currentPositionMs = 0;
      _playingController.add(_isPlaying);
      _positionController.add(_currentPositionMs);
    } catch (_) {}
  }

  Stream<bool> get playerStateStream => playingStream;
  Future<void> play(String path) => playAudio(path);
  Future<void> pause() => pauseAudio();
  Future<void> stop() => stopAudio();

  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    _playingController.close();
    _positionController.close();
    _durationController.close();
  }
}
