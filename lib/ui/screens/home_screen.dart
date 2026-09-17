import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../state/auth_provider.dart';
import '../../state/notes_provider.dart';
import '../../theme/app_theme.dart';
import '../components/note_card.dart';
import 'import_sheet.dart';
import 'note_detail_screen.dart';
import 'record_screen.dart';
import 'settings_screen.dart';
import 'tasks_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final notes = Provider.of<NotesProvider>(context, listen: false);
      if (auth.currentUser != null) {
        notes.updateUserId(auth.currentUser!.id);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openRecordingStudio() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RecordScreen(initialIsMeeting: false),
      ),
    );
  }

  void _openImportSheet() {
    ImportBottomSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final notesProvider = Provider.of<NotesProvider>(context);
    final notes = notesProvider.filteredNotes;
    final now = DateTime.now();
    final yearStr = DateFormat("yyyy").format(now);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content Area
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header (Screenshot 2)
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 16, top: 16, bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // "Today" & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Today",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              yearStr,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              "Today",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Right Action Icons (Layout/Tasks, Search, Settings)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Tasks / Checklist shortcut
                          IconButton(
                            icon: const Icon(Icons.grid_view_outlined, size: 22, color: AppColors.iconColor),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksScreen()));
                            },
                            tooltip: "Tasks",
                          ),
                          // Search toggle
                          IconButton(
                            icon: Icon(
                              _isSearchVisible ? Icons.close : Icons.search,
                              size: 22,
                              color: AppColors.iconColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _isSearchVisible = !_isSearchVisible;
                                if (!_isSearchVisible) {
                                  _searchController.clear();
                                  notesProvider.setSearchQuery("");
                                }
                              });
                            },
                            tooltip: "Search",
                          ),
                          // Settings Gear
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, size: 22, color: AppColors.iconColor),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                            },
                            tooltip: "Settings",
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Collapsible Search Field
                if (_isSearchVisible)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => notesProvider.setSearchQuery(val),
                      decoration: InputDecoration(
                        hintText: "Search notes, transcripts, summaries...",
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                                onPressed: () {
                                  _searchController.clear();
                                  notesProvider.setSearchQuery("");
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),

                // Notes List
                Expanded(
                  child: notes.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.notes, size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 16),
                                const Text(
                                  "No notes yet",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Tap the microphone button to record a voice note, or tap Import (+) to import media and documents.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                                ),
                                const SizedBox(height: 24),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text("Import or Create Note"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textPrimary,
                                    side: const BorderSide(color: AppColors.cardBorder),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: _openImportSheet,
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.accentDark,
                          onRefresh: () => notesProvider.refreshNotes(),
                          child: ListView.separated(
                            padding: const EdgeInsets.only(
                              left: 20,
                              right: 20,
                              top: 8,
                              bottom: 110, // Generous padding so floating bottom dock never overlaps cards
                            ),
                            itemCount: notes.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (ctx, i) {
                              final note = notes[i];
                              return NoteCard(
                                note: note,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NoteDetailScreen(noteId: note.id),
                                    ),
                                  );
                                },
                                onToggleFavorite: () => notesProvider.toggleFavorite(note),
                                onToggleArchive: () => notesProvider.toggleArchive(note),
                                onDelete: () => notesProvider.moveToTrash(note),
                                onShare: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NoteDetailScreen(noteId: note.id),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),

            // Bottom Dock matching Screenshot 2 (Floating Capsule + Mic Button)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Row(
                children: [
                  // Capsule Dock (Transcripts + Import)
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.cardBorder, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Left: Transcripts Tab
                        InkWell(
                          onTap: () {
                            notesProvider.setFilter("All");
                          },
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.graphic_eq, size: 20, color: AppColors.iconColor),
                                SizedBox(height: 2),
                                Text(
                                  "Transcripts",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Right: Import (+) Tab (Highlighted Pill button)
                        Container(
                          margin: const EdgeInsets.only(right: 6, top: 5, bottom: 5),
                          decoration: BoxDecoration(
                            color: AppColors.dockSelected,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: InkWell(
                            onTap: _openImportSheet,
                            borderRadius: BorderRadius.circular(24),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 22),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, size: 20, color: AppColors.iconColor),
                                  SizedBox(height: 2),
                                  Text(
                                    "Import",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Floating Circular Microphone Button (Right side, Screenshot 2)
                  GestureDetector(
                    onTap: _openRecordingStudio,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppColors.accentDark,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.mic,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
