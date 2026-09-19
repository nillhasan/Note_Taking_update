import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
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
      List<PlatformFile> files;
      try {
        files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'opus', 'flac'],
        );
      } catch (_) {
        files = await FilePicker.pickFiles(type: FileType.audio);
      }

      if (files.isEmpty || files.first.path == null) {
        return ImportResult(success: false, errorMessage: "No audio file selected.");
      }

      final file = File(files.first.path!);
      if (!file.existsSync() || file.lengthSync() == 0) {
        return ImportResult(success: false, errorMessage: "Selected audio file is empty or unreadable.");
      }

      // Check audio file size (max 50 MB)
      if (file.lengthSync() > 50 * 1024 * 1024) {
        return ImportResult(
          success: false,
          errorMessage: "Audio file is too large (${(file.lengthSync() / (1024 * 1024)).toStringAsFixed(1)} MB). Please select an audio file under 50 MB.",
        );
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
      List<PlatformFile> files;
      try {
        files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp4', 'mov', 'mkv', 'avi', '3gp'],
        );
      } catch (_) {
        files = await FilePicker.pickFiles(type: FileType.video);
      }

      if (files.isEmpty || files.first.path == null) {
        return ImportResult(success: false, errorMessage: "No video file selected.");
      }

      final file = File(files.first.path!);
      if (!file.existsSync() || file.lengthSync() == 0) {
        return ImportResult(success: false, errorMessage: "Selected video file is empty.");
      }

      // Guard video size against out-of-memory and Gemini inline payload limits (25MB)
      final sizeBytes = file.lengthSync();
      if (sizeBytes > 25 * 1024 * 1024) {
        return ImportResult(
          success: false,
          errorMessage: "Video file is too large (${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB). For AI analysis, please choose a video under 25 MB or import its audio track.",
        );
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

  /// Pick and read text from PDF, DOC, DOCX, TXT, MD, JSON, CSV
  Future<ImportResult> pickDocumentFile() async {
    try {
      List<PlatformFile> files;
      try {
        files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'md', 'json', 'csv'],
        );
      } catch (_) {
        files = await FilePicker.pickFiles(type: FileType.any);
      }

      if (files.isEmpty || files.first.path == null) {
        return ImportResult(success: false, errorMessage: "No document selected.");
      }

      final file = File(files.first.path!);
      if (!file.existsSync() || file.lengthSync() == 0) {
        return ImportResult(success: false, errorMessage: "Selected document is empty.");
      }

      if (file.lengthSync() > 15 * 1024 * 1024) {
        return ImportResult(success: false, errorMessage: "Document exceeds 15 MB limit.");
      }

      final ext = p.extension(file.path).toLowerCase();
      final rawName = p.basenameWithoutExtension(file.path);
      final cleanTitle = rawName.replaceAll(RegExp(r'[_-]'), ' ');

      String extractedText = "";

      if (ext == '.txt' || ext == '.md' || ext == '.json' || ext == '.csv') {
        try {
          extractedText = await file.readAsString();
        } catch (_) {
          final bytes = await file.readAsBytes();
          extractedText = String.fromCharCodes(bytes);
        }
      } else if (ext == '.docx') {
        final bytes = await file.readAsBytes();
        final raw = String.fromCharCodes(bytes);
        final wtRegex = RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true);
        final matches = wtRegex.allMatches(raw);
        if (matches.isNotEmpty) {
          final sb = StringBuffer();
          for (final m in matches) {
            final t = m.group(1)?.trim();
            if (t != null && t.isNotEmpty) {
              sb.write('$t ');
            }
          }
          extractedText = sb.toString().trim();
        }
        if (extractedText.isEmpty) {
          extractedText = _extractPrintableStrings(bytes);
        }
      } else if (ext == '.pdf') {
        final bytes = await file.readAsBytes();
        extractedText = _extractPdfText(bytes);
      } else {
        // DOC or other binary formats
        final bytes = await file.readAsBytes();
        extractedText = _extractPrintableStrings(bytes);
      }

      if (extractedText.trim().isEmpty) {
        return ImportResult(
          success: false,
          errorMessage: "Could not extract readable text from this document. It may be scanned or image-based.",
        );
      }

      return ImportResult(
        success: true,
        filePath: file.path,
        title: cleanTitle.isNotEmpty ? cleanTitle : "Imported Document",
        textContent: extractedText.trim(),
        mimeType: "document",
      );
    } catch (e) {
      return ImportResult(success: false, errorMessage: "Error extracting document: $e");
    }
  }

  /// Extracts clean text from standard and compressed (/FlateDecode) PDF documents
  String _extractPdfText(List<int> bytes) {
    final sb = StringBuffer();
    final len = bytes.length;

    // 1. Search for all "stream" ... "endstream" blocks
    int pos = 0;
    final streamMarker = utf8.encode('stream');
    final endstreamMarker = utf8.encode('endstream');

    final List<List<int>> streamContents = [];

    while (pos < len) {
      final streamStart = _findSublist(bytes, streamMarker, pos);
      if (streamStart == -1) break;

      // Move past "stream" and any trailing \r or \n
      int contentStart = streamStart + streamMarker.length;
      while (contentStart < len && (bytes[contentStart] == 10 || bytes[contentStart] == 13)) {
        contentStart++;
      }

      final streamEnd = _findSublist(bytes, endstreamMarker, contentStart);
      if (streamEnd == -1) break;

      int contentEnd = streamEnd;
      // Trim trailing whitespace/\r/\n before endstream
      while (contentEnd > contentStart &&
          (bytes[contentEnd - 1] == 10 || bytes[contentEnd - 1] == 13 || bytes[contentEnd - 1] == 32)) {
        contentEnd--;
      }

      if (contentEnd > contentStart) {
        final rawStream = bytes.sublist(contentStart, contentEnd);
        // Try to decompress with zlib / deflate
        List<int>? decompressed;
        try {
          decompressed = zlib.decode(rawStream);
        } catch (_) {
          try {
            decompressed = ZLibDecoder(raw: true).convert(rawStream);
          } catch (_) {
            decompressed = rawStream;
          }
        }

        if (decompressed.isNotEmpty) {
          streamContents.add(decompressed);
        }
      }

      pos = streamEnd + endstreamMarker.length;
    }

    // 2. Extract text from stream contents
    for (final stream in streamContents) {
      final text = _decodeStreamToString(stream);
      _extractTextFromPdfCommands(text, sb);
    }

    // 3. Fallback: If no stream text found, scan for BT ... ET or readable strings in uncompressed PDF
    if (sb.isEmpty) {
      final rawString = _decodeStreamToString(bytes);
      _extractTextFromPdfCommands(rawString, sb);
    }

    final result = sb.toString().trim();
    // Filter out any PDF object headers, xref, or dictionary tokens
    final cleanLines = result.split('\n').map((l) => l.trim()).where((l) {
      if (l.isEmpty) return false;
      if (l.startsWith('%PDF-') || l == '%' || l.startsWith('%%')) return false;
      if (RegExp(r'^\d+\s+\d+\s+obj\b').hasMatch(l)) return false;
      if (l == 'endobj' || l == 'endstream' || l.startsWith('xref') || l == 'trailer' || l.startsWith('startxref')) return false;
      if (l.startsWith('<<') || l.endsWith('>>')) return false;
      if (l.startsWith('/') && !l.contains(' ')) return false;
      if (l.contains('/FlateDecode') || l.contains('/MediaBox') || l.contains('/Font') || l.contains('/Catalog')) return false;
      return true;
    }).toList();

    return cleanLines.join('\n').trim();
  }

  String _decodeStreamToString(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      try {
        return latin1.decode(bytes);
      } catch (_) {
        return String.fromCharCodes(bytes);
      }
    }
  }

  int _findSublist(List<int> source, List<int> pattern, int start) {
    if (pattern.isEmpty || source.length < pattern.length) return -1;
    final max = source.length - pattern.length;
    for (int i = start; i <= max; i++) {
      bool match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (source[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  void _extractTextFromPdfCommands(String content, StringBuffer sb) {
    final btBlocks = RegExp(r'BT\s+(.*?)\s+ET', dotAll: true).allMatches(content);
    final List<String> blocks = btBlocks.isNotEmpty
        ? btBlocks.map((m) => m.group(1)!).toList()
        : [content];

    for (final block in blocks) {
      final lineBuffer = StringBuffer();

      final opRegex = RegExp(
        r'\(((?:[^\\()]|\\.)*)\)\s*Tj|'
        r'\[((?:[^\\\[\]]|\\.)*)\]\s*TJ|'
        r'<([0-9a-fA-F\s]+)>\s*Tj|'
        r'\(((?:[^\\()]|\\.)*)\)\s*[\x27\x22]|'
        r'<([0-9a-fA-F\s]+)>\s*[\x27\x22]|'
        r'(?:[-0-9.]+\s+[-0-9.]+\s+T[dD]|T\*)',
      );

      for (final m in opRegex.allMatches(block)) {
        if (m.group(1) != null) {
          final t = _unescapePdf(m.group(1)!);
          if (t.isNotEmpty) lineBuffer.write('$t ');
        } else if (m.group(2) != null) {
          final inner = m.group(2)!;
          final tokens = RegExp(r'\(((?:[^\\()]|\\.)*)\)|<([0-9a-fA-F\s]+)>|(-?\d+(?:\.\d+)?)').allMatches(inner);
          for (final tm in tokens) {
            if (tm.group(1) != null) {
              final str = _unescapePdf(tm.group(1)!);
              lineBuffer.write(str);
            } else if (tm.group(2) != null) {
              final str = _decodeHexPdf(tm.group(2)!);
              lineBuffer.write(str);
            } else if (tm.group(3) != null) {
              final offset = double.tryParse(tm.group(3)!) ?? 0;
              if (offset < -120) {
                final cur = lineBuffer.toString();
                if (cur.isNotEmpty && !cur.endsWith(' ')) {
                  lineBuffer.write(' ');
                }
              }
            }
          }
          lineBuffer.write(' ');
        } else if (m.group(3) != null) {
          final t = _decodeHexPdf(m.group(3)!);
          if (t.isNotEmpty) lineBuffer.write('$t ');
        } else if (m.group(4) != null) {
          final line = lineBuffer.toString().trim();
          if (line.isNotEmpty) sb.writeln(line);
          lineBuffer.clear();
          final t = _unescapePdf(m.group(4)!);
          if (t.isNotEmpty) lineBuffer.write('$t ');
        } else if (m.group(5) != null) {
          final line = lineBuffer.toString().trim();
          if (line.isNotEmpty) sb.writeln(line);
          lineBuffer.clear();
          final t = _decodeHexPdf(m.group(5)!);
          if (t.isNotEmpty) lineBuffer.write('$t ');
        } else {
          final line = lineBuffer.toString().trim();
          if (line.isNotEmpty) {
            sb.writeln(line);
            lineBuffer.clear();
          }
        }
      }

      final remaining = lineBuffer.toString().trim();
      if (remaining.isNotEmpty) {
        sb.writeln(remaining);
      }
    }
  }

  String _decodeHexPdf(String hex) {
    final cleanHex = hex.replaceAll(RegExp(r'\s+'), '');
    if (cleanHex.isEmpty) return '';
    final bytes = <int>[];
    for (int i = 0; i < cleanHex.length; i += 2) {
      if (i + 1 < cleanHex.length) {
        final byte = int.tryParse(cleanHex.substring(i, i + 2), radix: 16);
        if (byte != null) bytes.add(byte);
      } else {
        final byte = int.tryParse('${cleanHex[i]}0', radix: 16);
        if (byte != null) bytes.add(byte);
      }
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      try {
        final codeUnits = <int>[];
        for (int i = 2; i < bytes.length; i += 2) {
          if (i + 1 < bytes.length) {
            codeUnits.add((bytes[i] << 8) | bytes[i + 1]);
          }
        }
        return String.fromCharCodes(codeUnits);
      } catch (_) {}
    }
    return String.fromCharCodes(bytes);
  }

  String _unescapePdf(String input) {
    var text = input.replaceAllMapped(RegExp(r'\\([0-7]{1,3})'), (m) {
      final code = int.tryParse(m.group(1)!, radix: 8);
      if (code != null && code > 0) {
        return String.fromCharCode(code);
      }
      return m.group(0)!;
    });

    return text
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\b', '')
        .replaceAll(r'\f', '')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', '\\');
  }

  String _extractPrintableStrings(List<int> bytes) {
    final len = bytes.length > 500000 ? 500000 : bytes.length;
    final buffer = StringBuffer();
    final currentWord = StringBuffer();

    for (int i = 0; i < len; i++) {
      final b = bytes[i];
      if ((b >= 32 && b <= 126) || b == 10 || b == 13 || b == 9) {
        currentWord.writeCharCode(b);
      } else {
        if (currentWord.length >= 4) {
          final s = currentWord.toString().trim();
          if (_isHumanReadable(s)) {
            buffer.writeln(s);
          }
        }
        currentWord.clear();
      }
    }
    if (currentWord.length >= 4) {
      final s = currentWord.toString().trim();
      if (_isHumanReadable(s)) {
        buffer.writeln(s);
      }
    }
    return buffer.toString().trim();
  }

  bool _isHumanReadable(String s) {
    if (s.startsWith('%PDF') || s.startsWith('<<') || s.endsWith('>>')) return false;
    if (RegExp(r'^\d+\s+\d+\s+obj').hasMatch(s)) return false;
    if (s == 'endobj' || s == 'endstream' || s.startsWith('xref') || s.startsWith('trailer')) return false;
    return RegExp(r'[a-zA-Z]{3,}').hasMatch(s);
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

  /// Fetch comprehensive YouTube video metadata, title, author, and full description
  Future<Map<String, String>?> fetchYouTubeMetadata(String url) async {
    final videoId = extractYouTubeId(url);
    String title = "";
    String author = "";
    String description = "";
    String thumbnail = "";

    // 1. Try scraping ytInitialPlayerResponse for full description and metadata
    if (videoId != null && videoId.isNotEmpty) {
      try {
        final watchUrl = Uri.parse("https://www.youtube.com/watch?v=$videoId");
        final res = await http.get(watchUrl, headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        }).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final body = res.body;
          final regex = RegExp(r'ytInitialPlayerResponse\s*=\s*({.+?});', dotAll: false);
          final match = regex.firstMatch(body);
          if (match != null) {
            final jsonStr = match.group(1)!;
            final data = jsonDecode(jsonStr);
            final videoDetails = data['videoDetails'];
            if (videoDetails != null) {
              title = videoDetails['title']?.toString() ?? "";
              author = videoDetails['author']?.toString() ?? "";
              description = videoDetails['shortDescription']?.toString() ?? "";
              final thumbs = videoDetails['thumbnail']?['thumbnails'] as List?;
              if (thumbs != null && thumbs.isNotEmpty) {
                thumbnail = thumbs.last['url']?.toString() ?? "";
              }
            }
          }
        }
      } catch (_) {}
    }

    // 2. Fallback to oEmbed if title or author missing
    if (title.isEmpty || author.isEmpty) {
      try {
        final oembedUrl = Uri.parse("https://www.youtube.com/oembed?url=${Uri.encodeComponent(url.trim())}&format=json");
        final response = await http.get(oembedUrl).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (title.isEmpty) title = data['title']?.toString() ?? '';
          if (author.isEmpty) author = data['author_name']?.toString() ?? '';
          if (thumbnail.isEmpty) thumbnail = data['thumbnail_url']?.toString() ?? '';
        }
      } catch (_) {}
    }

    if (title.isEmpty && videoId != null) {
      title = "YouTube Video: $videoId";
    }

    return {
      'title': title,
      'author': author,
      'description': description,
      'thumbnail': thumbnail,
      'videoId': videoId ?? '',
    };
  }

  /// Validate Instagram URL
  bool isValidInstagramUrl(String url) {
    final clean = url.trim().toLowerCase();
    return clean.contains("instagram.com/p/") || clean.contains("instagram.com/reel/") || clean.contains("instagram.com/tv/");
  }
}
