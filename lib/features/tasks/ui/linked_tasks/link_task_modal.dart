import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/themes/theme.dart';

/// Modal for searching and selecting a task to link to the current task.
///
/// Shows a search field and list of available tasks. Excludes:
/// - The current task itself
/// - Tasks already linked (both incoming and outgoing)
class LinkTaskModal extends ConsumerStatefulWidget {
  const LinkTaskModal({
    required this.currentTaskId,
    required this.existingLinkedIds,
    super.key,
  });

  /// The ID of the current task (to exclude from results).
  final String currentTaskId;

  /// IDs of tasks already linked (to exclude from results).
  final Set<String> existingLinkedIds;

  /// Shows the modal and returns the selected task, or null if cancelled.
  static Future<Task?> show({
    required BuildContext context,
    required String currentTaskId,
    required Set<String> existingLinkedIds,
  }) async {
    return showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => LinkTaskModal(
        currentTaskId: currentTaskId,
        existingLinkedIds: existingLinkedIds,
      ),
    );
  }

  @override
  ConsumerState<LinkTaskModal> createState() => _LinkTaskModalState();
}

class _LinkTaskModalState extends ConsumerState<LinkTaskModal> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<Task> _tasks = [];
  Set<String> _fts5Matches = {};
  bool _isLoading = true;
  String _query = '';

  final JournalDb _db = getIt<JournalDb>();
  final Fts5Db _fts5Db = getIt<Fts5Db>();

  @override
  void initState() {
    super.initState();
    _loadTasks();
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);

    try {
      // Fetch all non-completed tasks
      final tasks = await _db.getTasks(
        starredStatuses: [false, true],
        taskStatuses: [
          'OPEN',
          'GROOMED',
          'IN PROGRESS',
          'BLOCKED',
          'ON HOLD',
        ],
        categoryIds: [],
        limit: 200,
      );

      // Filter to Task type and exclude current and already-linked
      final excludeIds = {widget.currentTaskId, ...widget.existingLinkedIds};
      final filteredTasks = tasks
          .whereType<Task>()
          .where((task) => !excludeIds.contains(task.meta.id))
          .toList();

      if (mounted) {
        setState(() {
          _tasks = filteredTasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onSearchChanged(String query) async {
    _query = query.trim();

    if (_query.isEmpty) {
      setState(() => _fts5Matches = {});
      return;
    }

    // Use FTS5 for search
    try {
      final matches = await _fts5Db.watchFullTextMatches(_query).first;
      if (mounted) {
        setState(() => _fts5Matches = matches.toSet());
      }
    } catch (e) {
      // Fallback to empty if FTS5 fails
      if (mounted) {
        setState(() => _fts5Matches = {});
      }
    }
  }

  List<Task> get _filteredTasks {
    if (_query.isEmpty) {
      return _tasks;
    }

    // Filter by FTS5 matches or title substring
    final queryLower = _query.toLowerCase();
    return _tasks.where((task) {
      // Match by FTS5
      if (_fts5Matches.contains(task.meta.id)) {
        return true;
      }
      // Fallback to title substring match
      return task.data.title.toLowerCase().contains(queryLower);
    }).toList();
  }

  Future<void> _selectTask(Task task) async {
    // Create link from current task to selected task
    final persistenceLogic = getIt<PersistenceLogic>();
    await persistenceLogic.createLink(
      fromId: widget.currentTaskId,
      toId: task.meta.id,
    );

    await HapticFeedback.mediumImpact();

    if (mounted) {
      Navigator.of(context).pop(task);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTasks;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: context.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.messages.linkExistingTask,
                style: context.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: context.messages.searchTasksHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(height: 8),
            // Results
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            _query.isEmpty
                                ? context.messages.tasksLabelsNoLabels
                                : context.messages.searchHint,
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colorScheme.outline,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final task = filtered[index];
                            return _TaskListTile(
                              task: task,
                              onTap: () => _selectTask(task),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}

/// List tile for displaying a task in the search results.
class _TaskListTile extends StatelessWidget {
  const _TaskListTile({
    required this.task,
    required this.onTap,
  });

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = task.data.status;
    final statusColor = status.colorForBrightness(Theme.of(context).brightness);

    return ListTile(
      onTap: onTap,
      leading: Icon(
        _getStatusIcon(status),
        color: statusColor,
        size: 20,
      ),
      title: Text(
        task.data.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _getStatusLabel(status),
        style: TextStyle(
          color: statusColor,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.add_link_rounded, size: 20),
    );
  }

  String _getStatusLabel(TaskStatus status) {
    return status.map(
      open: (_) => 'Open',
      groomed: (_) => 'Groomed',
      inProgress: (_) => 'In Progress',
      blocked: (_) => 'Blocked',
      onHold: (_) => 'On Hold',
      done: (_) => 'Done',
      rejected: (_) => 'Rejected',
    );
  }

  IconData _getStatusIcon(TaskStatus status) {
    return status.map(
      open: (_) => Icons.radio_button_unchecked,
      groomed: (_) => Icons.done_outline_rounded,
      inProgress: (_) => Icons.play_circle_outline_rounded,
      blocked: (_) => Icons.block_rounded,
      onHold: (_) => Icons.pause_circle_outline_rounded,
      done: (_) => Icons.check_circle_rounded,
      rejected: (_) => Icons.cancel_rounded,
    );
  }
}
