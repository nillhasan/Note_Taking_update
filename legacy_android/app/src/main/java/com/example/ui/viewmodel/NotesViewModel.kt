package com.example.ui.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.audio.AudioPlayerManager
import com.example.data.model.ActionItemEntity
import com.example.data.model.FolderEntity
import com.example.data.model.NoteEntity
import com.example.data.model.TranscriptSegment
import com.example.data.remote.AuthManager
import com.example.data.remote.SyncState
import com.example.data.repository.NoteRepository
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.io.File
import java.util.Locale

class NotesViewModel(
    private val repository: NoteRepository,
    private val authManager: AuthManager,
    context: Context
) : ViewModel() {

    val audioPlayer = AudioPlayerManager(context, viewModelScope)
    val stripePaymentManager = com.example.data.remote.stripe.StripePaymentManager(context, authManager.supabaseService)

    val currentUser = authManager.currentUser
    val syncState: StateFlow<SyncState> = repository.syncState
    val lastSyncTime: StateFlow<Long> = repository.lastSyncTime
    val pastReceipts = stripePaymentManager.pastReceipts
    val activePaymentMethod = stripePaymentManager.activePaymentMethod

    private val _isStripeProcessing = MutableStateFlow(false)
    val isStripeProcessing: StateFlow<Boolean> = _isStripeProcessing.asStateFlow()

    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    private val _selectedFilter = MutableStateFlow("All") // All, Meetings, Voice, Favorites, Tasks, Archived, Trash
    val selectedFilter: StateFlow<String> = _selectedFilter.asStateFlow()

    private val _selectedFolder = MutableStateFlow<String?>(null)
    val selectedFolder: StateFlow<String?> = _selectedFolder.asStateFlow()

    private val _isDarkMode = MutableStateFlow(true)
    val isDarkMode: StateFlow<Boolean> = _isDarkMode.asStateFlow()

    fun toggleDarkMode() {
        _isDarkMode.value = !_isDarkMode.value
    }

    fun setDarkMode(enabled: Boolean) {
        _isDarkMode.value = enabled
    }

    private val _subscriptionTier = MutableStateFlow(com.example.data.model.SubscriptionTier.EXECUTIVE_PRO)
    val subscriptionTier: StateFlow<com.example.data.model.SubscriptionTier> = _subscriptionTier.asStateFlow()

    private val _isAnnualBilling = MutableStateFlow(true)
    val isAnnualBilling: StateFlow<Boolean> = _isAnnualBilling.asStateFlow()

    fun toggleBillingCycle() {
        _isAnnualBilling.value = !_isAnnualBilling.value
    }

    fun setBillingCycle(annual: Boolean) {
        _isAnnualBilling.value = annual
    }

    fun setSubscriptionTier(tier: com.example.data.model.SubscriptionTier) {
        _subscriptionTier.value = tier
    }

    private val _isProcessing = MutableStateFlow(false)
    val isProcessing: StateFlow<Boolean> = _isProcessing.asStateFlow()

    private val _processingStatusText = MutableStateFlow("Analyzing note with Gemini AI...")
    val processingStatusText: StateFlow<String> = _processingStatusText.asStateFlow()

    private val _selectedNoteId = MutableStateFlow<String?>(null)
    val selectedNoteId: StateFlow<String?> = _selectedNoteId.asStateFlow()

    init {
        viewModelScope.launch {
            currentUser.collect { user ->
                if (user != null) {
                    repository.startSync(user.id)
                }
            }
        }
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    val activeNotes: StateFlow<List<NoteEntity>> = combine(
        currentUser,
        _searchQuery,
        _selectedFilter,
        _selectedFolder
    ) { user, query, filter, folder ->
        FilterParams(user?.id ?: "guest", query, filter, folder)
    }.flatMapLatest { params ->
        if (params.query.isNotBlank()) {
            repository.searchNotes(params.userId, params.query)
        } else {
            when (params.filter) {
                "Favorites" -> repository.getFavoriteNotes(params.userId)
                "Archived" -> repository.getArchivedNotes(params.userId)
                "Trash" -> repository.getDeletedNotes(params.userId)
                else -> repository.getNotes(params.userId)
            }
        }
    }.combine(_selectedFilter) { list, filter ->
        when (filter) {
            "Meetings" -> list.filter { it.type == "MEETING" }
            "Voice" -> list.filter { it.type == "VOICE" }
            else -> list
        }
    }.combine(_selectedFolder) { list, folder ->
        if (folder != null && folder != "All") {
            list.filter { it.folder.equals(folder, ignoreCase = true) }
        } else list
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    @OptIn(ExperimentalCoroutinesApi::class)
    val allActionItems: StateFlow<List<ActionItemEntity>> = currentUser.flatMapLatest { user ->
        if (user != null) repository.getAllActionItems(user.id) else flowOf(emptyList())
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    @OptIn(ExperimentalCoroutinesApi::class)
    val folders: StateFlow<List<FolderEntity>> = currentUser.flatMapLatest { user ->
        if (user != null) repository.getFolders(user.id) else flowOf(emptyList())
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    @OptIn(ExperimentalCoroutinesApi::class)
    val currentNote: StateFlow<NoteEntity?> = _selectedNoteId.flatMapLatest { id ->
        if (id != null) repository.getNoteById(id) else flowOf(null)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    @OptIn(ExperimentalCoroutinesApi::class)
    val currentNoteActionItems: StateFlow<List<ActionItemEntity>> = _selectedNoteId.flatMapLatest { id ->
        if (id != null) repository.getActionItemsForNote(id) else flowOf(emptyList())
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun selectNote(noteId: String?) {
        _selectedNoteId.value = noteId
        audioPlayer.stopAudio()
    }

    fun setSearchQuery(query: String) {
        _searchQuery.value = query
    }

    fun setFilter(filter: String) {
        _selectedFilter.value = filter
    }

    fun setFolder(folder: String?) {
        _selectedFolder.value = folder
    }

    fun toggleFavorite(note: NoteEntity) {
        viewModelScope.launch {
            repository.toggleFavorite(note)
        }
    }

    fun toggleArchive(note: NoteEntity) {
        viewModelScope.launch {
            repository.toggleArchive(note)
        }
    }

    fun moveToTrash(note: NoteEntity) {
        viewModelScope.launch {
            repository.moveToTrash(note)
        }
    }

    fun restoreFromTrash(note: NoteEntity) {
        viewModelScope.launch {
            repository.restoreFromTrash(note)
        }
    }

    fun permanentlyDelete(note: NoteEntity) {
        viewModelScope.launch {
            repository.permanentlyDelete(note)
        }
    }

    fun toggleActionItem(item: ActionItemEntity) {
        viewModelScope.launch {
            repository.toggleActionItem(item)
        }
    }

    fun addActionItem(noteId: String, task: String, owner: String, dueDate: String) {
        val userId = currentUser.value?.id ?: "guest"
        viewModelScope.launch {
            repository.addActionItem(noteId, userId, task, owner, dueDate)
        }
    }

    fun deleteActionItem(itemId: String) {
        viewModelScope.launch {
            repository.deleteActionItem(itemId)
        }
    }

    fun createFolder(name: String) {
        val userId = currentUser.value?.id ?: "guest"
        viewModelScope.launch {
            repository.createFolder(userId, name)
        }
    }

    fun forceSync() {
        val userId = currentUser.value?.id ?: return
        repository.startSync(userId)
    }

    fun recordEmailSent(noteId: String, recipients: String, subject: String, contentType: String) {
        val userId = currentUser.value?.id ?: "guest"
        viewModelScope.launch {
            repository.recordEmailSent(noteId, userId, recipients, subject, contentType)
        }
    }

    suspend fun askAi(noteContext: String, question: String): String {
        return repository.askAi(noteContext, question)
    }

    suspend fun generateFollowUpEmail(title: String, summary: String, items: String): String {
        return repository.generateFollowUpEmail(title, summary, items)
    }

    fun processFinishedAudio(
        file: File?,
        durationSec: Int,
        isMeeting: Boolean,
        customTitle: String? = null,
        targetFolder: String? = null,
        userTranscript: String? = null,
        onComplete: (NoteEntity) -> Unit
    ) {
        val userId = currentUser.value?.id ?: "guest"
        viewModelScope.launch {
            _isProcessing.value = true
            _processingStatusText.value = "Transcribing voice input..."

            val cleanUserTranscript = userTranscript?.trim().orEmpty()
            val effectiveTranscript = cleanUserTranscript

            val defaultTitle = if (isMeeting) {
                "Meeting Discussion (${formatDuration(durationSec)})"
            } else {
                "Voice Note (${formatDuration(durationSec)})"
            }
            val finalTitle = customTitle?.trim()?.ifBlank { defaultTitle } ?: defaultTitle
            val type = if (isMeeting) "MEETING" else "VOICE"
            val folder = targetFolder?.trim()?.ifBlank { if (isMeeting) "Meetings" else "All" } ?: (if (isMeeting) "Meetings" else "All")

            // Build dynamic transcript segments from the actual transcript
            val rawLines = if (effectiveTranscript.isNotBlank()) {
                effectiveTranscript.split(Regex("(?<=[.!?\\n])\\s+")).filter { it.isNotBlank() }
            } else {
                emptyList()
            }
            val segments = mutableListOf<TranscriptSegment>()
            val totalSegments = rawLines.size.coerceAtLeast(1)
            val stepSeconds = if (durationSec > 0) (durationSec / totalSegments).coerceAtLeast(1) else 10

            rawLines.forEachIndexed { index, line ->
                val lineSec = index * stepSeconds
                val mins = lineSec / 60
                val secs = lineSec % 60
                val timeStr = String.format(Locale.getDefault(), "%02d:%02d", mins, secs)

                val (speaker, text) = if (line.contains(":") && line.indexOf(":") < 25) {
                    val spk = line.substringBefore(":").trim()
                    val txt = line.substringAfter(":").trim()
                    spk to txt
                } else if (isMeeting) {
                    val speakerName = if (index % 2 == 0) "Speaker 1" else "Speaker 2"
                    speakerName to line
                } else {
                    "Speaker 1" to line
                }

                segments.add(TranscriptSegment(speaker, timeStr, text))
            }

            if (segments.isEmpty()) {
                val placeholderMsg = if (effectiveTranscript.isNotBlank()) effectiveTranscript else "Audio recording captured (${formatDuration(durationSec)})"
                segments.add(TranscriptSegment("Speaker 1", "00:00", placeholderMsg))
            }

            _processingStatusText.value = "Extracting decisions & action items with Gemini AI..."

            val note = repository.createAndProcessNote(
                userId = userId,
                title = finalTitle,
                type = type,
                audioPath = file?.absolutePath,
                durationSec = durationSec,
                transcriptText = effectiveTranscript,
                segments = segments,
                folder = folder
            )

            _isProcessing.value = false
            onComplete(note)
        }
    }

    fun createTextNote(title: String, content: String, onComplete: (NoteEntity) -> Unit) {
        val userId = currentUser.value?.id ?: "guest"
        viewModelScope.launch {
            _isProcessing.value = true
            _processingStatusText.value = "Processing text with Gemini AI..."

            val segments = listOf(
                TranscriptSegment("Author", "00:00", content)
            )

            val note = repository.createAndProcessNote(
                userId = userId,
                title = title,
                type = "TEXT",
                audioPath = null,
                durationSec = 0,
                transcriptText = content,
                segments = segments,
                folder = "All"
            )

            _isProcessing.value = false
            onComplete(note)
        }
    }

    fun createFromTemplate(templateName: String, onComplete: (NoteEntity) -> Unit) {
        val sampleContent = when (templateName) {
            "Customer Call" -> "Discussed client expectations for Q3, onboarding timeline, and custom report requests. Client agreed to renew contract pending API throughput tests."
            "Daily Journal" -> "Reflected on sprint momentum, unblocked core infrastructure blockers, and defined three top priorities for tomorrow morning."
            "Business Idea" -> "Evaluated market fit for automated voice-to-action workflow. Key differentiation is instant real-time sync with local offline fallback."
            else -> "Notes captured using $templateName template."
        }
        createTextNote(title = "$templateName Note", content = sampleContent, onComplete = onComplete)
    }

    fun processStripeCheckout(
        card: com.example.data.remote.stripe.StripeCardInput,
        tier: com.example.data.model.SubscriptionTier,
        isAnnual: Boolean,
        onSuccess: (com.example.data.model.StripePaymentReceipt) -> Unit,
        onError: (String) -> Unit
    ) {
        viewModelScope.launch {
            _isStripeProcessing.value = true
            val user = currentUser.value
            val email = user?.email ?: "customer@enterprise.com"
            val userId = user?.id ?: "sp_usr_01"

            val result = stripePaymentManager.processPayment(
                card = card,
                tier = tier,
                isAnnual = isAnnual,
                customerEmail = email,
                userId = userId
            )

            _isStripeProcessing.value = false
            if (result.isSuccess) {
                val receipt = result.getOrThrow()
                _subscriptionTier.value = tier
                authManager.updateSubscriptionTier(tier)
                onSuccess(receipt)
            } else {
                onError(result.exceptionOrNull()?.message ?: "Stripe payment failed")
            }
        }
    }

    private fun formatDuration(durationSec: Int): String {
        val mins = durationSec / 60
        val secs = durationSec % 60
        return "${mins}m ${secs}s"
    }

    override fun onCleared() {
        super.onCleared()
        audioPlayer.stopAudio()
    }

    private data class FilterParams(
        val userId: String,
        val query: String,
        val filter: String,
        val folder: String?
    )
}
