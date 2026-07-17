import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:uuid/uuid.dart';

/// Maximum number of saved task views rendered as ambient sidebar monitors.
const int maxSidebarPinnedTaskFilters = 5;

enum SavedTaskFilterPinResult { updated, unchanged, limitReached }

/// Riverpod controller backing the user's pinned task-filter list.
///
/// State is the ordered list of [SavedTaskFilter]s. Position in the list is
/// the sort order. Mutations are routed through [SavedTaskFiltersRepository] so
/// every create/rename/update/delete persists locally *and* enqueues a
/// per-item sync message for peers. Reorders stay local (order is per-device).
class SavedTaskFiltersController extends AsyncNotifier<List<SavedTaskFilter>> {
  late final SavedTaskFiltersRepository _repository;
  final Uuid _uuid = const Uuid();

  /// Clock seam so tests can pin the `createdAt` / `updatedAt` stamps. Defaults
  /// to the wall clock in production.
  @visibleForTesting
  DateTime Function() now = DateTime.now;

  @override
  Future<List<SavedTaskFilter>> build() async {
    _repository = getIt<SavedTaskFiltersRepository>();
    return _repository.load();
  }

  /// Appends a new saved filter built from [filter] with the given [name].
  ///
  /// Returns the newly-created [SavedTaskFilter] so callers can mark it as
  /// the currently-active saved view in the page state.
  Future<SavedTaskFilter> create({
    required String name,
    required TasksFilter filter,
  }) async {
    final current = await future;
    final timestamp = now();
    final saved = SavedTaskFilter(
      id: _uuid.v4(),
      name: name,
      filter: filter,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    state = AsyncData([...current, saved]);
    await _repository.upsert(saved);
    return saved;
  }

  /// Renames the saved filter with [id]. No-op when [id] is missing or the
  /// trimmed name is empty / unchanged.
  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final current = await future;
    final idx = current.indexWhere((SavedTaskFilter f) => f.id == id);
    if (idx < 0) return;
    if (current[idx].name == trimmed) return;

    final updated = current[idx].copyWith(name: trimmed, updatedAt: now());
    final next = [...current];
    next[idx] = updated;
    state = AsyncData(next);
    await _repository.upsert(updated);
  }

  /// Replaces the filter payload of the saved filter with [id].
  ///
  /// Used when "Update '`<name>`'" is invoked from the modal — the saved view
  /// keeps its name and id but takes on the currently-active filter shape.
  Future<void> updateFilter(String id, TasksFilter filter) async {
    final current = await future;
    final idx = current.indexWhere((SavedTaskFilter f) => f.id == id);
    if (idx < 0) return;

    final updated = current[idx].copyWith(filter: filter, updatedAt: now());
    final next = [...current];
    next[idx] = updated;
    state = AsyncData(next);
    await _repository.upsert(updated);
  }

  /// Pins or unpins a saved view in the desktop sidebar.
  ///
  /// At most [maxSidebarPinnedTaskFilters] views may be pinned. Membership is
  /// synced as part of the saved-view definition; display order follows the
  /// existing per-device saved-view order.
  Future<SavedTaskFilterPinResult> setSidebarPinned(
    String id, {
    required bool pinned,
  }) async {
    final current = await future;
    final idx = current.indexWhere((SavedTaskFilter f) => f.id == id);
    if (idx < 0 || current[idx].pinnedToSidebar == pinned) {
      return SavedTaskFilterPinResult.unchanged;
    }
    if (pinned &&
        current.where((filter) => filter.pinnedToSidebar).length >=
            maxSidebarPinnedTaskFilters) {
      return SavedTaskFilterPinResult.limitReached;
    }

    final updated = current[idx].copyWith(
      pinnedToSidebar: pinned,
      updatedAt: now(),
    );
    final next = [...current];
    next[idx] = updated;
    state = AsyncData(next);
    await _repository.upsert(updated);
    return SavedTaskFilterPinResult.updated;
  }

  /// Removes the saved filter with [id]. No-op when missing.
  Future<void> delete(String id) async {
    final current = await future;
    if (!current.any((SavedTaskFilter f) => f.id == id)) return;
    final next = current
        .where((SavedTaskFilter f) => f.id != id)
        .toList(growable: false);
    state = AsyncData(next);
    await _repository.delete(id);
  }

  /// Moves the saved filter [dragId] to the position currently held by
  /// [targetId]. The dragged row is inserted at the target's index, shifting
  /// the rest. No-op when ids match or are missing.
  ///
  /// Order is per-device, so reorders persist locally without enqueuing sync.
  Future<void> reorder(String dragId, String targetId) async {
    if (dragId == targetId) return;

    final current = await future;
    final fromIdx = current.indexWhere((SavedTaskFilter f) => f.id == dragId);
    final toIdx = current.indexWhere((SavedTaskFilter f) => f.id == targetId);
    if (fromIdx < 0 || toIdx < 0) return;

    final next = [...current];
    final item = next.removeAt(fromIdx);
    next.insert(toIdx, item);
    state = AsyncData(next);
    await _repository.saveOrder(next);
  }
}

/// Provider exposing the [SavedTaskFiltersController].
final savedTaskFiltersControllerProvider =
    AsyncNotifierProvider<SavedTaskFiltersController, List<SavedTaskFilter>>(
      SavedTaskFiltersController.new,
      name: 'savedTaskFiltersControllerProvider',
    );
