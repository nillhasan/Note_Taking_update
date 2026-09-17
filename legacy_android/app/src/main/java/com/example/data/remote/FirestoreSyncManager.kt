package com.example.data.remote

import android.util.Log
import com.example.data.local.ActionItemDao
import com.example.data.local.NoteDao
import com.example.data.model.ActionItemEntity
import com.example.data.model.NoteEntity
import com.example.data.model.TranscriptSegment
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.SetOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

enum class SyncState {
    SYNCED,
    SYNCING,
    OFFLINE
}

class FirestoreSyncManager(
    private val noteDao: NoteDao,
    private val actionItemDao: ActionItemDao,
    private val scope: CoroutineScope
) {
    private var firestore: FirebaseFirestore? = null
    private var notesListenerRegistration: ListenerRegistration? = null
    private var actionItemsListenerRegistration: ListenerRegistration? = null

    private val _syncState = MutableStateFlow(SyncState.SYNCED)
    val syncState: StateFlow<SyncState> = _syncState.asStateFlow()

    private val _lastSyncTime = MutableStateFlow(System.currentTimeMillis())
    val lastSyncTime: StateFlow<Long> = _lastSyncTime.asStateFlow()

    init {
        try {
            firestore = FirebaseFirestore.getInstance()
        } catch (e: Exception) {
            Log.w("FirestoreSyncManager", "Firestore not initialized: ${e.message}")
            _syncState.value = SyncState.OFFLINE
        }
    }

    fun startListeningForUser(userId: String) {
        stopListening()
        val db = firestore ?: run {
            _syncState.value = SyncState.OFFLINE
            return
        }

        try {
            _syncState.value = SyncState.SYNCING
            // Real-time snapshot listener for Notes
            notesListenerRegistration = db.collection("users")
                .document(userId)
                .collection("notes")
                .addSnapshotListener { snapshots, error ->
                    if (error != null) {
                        Log.e("FirestoreSyncManager", "Notes snapshot error: ${error.message}")
                        _syncState.value = SyncState.OFFLINE
                        return@addSnapshotListener
                    }

                    if (snapshots != null && !snapshots.isEmpty) {
                        scope.launch(Dispatchers.IO) {
                            try {
                                val remoteNotes = snapshots.documents.mapNotNull { doc ->
                                    doc.toNoteEntity()
                                }
                                if (remoteNotes.isNotEmpty()) {
                                    noteDao.insertAll(remoteNotes)
                                }
                                _lastSyncTime.value = System.currentTimeMillis()
                                _syncState.value = SyncState.SYNCED
                            } catch (e: Exception) {
                                Log.e("FirestoreSyncManager", "Error parsing remote notes: ${e.message}")
                            }
                        }
                    } else {
                        _syncState.value = SyncState.SYNCED
                    }
                }

            // Real-time snapshot listener for Action Items
            actionItemsListenerRegistration = db.collection("users")
                .document(userId)
                .collection("action_items")
                .addSnapshotListener { snapshots, error ->
                    if (error != null) {
                        Log.e("FirestoreSyncManager", "Action items snapshot error: ${error.message}")
                        return@addSnapshotListener
                    }

                    if (snapshots != null && !snapshots.isEmpty) {
                        scope.launch(Dispatchers.IO) {
                            try {
                                val remoteItems = snapshots.documents.mapNotNull { doc ->
                                    doc.toActionItemEntity()
                                }
                                if (remoteItems.isNotEmpty()) {
                                    actionItemDao.insertAll(remoteItems)
                                }
                                _lastSyncTime.value = System.currentTimeMillis()
                            } catch (e: Exception) {
                                Log.e("FirestoreSyncManager", "Error parsing action items: ${e.message}")
                            }
                        }
                    }
                }
        } catch (e: Exception) {
            Log.e("FirestoreSyncManager", "Failed to register snapshot listener: ${e.message}")
            _syncState.value = SyncState.OFFLINE
        }
    }

    fun stopListening() {
        notesListenerRegistration?.remove()
        notesListenerRegistration = null
        actionItemsListenerRegistration?.remove()
        actionItemsListenerRegistration = null
    }

    suspend fun pushNote(note: NoteEntity) {
        val db = firestore ?: return
        try {
            _syncState.value = SyncState.SYNCING
            val map = note.toMap()
            db.collection("users")
                .document(note.userId)
                .collection("notes")
                .document(note.id)
                .set(map, SetOptions.merge())
                .await()

            noteDao.insertOrUpdate(note.copy(syncStatus = "SYNCED"))
            _lastSyncTime.value = System.currentTimeMillis()
            _syncState.value = SyncState.SYNCED
        } catch (e: Exception) {
            Log.w("FirestoreSyncManager", "Push note failed, saved locally: ${e.message}")
            _syncState.value = SyncState.OFFLINE
        }
    }

    suspend fun pushActionItem(item: ActionItemEntity) {
        val db = firestore ?: return
        try {
            val map = mapOf(
                "id" to item.id,
                "noteId" to item.noteId,
                "userId" to item.userId,
                "task" to item.task,
                "owner" to item.owner,
                "dueDate" to item.dueDate,
                "isCompleted" to item.isCompleted,
                "createdAt" to item.createdAt,
                "updatedAt" to item.updatedAt
            )
            db.collection("users")
                .document(item.userId)
                .collection("action_items")
                .document(item.id)
                .set(map, SetOptions.merge())
                .await()
        } catch (e: Exception) {
            Log.w("FirestoreSyncManager", "Push action item failed: ${e.message}")
        }
    }

    suspend fun deleteNoteFromCloud(userId: String, noteId: String) {
        val db = firestore ?: return
        try {
            db.collection("users")
                .document(userId)
                .collection("notes")
                .document(noteId)
                .delete()
                .await()
        } catch (e: Exception) {
            Log.w("FirestoreSyncManager", "Delete note from cloud failed: ${e.message}")
        }
    }

    private fun NoteEntity.toMap(): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "userId" to userId,
            "title" to title,
            "type" to type,
            "durationSec" to durationSec,
            "status" to status,
            "folder" to folder,
            "tags" to tags,
            "transcriptText" to transcriptText,
            "summaryShort" to summaryShort,
            "summaryDetailed" to summaryDetailed,
            "summaryBullets" to summaryBullets,
            "meetingMinutes" to meetingMinutes,
            "decisions" to decisions,
            "risks" to risks,
            "isFavorite" to isFavorite,
            "isArchived" to isArchived,
            "isDeleted" to isDeleted,
            "createdAt" to createdAt,
            "updatedAt" to updatedAt
        )
    }

    @Suppress("UNCHECKED_CAST")
    private fun DocumentSnapshot.toNoteEntity(): NoteEntity? {
        val id = getString("id") ?: id
        val userId = getString("userId") ?: return null
        val title = getString("title") ?: "Untitled Note"

        return NoteEntity(
            id = id,
            userId = userId,
            title = title,
            type = getString("type") ?: "VOICE",
            durationSec = getLong("durationSec")?.toInt() ?: 0,
            status = getString("status") ?: "COMPLETED",
            folder = getString("folder") ?: "All",
            tags = (get("tags") as? List<String>) ?: emptyList(),
            transcriptText = getString("transcriptText") ?: "",
            summaryShort = getString("summaryShort") ?: "",
            summaryDetailed = getString("summaryDetailed") ?: "",
            summaryBullets = (get("summaryBullets") as? List<String>) ?: emptyList(),
            meetingMinutes = getString("meetingMinutes") ?: "",
            decisions = (get("decisions") as? List<String>) ?: emptyList(),
            risks = (get("risks") as? List<String>) ?: emptyList(),
            isFavorite = getBoolean("isFavorite") ?: false,
            isArchived = getBoolean("isArchived") ?: false,
            isDeleted = getBoolean("isDeleted") ?: false,
            createdAt = getLong("createdAt") ?: System.currentTimeMillis(),
            updatedAt = getLong("updatedAt") ?: System.currentTimeMillis(),
            syncStatus = "SYNCED"
        )
    }

    private fun DocumentSnapshot.toActionItemEntity(): ActionItemEntity? {
        val id = getString("id") ?: id
        val noteId = getString("noteId") ?: return null
        val userId = getString("userId") ?: return null
        val task = getString("task") ?: return null

        return ActionItemEntity(
            id = id,
            noteId = noteId,
            userId = userId,
            task = task,
            owner = getString("owner") ?: "Unassigned",
            dueDate = getString("dueDate") ?: "",
            isCompleted = getBoolean("isCompleted") ?: false,
            createdAt = getLong("createdAt") ?: System.currentTimeMillis(),
            updatedAt = getLong("updatedAt") ?: System.currentTimeMillis(),
            syncStatus = "SYNCED"
        )
    }
}
