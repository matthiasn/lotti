import 'dart:async';

import 'package:flutter/material.dart';
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
  final ValueChanged<Task> onTaskSelected;

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
  Set<String> _fts5Matches = {};

  /// Full-text hits that fall outside the prefetched window, fetched by id.
  /// Kept separate from [_tasks] so clearing the query drops them again.
  List<Task> _resolvedMatches = const [];

  /// Tasks created from a search miss during this session. Held so the pick
  /// handler can resolve the id the picker hands back — the freshly created
  /// task is in neither the prefetch nor the full-text results.
  List<Task> _createdTasks = const [];

  /// The query [_resolvedMatches] and [_fts5Matches] currently describe, or
  /// null before the first lookup resolves. Anything reading the pool to
  /// decide a task does *not* exist has to know the pool is current.
  String? _resolvedQuery;

  /// Every task a row can be built from. Both the row builder and the pick
  /// handler must read this same list: building rows from a wider set than
  /// picks are resolved against is what let a rendered row throw on tap.
  List<Task> get _candidatePool => [
    ..._tasks,
    ..._resolvedMatches,
    ..._createdTasks,
  ];
  bool _isLoading = true;
  String? _lastFetchedQuery;

  final JournalDb _db = getIt<JournalDb>();
  final Fts5Db _fts5Db = getIt<Fts5Db>();

  // Guards against out-of-order FTS5 resolution: typing isn't debounced, so
  // an older keystroke's lookup can resolve after a newer one's and overwrite
  // fresh matches with stale ones.
  int _searchGeneration = 0;

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
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchFts5(String query) async {
    final generation = ++_searchGeneration;

    try {
      final matches = (await _fts5Db.watchFullTextMatches(query).first).toSet();

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

      if (mounted && generation == _searchGeneration) {
        setState(() {
          _fts5Matches = matches;
          _resolvedMatches = resolved;
          _resolvedQuery = query.trim();
        });
      }
    } catch (e) {
      if (mounted && generation == _searchGeneration) {
        setState(() {
          _fts5Matches = {};
          _resolvedMatches = const [];
          // A failed lookup still resolves the query: the pool is as complete
          // as it is going to get, so the create row must not stay withheld
          // forever on a database that is simply unavailable.
          _resolvedQuery = query.trim();
        });
      }
    }
  }

  /// [EntityPickerSheet] calls this synchronously on every keystroke (and
  /// every rebuild); a distinct query kicks off the async FTS5 lookup exactly
  /// once (guarded by [_lastFetchedQuery]) and its result arrives later via
  /// [_fetchFts5]'s own `setState`, well outside this build pass.
  List<PickerItem> _entriesBuilder(String query) {
    if (query != _lastFetchedQuery) {
      _lastFetchedQuery = query;
      if (query.isEmpty) {
        _fts5Matches = {};
        _resolvedMatches = const [];
        _resolvedQuery = null;
      } else {
        unawaited(_fetchFts5(query));
      }
    }

    final candidates = _candidatePool.where(
      (task) => !widget.excludeIds.contains(task.meta.id),
    );
    final queryLower = query.toLowerCase();
    final filtered = query.isEmpty
        ? candidates
        : candidates.where(
            (task) =>
                _fts5Matches.contains(task.meta.id) ||
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
              Icons.add_link,
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
    setState(() => _createdTasks = [..._createdTasks, created]);
    return created.meta.id;
  }

  /// Offer the create row on an exact-title miss, matching the category and
  /// label pickers: typing "Migrate" still offers to create it even when
  /// "Migrate the database" already exists, because the shorter title is a
  /// legitimately different task.
  ///
  /// Withheld until the query's full-text lookup has resolved. On a backlog
  /// larger than the 200-row prefetch an exact-title match can live outside
  /// the window, so [_candidatePool] does not contain it yet — offering the
  /// create row in that gap invites a duplicate of a task that already
  /// exists, which is precisely what the exact-title check exists to prevent.
  bool _shouldShowCreate(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed != _resolvedQuery) return false;
    final lowered = trimmed.toLowerCase();
    // Against the same filtered set the rows are built from. Checked against
    // the raw pool, a query exactly matching an *excluded* task — the anchor
    // itself, or one already holding this relation — hid every row (excluded)
    // and suppressed the create row too (the excluded task counted as an
    // existing duplicate), leaving a dead end with neither.
    return !_candidatePool
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
      onPick: (id) {
        final picked = _candidatePool
            .where((task) => task.meta.id == id)
            .firstOrNull;
        if (picked != null) widget.onTaskSelected(picked);
      },
      createFromQuery: widget.onCreateTask == null ? null : _createFromQuery,
      shouldShowCreate: _shouldShowCreate,
      createRowKey: const ValueKey('link-picker-create'),
      createSemanticsLabel: context.messages.linkPickerCreateTaskSemanticLabel,
    );
  }
}
