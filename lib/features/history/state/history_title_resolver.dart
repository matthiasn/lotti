import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/history/domain/history_entry.dart';

/// Identifies one entity across the kinds the history records.
typedef HistoryEntityKey = (HistoryEntityKind, String);

HistoryEntityKey historyEntityKeyOf(HistoryTarget target) =>
    (target.kind, target.entityId);

/// Reads the current title of the entities a page of history points at.
///
/// The history stores no titles: a task renamed after it was opened shows
/// its new name, and one titled only after it was first opened shows that
/// title rather than nothing.
class HistoryTitleResolver {
  HistoryTitleResolver(this._journalDb);

  final JournalDb _journalDb;

  /// The current title of every target that still exists, keyed by
  /// [historyEntityKeyOf]. A target that is deleted — or private while
  /// private entries are hidden — has no key, and reads as gone.
  ///
  /// Journal-backed kinds are read in one batch; dashboards and habits, of
  /// which a page holds a handful at most, one by one.
  Future<Map<HistoryEntityKey, String>> currentTitles(
    Iterable<HistoryTarget> targets,
  ) async {
    final keys = targets.map(historyEntityKeyOf).toSet();
    final journalIds = {
      for (final (kind, id) in keys)
        if (_isJournalKind(kind)) id,
    };
    final entities = {
      for (final entity in await _journalDb.getJournalEntitiesForIds(
        journalIds,
      ))
        if (!entity.isDeleted) entity.id: entity,
    };

    final titles = <HistoryEntityKey, String>{};
    for (final key in keys) {
      final (kind, id) = key;
      final title = switch (kind) {
        HistoryEntityKind.dashboard => switch (await _journalDb
            .getDashboardById(id)) {
          final dashboard? when dashboard.deletedAt == null => dashboard.name,
          _ => null,
        },
        HistoryEntityKind.habit => switch (await _journalDb.getHabitById(id)) {
          final habit? when habit.deletedAt == null => habit.name,
          _ => null,
        },
        _ => switch (entities[id]) {
          final entity? => historyTitleOf(entity),
          null => null,
        },
      };
      if (title != null) titles[key] = title;
    }
    return titles;
  }

  static bool _isJournalKind(HistoryEntityKind kind) => switch (kind) {
    HistoryEntityKind.task ||
    HistoryEntityKind.entry ||
    HistoryEntityKind.project ||
    HistoryEntityKind.event ||
    HistoryEntityKind.person => true,
    HistoryEntityKind.dashboard || HistoryEntityKind.habit => false,
  };
}

/// The title a journal entity is known by: its own title field where it has
/// one, otherwise the first line of its text. Empty for an entity with
/// neither — the page then shows a placeholder.
String historyTitleOf(JournalEntity entity) {
  final title = switch (entity) {
    Task(:final data) => data.title,
    ProjectEntry(:final data) => data.title,
    JournalEvent(:final data) => data.title,
    RelationshipEntry(:final data) => data.title,
    GoalEntry(:final data) => data.title,
    Checklist(:final data) => data.title,
    ChecklistItem(:final data) => data.title,
    _ => _firstLine(entity.entryText?.plainText),
  };
  return title.trim();
}

String _firstLine(String? text) {
  if (text == null) return '';
  for (final line in text.split('\n')) {
    if (line.trim().isNotEmpty) return line;
  }
  return '';
}
