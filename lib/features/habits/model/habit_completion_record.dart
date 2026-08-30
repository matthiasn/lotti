import 'package:flutter/foundation.dart';
import 'package:lotti/classes/entity_definitions.dart';

/// The few fields every habit-completion consumer actually reads.
///
/// The habits controller and the heatmap both used to take
/// `List<JournalEntity>` and then touch only `data.habitId`,
/// `data.completionType` and `meta.dateFrom` — never the body, never the
/// vector clock, never anything else on the entity.
///
/// Carrying the whole entity was the expensive part. The 2026-06/07 slow-query
/// logs put `getHabitCompletionsInRange` at **636 ms average** over 14 days,
/// but the SQL itself measures ~29 ms on a comparable 10,000-row / 1,460-result
/// data set. The gap is the ~20 columns per row — including a fat `serialized`
/// JSON payload — crossing the isolate port, which the slow-query interceptor
/// measures because it wraps the executor on the calling side.
///
/// Projecting to these three fields in SQL removes that payload from the wire
/// entirely. See `docs/perf/2026-08-01_slow-queries-investigation.md`.
@immutable
class HabitCompletionRecord {
  const HabitCompletionRecord({
    required this.habitId,
    required this.dateFrom,
    this.completionType,
    this.source = HabitCompletionSource.manual,
    this.autoCompleteReason,
  });

  /// `json_extract(serialized, '$.data.habitId')`.
  final String habitId;

  /// The recorded wall-clock timestamp, from the serialized
  /// `meta.dateFrom` — **not** the `date_from` column.
  ///
  /// Same instant, different day: the column is a Unix epoch reconstructed in
  /// the reader's zone, so a completion entered at 23:30 in Berlin reads back
  /// as the next day in Auckland. The day this carries is the one it was
  /// recorded on, which is what every consumer means by "that day".
  final DateTime dateFrom;

  /// `json_extract(serialized, '$.data.completionType')`.
  ///
  /// Null is meaningful rather than missing data. Legacy entries written
  /// before the field existed carry it, and so does any completion type synced
  /// from a newer peer that this build cannot decode.
  ///
  /// Consumers treat it as **recorded, but not successful**: it counts in
  /// `allByDay` and the heatmap denominator, but not in streaks,
  /// `successfulByDay`, `successfulToday` or the heatmap's success numerator.
  final HabitCompletionType? completionType;

  /// `json_extract(serialized, '$.data.source')` — who wrote the completion.
  /// Missing or unrecognised values decode as manual, the value every entry
  /// written before the field existed carries.
  final HabitCompletionSource source;

  /// `json_extract(serialized, '$.data.autoCompleteReason')` — for an auto
  /// completion, the signal that fired, as the habit row shows it.
  final String? autoCompleteReason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitCompletionRecord &&
          other.habitId == habitId &&
          other.dateFrom == dateFrom &&
          other.completionType == completionType &&
          other.source == source &&
          other.autoCompleteReason == autoCompleteReason;

  @override
  int get hashCode => Object.hash(
    habitId,
    dateFrom,
    completionType,
    source,
    autoCompleteReason,
  );

  @override
  String toString() =>
      'HabitCompletionRecord(habitId: $habitId, dateFrom: $dateFrom, '
      'completionType: $completionType, source: $source, '
      'autoCompleteReason: $autoCompleteReason)';
}
