import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/import_service.dart';
import '../../state/notes_provider.dart';
import '../../theme/app_theme.dart';
import 'note_detail_screen.dart';

enum ImportAction { audio, video, youtube, instagram, pdfWord, textNote }

class ImportBottomSheet extends StatelessWidget {
  const ImportBottomSheet({super.key});

  static Future<void> show(BuildContext parentContext) async {
    final action = await showModalBottomSheet<ImportAction>(
      context: parentContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ImportBottomSheet(),
    );

    if (action == null || !parentContext.mounted) return;

    switch (action) {
      case ImportAction.audio:
        _handleAudio(parentContext);
        break;
      case ImportAction.video:
        _handleVideo(parentContext);
        break;
      case ImportAction.youtube:
        _handleYouTube(parentContext);
        break;
      case ImportAction.instagram:
        _handleInstagram(parentContext);
        break;
      case ImportAction.pdfWord:
        _handlePdfWord(parentContext);
        break;
      case ImportAction.textNote:
        _handleTextNote(parentContext);
        break;
    }
  }

  static void _handleAudio(BuildContext context) async {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final res = await ImportService.instance.pickAudioFile();

    if (!res.success) {
      if (res.errorMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.errorMessage!), backgroundColor: AppColors.recordingRed),
        );
      }
      return;
    }

    if (context.mounted) {
      _processImportedAudio(context, notesProvider, res.filePath!, res.title ?? "Audio Note");
    }
  }

  static void _handleVideo(BuildContext context) async {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final res = await ImportService.instance.pickVideoFile();

    if (!res.success) {
      if (res.errorMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.errorMessage!), backgroundColor: AppColors.recordingRed),
        );
      }
      return;
    }

    if (context.mounted) {
      _processImportedAudio(context, notesProvider, res.filePath!, res.title ?? "Video Note");
    }
  }

  static void _handleYouTube(BuildContext context) {
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Import YouTube Video", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Paste a public YouTube video link to extract and summarize:",
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                hintText: "https://www.youtube.com/watch?v=...",
                prefixIcon: Icon(Icons.link, size: 20),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isEmpty) return;

              if (!ImportService.instance.isValidYouTubeUrl(url)) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid YouTube URL."), backgroundColor: AppColors.recordingRed),
                );
                return;
              }

              Navigator.pop(ctx);
              final videoId = ImportService.instance.extractYouTubeId(url) ?? "Video";
              final notesProvider = Provider.of<NotesProvider>(context, listen: false);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Fetching YouTube metadata and generating AI summary..."),
                    backgroundColor: AppColors.accentDark,
                    duration: Duration(seconds: 3),
                  ),
                );
              }

              final meta = await ImportService.instance.fetchYouTubeMetadata(url);
              final videoTitle = (meta != null && meta['title']!.isNotEmpty)
                  ? meta['title']!
                  : "YouTube: $videoId";
              final author = meta?['author'] ?? "";
              final description = meta?['description'] ?? "";

              final note = await notesProvider.createYouTubeNote(
                title: videoTitle,
                author: author,
                description: description,
                url: url,
              );

              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => NoteDetailScreen(noteId: note.id)),
                );
              }
            },
            child: const Text("Import"),
          ),
        ],
      ),
    );
  }

  static void _handleInstagram(BuildContext context) {
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Import Instagram Content", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Paste an Instagram Reel or post URL:",
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                hintText: "https://www.instagram.com/reel/...",
                prefixIcon: Icon(Icons.link, size: 20),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isEmpty) return;

              if (!ImportService.instance.isValidInstagramUrl(url)) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text("Please enter a valid Instagram post or reel link."),
                    backgroundColor: AppColors.recordingRed,
                  ),
                );
                return;
              }

              Navigator.pop(ctx);
              final notesProvider = Provider.of<NotesProvider>(context, listen: false);

              // Extract identifier from URL
              final segments = url.split('/').where((s) => s.isNotEmpty).toList();
              final postCode = segments.isNotEmpty ? segments.last : "Post";

              // Create bookmark note
              final note = await notesProvider.createTextNote(
                "Instagram Bookmark ($postCode)",
                "Source: $url\n\nInstagram content link saved. Note: Direct Instagram audio extraction is restricted by Instagram. Upload the media file directly for automatic voice-to-text transcript.",
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Instagram link saved as a note! Upload audio or video directly for full transcription.",
                    ),
                    duration: Duration(seconds: 4),
                    backgroundColor: AppColors.accentDark,
                  ),
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => NoteDetailScreen(noteId: note.id)),
                );
              }
            },
            child: const Text("Save Bookmark"),
          ),
        ],
      ),
    );
  }

  static void _handlePdfWord(BuildContext context) async {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final res = await ImportService.instance.pickDocumentFile();

    if (!res.success) {
      if (res.errorMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.errorMessage!), backgroundColor: AppColors.recordingRed),
        );
      }
      return;
    }

    if (context.mounted && res.textContent != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Document text extracted. Analyzing with AI..."),
          backgroundColor: AppColors.accentDark,
          duration: Duration(seconds: 3),
        ),
      );

      final note = await notesProvider.createTextNote(
        res.title ?? "Document Notes",
        res.textContent!,
      );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NoteDetailScreen(noteId: note.id)),
        );
      }
    }
  }

  static void _handleTextNote(BuildContext context) {
    final titleController = TextEditingController(text: "New Note");
    final contentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Create Text Note", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Note Title"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: "Content",
                hintText: "Write or paste notes here...",
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final title = titleController.text.trim();
                  final content = contentController.text.trim();
                  if (title.isNotEmpty && content.isNotEmpty) {
                    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
                    Navigator.pop(ctx);
                    final note = await notesProvider.createTextNote(title, content);
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => NoteDetailScreen(noteId: note.id)),
                      );
                    }
                  }
                },
                child: const Text("Save & Summarize with AI", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _processImportedAudio(BuildContext context, NotesProvider notesProvider, String filePath, String title) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Processing audio file with AI..."), backgroundColor: AppColors.accentDark),
    );

    final note = await notesProvider.processFinishedAudio(
      filePath: filePath,
      customTitle: title,
      isMeeting: false,
    );

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NoteDetailScreen(noteId: note.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 1. Audio
          _buildOptionTile(
            icon: Icons.graphic_eq,
            title: "Audio",
            onTap: () => Navigator.pop(context, ImportAction.audio),
          ),

          // 2. Video
          _buildOptionTile(
            icon: Icons.videocam_outlined,
            title: "Video",
            onTap: () => Navigator.pop(context, ImportAction.video),
          ),

          // 3. YouTube
          _buildOptionTile(
            icon: Icons.smart_display_outlined,
            title: "YouTube",
            onTap: () => Navigator.pop(context, ImportAction.youtube),
          ),

          // 4. Instagram
          _buildOptionTile(
            icon: Icons.camera_alt_outlined,
            title: "Instagram",
            onTap: () => Navigator.pop(context, ImportAction.instagram),
          ),

          // 5. PDF, Word
          _buildOptionTile(
            icon: Icons.description_outlined,
            title: "PDF, Word",
            onTap: () => Navigator.pop(context, ImportAction.pdfWord),
          ),

          // 6. Text Note
          _buildOptionTile(
            icon: Icons.text_fields,
            title: "Text Note",
            onTap: () => Navigator.pop(context, ImportAction.textNote),
            showDivider: false,
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool showDivider = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 24, color: AppColors.iconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
