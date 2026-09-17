package com.example.ui.screens

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DeleteOutline
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.audio.AudioRecorderManager
import com.example.audio.RecordingStatus
import com.example.audio.SpeechRecognitionManager
import com.example.ui.components.WaveformVisualizer
import com.example.ui.theme.NoteFlowRecordingRed
import com.example.ui.viewmodel.NotesViewModel
import java.util.Locale

@Composable
fun RecordingScreen(
    viewModel: NotesViewModel,
    isMeeting: Boolean,
    onBack: () -> Unit,
    onRecordingFinished: (noteId: String) -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val recorder = remember { AudioRecorderManager(context, scope) }
    val speechManager = remember { SpeechRecognitionManager(context) }

    val recordingStatus by recorder.status.collectAsStateWithLifecycle()
    val durationSec by recorder.durationSec.collectAsStateWithLifecycle()
    val amplitudes by recorder.amplitudesList.collectAsStateWithLifecycle()

    val liveTranscriptFromMic by speechManager.liveTranscript.collectAsStateWithLifecycle()
    val isListening by speechManager.isListening.collectAsStateWithLifecycle()

    val isProcessing by viewModel.isProcessing.collectAsStateWithLifecycle()
    val processingStatusText by viewModel.processingStatusText.collectAsStateWithLifecycle()

    // Clean, simple state
    var isMeetingMode by remember { mutableStateOf(isMeeting) }
    var noteTitle by remember { mutableStateOf("") }
    var transcriptText by remember { mutableStateOf("") }
    var hasUserEditedTranscript by remember { mutableStateOf(false) }

    var hasPermission by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.RECORD_AUDIO
            ) == PackageManager.PERMISSION_GRANTED
        )
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        hasPermission = granted
        if (granted) {
            recorder.startRecording()
            speechManager.startListening()
        }
    }

    // Auto-start recording on screen open
    LaunchedEffect(Unit) {
        if (hasPermission) {
            recorder.startRecording()
            speechManager.startListening()
        } else {
            permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
    }

    // Sync speech from microphone if available
    LaunchedEffect(liveTranscriptFromMic) {
        if (liveTranscriptFromMic.isNotBlank() && !hasUserEditedTranscript) {
            transcriptText = liveTranscriptFromMic
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            recorder.stopRecording()
            speechManager.cancelListening()
        }
    }

    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.12f,
        animationSpec = infiniteRepeatable(
            animation = tween(900, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseScale"
    )

    val formattedDuration = remember(durationSec) {
        val mins = durationSec / 60
        val secs = durationSec % 60
        String.format(Locale.getDefault(), "%02d:%02d", mins, secs)
    }

    val wordCount = remember(transcriptText) {
        if (transcriptText.isBlank()) 0 else transcriptText.trim().split("\\s+".toRegex()).size
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .statusBarsPadding()
    ) {
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // Clean Top Bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                IconButton(
                    onClick = {
                        recorder.cancelRecording()
                        speechManager.cancelListening()
                        onBack()
                    },
                    modifier = Modifier.testTag("recording_back_button")
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Cancel",
                        tint = MaterialTheme.colorScheme.onSurface
                    )
                }

                // Simple Mode Switcher: Voice Memo or Meeting
                Surface(
                    shape = RoundedCornerShape(20.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    modifier = Modifier.clickable {
                        isMeetingMode = !isMeetingMode
                    }
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                    ) {
                        Icon(
                            imageVector = if (isMeetingMode) Icons.Default.Groups else Icons.Default.Mic,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = if (isMeetingMode) "Meeting Mode" else "Voice Note",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }

                // Recording indicator pill
                Surface(
                    shape = RoundedCornerShape(20.dp),
                    color = if (recordingStatus == RecordingStatus.RECORDING) NoteFlowRecordingRed.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surfaceVariant
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(if (recordingStatus == RecordingStatus.RECORDING) NoteFlowRecordingRed else Color.Gray)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = when (recordingStatus) {
                                RecordingStatus.RECORDING -> "Recording"
                                RecordingStatus.PAUSED -> "Paused"
                                else -> "Ready"
                            },
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (recordingStatus == RecordingStatus.RECORDING) NoteFlowRecordingRed else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            // Scrollable Content Area (Middle)
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // Title Input: Simple, prominent, clean
                OutlinedTextField(
                    value = noteTitle,
                    onValueChange = { noteTitle = it },
                    placeholder = {
                        Text(
                            if (isMeetingMode) "Meeting Title (e.g. Sprint Review)" else "Note Title (e.g. Quick Memo)",
                            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                        )
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("recording_title_input"),
                    shape = RoundedCornerShape(14.dp),
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedContainerColor = MaterialTheme.colorScheme.surface,
                        unfocusedContainerColor = MaterialTheme.colorScheme.surface
                    )
                )

                Spacer(modifier = Modifier.height(16.dp))

                // Interactive Record / Pause Button
                Box(
                    modifier = Modifier
                        .size(88.dp)
                        .scale(if (recordingStatus == RecordingStatus.RECORDING) pulseScale else 1f)
                        .clip(CircleShape)
                        .background(
                            Brush.radialGradient(
                                colors = listOf(
                                    if (recordingStatus == RecordingStatus.RECORDING) NoteFlowRecordingRed else MaterialTheme.colorScheme.primary,
                                    if (recordingStatus == RecordingStatus.RECORDING) NoteFlowRecordingRed.copy(alpha = 0.7f) else MaterialTheme.colorScheme.primary.copy(alpha = 0.7f)
                                )
                            )
                        )
                        .clickable {
                            when (recordingStatus) {
                                RecordingStatus.RECORDING -> {
                                    recorder.pauseRecording()
                                    speechManager.stopListening()
                                }
                                RecordingStatus.PAUSED -> {
                                    recorder.resumeRecording()
                                    speechManager.startListening()
                                }
                                else -> {
                                    if (hasPermission) {
                                        recorder.startRecording()
                                        speechManager.startListening()
                                    } else {
                                        permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                                    }
                                }
                            }
                        }
                        .testTag("center_mic_button"),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = when (recordingStatus) {
                            RecordingStatus.RECORDING -> Icons.Default.Pause
                            RecordingStatus.PAUSED -> Icons.Default.PlayArrow
                            else -> Icons.Default.Mic
                        },
                        contentDescription = "Toggle Recording",
                        tint = Color.White,
                        modifier = Modifier.size(38.dp)
                    )
                }

                Spacer(modifier = Modifier.height(10.dp))

                // Big Digital Timer
                Text(
                    text = formattedDuration,
                    fontSize = 38.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    color = MaterialTheme.colorScheme.onBackground
                )

                Text(
                    text = when (recordingStatus) {
                        RecordingStatus.RECORDING -> "Listening to speech..."
                        RecordingStatus.PAUSED -> "Paused — tap button to resume"
                        else -> "Tap button to start recording"
                    },
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Spacer(modifier = Modifier.height(10.dp))

                // Waveform
                WaveformVisualizer(
                    amplitudes = amplitudes,
                    isRecording = recordingStatus == RecordingStatus.RECORDING,
                    barColor = if (recordingStatus == RecordingStatus.RECORDING) NoteFlowRecordingRed else MaterialTheme.colorScheme.primary
                )

                Spacer(modifier = Modifier.height(14.dp))

                // Speech & Live Transcript Card
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("live_transcript_card"),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
                    )
                ) {
                    Column(
                        modifier = Modifier.padding(14.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(
                                text = "Transcript & Notes",
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.sp,
                                color = MaterialTheme.colorScheme.onSurface
                            )

                            Text(
                                text = "$wordCount words",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Medium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }

                        Spacer(modifier = Modifier.height(8.dp))

                        // Editable Text Box for Speech / Notes
                        OutlinedTextField(
                            value = transcriptText,
                            onValueChange = {
                                transcriptText = it
                                hasUserEditedTranscript = true
                            },
                            placeholder = {
                                Text(
                                    if (liveTranscriptFromMic.isNotBlank()) "Hearing: \"$liveTranscriptFromMic\"..." else "Speak into mic or type your speech notes here...",
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                                )
                            },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(115.dp)
                                .testTag("transcript_edit_field"),
                            shape = RoundedCornerShape(10.dp),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedContainerColor = MaterialTheme.colorScheme.surface,
                                unfocusedContainerColor = MaterialTheme.colorScheme.surface
                            )
                        )

                        if (liveTranscriptFromMic.isNotBlank()) {
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "Live: $liveTranscriptFromMic",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.primary,
                                fontStyle = androidx.compose.ui.text.font.FontStyle.Italic,
                                maxLines = 1,
                                overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis
                            )
                        }

                        Spacer(modifier = Modifier.height(8.dp))

                        // Quick Assist Actions: Insert Sample & Clear
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.1f),
                                modifier = Modifier.clickable {
                                    hasUserEditedTranscript = true
                                    val t = noteTitle.trim().ifBlank { "Sprint Review" }
                                    transcriptText = "Discussion on $t: Reviewed project requirements and timeline. Sarah will test deployment by Friday. Alex will prepare release notes and email stakeholders. Approved next milestone."
                                }
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp)
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.AutoAwesome,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.size(14.dp)
                                    )
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text(
                                        text = "Insert Sample Speech",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                }
                            }

                            if (transcriptText.isNotBlank()) {
                                Surface(
                                    shape = RoundedCornerShape(8.dp),
                                    color = MaterialTheme.colorScheme.surface,
                                    modifier = Modifier.clickable {
                                        transcriptText = ""
                                        hasUserEditedTranscript = true
                                    }
                                ) {
                                    Text(
                                        text = "Clear",
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp)
                                    )
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))
            }

            // Fixed, Pinned Bottom Action Bar (ALWAYS VISIBLE & UNCLUTTERED)
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding(),
                color = MaterialTheme.colorScheme.surface,
                shadowElevation = 8.dp
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Cancel / Discard
                    OutlinedButton(
                        onClick = {
                            recorder.cancelRecording()
                            speechManager.cancelListening()
                            onBack()
                        },
                        modifier = Modifier
                            .weight(0.35f)
                            .height(50.dp)
                            .testTag("discard_recording_button"),
                        shape = RoundedCornerShape(14.dp),
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = MaterialTheme.colorScheme.error
                        )
                    ) {
                        Icon(
                            imageVector = Icons.Default.DeleteOutline,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Cancel", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                    }

                    // Done & Analyze (Primary Action)
                    Button(
                        onClick = {
                            val file = recorder.stopRecording()
                            speechManager.stopListening()
                            val finalDurationSec = maxOf(durationSec, 1)

                            val finalTranscript = transcriptText.trim()

                            val finalTitle = noteTitle.trim().ifBlank {
                                if (isMeetingMode) "Meeting Note" else "Voice Note"
                            }

                            viewModel.processFinishedAudio(
                                file = file,
                                durationSec = finalDurationSec,
                                isMeeting = isMeetingMode,
                                customTitle = finalTitle,
                                targetFolder = if (isMeetingMode) "Meetings" else "All",
                                userTranscript = finalTranscript
                            ) { processedNote ->
                                viewModel.selectNote(processedNote.id)
                                onRecordingFinished(processedNote.id)
                            }
                        },
                        modifier = Modifier
                            .weight(0.65f)
                            .height(50.dp)
                            .testTag("stop_process_button"),
                        shape = RoundedCornerShape(14.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.primary
                        )
                    ) {
                        Icon(
                            imageVector = Icons.Default.AutoAwesome,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "Done & Analyze",
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp
                        )
                    }
                }
            }
        }

        // Full Screen Processing Dialog
        if (isProcessing) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.75f))
                    .clickable(enabled = false) {},
                contentAlignment = Alignment.Center
            ) {
                Surface(
                    shape = RoundedCornerShape(20.dp),
                    color = MaterialTheme.colorScheme.surface,
                    modifier = Modifier.padding(32.dp)
                ) {
                    Column(
                        modifier = Modifier.padding(24.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(44.dp),
                            color = MaterialTheme.colorScheme.primary,
                            strokeWidth = 4.dp
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = "Analyzing with NoteFlow AI",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = processingStatusText,
                            fontSize = 13.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}
