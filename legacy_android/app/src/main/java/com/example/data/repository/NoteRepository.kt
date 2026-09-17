package com.example.data.repository

import com.example.data.local.ActionItemDao
import com.example.data.local.EmailActivityDao
import com.example.data.local.FolderDao
import com.example.data.local.NoteDao
import com.example.data.model.ActionItemEntity
import com.example.data.model.EmailActivityRecord
import com.example.data.model.FolderEntity
import com.example.data.model.NoteEntity
import com.example.data.model.TranscriptSegment
import com.example.data.remote.FirestoreSyncManager
import com.example.data.remote.GeminiService
import com.example.data.remote.SyncState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

class NoteRepository(
    private val noteDao: NoteDao,
    private val actionItemDao: ActionItemDao,
    private val folderDao: FolderDao,
    private val emailActivityDao: EmailActivityDao,
    private val syncManager: FirestoreSyncManager,
    private val geminiService: GeminiService,
    private val scope: CoroutineScope
) {
    val syncState: StateFlow<SyncState> = syncManager.syncState
    val lastSyncTime: StateFlow<Long> = syncManager.lastSyncTime

    fun startSync(userId: String) {
        syncManager.startListeningForUser(userId)
        // Ensure default folders and starter notes exist
        scope.launch(Dispatchers.IO) {
            initDefaultFoldersAndNotes(userId)
        }
    }

    fun getNotes(userId: String): Flow<List<NoteEntity>> = noteDao.getActiveNotes(userId)
    fun getFavoriteNotes(userId: String): Flow<List<NoteEntity>> = noteDao.getFavoriteNotes(userId)
    fun getArchivedNotes(userId: String): Flow<List<NoteEntity>> = noteDao.getArchivedNotes(userId)
    fun getDeletedNotes(userId: String): Flow<List<NoteEntity>> = noteDao.getDeletedNotes(userId)
    fun getNoteById(id: String): Flow<NoteEntity?> = noteDao.getNoteById(id)
    suspend fun getNoteByIdOnce(id: String): NoteEntity? = noteDao.getNoteByIdOnce(id)
    fun searchNotes(userId: String, query: String): Flow<List<NoteEntity>> = noteDao.searchNotes(userId, query)

    fun getActionItemsForNote(noteId: String): Flow<List<ActionItemEntity>> = actionItemDao.getActionItemsForNote(noteId)
    fun getAllActionItems(userId: String): Flow<List<ActionItemEntity>> = actionItemDao.getAllActionItemsForUser(userId)
    fun getFolders(userId: String): Flow<List<FolderEntity>> = folderDao.getFoldersForUser(userId)
    fun getEmailActivities(noteId: String): Flow<List<EmailActivityRecord>> = emailActivityDao.getActivitiesForNote(noteId)

    suspend fun saveNote(note: NoteEntity) = withContext(Dispatchers.IO) {
        val updatedNote = note.copy(updatedAt = System.currentTimeMillis())
        noteDao.insertOrUpdate(updatedNote)
        syncManager.pushNote(updatedNote)
    }

    suspend fun createAndProcessNote(
        userId: String,
        title: String,
        type: String,
        audioPath: String?,
        durationSec: Int,
        transcriptText: String,
        segments: List<TranscriptSegment>,
        folder: String = "All"
    ): NoteEntity = withContext(Dispatchers.IO) {
        val noteId = UUID.randomUUID().toString()
        val initialNote = NoteEntity(
            id = noteId,
            userId = userId,
            title = title,
            type = type,
            audioPath = audioPath,
            durationSec = durationSec,
            status = "ANALYZING",
            folder = folder,
            tags = listOf("#voice", "#meeting"),
            transcriptText = transcriptText,
            transcriptSegments = segments,
            summaryShort = "Generating executive summary...",
            summaryDetailed = "AI analysis in progress...",
            meetingMinutes = "Drafting minutes...",
            syncStatus = "PENDING_PUSH"
        )
        noteDao.insertOrUpdate(initialNote)

        // Perform AI understanding via GeminiService (with direct audio file multimodal analysis if needed)
        val audioFile = if (!audioPath.isNullOrBlank()) java.io.File(audioPath) else null
        val (finalTranscript, analysis) = geminiService.analyzeNote(transcriptText, title, audioFile)

        val finalSegments = if (finalTranscript.isNotBlank() && (segments.isEmpty() || segments.firstOrNull()?.text?.isBlank() == true)) {
            val rawLines = finalTranscript.split(Regex("(?<=[.!?\\n])\\s+")).filter { it.isNotBlank() }
            val segList = mutableListOf<TranscriptSegment>()
            val totalSegs = rawLines.size.coerceAtLeast(1)
            val stepSec = if (durationSec > 0) (durationSec / totalSegs).coerceAtLeast(1) else 5
            rawLines.forEachIndexed { idx, line ->
                val lineSec = idx * stepSec
                val timeStr = String.format(java.util.Locale.getDefault(), "%02d:%02d", lineSec / 60, lineSec % 60)
                segList.add(TranscriptSegment("Speaker 1", timeStr, line))
            }
            if (segList.isNotEmpty()) segList else listOf(TranscriptSegment("Speaker 1", "00:00", finalTranscript))
        } else {
            segments
        }

        val processedNote = initialNote.copy(
            transcriptText = if (finalTranscript.isNotBlank()) finalTranscript else initialNote.transcriptText,
            transcriptSegments = finalSegments,
            status = "COMPLETED",
            tags = (initialNote.tags + analysis.suggestedTags).distinct(),
            summaryShort = analysis.summaryShort,
            summaryDetailed = analysis.summaryDetailed,
            summaryBullets = analysis.summaryBullets,
            meetingMinutes = analysis.meetingMinutes,
            decisions = analysis.decisions,
            risks = analysis.risks,
            updatedAt = System.currentTimeMillis(),
            syncStatus = "SYNCED"
        )
        noteDao.insertOrUpdate(processedNote)
        syncManager.pushNote(processedNote)

        // Save extracted action items
        val actionItemEntities = analysis.actionItems.map { extracted ->
            ActionItemEntity(
                id = UUID.randomUUID().toString(),
                noteId = noteId,
                userId = userId,
                task = extracted.task,
                owner = extracted.owner,
                dueDate = extracted.dueDate,
                isCompleted = false
            )
        }
        if (actionItemEntities.isNotEmpty()) {
            actionItemDao.insertAll(actionItemEntities)
            actionItemEntities.forEach { syncManager.pushActionItem(it) }
        }

        processedNote
    }

    suspend fun toggleFavorite(note: NoteEntity) = withContext(Dispatchers.IO) {
        val updated = note.copy(isFavorite = !note.isFavorite, updatedAt = System.currentTimeMillis())
        noteDao.insertOrUpdate(updated)
        syncManager.pushNote(updated)
    }

    suspend fun toggleArchive(note: NoteEntity) = withContext(Dispatchers.IO) {
        val updated = note.copy(isArchived = !note.isArchived, updatedAt = System.currentTimeMillis())
        noteDao.insertOrUpdate(updated)
        syncManager.pushNote(updated)
    }

    suspend fun moveToTrash(note: NoteEntity) = withContext(Dispatchers.IO) {
        val updated = note.copy(isDeleted = true, updatedAt = System.currentTimeMillis())
        noteDao.insertOrUpdate(updated)
        syncManager.pushNote(updated)
    }

    suspend fun restoreFromTrash(note: NoteEntity) = withContext(Dispatchers.IO) {
        val updated = note.copy(isDeleted = false, updatedAt = System.currentTimeMillis())
        noteDao.insertOrUpdate(updated)
        syncManager.pushNote(updated)
    }

    suspend fun permanentlyDelete(note: NoteEntity) = withContext(Dispatchers.IO) {
        noteDao.hardDeleteNote(note.id)
        actionItemDao.deleteForNote(note.id)
        syncManager.deleteNoteFromCloud(note.userId, note.id)
    }

    suspend fun toggleActionItem(item: ActionItemEntity) = withContext(Dispatchers.IO) {
        val updated = item.copy(isCompleted = !item.isCompleted, updatedAt = System.currentTimeMillis())
        actionItemDao.update(updated)
        syncManager.pushActionItem(updated)
    }

    suspend fun addActionItem(noteId: String, userId: String, task: String, owner: String, dueDate: String) = withContext(Dispatchers.IO) {
        val newItem = ActionItemEntity(
            id = UUID.randomUUID().toString(),
            noteId = noteId,
            userId = userId,
            task = task,
            owner = owner.ifBlank { "Unassigned" },
            dueDate = dueDate
        )
        actionItemDao.insertOrUpdate(newItem)
        syncManager.pushActionItem(newItem)
    }

    suspend fun deleteActionItem(itemId: String) = withContext(Dispatchers.IO) {
        actionItemDao.deleteById(itemId)
    }

    suspend fun createFolder(userId: String, name: String, colorHex: String = "#2563EB") = withContext(Dispatchers.IO) {
        val folder = FolderEntity(
            id = UUID.randomUUID().toString(),
            userId = userId,
            name = name,
            colorHex = colorHex
        )
        folderDao.insertOrUpdate(folder)
    }

    suspend fun recordEmailSent(noteId: String, userId: String, recipients: String, subject: String, contentType: String) = withContext(Dispatchers.IO) {
        val record = EmailActivityRecord(
            id = UUID.randomUUID().toString(),
            noteId = noteId,
            userId = userId,
            recipients = recipients,
            contentType = contentType,
            subject = subject,
            sentAt = System.currentTimeMillis()
        )
        emailActivityDao.insert(record)
    }

    suspend fun askAi(noteContext: String, question: String): String {
        return geminiService.askAiAboutNote(noteContext, question)
    }

    suspend fun generateFollowUpEmail(noteTitle: String, summary: String, actionItems: String): String {
        return geminiService.generateFollowUpEmail(noteTitle, summary, actionItems)
    }

    private suspend fun initDefaultFoldersAndNotes(userId: String) {
        val defaultFolders = listOf(
            FolderEntity(UUID.randomUUID().toString(), userId, "Meetings", "#2563EB"),
            FolderEntity(UUID.randomUUID().toString(), userId, "Strategy", "#7C3AED"),
            FolderEntity(UUID.randomUUID().toString(), userId, "Product", "#059669"),
            FolderEntity(UUID.randomUUID().toString(), userId, "Personal", "#D97706")
        )
        folderDao.insertAll(defaultFolders)

        // Check if user has notes already
        val sampleId = "sample_note_01"
        val existing = noteDao.getNoteByIdOnce(sampleId)
        if (existing == null) {
            val starterNote = NoteEntity(
                id = sampleId,
                userId = userId,
                title = "Q3 Product Strategy & Real-Time Sync Alignment",
                type = "MEETING",
                durationSec = 245,
                status = "COMPLETED",
                folder = "Meetings",
                tags = listOf("#strategy", "#product", "#q3-planning"),
                transcriptText = "Alex: Welcome everyone. Today we are aligning on our Q3 roadmap for NoteFlow AI. Specifically, our focus is offline-first real-time database synchronization and intelligent meeting minutes.\nSarah: Thanks Alex. On the engineering side, we've integrated Room for local storage and Firestore for real-time cloud listening. All client changes update instantaneously.\nDavid: That's huge for users in low-connectivity environments. What about action items and automated calendar invites?\nAlex: Action items are automatically parsed from transcripts, complete with owner and due date. We also have one-tap Android Calendar export and email summaries.\nSarah: Excellent. I will finalize the security benchmarks by Friday 5 PM.",
                transcriptSegments = listOf(
                    TranscriptSegment("Alex Vance", "00:00", "Welcome everyone. Today we are aligning on our Q3 roadmap for NoteFlow AI. Specifically, our focus is offline-first real-time database synchronization and intelligent meeting minutes."),
                    TranscriptSegment("Sarah Chen", "00:35", "Thanks Alex. On the engineering side, we've integrated Room for local storage and Firestore for real-time cloud listening. All client changes update instantaneously."),
                    TranscriptSegment("David Kim", "01:10", "That's huge for users in low-connectivity environments. What about action items and automated calendar invites?"),
                    TranscriptSegment("Alex Vance", "01:45", "Action items are automatically parsed from transcripts, complete with owner and due date. We also have one-tap Android Calendar export and email summaries."),
                    TranscriptSegment("Sarah Chen", "02:15", "Excellent. I will finalize the security benchmarks by Friday 5 PM.")
                ),
                summaryShort = "The team aligned on the Q3 NoteFlow AI roadmap, centering on offline-first real-time cloud sync, automatic meeting minutes, and seamless action item export.",
                summaryDetailed = "In this executive strategy sync, Alex Vance, Sarah Chen, and David Kim reviewed the core architecture for NoteFlow AI. The discussion validated the offline-first hybrid design using Room local storage paired with Firestore real-time listeners. Key features discussed include automated transcript parsing, speaker timestamps, Android Calendar integrations, and email sharing workflows.",
                summaryBullets = listOf(
                    "Validated offline-first hybrid architecture (Room + Firestore real-time sync)",
                    "Confirmed automated extraction of action items with owners and due dates",
                    "Approved native email composer and calendar integration workflows"
                ),
                meetingMinutes = """
                    Meeting: Q3 Product Strategy & Real-Time Sync Alignment
                    Date: Today
                    Attendees: Alex Vance (PM), Sarah Chen (Lead Eng), David Kim (Tech Arch)
                    
                    Agenda:
                    1. Architecture review for offline-first synchronization
                    2. Action item extraction and calendar linking
                    3. Security and release schedule
                    
                    Key Discussions:
                    • Room DB provides 0ms local latency; Firestore handles multi-device sync.
                    • Transcripts parse speaker turns and timestamps dynamically.
                    • Email summaries support multiple formats (Short, Minutes, Full Transcript).
                    
                    Decisions Made:
                    • Ship the hybrid synchronization model for production.
                    • Require explicit consent before microphone capture.
                """.trimIndent(),
                decisions = listOf(
                    "Standardize on Room + Firestore hybrid synchronization.",
                    "Include native email composer and calendar export in core MVP."
                ),
                risks = listOf(
                    "Network drops during cloud synchronization (mitigated by Room local cache).",
                    "Microphone permission denials on fresh installs (handled with graceful prompt)."
                ),
                isFavorite = true,
                createdAt = System.currentTimeMillis() - 7200000,
                updatedAt = System.currentTimeMillis() - 7200000,
                syncStatus = "SYNCED"
            )
            noteDao.insertOrUpdate(starterNote)

            val actionItems = listOf(
                ActionItemEntity(UUID.randomUUID().toString(), sampleId, userId, "Finalize security benchmarks and sync tests", "Sarah Chen", "Friday, 5:00 PM", false),
                ActionItemEntity(UUID.randomUUID().toString(), sampleId, userId, "Prepare demo walkthrough of voice recording and AI minutes", "Alex Vance", "Tomorrow, 2:00 PM", true),
                ActionItemEntity(UUID.randomUUID().toString(), sampleId, userId, "Review Gemini API prompt templates for speaker parsing", "David Kim", "Next Monday", false)
            )
            actionItemDao.insertAll(actionItems)
        }
    }
}
