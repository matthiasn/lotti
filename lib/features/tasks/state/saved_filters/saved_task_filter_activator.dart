import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'saved_task_filter_activator.g.dart';

/// Applies a [SavedTaskFilter] to the live tasks page state.
///
/// The ephemeral search query is intentionally preserved across activations —
/// it is never part of a saved filter (the design treats it as a separate
/// concern from the persisted filter shape).
class SavedTaskFilterActivator {
  const SavedTaskFilterActivator(this._controller);

  final JournalPageController _controller;

  Future<void> activate(SavedTaskFilter saved) {
    final f = saved.filter;
    return _controller.applyBatchFilterUpdate(
      statuses: f.selectedTaskStatuses,
      categoryIds: f.selectedCategoryIds,
      labelIds: f.selectedLabelIds,
      projectIds: f.selectedProjectIds,
      priorities: f.selectedPriorities,
      sortOption: f.sortOption,
      agentAssignmentFilter: f.agentAssignmentFilter,
      showCreationDate: f.showCreationDate,
      showDueDate: f.showDueDate,
    );
  }
}

/// Builds a [TasksFilter] snapshot from the live tasks-page state for
/// comparison against persisted saved filters.
///
/// Mirrors the field set in [JournalPageController._persistTasksFilterWithoutRefresh],
/// minus the display-only `showCoverArt` / `showProjectsHeader` / `showDistances`
/// flags which the saved-filter UX intentionally ignores when matching.
TasksFilter _liveFilterFor(JournalPageState pageState) {
  return TasksFilter(
    selectedCategoryIds: pageState.selectedCategoryIds,
    selectedProjectIds: pageState.selectedProjectIds,
    selectedTaskStatuses: pageState.selectedTaskStatuses,
    selectedLabelIds: pageState.selectedLabelIds,
    selectedPriorities: pageState.selectedPriorities,
    sortOption: pageState.sortOption,
    showCreationDate: pageState.showCreationDate,
    showDueDate: pageState.showDueDate,
    agentAssignmentFilter: pageState.agentAssignmentFilter,
  );
}

/// Treat two [TasksFilter]s as equivalent when their saved-filter-relevant
/// fields agree. Display-only and persistence-only fields are ignored.
bool _matches(TasksFilter saved, TasksFilter live) {
  bool eq(Iterable<String> a, Iterable<String> b) {
    final sA = a.toSet();
    final sB = b.toSet();
    return sA.length == sB.length && sA.containsAll(sB);
  }

  return eq(saved.selectedCategoryIds, live.selectedCategoryIds) &&
      eq(saved.selectedProjectIds, live.selectedProjectIds) &&
      eq(saved.selectedTaskStatuses, live.selectedTaskStatuses) &&
      eq(saved.selectedLabelIds, live.selectedLabelIds) &&
      eq(saved.selectedPriorities, live.selectedPriorities) &&
      saved.sortOption == live.sortOption &&
      saved.showCreationDate == live.showCreationDate &&
      saved.showDueDate == live.showDueDate &&
      saved.agentAssignmentFilter == live.agentAssignmentFilter;
}

/// Returns true when the live tasks filter has at least one active clause
/// — non-empty selection sets, a non-default agent mode, or a non-default
/// sort. Display toggles do not count.
///
/// Sort is included because [_matches] also compares it: a saved filter that
/// differs only by sort would otherwise leave Save disabled even though the
/// live shape doesn't match any saved entry.
bool _hasActiveClauses(TasksFilter live) {
  return live.selectedTaskStatuses.isNotEmpty ||
      live.selectedCategoryIds.isNotEmpty ||
      live.selectedProjectIds.isNotEmpty ||
      live.selectedLabelIds.isNotEmpty ||
      live.selectedPriorities.isNotEmpty ||
      live.agentAssignmentFilter != AgentAssignmentFilter.all ||
      live.sortOption != TaskSortOption.byPriority;
}

/// id of the saved filter whose persisted shape matches the live tasks-page
/// filter, or null when no saved filter matches.
@riverpod
String? currentSavedTaskFilterId(Ref ref) {
  final pageState = ref.watch(journalPageControllerProvider(true));
  final saved =
      ref.watch(savedTaskFiltersControllerProvider).value ??
      const <SavedTaskFilter>[];
  if (saved.isEmpty) return null;
  final live = _liveFilterFor(pageState);
  for (final v in saved) {
    if (_matches(v.filter, live)) return v.id;
  }
  return null;
}

/// True when the live filter has clauses that don't match any saved filter
/// — the sidebar `+` and the modal Save button use this to decide whether
/// they're enabled.
@riverpod
bool tasksFilterHasUnsavedClauses(Ref ref) {
  final pageState = ref.watch(journalPageControllerProvider(true));
  final live = _liveFilterFor(pageState);
  if (!_hasActiveClauses(live)) return false;
  final matchedId = ref.watch(currentSavedTaskFilterIdProvider);
  return matchedId == null;
}

/// Snapshot of the live tasks filter shape — used by the modal save flow to
/// build a new [SavedTaskFilter] payload.
@riverpod
TasksFilter liveTasksFilter(Ref ref) {
  final pageState = ref.watch(journalPageControllerProvider(true));
  return _liveFilterFor(pageState);
}
