import 'package:drift/drift.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/last_read.dart';
import 'package:lotti/services/logging_service.dart';

const _logDomain = 'sync';
const _logSub = 'queue.markerSeed';

/// One-shot migration: copies the legacy `lastReadMatrixEventTs` and
/// `lastReadMatrixEventId` from `SettingsDb` into the new
/// `queue_markers` table so Phase 2's queue pipeline starts from
/// wherever the legacy pipeline stopped. Subsequent calls are no-ops
/// (idempotent).
///
/// The seeder is conservative: if `queue_markers` already holds a row
/// for the room, we never overwrite it — the queue pipeline is the
/// authority on its own marker once it has one, and a stale settings
/// value must not regress it.
class QueueMarkerSeeder {
  QueueMarkerSeeder({
    required SyncDatabase syncDb,
    required SettingsDb settingsDb,
    required LoggingService logging,
  }) : _syncDb = syncDb,
       _settingsDb = settingsDb,
       _logging = logging;

  final SyncDatabase _syncDb;
  final SettingsDb _settingsDb;
  final LoggingService _logging;

  /// Returns `true` if a new row was seeded, `false` if a row already
  /// existed (or no legacy marker was stored).
  Future<bool> seedIfAbsent(String roomId) async {
    final existing = await (_syncDb.select(
      _syncDb.queueMarkers,
    )..where((t) => t.roomId.equals(roomId))).getSingleOrNull();
    if (existing != null) {
      _logging.captureEvent(
        'queue.markerSeed.skip roomId=$roomId reason=alreadySeeded',
        domain: _logDomain,
        subDomain: _logSub,
      );
      return false;
    }

    final legacyTs = await getLastReadMatrixEventTs(_settingsDb);
    final legacyEventId = await getLastReadMatrixEventId(_settingsDb);
    if (legacyTs == null && legacyEventId == null) {
      _logging.captureEvent(
        'queue.markerSeed.skip roomId=$roomId reason=noLegacyMarker',
        domain: _logDomain,
        subDomain: _logSub,
      );
      return false;
    }

    await _syncDb
        .into(_syncDb.queueMarkers)
        .insert(
          QueueMarkersCompanion.insert(
            roomId: roomId,
            lastAppliedEventId: Value(legacyEventId),
            lastAppliedTs: Value(legacyTs ?? 0),
          ),
        );

    _logging.captureEvent(
      'queue.markerSeed.done roomId=$roomId '
      'legacyEventId=${legacyEventId ?? 'null'} '
      'legacyTs=${legacyTs ?? 'null'}',
      domain: _logDomain,
      subDomain: _logSub,
    );
    return true;
  }
}
