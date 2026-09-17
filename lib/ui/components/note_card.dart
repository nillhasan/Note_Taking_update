import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class NoteCard extends StatelessWidget {
  final NoteEntity note;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleArchive;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onToggleArchive,
    required this.onDelete,
    required this.onShare,
  });

  String _formatDuration(int sec) {
    if (sec <= 0) return "1 min";
    final mins = sec ~/ 60;
    return mins > 0 ? "$mins min" : "< 1 min";
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat("MMM d, yyyy").format(date);
  }

  String _getPreviewSnippet() {
    if (note.summaryShort.isNotEmpty) {
      return note.summaryShort;
    }
    if (note.transcriptText.isNotEmpty) {
      return note.transcriptText;
    }
    if (note.summaryDetailed.isNotEmpty) {
      return note.summaryDetailed;
    }
    return "Voice recording and automated transcript...";
  }

  @override
  Widget build(BuildContext context) {
    final durationStr = _formatDuration(note.durationSec);
    final dateStr = _formatDate(note.createdAt);
    final preview = _getPreviewSnippet();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Title + 3-Dot More Menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_horiz,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) {
                        switch (val) {
                          case 'favorite':
                            onToggleFavorite();
                            break;
                          case 'share':
                            onShare();
                            break;
                          case 'archive':
                            onToggleArchive();
                            break;
                          case 'delete':
                            onDelete();
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'favorite',
                          child: Row(
                            children: [
                              Icon(
                                note.isFavorite ? Icons.star : Icons.star_border,
                                size: 18,
                                color: note.isFavorite ? AppColors.warningAmber : AppColors.textPrimary,
                              ),
                              const SizedBox(width: 10),
                              Text(note.isFavorite ? "Unfavorite" : "Favorite"),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'share',
                          child: const Row(
                            children: [
                              Icon(Icons.share_outlined, size: 18, color: AppColors.textPrimary),
                              SizedBox(width: 10),
                              Text("Share"),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(
                                note.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                                size: 18,
                                color: AppColors.textPrimary,
                              ),
                              const SizedBox(width: 10),
                              Text(note.isArchived ? "Unarchive" : "Archive"),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: const Row(
                            children: [
                              Icon(Icons.delete_outline, size: 18, color: AppColors.recordingRed),
                              SizedBox(width: 10),
                              Text("Delete", style: TextStyle(color: AppColors.recordingRed)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Subtitle Row: Audio Wave Icon + Date · Duration
                Row(
                  children: [
                    const Icon(
                      Icons.graphic_eq,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "$dateStr · $durationStr",
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Short content preview (1-2 lines)
                Text(
                  preview,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
