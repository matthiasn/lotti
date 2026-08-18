import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/health_data_types.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';

/// Storage type of the generic series the Asleep dashboard chart plots.
const asleepStorageType = 'HealthDataType.SLEEP_ASLEEP';

enum SleepAsleepBackfillStatus {
  /// The generic copy was missing and has been written.
  created,

  /// A copy already existed — the write was rejected on its deterministic id.
  alreadyPresent,

  /// A whole query window failed; its samples were not examined.
  failed,
}

class SleepAsleepBackfillReport {
  SleepAsleepBackfillReport(Iterable<SleepAsleepBackfillStatus> outcomes)
    : outcomes = List.unmodifiable(outcomes);

  final List<SleepAsleepBackfillStatus> outcomes;

  int count(SleepAsleepBackfillStatus status) =>
      outcomes.where((outcome) => outcome == status).length;

  int get scanned => outcomes.length;

  int get created => count(SleepAsleepBackfillStatus.created);

  int get failed => count(SleepAsleepBackfillStatus.failed);
}

/// Restores the generic `SLEEP_ASLEEP` copies of staged sleep samples that were
/// never written.
///
/// The Asleep chart plots one generic series, and staged samples reach it by
/// being stored a second time under [asleepStorageType] as they are imported
/// (see [sleepStagesDuplicatedAsAsleep]). Between June 2025 and August 2026 the
/// set driving that copy named `HealthDataType.SLEEP_ASLEEP_CORE` — not a value
/// of the plugin's enum, since the plugin calls Apple's *core* stage
/// `SLEEP_LIGHT`. It was a string compare that nothing type-checked, so it
/// silently never matched; deep and REM matched only because their plugin names
/// happen to coincide with the names that were written.
///
/// Core is the largest stage of a typical night, so for that window the Asleep
/// series holds deep and REM alone — roughly 40% of a real night, which reads
/// as sleep that simply is not there.
///
/// Correcting the set fixed *future* imports and nothing else: the copy is made
/// at import time, and a delta import only ever looks forward from the newest
/// stored sample. The staged rows are still in the database with no twin, and
/// nothing would ever give them one.
///
/// **This adds rows; it never rewrites one.** Each missing copy is rebuilt by
/// putting the stored stage row's own data back through
/// [PersistenceLogic.createQuantitativeEntry] with the data type swapped —
/// exactly what the import does. Health entries carry deterministic uuidV5 ids
/// derived from their content, so this produces the very id an import would,
/// and `createDbEntity` writes with `overwrite: false`. A copy that already
/// exists is therefore rejected rather than duplicated, which makes the
/// backfill idempotent and leaves a later re-import a no-op instead of a source
/// of double-counted nights.
class SleepAsleepBackfillService {
  SleepAsleepBackfillService({
    required this.journalDb,
    required this.persistenceLogic,
    required this.logger,
  });

  /// Rows are read a year at a time so years of per-segment sleep samples never
  /// land in memory at once — [JournalDb.getQuantitativeByType] takes a range
  /// but no page offset, which makes the calendar year the natural window.
  static const _firstYear = 2015;

  /// Overhang on each window's end. The query matches a row only when it lies
  /// wholly inside the range, so a segment spanning midnight on 31 December
  /// belongs to neither adjacent year without it. [backfill] de-duplicates by
  /// entry id, so the days the widened windows share are still visited once.
  static const _windowOverhang = Duration(days: 1);

  final JournalDb journalDb;
  final PersistenceLogic persistenceLogic;
  final DomainLogger logger;

  Future<SleepAsleepBackfillReport> backfill({DateTime? now}) async {
    final outcomes = <SleepAsleepBackfillStatus>[];
    final visited = <String>{};
    final lastYear = (now ?? DateTime.now()).year;

    for (final stageType in sleepStagesDuplicatedAsAsleep) {
      for (var year = _firstYear; year <= lastYear; year++) {
        try {
          final entities = await journalDb.getQuantitativeByType(
            type: stageType,
            rangeStart: DateTime(year),
            rangeEnd: DateTime(year + 1).add(_windowOverhang),
          );
          for (final entity in entities.whereType<QuantitativeEntry>()) {
            if (!visited.add(entity.id)) continue;
            outcomes.add(await _restoreCopy(entity));
          }
        } catch (error, stackTrace) {
          logger.error(
            LogDomain.health,
            error,
            stackTrace: stackTrace,
            subDomain: 'sleepAsleepBackfill',
          );
          outcomes.add(SleepAsleepBackfillStatus.failed);
        }
      }
    }

    final report = SleepAsleepBackfillReport(outcomes);
    logger.log(
      LogDomain.health,
      'sleep asleep backfill completed: scanned=${report.scanned} '
      'created=${report.created} '
      'present=${report.count(SleepAsleepBackfillStatus.alreadyPresent)} '
      'failed=${report.failed}',
      subDomain: 'sleepAsleepBackfill',
    );
    return report;
  }

  Future<SleepAsleepBackfillStatus> _restoreCopy(
    QuantitativeEntry stage,
  ) async {
    // `createQuantitativeEntry` catches its own failures and returns null, so
    // a null here means either "already stored" or "the write failed" — both
    // of which leave the row untouched, and neither of which should stop the
    // sweep. Counting it as present rather than failed keeps the reported
    // number honest for the overwhelmingly common case.
    final created = await persistenceLogic.createQuantitativeEntry(
      stage.data.copyWith(dataType: asleepStorageType),
    );
    return created != null
        ? SleepAsleepBackfillStatus.created
        : SleepAsleepBackfillStatus.alreadyPresent;
  }
}
