package com.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.lifecycleScope
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.example.data.local.AppDatabase
import com.example.data.remote.AuthManager
import com.example.data.remote.FirestoreSyncManager
import com.example.data.remote.GeminiService
import com.example.data.repository.NoteRepository
import com.example.ui.screens.AuthScreen
import com.example.ui.screens.HomeScreen
import com.example.ui.screens.NoteDetailScreen
import com.example.ui.screens.RecordingScreen
import com.example.ui.screens.SettingsScreen
import com.example.ui.theme.MyApplicationTheme
import com.example.ui.viewmodel.AuthViewModel
import com.example.ui.viewmodel.NotesViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // Initialize Data & Dependency Layer
        val database = AppDatabase.getInstance(applicationContext)
        val noteDao = database.noteDao()
        val actionItemDao = database.actionItemDao()
        val folderDao = database.folderDao()
        val emailActivityDao = database.emailActivityDao()

        val authManager = AuthManager(applicationContext)
        val syncManager = FirestoreSyncManager(noteDao, actionItemDao, lifecycleScope)
        val geminiService = GeminiService(applicationContext)

        val repository = NoteRepository(
            noteDao = noteDao,
            actionItemDao = actionItemDao,
            folderDao = folderDao,
            emailActivityDao = emailActivityDao,
            syncManager = syncManager,
            geminiService = geminiService,
            scope = lifecycleScope
        )

        val authViewModel = AuthViewModel(authManager)
        val notesViewModel = NotesViewModel(repository, authManager, applicationContext)

        setContent {
            val isDarkMode by notesViewModel.isDarkMode.collectAsStateWithLifecycle()
            MyApplicationTheme(darkTheme = isDarkMode) {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    NoteFlowAppNavigation(
                        authViewModel = authViewModel,
                        notesViewModel = notesViewModel
                    )
                }
            }
        }
    }
}

@Composable
fun NoteFlowAppNavigation(
    authViewModel: AuthViewModel,
    notesViewModel: NotesViewModel
) {
    val navController = rememberNavController()
    val currentUser by authViewModel.currentUser.collectAsStateWithLifecycle()

    val startDestination = remember {
        if (currentUser != null) "home" else "auth"
    }

    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        composable("auth") {
            AuthScreen(
                authViewModel = authViewModel,
                onAuthSuccess = {
                    navController.navigate("home") {
                        popUpTo("auth") { inclusive = true }
                    }
                }
            )
        }

        composable("home") {
            HomeScreen(
                viewModel = notesViewModel,
                onNavigateToRecord = { isMeeting ->
                    navController.navigate("record/$isMeeting")
                },
                onNavigateToNoteDetail = { noteId ->
                    notesViewModel.selectNote(noteId)
                    navController.navigate("note_detail/$noteId")
                },
                onNavigateToSettings = {
                    navController.navigate("settings")
                }
            )
        }

        composable(
            route = "record/{isMeeting}",
            arguments = listOf(
                navArgument("isMeeting") { type = NavType.BoolType; defaultValue = false }
            )
        ) { backStackEntry ->
            val isMeeting = backStackEntry.arguments?.getBoolean("isMeeting") ?: false
            RecordingScreen(
                viewModel = notesViewModel,
                isMeeting = isMeeting,
                onBack = {
                    navController.popBackStack()
                },
                onRecordingFinished = { noteId ->
                    notesViewModel.selectNote(noteId)
                    navController.navigate("note_detail/$noteId") {
                        popUpTo("home")
                    }
                }
            )
        }

        composable(
            route = "note_detail/{noteId}",
            arguments = listOf(
                navArgument("noteId") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val noteId = backStackEntry.arguments?.getString("noteId") ?: ""
            NoteDetailScreen(
                viewModel = notesViewModel,
                noteId = noteId,
                onBack = {
                    navController.popBackStack()
                }
            )
        }

        composable("settings") {
            SettingsScreen(
                authViewModel = authViewModel,
                notesViewModel = notesViewModel,
                onBack = {
                    navController.popBackStack()
                },
                onSignedOut = {
                    navController.navigate("auth") {
                        popUpTo(0) { inclusive = true }
                    }
                }
            )
        }
    }
}

@Composable
fun Greeting(name: String, modifier: Modifier = Modifier) {
    Text(text = "Hello $name!", modifier = modifier)
}

@Preview(showBackground = true)
@Composable
fun GreetingPreview() {
    MyApplicationTheme { Greeting("NoteFlow AI") }
}
