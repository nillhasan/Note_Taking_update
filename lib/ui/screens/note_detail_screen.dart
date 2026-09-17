import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../state/notes_provider.dart';
import '../../theme/app_theme.dart';
import '../components/action_item_row.dart';

class NoteDetailScreen extends StatefulWidget {
  final String noteId;

  const NoteDetailScreen({super.key, required this.noteId});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  NoteEntity? _note;
  List<ActionItemEntity> _actionItems = [];
  bool _isLoading = true;

  // Ask AI in-note grounded chat
  final TextEditingController _chatInputController = TextEditingController();
  final List<Map<String, String>> _chatMessages = [];
  bool _isChatLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadNoteData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatInputController.dispose();
    super.dispose();
  }

  Future<void> _loadNoteData() async {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final n = await notesProvider.dbHelper.getNoteById(widget.noteId);
    final items = await notesProvider.dbHelper.getActionItemsForNote(widget.noteId);
    if (mounted) {
      setState(() {
        _note = n;
        _actionItems = items;
        _isLoading = false;
      });
    }
  }

  String _formatDuration(int sec) {
    final mins = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return "$mins:$s";
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat("MMM d, yyyy • h:mm a").format(date);
  }

  // --- Editable AI Content Dialog (Requirement #28) ---
  void _editSection({
    required String sectionName,
    required String initialContent,
    required Function(String) onSave,
  }) {
    final controller = TextEditingController(text: initialContent);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Edit $sectionName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: "Edit content...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
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
              onSave(controller.text.trim());
            },
            child: const Text("Save Changes"),
          ),
        ],
      ),
    );
  }

  void _showAddActionItemDialog() {
    final taskController = TextEditingController();
    final ownerController = TextEditingController(text: "Unassigned");
    final dueController = TextEditingController(text: "Friday, 5:00 PM");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Add Action Item", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: taskController,
                decoration: const InputDecoration(labelText: "Task Description"),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ownerController,
                decoration: const InputDecoration(labelText: "Owner (e.g. Sarah)"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dueController,
                decoration: const InputDecoration(labelText: "Due Date / Time"),
              ),
            ],
          ),
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
              final task = taskController.text.trim();
              if (task.isNotEmpty && _note != null) {
                final notesProvider = Provider.of<NotesProvider>(context, listen: false);
                await notesProvider.addActionItem(
                  _note!.id,
                  task,
                  ownerController.text.trim(),
                  dueController.text.trim(),
                );
                await _loadNoteData();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text("Add Task"),
          ),
        ],
      ),
    );
  }

  // --- Email Composer (Requirements #37, #38) ---
  void _showEmailShareDialog() {
    if (_note == null) return;
    final toController = TextEditingController();
    final ccController = TextEditingController();
    final subjectController = TextEditingController(text: "Notes: ${_note!.title}");
    String formatType = "SUMMARY";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          String bodyPreview;
          if (formatType == "SUMMARY") {
            bodyPreview = "${_note!.summaryShort}\n\nGenerated by NoteFlow AI";
          } else if (formatType == "DETAILED") {
            bodyPreview = "${_note!.summaryDetailed}\n\nGenerated by NoteFlow AI";
          } else if (formatType == "MINUTES") {
            bodyPreview = "${_note!.meetingMinutes}\n\nDecisions:\n${_note!.decisions.map((d) => '• $d').join('\n')}\n\nGenerated by NoteFlow AI";
          } else if (formatType == "TASKS") {
            final tasks = _actionItems.map((a) => "• ${a.task} [${a.owner}] (Due: ${a.dueDate})").join("\n");
            bodyPreview = "Action Items for ${_note!.title}:\n\n$tasks\n\nGenerated by NoteFlow AI";
          } else {
            bodyPreview = "Full Transcript:\n\n${_note!.transcriptText}\n\nGenerated by NoteFlow AI";
          }

          final bodyController = TextEditingController(text: bodyPreview);

          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Email Note", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: toController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: "To (e.g. colleague@company.com)"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ccController,
                      decoration: const InputDecoration(labelText: "CC (optional)"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(labelText: "Subject"),
                    ),
                    const SizedBox(height: 12),
                    const Text("Content Format:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text("Summary", style: TextStyle(fontSize: 11)),
                            selected: formatType == "SUMMARY",
                            onSelected: (_) => setModalState(() => formatType = "SUMMARY"),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text("Detailed", style: TextStyle(fontSize: 11)),
                            selected: formatType == "DETAILED",
                            onSelected: (_) => setModalState(() => formatType = "DETAILED"),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text("Minutes", style: TextStyle(fontSize: 11)),
                            selected: formatType == "MINUTES",
                            onSelected: (_) => setModalState(() => formatType = "MINUTES"),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text("Actions", style: TextStyle(fontSize: 11)),
                            selected: formatType == "TASKS",
                            onSelected: (_) => setModalState(() => formatType = "TASKS"),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text("Full Transcript", style: TextStyle(fontSize: 11)),
                            selected: formatType == "TRANSCRIPT",
                            onSelected: (_) => setModalState(() => formatType = "TRANSCRIPT"),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyController,
                      maxLines: 6,
                      decoration: const InputDecoration(labelText: "Body (editable)"),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text("Copy"),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: bodyController.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Draft copied to clipboard!"), backgroundColor: AppColors.accentDark),
                  );
                  Navigator.pop(ctx);
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.send, size: 16, color: Colors.white),
                label: const Text("Send"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final to = toController.text.trim();
                  final sub = subjectController.text.trim();
                  final body = bodyController.text;
                  final uri = Uri(
                    scheme: 'mailto',
                    path: to,
                    query: 'subject=${Uri.encodeComponent(sub)}&body=${Uri.encodeComponent(body)}',
                  );

                  final notesProvider = Provider.of<NotesProvider>(context, listen: false);
                  await notesProvider.recordEmailSent(_note!.id, to, sub, formatType);

                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    Clipboard.setData(ClipboardData(text: body));
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Email client unavailable. Draft copied to clipboard!"), backgroundColor: AppColors.accentDark),
                      );
                    }
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _sendAiQuestion(String query) async {
    if (query.trim().isEmpty || _note == null) return;
    _chatInputController.clear();

    setState(() {
      _chatMessages.add({"role": "user", "text": query.trim()});
      _isChatLoading = true;
    });

    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final contextText = """
Note Title: ${_note!.title}
Type: ${_note!.type}
Transcript:
${_note!.transcriptText}

Short Summary:
${_note!.summaryShort}

Minutes:
${_note!.meetingMinutes}

Decisions:
${_note!.decisions.join(', ')}

Action Items:
${_actionItems.map((a) => '${a.task} (${a.owner}, due: ${a.dueDate})').join(', ')}
""".trim();

    String reply;
    try {
      reply = await notesProvider.askAi(contextText, query);
    } catch (e) {
      reply = e.toString().replaceFirst("Exception: ", "");
    }

    if (mounted) {
      setState(() {
        _chatMessages.add({"role": "ai", "text": reply});
        _isChatLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesProvider = Provider.of<NotesProvider>(context);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accentDark)),
      );
    }

    if (_note == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text("Note Detail")),
        body: const Center(child: Text("Note not found")),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _note!.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _note!.isFavorite ? Icons.star : Icons.star_border,
              color: _note!.isFavorite ? AppColors.warningAmber : AppColors.textPrimary,
            ),
            onPressed: () async {
              await notesProvider.toggleFavorite(_note!);
              await _loadNoteData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.textPrimary),
            onPressed: _showEmailShareDialog,
            tooltip: "Share / Email",
          ),
          PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'regenerate') {
                await notesProvider.regenerateSummary(_note!);
                await _loadNoteData();
                if (context.mounted) {
                  if (notesProvider.lastAiError != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(notesProvider.lastAiError!),
                        backgroundColor: AppColors.recordingRed,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Summary regenerated successfully."),
                        backgroundColor: AppColors.accentDark,
                      ),
                    );
                  }
                }
              } else if (val == 'archive') {
                await notesProvider.toggleArchive(_note!);
                if (context.mounted) Navigator.pop(context);
              } else if (val == 'delete') {
                await notesProvider.moveToTrash(_note!);
                if (context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'regenerate',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text("Regenerate Summary"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'archive',
                child: Text(_note!.isArchived ? "Unarchive" : "Archive Note"),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text("Move to Trash", style: TextStyle(color: AppColors.recordingRed)),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Metadata Bar (Date • Duration)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.graphic_eq, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    "${_formatDate(_note!.createdAt)} · ${_formatDuration(_note!.durationSec)}",
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            // Audio Playback Bar if audio path exists
            if (_note!.audioPath != null && _note!.audioPath!.isNotEmpty)
              StreamBuilder<bool>(
                stream: notesProvider.audioPlayer.playingStream,
                initialData: notesProvider.audioPlayer.isPlaying,
                builder: (context, playingSnap) {
                  final isPlaying = playingSnap.data ?? false;
                  return StreamBuilder<int>(
                    stream: notesProvider.audioPlayer.positionStream,
                    initialData: notesProvider.audioPlayer.currentPositionMs,
                    builder: (context, posSnap) {
                      final currentMs = posSnap.data ?? 0;
                      final totalMs = _note!.durationSec > 0 ? _note!.durationSec * 1000 : 15000;
                      final progress = (currentMs / (totalMs > 0 ? totalMs : 1)).clamp(0.0, 1.0);

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                if (isPlaying) {
                                  notesProvider.audioPlayer.pauseAudio();
                                } else {
                                  notesProvider.audioPlayer.playAudio(
                                    _note!.audioPath,
                                    fallbackDurationSec: _note!.durationSec,
                                  );
                                }
                              },
                              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 22, color: AppColors.accentDark),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: AppColors.surfaceVariant,
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentDark),
                                    borderRadius: BorderRadius.circular(4),
                                    minHeight: 5,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(currentMs ~/ 1000),
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                      Text(
                                        _formatDuration(_note!.durationSec),
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

            // Tabs: Summary | Minutes | Actions | Transcript
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.accentDark,
              indicatorWeight: 2,
              tabs: [
                const Tab(text: "Summary"),
                const Tab(text: "Minutes"),
                Tab(text: "Actions (${_actionItems.length})"),
                const Tab(text: "Transcript"),
              ],
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Summary
                  _buildSummaryTab(notesProvider),

                  // Tab 2: Minutes
                  _buildMinutesTab(notesProvider),

                  // Tab 3: Actions
                  _buildActionsTab(notesProvider),

                  // Tab 4: Transcript
                  _buildTranscriptTab(notesProvider),
                ],
              ),
            ),

            // Grounded Ask AI Bottom Bar (Requirement #29)
            _buildAskAiBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTab(NotesProvider notesProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Executive Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Executive Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                          onPressed: () {
                            _editSection(
                              sectionName: "Summary",
                              initialContent: _note!.summaryShort,
                              onSave: (val) async {
                                final updated = _note!.copyWith(summaryShort: val);
                                await notesProvider.updateNote(updated);
                                await _loadNoteData();
                              },
                            );
                          },
                          tooltip: "Edit",
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.textSecondary),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _note!.summaryShort));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Summary copied!"), backgroundColor: AppColors.accentDark),
                            );
                          },
                          tooltip: "Copy",
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _note!.summaryShort.isNotEmpty ? _note!.summaryShort : "No summary available. Tap Regenerate to synthesize.",
                  style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Key Points
          if (_note!.summaryBullets.isNotEmpty) ...[
            const Text("Key Points", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ..._note!.summaryBullets.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("• ", style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                      Expanded(child: Text(b, style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textPrimary))),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
          ],

          // Decisions
          if (_note!.decisions.isNotEmpty) ...[
            const Text("Decisions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ..._note!.decisions.map((d) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppColors.successGreen, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(d, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary))),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildMinutesTab(NotesProvider notesProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Meeting Minutes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                      onPressed: () {
                        _editSection(
                          sectionName: "Meeting Minutes",
                          initialContent: _note!.meetingMinutes,
                          onSave: (val) async {
                            final updated = _note!.copyWith(meetingMinutes: val);
                            await notesProvider.updateNote(updated);
                            await _loadNoteData();
                          },
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.textSecondary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _note!.meetingMinutes));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Minutes copied!"), backgroundColor: AppColors.accentDark),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _note!.meetingMinutes.isNotEmpty ? _note!.meetingMinutes : "No minutes synthesized for this note.",
              style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsTab(NotesProvider notesProvider) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.small(
        onPressed: _showAddActionItemDialog,
        backgroundColor: AppColors.accentDark,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _actionItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.checklist, size: 40, color: AppColors.textMuted),
                  const SizedBox(height: 8),
                  const Text("No action items yet", style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _showAddActionItemDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text("Add Task"),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.textPrimary),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _actionItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final item = _actionItems[i];
                return ActionItemRow(
                  item: item,
                  onToggleCompleted: () async {
                    await notesProvider.toggleActionItem(item);
                    await _loadNoteData();
                  },
                  onDelete: () async {
                    await notesProvider.deleteActionItem(item.id);
                    await _loadNoteData();
                  },
                );
              },
            ),
    );
  }

  Widget _buildTranscriptTab(NotesProvider notesProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Full Transcript", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                      onPressed: () {
                        _editSection(
                          sectionName: "Transcript",
                          initialContent: _note!.transcriptText,
                          onSave: (val) async {
                            final updated = _note!.copyWith(transcriptText: val);
                            await notesProvider.updateNote(updated);
                            await _loadNoteData();
                          },
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.textSecondary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _note!.transcriptText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Transcript copied!"), backgroundColor: AppColors.accentDark),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _note!.transcriptText.isNotEmpty ? _note!.transcriptText : "No transcript recorded for this note.",
              style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  // --- Grounded Ask AI Bar (Requirement #29) ---
  Widget _buildAskAiBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Suggested Questions Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSuggestChip("What are the key points?"),
                const SizedBox(width: 6),
                _buildSuggestChip("What decisions were made?"),
                const SizedBox(width: 6),
                _buildSuggestChip("What are the action items?"),
                const SizedBox(width: 6),
                _buildSuggestChip("What should I do next?"),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Message history bubble if any
          if (_chatMessages.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _chatMessages.length,
                itemBuilder: (ctx, i) {
                  final msg = _chatMessages[i];
                  final isUser = msg["role"] == "user";
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isUser ? AppColors.accentDark : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        msg["text"] ?? "",
                        style: TextStyle(
                          fontSize: 13,
                          color: isUser ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          if (_isChatLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentDark)),
                  SizedBox(width: 8),
                  Text("Grounding answer in note...", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),

          // Input field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatInputController,
                  decoration: InputDecoration(
                    hintText: "Ask about this note...",
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onSubmitted: (val) => _sendAiQuestion(val),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: AppColors.accentDark, size: 20),
                onPressed: () => _sendAiQuestion(_chatInputController.text),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestChip(String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      backgroundColor: AppColors.surfaceVariant,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      visualDensity: VisualDensity.compact,
      onPressed: () => _sendAiQuestion(label),
    );
  }
}
