import 'dart:io';

import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:path/path.dart' as p;

/// Recognises a late copy of a journal entry that a build before #4534 purged
/// without leaving a tombstone (ADR 0131).
///
/// Such a purge removed the deleted row outright, so a device that missed the
/// deletion — or a deep backfill round with one — could hand the entry back,
/// and it was stored again. The sequence log, a separate database the purge
/// never touched, still names every version this device received of the
/// entry. A device with no row for an entry it once held at least as new as
/// an incoming copy has dropped that copy's successor; storing the copy would
/// bring back what was deleted.
///
/// A journal restored from a backup loses rows the sequence log still names,
/// and those were never deleted: refusing their copies would lose them for
/// good. The guard stands down for good on a device whose journal was ever
/// restored, which `restoreDatabaseFromBackup` marks and whose corrupt copy it
/// keeps beside the journal.
class PurgedEntryGuard {
  PurgedEntryGuard({
    required this._syncDatabase,
    required this._documentsDirectory,
    this.journalFileName = 'db.sqlite',
  });

  final SyncDatabase _syncDatabase;
  final Directory _documentsDirectory;
  final String journalFileName;
  bool? _restored;

  /// Whether this device's journal was ever restored from a backup: a kept
  /// corrupt copy, or the marker a restore writes, lies beside it.
  bool get journalWasRestored => _restored ??= _scanForRestore();

  bool _scanForRestore() {
    if (!_documentsDirectory.existsSync()) return false;
    for (final entity in _documentsDirectory.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name == '$journalFileName.restored' ||
          name.startsWith('$journalFileName.corrupt-')) {
        return true;
      }
    }
    return false;
  }

  /// Whether [incoming], a copy of an entry this device holds no row for, is
  /// no newer than a version of it the sequence log shows this device held.
  /// A clockless copy cannot be ordered and counts as stale once a clocked
  /// version was held. Always false on a restored journal.
  Future<bool> isStaleCopyOfPurged({
    required String entryId,
    required VectorClock? incoming,
  }) async {
    if (journalWasRestored) return false;
    final floor = await _syncDatabase.heldJournalClockFloor(entryId);
    if (floor.isEmpty) return false;
    if (incoming == null) return true;
    final order = VectorClock.compare(VectorClock(floor), incoming);
    return order == VclockStatus.a_gt_b || order == VclockStatus.equal;
  }
}
