import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/date_utils_extension.dart';

/// Stable key for the daily last-write-wins habit completion contract.
String habitCompletionDayKey(HabitCompletionEntry entry) =>
    '${entry.data.habitId}:${entry.meta.dateFrom.ymd}';

/// Orders habit completion entries by write recency.
///
/// The effective day is carried by `dateFrom`; write recency is carried by
/// metadata timestamps. Tie-breakers keep legacy rows deterministic even when
/// old imports have coarse timestamps.
int compareHabitCompletionWriteRecency(
  HabitCompletionEntry a,
  HabitCompletionEntry b,
) {
  final updatedAtCompare = a.meta.updatedAt.compareTo(b.meta.updatedAt);
  if (updatedAtCompare != 0) return updatedAtCompare;

  final createdAtCompare = a.meta.createdAt.compareTo(b.meta.createdAt);
  if (createdAtCompare != 0) return createdAtCompare;

  final dateToCompare = a.meta.dateTo.compareTo(b.meta.dateTo);
  if (dateToCompare != 0) return dateToCompare;

  return a.meta.id.compareTo(b.meta.id);
}

/// Returns one habit completion per habit/day, preserving the latest write.
List<HabitCompletionEntry> latestHabitCompletionsByDay(
  Iterable<JournalEntity> entities,
) {
  final latestByDay = <String, HabitCompletionEntry>{};

  for (final entity in entities) {
    if (entity is! HabitCompletionEntry) continue;

    final key = habitCompletionDayKey(entity);
    final existing = latestByDay[key];
    if (existing == null ||
        compareHabitCompletionWriteRecency(existing, entity) < 0) {
      latestByDay[key] = entity;
    }
  }

  return latestByDay.values.toList()..sort((a, b) {
    final dateFromCompare = a.meta.dateFrom.compareTo(b.meta.dateFrom);
    if (dateFromCompare != 0) return dateFromCompare;

    return a.data.habitId.compareTo(b.data.habitId);
  });
}
