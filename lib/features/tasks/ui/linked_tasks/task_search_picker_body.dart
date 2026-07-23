import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Search-and-pick body shared by `LinkTaskModal` and `BlockingTaskPickerModal`:
/// loads open tasks (bounded, non-closed), filters by FTS5 match or title
/// substring as the user types, and renders results as a scrollable list with
/// loading/empty states. Knows nothing about link types, persistence, or
/// navigation — callers own what happens when a task is picked via
/// [onTaskSelected].
class TaskSearchPickerBody extends ConsumerStatefulWidget {
  const TaskSearchPickerBody({
    required this.excludeIds,
    required this.onTaskSelected,
    this.scrollController,
    super.key,
  });

  /// Task ids to exclude from the candidate list (e.g. the current/anchor
  /// task, tasks already linked with the relationship being created).
  final Set<String> excludeIds;

  /// Called when the user taps a result. The body does not close itself or
  /// persist anything — the caller decides what selecting a task means.
  final ValueChanged<Task> onTaskSelected;

  /// Forwarded to the results `ListView` so a host `DraggableScrollableSheet`
  /// can coordinate drag-to-resize with list scrolling. Optional — omit when
  /// the body isn't hosted inside a draggable sheet.
  final ScrollController? scrollController;

  @override
  ConsumerState<TaskSearchPickerBody> createState() =>
      _TaskSearchPickerBodyState();
}

class _TaskSearchPickerBodyState extends ConsumerState<TaskSearchPickerBody> {
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
      final tasks = await _db.getTasks(
        starredStatuses: [false, true],
        taskStatuses: openTaskStatuses,
        categoryIds: [],
        limit: 200,
      );

      if (mounted) {
        setState(() {
          _tasks = tasks.whereType<Task>().toList();
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

    try {
      final matches = await _fts5Db.watchFullTextMatches(_query).first;
      if (mounted) {
        setState(() => _fts5Matches = matches.toSet());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _fts5Matches = {});
      }
    }
  }

  // Applies widget.excludeIds at read time (not baked into _tasks at load
  // time) so a caller whose exclude set arrives after the initial task load
  // — e.g. BlockingTaskPickerModal's existing-blockers set, which resolves
  // from an async provider — still gets it honored on the next build.
  List<Task> get _filteredTasks {
    final candidates = _tasks.where(
      (task) => !widget.excludeIds.contains(task.meta.id),
    );
    if (_query.isEmpty) {
      return candidates.toList();
    }

    final queryLower = _query.toLowerCase();
    return candidates.where((task) {
      if (_fts5Matches.contains(task.meta.id)) {
        return true;
      }
      return task.data.title.toLowerCase().contains(queryLower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DesignSystemSearch(
            controller: _searchController,
            focusNode: _focusNode,
            hintText: context.messages.searchTasksHint,
            onChanged: _onSearchChanged,
            onClear: () => _onSearchChanged(''),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
              ? Center(
                  child: Text(
                    _query.isEmpty
                        ? context.messages.noTasksToLink
                        : context.messages.noTasksFound,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.outline,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final task = filtered[index];
                    return TaskListTile(
                      task: task,
                      onTap: () => widget.onTaskSelected(task),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// List tile for displaying a task in search results.
class TaskListTile extends StatelessWidget {
  const TaskListTile({
    required this.task,
    required this.onTap,
    super.key,
  });

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = task.data.status;
    final statusString = status.toDbString;
    final statusColor = taskColorFromStatusString(
      statusString,
      brightness: Theme.of(context).brightness,
    );

    return ListTile(
      onTap: onTap,
      leading: Icon(
        taskIconFromStatusString(statusString),
        color: statusColor,
        size: 20,
      ),
      title: Text(
        task.data.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        taskLabelFromStatusString(statusString, context),
        style: TextStyle(
          color: statusColor,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.add_link_rounded, size: 20),
    );
  }
}
