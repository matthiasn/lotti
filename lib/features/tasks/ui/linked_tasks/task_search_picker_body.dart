import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/picker/entity_picker_sheet.dart';
import 'package:material_ui/material_ui.dart';

/// Search-and-pick body shared by `LinkTaskModal` and `BlockingTaskPickerModal`:
/// loads open tasks (bounded, non-closed), filters by FTS5 match or title
/// substring as the user types, and renders results through the shared
/// [EntityPickerSheet] (the same search-and-pick component categories and
/// labels use) with loading/empty states. Knows nothing about link types,
/// persistence, or navigation — callers own what happens when a task is
/// picked via [onTaskSelected].
class TaskSearchPickerBody extends StatefulWidget {
  const TaskSearchPickerBody({
    required this.excludeIds,
    required this.onTaskSelected,
    this.taskStatuses = allTaskStatuses,
    this.topInset = true,
    this.onCreateTask,
    super.key,
  });

  /// Task ids to exclude from the candidate list (e.g. the current/anchor
  /// task, tasks already linked with the relationship being created).
  final Set<String> excludeIds;

  /// Called when the user taps a result. The body does not close itself or
  /// persist anything — the caller decides what selecting a task means.
  ///
  /// Returns a future when the caller writes something (the link modal does),
  /// so the picker's create lock can be held until that write lands rather
  /// than until the callback merely returns.
  final FutureOr<void> Function(Task task) onTaskSelected;

  /// Statuses a candidate may hold. Defaults to every status: "Follows up
  /// on", "Duplicates", "Fixes" and "Supersedes" all routinely reference work
  /// that is already finished, and excluding closed tasks made those links
  /// impossible to express while the modal reported "No tasks found" for a
  /// task the user could see elsewhere in the app. The blocker picker narrows
  /// this to open statuses, since a finished task cannot block anything.
  final List<String> taskStatuses;

  /// False when this body sits below other modal content that already
  /// supplies the gap under the header (the link modal's relation dropdown).
  final bool topInset;

  /// Creates a task titled after the current query, or null on failure.
  ///
  /// Supplied, a search that matches nothing offers to create the task the
  /// user just described instead of dead-ending on "No tasks found" — the
  /// query is already the title. The created task is fed straight back
  /// through [onTaskSelected], so creating and picking are the same act and
  /// the caller's linking, confirmation and undo all happen unchanged.
  ///
  /// Null (the default) leaves the picker search-only.
  final Future<Task?> Function(String title)? onCreateTask;

  @override
  State<TaskSearchPickerBody> createState() => _TaskSearchPickerBodyState();
}

class _TaskSearchPickerBodyState extends State<TaskSearchPickerBody> {
  List<Task> _tasks = [];

  /// The ids that matched [_matchedQuery] in the full-text index.
  Set<String> _fts5Matches = const {};

  /// Full-text hits that fall outside the prefetched window, fetched by id.
  /// Kept separate from [_tasks] so they only ever count for the query that
  /// found them.
  List<Task> _resolvedMatches = const [];

  /// Tasks created from a search miss during this session. Held so the pick
  /// handler can resolve the id the picker hands back — the freshly created
  /// task is in neither the prefetch nor the full-text results.
  List<Task> _createdTasks = const [];

  /// The trimmed query [_fts5Matches] and [_resolvedMatches] describe, or null
  /// before any lookup has run.
  ///
  /// Results for a *different* query are ignored rather than cleared, so a
  /// cleared search shows the same list a freshly opened picker does without
  /// anything having to be mutated mid-build to make that true.
  String? _matchedQuery;

  bool _isLoading = true;

  final JournalDb _db = getIt<JournalDb>();
  final Fts5Db _fts5Db = getIt<Fts5Db>();

  /// Guards against out-of-order resolution: a lookup for a query the user has
  /// already left can still land after a newer one, and must not overwrite the
  /// fresher matches.
  int _searchGeneration = 0;

  /// The tasks a row may be built from for [query], and the same set
  /// [_shouldShowCreate] weighs before offering to create a duplicate.
  List<Task> _candidatePool(String query) => [
    ..._tasks,
    if (query.isNotEmpty && query == _matchedQuery) ..._resolvedMatches,
    ..._createdTasks,
  ];

  /// Every task this picker has *ever* been able to show, by id.
  ///
  /// Accumulates rather than mirroring the latest lookup, because `setState`
  /// only schedules a repaint: rows built for the previous query stay mounted
  /// and hit-testable for a frame after a newer lookup has already replaced
  /// [_resolvedMatches]. A tap landing in that window has to resolve against
  /// something that still knows the old row, or it is silently dropped —
  /// reading the live lists here made the invariant this exists for
  /// ("a pick can always resolve a row that was on screen") false.
  ///
  /// Bounded by the tasks one picker session surfaces: the prefetch window
  /// plus a handful of full-text hits per query.
  final Map<String, Task> _pickable = {};

  void _registerPickable(Iterable<Task> tasks) {
    for (final task in tasks) {
      _pickable[task.meta.id] = task;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);

    try {
      // Every category plus '' for uncategorized. An empty list does NOT mean
      // "no category filter" — the query builder short-circuits it to
      // `WHERE 1 = 0` (database_task_query_builders.dart), so passing []
      // returned nothing at all in production while every mocked test passed.
      // JournalQueryRunner expands the same way for the same reason.
      final categoryIds = [
        ...getIt<EntitiesCacheService>().sortedCategories.map((c) => c.id),
        '',
      ];

      final tasks = await _db.getTasks(
        starredStatuses: [false, true],
        taskStatuses: widget.taskStatuses,
        categoryIds: categoryIds,
        limit: 200,
      );

      if (mounted) {
        setState(() {
          _tasks = tasks.whereType<Task>().toList();
          _registerPickable(_tasks);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Loads the full-text hits for [query] into the fields the row builder and
  /// the create-row check read.
  ///
  /// The picker awaits this *before* it advances to [query], which is why this
  /// deliberately does not `setState`: the picker's own commit is the rebuild,
  /// and it happens in the frame that starts using these results. Rebuilding
  /// here would paint one frame of the previous query's rows filtered by this
  /// query's matches — the flicker this indirection exists to remove.
  Future<void> _resolveQuery(String query) async {
    final generation = ++_searchGeneration;
    final trimmed = query.trim();

    try {
      final matches = (await _fts5Db.watchFullTextMatches(trimmed).first)
          .toSet();

      // Resolve the hits the prefetch never loaded. Intersecting matches
      // against the preloaded window instead meant that on a backlog larger
      // than the window, a task that exists and matches was reported as "No
      // tasks found" — the picker stating confidently that it isn't there.
      final unloaded = matches.difference(
        _tasks.map((task) => task.meta.id).toSet(),
      );
      final resolved = unloaded.isEmpty
          ? const <Task>[]
          : (await _db.getJournalEntitiesForIds(unloaded))
                .whereType<Task>()
                .where(
                  (task) => widget.taskStatuses.contains(
                    task.data.status.toDbString,
                  ),
                )
                .toList();

      if (generation != _searchGeneration) return;
      _fts5Matches = matches;
      _resolvedMatches = resolved;
      _registerPickable(resolved);
      _matchedQuery = trimmed;
    } catch (e) {
      if (generation != _searchGeneration) return;
      // A failed lookup still counts as resolved: the pool is as complete as
      // it is going to get, so the create row must not stay withheld forever
      // on a database that is simply unavailable.
      _fts5Matches = const {};
      _resolvedMatches = const [];
      _matchedQuery = trimmed;
    }
  }

  /// Builds the rows for [query], which the picker only ever passes once
  /// [_resolveQuery] has finished for it. Pure: no lookup is started here, so
  /// a rebuild for any other reason cannot kick off database work.
  List<PickerItem> _entriesBuilder(String query) {
    final candidates = _candidatePool(
      query,
    ).where((task) => !widget.excludeIds.contains(task.meta.id));
    final queryLower = query.toLowerCase();
    final matches = query == _matchedQuery ? _fts5Matches : const <String>{};
    final filtered = query.isEmpty
        ? candidates
        : candidates.where(
            (task) =>
                matches.contains(task.meta.id) ||
                task.data.title.toLowerCase().contains(queryLower),
          );

    final tokens = context.designTokens;
    return [
      for (final task in filtered)
        PickerItem(
          id: task.meta.id,
          leading: StatusGlyph(status: task.data.status),
          title: task.data.title,
          subtitle: taskLabelFromStatusString(
            task.data.status.toDbString,
            context,
          ),
          // The same status metadata the card renders one tap away, at the
          // same ink — it was reading a rank louder here than there.
          subtitleEmphasis: tokens.colors.text.lowEmphasis,
          // These rows are one tap from the linked-tasks card's rows and read
          // identically — same glyph, title and status — but tapping here
          // *creates a link* where tapping there opens the task. The trailing
          // mark is the only thing that says which, so it is not decoration:
          // it is the difference between the two gestures.
          badges: [
            Icon(
              LottiIcons.link,
              size: tokens.spacing.step5,
              // Not below the status text beside it: this glyph is the only
              // thing distinguishing a row that commits from one that
              // navigates, so it cannot be the quietest mark on the row.
              color: tokens.colors.interactive.enabled,
            ),
          ],
        ),
    ];
  }

  /// Creates the task and registers it locally, returning the id the picker
  /// then feeds back through its own pick callback — which is what links it.
  /// Creating and picking are deliberately the same act: the caller's link,
  /// confirmation and undo path stay one code path rather than two that must
  /// agree.
  Future<String?> _createFromQuery(String query) async {
    final created = await widget.onCreateTask!(query.trim());
    if (created == null || !mounted) return null;
    setState(() {
      _createdTasks = [..._createdTasks, created];
      _registerPickable([created]);
    });
    return created.meta.id;
  }

  /// Offer the create row on an exact-title miss, matching the category and
  /// label pickers: typing "Migrate" still offers to create it even when
  /// "Migrate the database" already exists, because the shorter title is a
  /// legitimately different task.
  ///
  /// The picker only asks this for a query whose full-text lookup has already
  /// landed, which is what makes the check safe: on a backlog larger than the
  /// 200-row prefetch an exact-title match can live outside the window, and
  /// offering the create row before that hit is in the pool would invite a
  /// duplicate of a task that already exists.
  bool _shouldShowCreate(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return false;
    final lowered = trimmed.toLowerCase();
    // Against the same filtered set the rows are built from. Checked against
    // the raw pool, a query exactly matching an *excluded* task — the anchor
    // itself, or one already holding this relation — hid every row (excluded)
    // and suppressed the create row too (the excluded task counted as an
    // existing duplicate), leaving a dead end with neither.
    return !_candidatePool(trimmed)
        .where((task) => !widget.excludeIds.contains(task.meta.id))
        .any((task) => task.data.title.trim().toLowerCase() == lowered);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: DesignSystemSpinner());
    }

    final hasCandidates = _tasks.any(
      (task) => !widget.excludeIds.contains(task.meta.id),
    );

    return EntityPickerSheet(
      mode: PickerMode.single,
      entriesBuilder: _entriesBuilder,
      // The rows for a query depend on a database lookup, so the picker waits
      // for it: one settled result set per pause in typing, instead of a
      // recompute per keystroke against results still in flight.
      onQueryResolve: _resolveQuery,
      // Task titles are sentences, not short entity names — one line truncates
      // real words away on the row whose tap immediately commits the link.
      titleMaxLines: 2,
      topInset: widget.topInset,
      // Same rank as the linked-tasks card row: one task title, one size,
      // whether it is read on the card or in this modal one tap away.
      rowSize: DesignSystemListItemSize.small,
      searchHintText: context.messages.searchTasksHint,
      emptyMessage: hasCandidates
          ? context.messages.noTasksFound
          : context.messages.noTasksToLink,
      // Resolved against the same pool the rows were built from. Reading
      // _tasks alone threw on any row that came from a full-text match outside
      // the prefetch window — the picker rendered the task, then died on the
      // tap.
      onPick: (id) async {
        final picked = _pickable[id];
        if (picked != null) await widget.onTaskSelected(picked);
      },
      createFromQuery: widget.onCreateTask == null ? null : _createFromQuery,
      shouldShowCreate: _shouldShowCreate,
      createRowKey: const ValueKey('link-picker-create'),
      createSemanticsLabel: context.messages.linkPickerCreateTaskSemanticLabel,
    );
  }
}
