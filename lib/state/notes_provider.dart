import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../data/local/database_helper.dart';
import '../data/local/preferences_service.dart';
import '../services/ai/ai_service.dart';
import '../services/audio_manager.dart';
import '../services/cloud_sync_service.dart';
import '../services/gemini_service.dart';
import '../services/stripe_payment_manager.dart';

class NotesProvider with ChangeNotifier {
  final AudioPlayerManager audioPlayer = AudioPlayerManager();
  final StripePaymentManager stripePaymentManager = StripePaymentManager.instance;
  final CloudSyncService cloudSync = CloudSyncService.instance;
  final GeminiService geminiService = GeminiService.instance;
  final AiService aiService = AiService.instance;
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

  String _userId = "guest_user";
  String get userId => _userId;

  List<NoteEntity> _allNotes = [];
  List<ActionItemEntity> _allActionItems = [];
  List<FolderEntity> _folders = [];

  String _searchQuery = "";
  String get searchQuery => _searchQuery;

  String _selectedFilter = "All"; // All, Meetings, Voice, Favorites, Tasks, Archived, Trash
  String get selectedFilter => _selectedFilter;

  String? _selectedFolder;
  String? get selectedFolder => _selectedFolder;

  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  SubscriptionTier _subscriptionTier = SubscriptionTier.EXECUTIVE_PRO;
  SubscriptionTier get subscriptionTier => _subscriptionTier;

  bool _isAnnualBilling = true;
  bool get isAnnualBilling => _isAnnualBilling;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  String _processingStatusText = "Analyzing note with Gemini AI...";
  String get processingStatusText => _processingStatusText;

  String? _lastAiError;
  String? get lastAiError => _lastAiError;

  void clearAiError() {
    _lastAiError = null;
    notifyListeners();
  }

  bool _isStripeProcessing = false;
  bool get isStripeProcessing => _isStripeProcessing;

  String? _selectedNoteId;
  String? get selectedNoteId => _selectedNoteId;

  NoteEntity? _currentNote;
  NoteEntity? get currentNote => _currentNote;

  List<ActionItemEntity> _currentNoteActionItems = [];
  List<ActionItemEntity> get currentNoteActionItems => _currentNoteActionItems;

  NotesProvider() {
    _initSettings();
  }

  Future<void> _initSettings() async {
    _isDarkMode = await PreferencesService.instance.isDarkMode();
    _isAnnualBilling = await PreferencesService.instance.isAnnualBilling();
    notifyListeners();
  }

  void updateUserId(String newUserId) {
    if (_userId != newUserId) {
      _userId = newUserId;
      cloudSync.startListeningForUser(newUserId);
      dbHelper.initDefaultFoldersAndNotes(newUserId).then((_) {
        refreshNotes();
      });
    }
  }

  Future<void> refreshNotes() async {
    _allNotes = await dbHelper.getActiveNotes(_userId);
    _allActionItems = await dbHelper.getAllActionItems(_userId);
    _folders = await dbHelper.getFoldersForUser(_userId);

    if (_selectedNoteId != null) {
      _currentNote = await dbHelper.getNoteById(_selectedNoteId!);
      _currentNoteActionItems = await dbHelper.getActionItemsForNote(_selectedNoteId!);
    }

    notifyListeners();
  }

  List<NoteEntity> get filteredNotes {
    List<NoteEntity> list = _allNotes;

    // Apply primary filter
    if (_selectedFilter == "Favorites") {
      list = list.where((n) => n.isFavorite && !n.isDeleted && !n.isArchived).toList();
    } else if (_selectedFilter == "Archived") {
      // Archived
    } else if (_selectedFilter == "Trash") {
      // Trash
    } else if (_selectedFilter == "Meetings") {
      list = list.where((n) => n.type == "MEETING").toList();
    } else if (_selectedFilter == "Voice") {
      list = list.where((n) => n.type == "VOICE").toList();
    }

    // Apply folder filter
    if (_selectedFolder != null && _selectedFolder != "All") {
      list = list.where((n) => n.folder.toLowerCase() == _selectedFolder!.toLowerCase()).toList();
    }

    // Apply search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((n) {
        return n.title.toLowerCase().contains(q) ||
            n.transcriptText.toLowerCase().contains(q) ||
            n.summaryShort.toLowerCase().contains(q) ||
            n.summaryDetailed.toLowerCase().contains(q) ||
            n.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    return list;
  }

  List<ActionItemEntity> get allActionItems => _allActionItems;
  List<FolderEntity> get folders => _folders;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void setFolder(String? folder) {
    _selectedFolder = folder;
    notifyListeners();
  }

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    PreferencesService.instance.setDarkMode(_isDarkMode);
    notifyListeners();
  }

  void toggleBillingCycle() {
    _isAnnualBilling = !_isAnnualBilling;
    PreferencesService.instance.setAnnualBilling(_isAnnualBilling);
    notifyListeners();
  }

  void selectNote(String? noteId) async {
    _selectedNoteId = noteId;
    audioPlayer.stopAudio();
    if (noteId != null) {
      _currentNote = await dbHelper.getNoteById(noteId);
      _currentNoteActionItems = await dbHelper.getActionItemsForNote(noteId);
    } else {
      _currentNote = null;
      _currentNoteActionItems = [];
    }
    notifyListeners();
  }

  Future<void> toggleFavorite(NoteEntity note) async {
    final updated = note.copyWith(
      isFavorite: !note.isFavorite,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await dbHelper.insertOrUpdateNote(updated);
    await cloudSync.pushNote(updated);
    await refreshNotes();
  }

  Future<void> toggleArchive(NoteEntity note) async {
    final updated = note.copyWith(
      isArchived: !note.isArchived,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await dbHelper.insertOrUpdateNote(updated);
    await cloudSync.pushNote(updated);
    await refreshNotes();
  }

  Future<void> moveToTrash(NoteEntity note) async {
    final updated = note.copyWith(
      isDeleted: true,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await dbHelper.insertOrUpdateNote(updated);
    await cloudSync.pushNote(updated);
    await refreshNotes();
  }

  Future<void> restoreFromTrash(NoteEntity note) async {
    final updated = note.copyWith(
      isDeleted: false,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await dbHelper.insertOrUpdateNote(updated);
    await cloudSync.pushNote(updated);
    await refreshNotes();
  }

  Future<void> permanentlyDelete(NoteEntity note) async {
    await dbHelper.hardDeleteNote(note.id);
    await cloudSync.deleteNoteFromCloud(note.userId, note.id);
    if (_selectedNoteId == note.id) {
      _selectedNoteId = null;
      _currentNote = null;
    }
    await refreshNotes();
  }

  Future<void> toggleActionItem(ActionItemEntity item) async {
    final updated = item.copyWith(
      isCompleted: !item.isCompleted,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await dbHelper.insertOrUpdateActionItem(updated);
    await cloudSync.pushActionItem(updated);
    await refreshNotes();
  }

  Future<void> addActionItem(String noteId, String task, String owner, String dueDate) async {
    final item = ActionItemEntity(
      id: const Uuid().v4(),
      noteId: noteId,
      userId: _userId,
      task: task,
      owner: owner.trim().isNotEmpty ? owner.trim() : "Unassigned",
      dueDate: dueDate.trim(),
    );
    await dbHelper.insertOrUpdateActionItem(item);
    await cloudSync.pushActionItem(item);
    await refreshNotes();
  }

  Future<void> deleteActionItem(String id) async {
    await dbHelper.deleteActionItem(id);
    await refreshNotes();
  }

  Future<void> createFolder(String name, {String colorHex = "#2563EB"}) async {
    final folder = FolderEntity(
      id: const Uuid().v4(),
      userId: _userId,
      name: name,
      colorHex: colorHex,
    );
    await dbHelper.insertFolder(folder);
    await refreshNotes();
  }

  Future<void> recordEmailSent(String noteId, String recipients, String subject, String contentType) async {
    final record = EmailActivityRecord(
      id: const Uuid().v4(),
      noteId: noteId,
      userId: _userId,
      recipients: recipients,
      contentType: contentType,
      subject: subject,
    );
    await dbHelper.insertEmailActivity(record);
  }

  Future<String> askAi(String noteContext, String question) async {
    return await aiService.askAboutNote(noteContext, question);
  }

  Future<String> generateFollowUpEmail(String title, String summary, String items) async {
    return await aiService.generateFollowUpEmail(title, summary, items);
  }

  Future<void> updateNote(NoteEntity note) async {
    final updated = note.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch);
    await dbHelper.insertOrUpdateNote(updated);
    await cloudSync.pushNote(updated);
    if (_selectedNoteId == note.id) {
      _currentNote = updated;
    }
    await refreshNotes();
  }

  Future<void> regenerateSummary(NoteEntity note) async {
    _isProcessing = true;
    _processingStatusText = "Analyzing note with AI...";
    _lastAiError = null;
    notifyListeners();

    try {
      final textToAnalyze = note.transcriptText.isNotEmpty ? note.transcriptText : note.summaryDetailed;
      final analysis = await aiService.analyzeContent(textToAnalyze, note.title);

      final updated = note.copyWith(
        summaryShort: analysis.summaryShort,
        summaryDetailed: analysis.summaryDetailed,
        summaryBullets: analysis.summaryBullets,
        meetingMinutes: analysis.meetingMinutes,
        decisions: analysis.decisions,
        risks: analysis.risks,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await dbHelper.insertOrUpdateNote(updated);
      await cloudSync.pushNote(updated);
      if (_selectedNoteId == note.id) {
        _currentNote = updated;
      }
      _lastAiError = null;
      await refreshNotes();
    } catch (e) {
      _lastAiError = e.toString().replaceFirst("Exception: ", "");
    }

    _isProcessing = false;
    notifyListeners();
  }

  Future<NoteEntity> processFinishedAudio({
    File? file,
    String? filePath,
    int durationSec = 0,
    bool isMeeting = false,
    String? customTitle,
    String? targetFolder,
    String? userTranscript,
  }) async {
    _isProcessing = true;
    _processingStatusText = "Transcribing voice input...";
    _lastAiError = null;
    notifyListeners();

    if (file == null && filePath != null && filePath.isNotEmpty) {
      file = File(filePath);
    }

    String cleanTranscript = userTranscript?.trim() ?? "";

    // If user transcript is empty and we have an audio file, perform real transcription!
    if (cleanTranscript.isEmpty && file != null && file.existsSync()) {
      _processingStatusText = "Transcribing audio with AI...";
      notifyListeners();

      try {
        final aiTranscript = await aiService.transcribeAudio(file);
        if (aiTranscript != null && aiTranscript.trim().isNotEmpty) {
          cleanTranscript = aiTranscript.trim();
        }
      } catch (e) {
        _lastAiError = e.toString().replaceFirst("Exception: ", "");
      }
    }

    final defaultTitle = isMeeting
        ? "Meeting Discussion (${_formatDuration(durationSec > 0 ? durationSec : 30)})"
        : "Voice Note (${_formatDuration(durationSec > 0 ? durationSec : 15)})";
    final finalTitle = customTitle?.trim().isNotEmpty == true ? customTitle!.trim() : defaultTitle;
    final type = isMeeting ? "MEETING" : "VOICE";
    final folder = targetFolder?.trim().isNotEmpty == true ? targetFolder!.trim() : (isMeeting ? "Meetings" : "All");

    _processingStatusText = "Generating summary and extracting action items...";
    notifyListeners();

    NoteAiAnalysis? analysis;
    try {
      final textForAnalysis = cleanTranscript.isNotEmpty ? cleanTranscript : finalTitle;
      analysis = await aiService.analyzeContent(textForAnalysis, finalTitle);
      _lastAiError = null;
    } catch (e) {
      _lastAiError = e.toString().replaceFirst("Exception: ", "");
    }

    // Segment transcripts
    final rawLines = cleanTranscript.isNotEmpty
        ? cleanTranscript.split(RegExp(r'(?<=[.!?\n])\s+')).where((l) => l.trim().isNotEmpty).toList()
        : <String>[];
    final segments = <TranscriptSegment>[];
    final totalSegs = rawLines.isNotEmpty ? rawLines.length : 1;
    final stepSec = durationSec > 0 ? (durationSec ~/ totalSegs).clamp(1, 60) : 10;

    for (int i = 0; i < rawLines.length; i++) {
      final lineSec = i * stepSec;
      final mins = lineSec ~/ 60;
      final secs = lineSec % 60;
      final timeStr = "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
      final line = rawLines[i];

      String speaker = "Speaker 1";
      String text = line;
      if (line.contains(":") && line.indexOf(":") < 25) {
        speaker = line.split(":").first.trim();
        text = line.split(":").last.trim();
      } else if (isMeeting) {
        speaker = i % 2 == 0 ? "Speaker 1" : "Speaker 2";
      }

      segments.add(TranscriptSegment(speaker: speaker, timestamp: timeStr, text: text));
    }

    if (segments.isEmpty) {
      segments.add(TranscriptSegment(
        speaker: "Speaker 1",
        timestamp: "00:00",
        text: cleanTranscript.isNotEmpty ? cleanTranscript : "Audio note recorded (${_formatDuration(durationSec)})",
      ));
    }

    const uuid = Uuid();
    final noteId = uuid.v4();
    final newNote = NoteEntity(
      id: noteId,
      userId: _userId,
      title: finalTitle,
      type: type,
      audioPath: file?.path,
      durationSec: durationSec,
      status: "COMPLETED",
      folder: folder,
      tags: {"#voice", if (isMeeting) "#meeting", ...?analysis?.suggestedTags}.toList(),
      transcriptText: cleanTranscript,
      transcriptSegments: segments,
      summaryShort: analysis?.summaryShort ?? (cleanTranscript.isNotEmpty ? cleanTranscript : finalTitle),
      summaryDetailed: analysis?.summaryDetailed ?? (cleanTranscript.isNotEmpty ? cleanTranscript : finalTitle),
      summaryBullets: analysis?.summaryBullets ?? [],
      meetingMinutes: analysis?.meetingMinutes ?? (cleanTranscript.isNotEmpty ? cleanTranscript : "No audio transcript recorded."),
      decisions: analysis?.decisions ?? [],
      risks: analysis?.risks ?? [],
      syncStatus: "SYNCED",
    );

    await dbHelper.insertOrUpdateNote(newNote);
    await cloudSync.pushNote(newNote);

    // Save extracted action items
    if (analysis != null && analysis.actionItems.isNotEmpty) {
      final actionItemEntities = analysis.actionItems.map((extracted) {
        return ActionItemEntity(
          id: uuid.v4(),
          noteId: noteId,
          userId: _userId,
          task: extracted.task,
          owner: extracted.owner,
          dueDate: extracted.dueDate,
          isCompleted: false,
        );
      }).toList();

      if (actionItemEntities.isNotEmpty) {
        await dbHelper.insertActionItems(actionItemEntities);
        for (final a in actionItemEntities) {
          await cloudSync.pushActionItem(a);
        }
      }
    }

    _isProcessing = false;
    await refreshNotes();
    return newNote;
  }

  Future<NoteEntity> createTextNote(String title, String content) async {
    _isProcessing = true;
    _processingStatusText = "Processing text with AI...";
    _lastAiError = null;
    notifyListeners();

    const uuid = Uuid();
    final noteId = uuid.v4();

    NoteAiAnalysis? analysis;
    try {
      analysis = await aiService.analyzeContent(content, title);
      _lastAiError = null;
    } catch (e) {
      _lastAiError = e.toString().replaceFirst("Exception: ", "");
    }

    final note = NoteEntity(
      id: noteId,
      userId: _userId,
      title: title,
      type: "TEXT",
      durationSec: 0,
      status: "COMPLETED",
      folder: "All",
      tags: {"#text", ...?analysis?.suggestedTags}.toList(),
      transcriptText: content,
      transcriptSegments: [TranscriptSegment(speaker: "Author", timestamp: "00:00", text: content)],
      summaryShort: analysis?.summaryShort ?? content,
      summaryDetailed: analysis?.summaryDetailed ?? content,
      summaryBullets: analysis?.summaryBullets ?? [],
      meetingMinutes: analysis?.meetingMinutes ?? content,
      decisions: analysis?.decisions ?? [],
      risks: analysis?.risks ?? [],
    );

    await dbHelper.insertOrUpdateNote(note);
    await cloudSync.pushNote(note);

    _isProcessing = false;
    await refreshNotes();
    return note;
  }

  Future<NoteEntity> createFromTemplate(String templateName) async {
    String sampleContent;
    switch (templateName) {
      case "Customer Call":
        sampleContent = "Discussed client expectations for Q3, onboarding timeline, and custom report requests. Client agreed to renew contract pending API throughput tests.";
        break;
      case "Daily Journal":
        sampleContent = "Reflected on sprint momentum, unblocked core infrastructure blockers, and defined three top priorities for tomorrow morning.";
        break;
      case "Business Idea":
        sampleContent = "Evaluated market fit for automated voice-to-action workflow. Key differentiation is instant real-time sync with local offline fallback.";
        break;
      default:
        sampleContent = "Notes captured using $templateName template.";
    }
    return await createTextNote("$templateName Note", sampleContent);
  }

  Future<StripePaymentReceipt?> processStripeCheckout({
    required StripeCardInput card,
    required SubscriptionTier tier,
    required bool isAnnual,
    required String customerEmail,
  }) async {
    _isStripeProcessing = true;
    notifyListeners();

    try {
      final receipt = await stripePaymentManager.processPayment(
        card: card,
        tier: tier,
        isAnnual: isAnnual,
        customerEmail: customerEmail,
        userId: _userId,
      );
      _subscriptionTier = tier;
      _isStripeProcessing = false;
      notifyListeners();
      return receipt;
    } catch (_) {
      _isStripeProcessing = false;
      notifyListeners();
      return null;
    }
  }

  String _formatDuration(int durationSec) {
    final mins = durationSec ~/ 60;
    final secs = durationSec % 60;
    return "${mins}m ${secs}s";
  }

  @override
  void dispose() {
    audioPlayer.stopAudio();
    audioPlayer.dispose();
    cloudSync.dispose();
    super.dispose();
  }
}
