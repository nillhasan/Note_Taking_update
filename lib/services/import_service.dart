import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class ImportResult {
  final bool success;
  final String? filePath;
  final String? title;
  final String? textContent;
  final String? mimeType;
  final String? errorMessage;

  ImportResult({
    required this.success,
    this.filePath,
    this.title,
    this.textContent,
    this.mimeType,
    this.errorMessage,
  });
}

class ImportService {
  static final ImportService instance = ImportService._init();
  ImportService._init();

  /// Pick and validate an Audio file
  Future<ImportResult> pickAudioFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg'],
      );

      if (files.isEmpty || files.first.path == null) {
        return ImportResult(success: false, errorMessage: "No audio file selected.");
      }

      final file = File(files.first.path!);
      if (!file.existsSync() || file.lengthSync() == 0) {
        return ImportResult(success: false, errorMessage: "Selected audio file is empty or unreadable.");
      }

      final rawName = p.basenameWithoutExtension(file.path);
      final cleanTitle = rawName.replaceAll(RegExp(r'[_-]'), ' ');

      return ImportResult(
        success: true,
        filePath: file.path,
        title: cleanTitle.isNotEmpty ? cleanTitle : "Imported Audio",
        mimeType: "audio",
      );
    } catch (e) {
      return ImportResult(success: false, errorMessage: "Failed to select audio: $e");
    }
  }

  /// Pick and validate a Video file
  Future<ImportResult> pickVideoFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'mkv', 'avi', '3gp'],
      );

      if (files.isEmpty || files.first.path == null) {
        return ImportResult(success: false, errorMessage: "No video file selected.");
      }

      final file = File(files.first.path!);
      if (!file.existsSync() || file.lengthSync() == 0) {
        return ImportResult(success: false, errorMessage: "Selected video file is empty.");
      }

      final rawName = p.basenameWithoutExtension(file.path);
      final cleanTitle = rawName.replaceAll(RegExp(r'[_-]'), ' ');

      return ImportResult(
        success: true,
        filePath: file.path,
        title: cleanTitle.isNotEmpty ? cleanTitle : "Imported Video",
        mimeType: "video",
      );
    } catch (e) {
      return ImportResult(success: false, errorMessage: "Failed to select video: $e");
    }
  }

  /// Pick and read text from PDF, DOC, DOCX, or TXT
  Future<ImportResult> pickDocumentFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'md'],
      );

      if (files.isEmpty || files.first.path == null) {
        return ImportResult(success: false, errorMessage: "No document selected.");
      }

      final file = File(files.first.path!);
      if (!file.existsSync() || file.lengthSync() == 0) {
        return ImportResult(success: false, errorMessage: "Selected document is empty.");
      }

      final ext = p.extension(file.path).toLowerCase();
      final rawName = p.basenameWithoutExtension(file.path);
      final cleanTitle = rawName.replaceAll(RegExp(r'[_-]'), ' ');

      String extractedText = "";

      if (ext == '.txt' || ext == '.md') {
        extractedText = await file.readAsString();
      } else {
        // Read file bytes and extract printable text strings
        final bytes = await file.readAsBytes();
        final textBuffer = StringBuffer();
        final regex = RegExp(r'[\x20-\x7E\s]{4,}');
        final rawString = String.fromCharCodes(bytes);
        final matches = regex.allMatches(rawString);
        for (final m in matches) {
          final s = m.group(0)?.trim();
          if (s != null && s.length > 5) {
            textBuffer.writeln(s);
          }
        }
        extractedText = textBuffer.toString().trim();
      }

      if (extractedText.isEmpty) {
        return ImportResult(
          success: false,
          errorMessage: "Could not extract readable text from this document. It may be scanned or image-based.",
        );
      }

      return ImportResult(
        success: true,
        filePath: file.path,
        title: cleanTitle.isNotEmpty ? cleanTitle : "Imported Document",
        textContent: extractedText,
        mimeType: "document",
      );
    } catch (e) {
      return ImportResult(success: false, errorMessage: "Error extracting document: $e");
    }
  }

  /// Validate YouTube URL and extract ID
  bool isValidYouTubeUrl(String url) {
    final clean = url.trim();
    return clean.contains("youtube.com/watch") || clean.contains("youtu.be/") || clean.contains("youtube.com/shorts/");
  }

  String? extractYouTubeId(String url) {
    final clean = url.trim();
    if (clean.contains("youtu.be/")) {
      return clean.split("youtu.be/").last.split("?").first;
    } else if (clean.contains("v=")) {
      return clean.split("v=").last.split("&").first;
    } else if (clean.contains("/shorts/")) {
      return clean.split("/shorts/").last.split("?").first;
    }
    return null;
  }

  /// Validate Instagram URL
  bool isValidInstagramUrl(String url) {
    final clean = url.trim().toLowerCase();
    return clean.contains("instagram.com/p/") || clean.contains("instagram.com/reel/") || clean.contains("instagram.com/tv/");
  }
}
