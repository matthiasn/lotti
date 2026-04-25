import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_persistence.dart';
import 'package:lotti/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'saved_task_filters_controller.g.dart';

/// Riverpod controller backing the user's pinned task-filter list.
///
/// State is the ordered list of [SavedTaskFilter]s. Position in the list is
/// the sort order. Mutations write through to [SavedTaskFiltersPersistence]
/// after each operation.
@Riverpod(keepAlive: true)
class SavedTaskFiltersController extends _$SavedTaskFiltersController {
  late final SavedTaskFiltersPersistence _persistence;
  final Uuid _uuid = const Uuid();

  @override
  Future<List<SavedTaskFilter>> build() async {
    _persistence = SavedTaskFiltersPersistence(getIt<SettingsDb>());
    return _persistence.load();
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
    final saved = SavedTaskFilter(
      id: _uuid.v4(),
      name: name,
      filter: filter,
    );
    final next = [...current, saved];
    state = AsyncData(next);
    await _persistence.save(next);
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

    final next = [...current];
    next[idx] = current[idx].copyWith(name: trimmed);
    state = AsyncData(next);
    await _persistence.save(next);
  }

  /// Replaces the filter payload of the saved filter with [id].
  ///
  /// Used when "Update '`<name>`'" is invoked from the modal — the saved view
  /// keeps its name and id but takes on the currently-active filter shape.
  Future<void> updateFilter(String id, TasksFilter filter) async {
    final current = await future;
    final idx = current.indexWhere((SavedTaskFilter f) => f.id == id);
    if (idx < 0) return;

    final next = [...current];
    next[idx] = current[idx].copyWith(filter: filter);
    state = AsyncData(next);
    await _persistence.save(next);
  }

  /// Removes the saved filter with [id]. No-op when missing.
  Future<void> delete(String id) async {
    final current = await future;
    if (!current.any((SavedTaskFilter f) => f.id == id)) return;
    final next = current
        .where((SavedTaskFilter f) => f.id != id)
        .toList(growable: false);
    state = AsyncData(next);
    await _persistence.save(next);
  }

  /// Moves the saved filter [dragId] to the position currently held by
  /// [targetId]. The dragged row is inserted at the target's index, shifting
  /// the rest. No-op when ids match or are missing.
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
    await _persistence.save(next);
  }
}
