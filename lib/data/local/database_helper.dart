import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('noteflow.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final appDir = await getApplicationDocumentsDirectory();
      path = join(appDir.path, filePath);
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        audioPath TEXT,
        durationSec INTEGER NOT NULL,
        status TEXT NOT NULL,
        folder TEXT NOT NULL,
        tags TEXT NOT NULL,
        transcriptText TEXT NOT NULL,
        transcriptSegments TEXT NOT NULL,
        summaryShort TEXT NOT NULL,
        summaryDetailed TEXT NOT NULL,
        summaryBullets TEXT NOT NULL,
        meetingMinutes TEXT NOT NULL,
        decisions TEXT NOT NULL,
        risks TEXT NOT NULL,
        isFavorite INTEGER NOT NULL,
        isArchived INTEGER NOT NULL,
        isDeleted INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        syncStatus TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE action_items (
        id TEXT PRIMARY KEY,
        noteId TEXT NOT NULL,
        userId TEXT NOT NULL,
        task TEXT NOT NULL,
        owner TEXT NOT NULL,
        dueDate TEXT NOT NULL,
        isCompleted INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        syncStatus TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE folders (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        name TEXT NOT NULL,
        colorHex TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE email_activities (
        id TEXT PRIMARY KEY,
        noteId TEXT NOT NULL,
        userId TEXT NOT NULL,
        recipients TEXT NOT NULL,
        contentType TEXT NOT NULL,
        subject TEXT NOT NULL,
        sentAt INTEGER NOT NULL
      )
    ''');
  }

  // --- Note Operations ---

  Future<List<NoteEntity>> getActiveNotes(String userId) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'userId = ? AND isDeleted = 0 AND isArchived = 0',
      whereArgs: [userId],
      orderBy: 'updatedAt DESC',
    );
    return maps.map((e) => NoteEntity.fromMap(e)).toList();
  }

  Future<List<NoteEntity>> getFavoriteNotes(String userId) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'userId = ? AND isDeleted = 0 AND isFavorite = 1',
      whereArgs: [userId],
      orderBy: 'updatedAt DESC',
    );
    return maps.map((e) => NoteEntity.fromMap(e)).toList();
  }

  Future<List<NoteEntity>> getArchivedNotes(String userId) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'userId = ? AND isDeleted = 0 AND isArchived = 1',
      whereArgs: [userId],
      orderBy: 'updatedAt DESC',
    );
    return maps.map((e) => NoteEntity.fromMap(e)).toList();
  }

  Future<List<NoteEntity>> getDeletedNotes(String userId) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'userId = ? AND isDeleted = 1',
      whereArgs: [userId],
      orderBy: 'updatedAt DESC',
    );
    return maps.map((e) => NoteEntity.fromMap(e)).toList();
  }

  Future<NoteEntity?> getNoteById(String id) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return NoteEntity.fromMap(maps.first);
    }
    return null;
  }

  Future<List<NoteEntity>> searchNotes(String userId, String query) async {
    final db = await database;
    final searchPattern = '%$query%';
    final maps = await db.query(
      'notes',
      where: 'userId = ? AND isDeleted = 0 AND (title LIKE ? OR transcriptText LIKE ? OR summaryShort LIKE ? OR summaryDetailed LIKE ? OR tags LIKE ?)',
      whereArgs: [userId, searchPattern, searchPattern, searchPattern, searchPattern, searchPattern],
      orderBy: 'updatedAt DESC',
    );
    return maps.map((e) => NoteEntity.fromMap(e)).toList();
  }

  Future<void> insertOrUpdateNote(NoteEntity note) async {
    final db = await database;
    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertNotes(List<NoteEntity> notes) async {
    final db = await database;
    final batch = db.batch();
    for (final note in notes) {
      batch.insert('notes', note.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> hardDeleteNote(String id) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
    await db.delete('action_items', where: 'noteId = ?', whereArgs: [id]);
  }

  // --- Action Items Operations ---

  Future<List<ActionItemEntity>> getActionItemsForNote(String noteId) async {
    final db = await database;
    final maps = await db.query(
      'action_items',
      where: 'noteId = ?',
      whereArgs: [noteId],
      orderBy: 'createdAt ASC',
    );
    return maps.map((e) => ActionItemEntity.fromMap(e)).toList();
  }

  Future<List<ActionItemEntity>> getAllActionItems(String userId) async {
    final db = await database;
    final maps = await db.query(
      'action_items',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((e) => ActionItemEntity.fromMap(e)).toList();
  }

  Future<void> insertOrUpdateActionItem(ActionItemEntity item) async {
    final db = await database;
    await db.insert(
      'action_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertActionItems(List<ActionItemEntity> items) async {
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert('action_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteActionItem(String id) async {
    final db = await database;
    await db.delete('action_items', where: 'id = ?', whereArgs: [id]);
  }

  // --- Folders Operations ---

  Future<List<FolderEntity>> getFoldersForUser(String userId) async {
    final db = await database;
    final maps = await db.query(
      'folders',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt ASC',
    );
    return maps.map((e) => FolderEntity.fromMap(e)).toList();
  }

  Future<void> insertFolder(FolderEntity folder) async {
    final db = await database;
    await db.insert('folders', folder.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertFolders(List<FolderEntity> folders) async {
    final db = await database;
    final batch = db.batch();
    for (final folder in folders) {
      batch.insert('folders', folder.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // --- Email Activities Operations ---

  Future<List<EmailActivityRecord>> getEmailActivitiesForNote(String noteId) async {
    final db = await database;
    final maps = await db.query(
      'email_activities',
      where: 'noteId = ?',
      whereArgs: [noteId],
      orderBy: 'sentAt DESC',
    );
    return maps.map((e) => EmailActivityRecord.fromMap(e)).toList();
  }

  Future<void> insertEmailActivity(EmailActivityRecord record) async {
    final db = await database;
    await db.insert('email_activities', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Default Seeding ---

  Future<void> initDefaultFoldersAndNotes(String userId) async {
    final existingFolders = await getFoldersForUser(userId);
    if (existingFolders.isEmpty) {
      const uuid = Uuid();
      final defaultFolders = [
        FolderEntity(id: uuid.v4(), userId: userId, name: "Meetings", colorHex: "#2563EB"),
        FolderEntity(id: uuid.v4(), userId: userId, name: "Strategy", colorHex: "#7C3AED"),
        FolderEntity(id: uuid.v4(), userId: userId, name: "Product", colorHex: "#059669"),
        FolderEntity(id: uuid.v4(), userId: userId, name: "Personal", colorHex: "#D97706"),
      ];
      await insertFolders(defaultFolders);
    }

    const sampleId = "sample_note_01";
    final existing = await getNoteById(sampleId);
    if (existing == null) {
      const uuid = Uuid();
      final starterNote = NoteEntity(
        id: sampleId,
        userId: userId,
        title: "Q3 Product Strategy & Real-Time Sync Alignment",
        type: "MEETING",
        durationSec: 245,
        status: "COMPLETED",
        folder: "Meetings",
        tags: ["#strategy", "#product", "#q3-planning"],
        transcriptText: "Alex: Welcome everyone. Today we are aligning on our Q3 roadmap for NoteFlow AI. Specifically, our focus is offline-first real-time database synchronization and intelligent meeting minutes.\nSarah: Thanks Alex. On the engineering side, we've integrated Room and SQLite for local storage and real-time cloud listening. All client changes update instantaneously.\nDavid: That's huge for users in low-connectivity environments. What about action items and automated calendar invites?\nAlex: Action items are automatically parsed from transcripts, complete with owner and due date. We also have one-tap email summaries.\nSarah: Excellent. I will finalize the security benchmarks by Friday 5 PM.",
        transcriptSegments: [
          TranscriptSegment(speaker: "Alex Vance", timestamp: "00:00", text: "Welcome everyone. Today we are aligning on our Q3 roadmap for NoteFlow AI. Specifically, our focus is offline-first real-time database synchronization and intelligent meeting minutes."),
          TranscriptSegment(speaker: "Sarah Chen", timestamp: "00:35", text: "Thanks Alex. On the engineering side, we've integrated Room and SQLite for local storage and real-time cloud listening. All client changes update instantaneously."),
          TranscriptSegment(speaker: "David Kim", timestamp: "01:10", text: "That's huge for users in low-connectivity environments. What about action items and automated calendar invites?"),
          TranscriptSegment(speaker: "Alex Vance", timestamp: "01:45", text: "Action items are automatically parsed from transcripts, complete with owner and due date. We also have one-tap email summaries."),
          TranscriptSegment(speaker: "Sarah Chen", timestamp: "02:15", text: "Excellent. I will finalize the security benchmarks by Friday 5 PM."),
        ],
        summaryShort: "The team aligned on the Q3 NoteFlow AI roadmap, centering on offline-first real-time cloud sync, automatic meeting minutes, and seamless action item export.",
        summaryDetailed: "In this executive strategy sync, Alex Vance, Sarah Chen, and David Kim reviewed the core architecture for NoteFlow AI. The discussion validated the offline-first hybrid design using local SQLite storage paired with real-time listeners. Key features discussed include automated transcript parsing, speaker timestamps, and email sharing workflows.",
        summaryBullets: [
          "Validated offline-first hybrid architecture (SQLite + real-time cloud sync)",
          "Confirmed automated extraction of action items with owners and due dates",
          "Approved native email composer and sharing workflows",
        ],
        meetingMinutes: """
Meeting: Q3 Product Strategy & Real-Time Sync Alignment
Date: Today
Attendees: Alex Vance (PM), Sarah Chen (Lead Eng), David Kim (Tech Arch)

Agenda:
1. Architecture review for offline-first synchronization
2. Action item extraction and calendar linking
3. Security and release schedule

Key Discussions:
• SQLite DB provides 0ms local latency; cloud handles multi-device sync.
• Transcripts parse speaker turns and timestamps dynamically.
• Email summaries support multiple formats (Short, Minutes, Full Transcript).

Decisions Made:
• Ship the hybrid synchronization model for production.
• Require explicit consent before microphone capture.
""".trim(),
        decisions: [
          "Standardize on SQLite + Cloud hybrid synchronization.",
          "Include native email composer in core MVP.",
        ],
        risks: [
          "Network drops during cloud synchronization (mitigated by SQLite local cache).",
          "Microphone permission denials on fresh installs (handled with graceful prompt).",
        ],
        isFavorite: true,
        createdAt: DateTime.now().millisecondsSinceEpoch - 7200000,
        updatedAt: DateTime.now().millisecondsSinceEpoch - 7200000,
        syncStatus: "SYNCED",
      );
      await insertOrUpdateNote(starterNote);

      final actionItems = [
        ActionItemEntity(
          id: uuid.v4(),
          noteId: sampleId,
          userId: userId,
          task: "Finalize security benchmarks and sync tests",
          owner: "Sarah Chen",
          dueDate: "Friday, 5:00 PM",
          isCompleted: false,
        ),
        ActionItemEntity(
          id: uuid.v4(),
          noteId: sampleId,
          userId: userId,
          task: "Prepare demo walkthrough of voice recording and AI minutes",
          owner: "Alex Vance",
          dueDate: "Tomorrow, 2:00 PM",
          isCompleted: true,
        ),
        ActionItemEntity(
          id: uuid.v4(),
          noteId: sampleId,
          userId: userId,
          task: "Review Gemini API prompt templates for speaker parsing",
          owner: "David Kim",
          dueDate: "Next Monday",
          isCompleted: false,
        ),
      ];
      await insertActionItems(actionItems);
    }
  }
}
