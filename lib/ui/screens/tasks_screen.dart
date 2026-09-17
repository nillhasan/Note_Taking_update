import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/notes_provider.dart';
import '../../theme/app_theme.dart';
import '../components/action_item_row.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _filter = "All"; // All, Pending, Completed
  String _searchQuery = "";

  void _showAddTaskDialog() {
    final taskController = TextEditingController();
    final ownerController = TextEditingController(text: "Alex");
    final dueController = TextEditingController(text: "Friday");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_task, color: AppColors.primarySky, size: 22),
            SizedBox(width: 8),
            Text("Create Action Item", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
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
                decoration: const InputDecoration(labelText: "Owner (e.g. Sarah Chen)"),
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
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final task = taskController.text.trim();
              if (task.isNotEmpty) {
                final notesProvider = Provider.of<NotesProvider>(context, listen: false);
                await notesProvider.addActionItem(
                  "general_tasks",
                  task,
                  ownerController.text.trim(),
                  dueController.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text("Add Action Item"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesProvider = Provider.of<NotesProvider>(context);

    var tasks = notesProvider.allActionItems;

    if (_filter == "Pending") {
      tasks = tasks.where((t) => !t.isCompleted).toList();
    } else if (_filter == "Completed") {
      tasks = tasks.where((t) => t.isCompleted).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      tasks = tasks.where((t) => t.task.toLowerCase().contains(q) || t.owner.toLowerCase().contains(q)).toList();
    }

    final completedCount = notesProvider.allActionItems.where((t) => t.isCompleted).length;
    final totalCount = notesProvider.allActionItems.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Action Items & Tasks"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notesProvider.refreshNotes(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Task Completion Progress",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$completedCount of $totalCount action items completed",
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: totalCount > 0 ? completedCount / totalCount : 0.0,
                            backgroundColor: AppColors.surfaceVariant,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.successGreen),
                            borderRadius: BorderRadius.circular(4),
                            minHeight: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          "${totalCount > 0 ? ((completedCount / totalCount) * 100).toInt() : 0}%",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.successGreen, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Search bar
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: "Search tasks or owner...",
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),

              // Filter chips
              Row(
                children: [
                  ChoiceChip(
                    label: Text("All (${notesProvider.allActionItems.length})"),
                    selected: _filter == "All",
                    onSelected: (_) => setState(() => _filter = "All"),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text("Pending (${notesProvider.allActionItems.where((t) => !t.isCompleted).length})"),
                    selected: _filter == "Pending",
                    onSelected: (_) => setState(() => _filter = "Pending"),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text("Completed ($completedCount)"),
                    selected: _filter == "Completed",
                    onSelected: (_) => setState(() => _filter = "Completed"),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tasks List
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.checklist_rounded, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text("No action items match your filter", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final item = tasks[i];
                          return ActionItemRow(
                            item: item,
                            onToggleCompleted: () => notesProvider.toggleActionItem(item),
                            onDelete: () => notesProvider.deleteActionItem(item.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        backgroundColor: AppColors.accentDark,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_task),
      ),
    );
  }
}
