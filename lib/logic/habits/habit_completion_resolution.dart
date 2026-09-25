import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/date_utils_extension.dart';

/// Stable key for the daily last-write-wins habit completion contract.
String habitCompletionDayKey(HabitCompletionEntry entry) =>
    '${entry.data.habitId}:${entry.meta.dateFrom.ymd}';

/// Orders the completions of one habit/day by which one settles the day: a
/// person's own entry above any automatic one, then write recency.
///
/// The auto-completion engine only fills a day it sees empty, but another
/// device may have recorded the day before that record syncs. Pure recency
/// would then let the later automatic success replace the person's skip on
/// every replica — the counterexample `specs/tla/HabitDaySettlement.tla`
/// finds under its "recency" order. Ranking the source first keeps "manual
/// beats auto" true across devices, not only on the one that wrote.
///
/// The effective day is carried by `dateFrom`; write recency is carried by
/// metadata timestamps. Tie-breakers keep legacy rows deterministic even when
/// old imports have coarse timestamps, and the id makes this a total order, so
/// every replica settles the same rows the same way. The SQL ranking in
/// `getHabitCompletionRecordsInRange` must order identically.
int compareHabitCompletionPrecedence(
  HabitCompletionEntry a,
  HabitCompletionEntry b,
) {
  final sourceCompare = _sourceRank(a).compareTo(_sourceRank(b));
  if (sourceCompare != 0) return sourceCompare;

  final updatedAtCompare = a.meta.updatedAt.compareTo(b.meta.updatedAt);
  if (updatedAtCompare != 0) return updatedAtCompare;

  final createdAtCompare = a.meta.createdAt.compareTo(b.meta.createdAt);
  if (createdAtCompare != 0) return createdAtCompare;

  final dateToCompare = a.meta.dateTo.compareTo(b.meta.dateTo);
  if (dateToCompare != 0) return dateToCompare;

  return a.meta.id.compareTo(b.meta.id);
}

int _sourceRank(HabitCompletionEntry entry) =>
    entry.data.source == HabitCompletionSource.auto ? 0 : 1;

/// Returns one habit completion per habit/day: the one that settles it under
/// [compareHabitCompletionPrecedence].
List<HabitCompletionEntry> latestHabitCompletionsByDay(
  Iterable<JournalEntity> entities,
) {
  final latestByDay = <String, HabitCompletionEntry>{};

  for (final entity in entities) {
    if (entity is! HabitCompletionEntry) continue;

    final key = habitCompletionDayKey(entity);
    final existing = latestByDay[key];
    if (existing == null ||
        compareHabitCompletionPrecedence(existing, entity) < 0) {
      latestByDay[key] = entity;
    }
  }

  return latestByDay.values.toList()..sort((a, b) {
    final dateFromCompare = a.meta.dateFrom.compareTo(b.meta.dateFrom);
    if (dateFromCompare != 0) return dateFromCompare;

    return a.data.habitId.compareTo(b.data.habitId);
  });
}
