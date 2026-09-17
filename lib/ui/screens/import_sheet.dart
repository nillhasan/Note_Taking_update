import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/import_service.dart';
import '../../state/notes_provider.dart';
import '../../theme/app_theme.dart';
import 'note_detail_screen.dart';

class ImportBottomSheet extends StatelessWidget {
  const ImportBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ImportBottomSheet(),
    );
  }

  void _handleAudio(BuildContext context) async {
    Navigator.pop(context);
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

  void _handleVideo(BuildContext context) async {
    Navigator.pop(context);
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

  void _handleYouTube(BuildContext context) {
    Navigator.pop(context);
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

              // Create YouTube note with metadata
              final note = await notesProvider.createTextNote(
                "YouTube: $videoId",
                "Source: $url\n\nYouTube link captured for automated analysis and transcription. Ensure video has public captions or provide direct audio/video upload for full synthesis.",
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

  void _handleInstagram(BuildContext context) {
    Navigator.pop(context);
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
            onPressed: () {
              Navigator.pop(ctx);
              // Per requirement #13:
              // "Instagram content could not be imported. Please upload the audio, video or transcript directly."
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Instagram content could not be imported. Please upload the audio, video or transcript directly.",
                  ),
                  duration: Duration(seconds: 4),
                  backgroundColor: AppColors.accentDark,
                ),
              );
            },
            child: const Text("Import"),
          ),
        ],
      ),
    );
  }

  void _handlePdfWord(BuildContext context) async {
    Navigator.pop(context);
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
        const SnackBar(content: Text("Document text extracted. Analyzing with AI..."), backgroundColor: AppColors.accentDark),
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

  void _handleTextNote(BuildContext context) {
    Navigator.pop(context);
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

  void _processImportedAudio(BuildContext context, NotesProvider notesProvider, String filePath, String title) async {
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
            onTap: () => _handleAudio(context),
          ),

          // 2. Video
          _buildOptionTile(
            icon: Icons.videocam_outlined,
            title: "Video",
            onTap: () => _handleVideo(context),
          ),

          // 3. YouTube
          _buildOptionTile(
            icon: Icons.smart_display_outlined,
            title: "YouTube",
            onTap: () => _handleYouTube(context),
          ),

          // 4. Instagram
          _buildOptionTile(
            icon: Icons.camera_alt_outlined,
            title: "Instagram",
            onTap: () => _handleInstagram(context),
          ),

          // 5. PDF, Word
          _buildOptionTile(
            icon: Icons.description_outlined,
            title: "PDF, Word",
            onTap: () => _handlePdfWord(context),
          ),

          // 6. Text Note
          _buildOptionTile(
            icon: Icons.text_fields,
            title: "Text Note",
            onTap: () => _handleTextNote(context),
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
