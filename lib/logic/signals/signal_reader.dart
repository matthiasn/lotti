import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/signals/signal_day_buckets.dart';
import 'package:lotti/logic/signals/signal_needs.dart';
import 'package:lotti/logic/signals/signal_window.dart';

/// Reads the journal into a [SignalWindow] — the seam between the database
/// and the pure evaluators.
///
/// The goals reader delegates its measurable and quantitative loading here
/// so both features bucket the same rows the same way; this class itself
/// knows nothing about goals or habits.
class SignalReader {
  const SignalReader({required this.journalDb});

  final JournalDb journalDb;

  /// Quantitative entities of [type] in `[rangeStart, rangeEnd)`, dropping
  /// rows written after [notAfter] so a live read and its parallel series
  /// describe one snapshot.
  Future<List<JournalEntity>> quantitativeEntities({
    required String type,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    DateTime? notAfter,
  }) async {
    final entities = await journalDb.getQuantitativeByType(
      type: type,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    if (notAfter == null) return entities;
    return entities
        .where((entity) => !entity.meta.dateFrom.isAfter(notAfter))
        .toList(growable: false);
  }

  /// Measurement entities of measurable [dataTypeId] in the range.
  Future<List<JournalEntity>> measurableEntities({
    required String dataTypeId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) => journalDb.getMeasurementsByType(
    type: dataTypeId,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
  );

  /// Every series an [AutoCompleteRule] tree needs, covering [days] calendar
  /// days ending on [reference]'s day (so `days: 14` is a two-week window
  /// including today). Entries after [reference] are excluded.
  Future<SignalWindow> read({
    required AutoCompleteRule rule,
    required DateTime reference,
    int days = 14,
  }) async {
    assert(days > 0, 'a signal window covers at least one day');
    final needs = SignalNeeds.of(rule);
    final end = signalDayKey(reference);
    final start = end.subtract(Duration(days: days - 1));
    // Local wall-clock bounds for the DB range query; the end is the next
    // local midnight built by component so a DST fall-back day keeps its
    // final hour.
    final rangeStart = DateTime(start.year, start.month, start.day);
    final rangeEnd = DateTime(
      reference.year,
      reference.month,
      reference.day + 1,
    );

    final quantitative = <String, Map<DateTime, num>>{};
    for (final type in needs.quantitativeTypes) {
      final entities = await quantitativeEntities(
        type: type,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        notAfter: reference,
      );
      quantitative[type] = bucketQuantitativeByDay(entities, type);
    }

    final measurables = <String, Map<DateTime, num>>{};
    for (final id in needs.measurableIds) {
      final entities = await measurableEntities(
        dataTypeId: id,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
      measurables[id] = bucketMeasurableTotalsByDay(
        entities
            .where((entity) => !entity.meta.dateFrom.isAfter(reference))
            .toList(growable: false),
      );
    }

    final habits = <String, Set<DateTime>>{};
    for (final habitId in needs.habitIds) {
      final entities = await journalDb.getHabitCompletionsByHabitId(
        habitId: habitId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
      habits[habitId] = habitSuccessDays(entities);
    }

    return SignalWindow(
      start: start,
      end: end,
      quantitativeByDay: quantitative,
      measurableTotalsByDay: measurables,
      habitSuccessDays: habits,
    );
  }
}
