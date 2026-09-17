import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteflow_ai/services/audio_manager.dart';

void main() {
  group('RecordingValidationResult Tests', () {
    test('success returns correct file and durationSec', () {
      final file = File('test_path.m4a');
      final result = RecordingValidationResult.success(
        file: file,
        durationSec: 45,
        fileSizeBytes: 10240,
      );

      expect(result.isValid, isTrue);
      expect(result.file?.path, 'test_path.m4a');
      expect(result.durationSec, 45);
      expect(result.fileSizeBytes, 10240);
      expect(result.errorMessage, isNull);
      expect(result.isSimulatorIssue, isFalse);
    });

    test('failure returns descriptive error message and empty file', () {
      final result = RecordingValidationResult.failure(
        errorMessage: "Simulator microphone audio not captured. Please check audio inputs.",
        isSimulatorIssue: true,
      );

      expect(result.isValid, isFalse);
      expect(result.file, isNull);
      expect(result.durationSec, 0);
      expect(result.fileSizeBytes, 0);
      expect(result.errorMessage, contains("Simulator microphone"));
      expect(result.isSimulatorIssue, isTrue);
    });
  });
}
