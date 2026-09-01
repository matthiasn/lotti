import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';

/// Whether saving [next] over [previous] changes what a recorded choice reads
/// as: a title that differs for any choice id [next] still lists. Adding,
/// archiving or reordering choices changes nothing already indexed; a
/// definition seen for the first time has nothing indexed under it yet.
bool choiceTitlesChanged(
  MeasurableDataType? previous,
  MeasurableDataType next,
) {
  if (previous == null) return false;
  final before = {
    for (final choice in previous.choices ?? const <MeasurableChoice>[])
      choice.id: choice.title,
  };
  for (final choice in next.choices ?? const <MeasurableChoice>[]) {
    final old = before[choice.id];
    if (old != null && old != choice.title) return true;
  }
  return false;
}

/// Rewrites the full-text rows of every measurement of [dataType] so they
/// carry its choices' current titles.
///
/// The index stores a measurement's summary — name and value, the choice's
/// title for a choice recording — at insert time, so a renamed choice would
/// otherwise keep matching its old name and never its new one. The
/// `EntitiesCacheService` the index resolves titles through reloads on the
/// definition's own notification; [dataType] is therefore stamped into it
/// first, so the rows are written with the saved titles rather than whatever
/// the cache still held.
Future<void> reindexMeasurementsForChoiceTitles({
  required JournalDb journalDb,
  required Fts5Db fts5Db,
  required Map<String, MeasurableDataType> cachedDataTypes,
  required MeasurableDataType dataType,
}) async {
  cachedDataTypes[dataType.id] = dataType;
  final entries = await journalDb.getMeasurementsByType(
    type: dataType.id,
    rangeStart: DateTime(1970),
    rangeEnd: DateTime(2100),
  );
  for (final entry in entries) {
    if (entry is! MeasurementEntry || entry.data.choiceId == null) continue;
    await fts5Db.insertText(entry, removePrevious: true);
  }
}
