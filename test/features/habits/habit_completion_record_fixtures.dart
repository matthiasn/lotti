import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/habits/model/habit_completion_record.dart';

/// Projects an existing `HabitCompletionEntry` fixture onto the lean
/// [HabitCompletionRecord] the habits reads now return.
///
/// The fixtures stay entity-shaped because that is what the write side of these
/// tests builds; this keeps the read side honest without duplicating every
/// fixture in two forms.
HabitCompletionRecord habitCompletionRecordFrom(HabitCompletionEntry entry) {
  return HabitCompletionRecord(
    habitId: entry.data.habitId,
    dateFrom: entry.meta.dateFrom,
    completionType: entry.data.completionType,
  );
}

/// [habitCompletionRecordFrom] over a list, skipping anything that is not a
/// habit completion — mirroring the SQL, which only ever selects
/// `type = 'HabitCompletionEntry'`.
List<HabitCompletionRecord> habitCompletionRecordsFrom(
  Iterable<JournalEntity> entries,
) {
  return entries
      .whereType<HabitCompletionEntry>()
      .map(habitCompletionRecordFrom)
      .toList();
}
