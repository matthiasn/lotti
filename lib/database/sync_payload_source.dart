import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/vector_clock.dart';

/// What the Matrix payload sender reads from the journal while it sends: the
/// rows behind queued entries, a concurrent version an entry keeps as an open
/// conflict, and the resend-attachments flag (ADR 0142).
///
/// In-process the source is `JournalDb`, which implements this. In the sync
/// isolate, which owns no journal connection, it is answered by the UI
/// isolate over the port — the sender's logic is the same on both sides.
abstract interface class SyncPayloadSource {
  /// The journal rows for [ids], deleted ones included, keyed by id.
  Future<Map<String, JournalEntity>> journalEntityMapForIdsIncludingDeleted(
    Iterable<String> ids,
  );

  /// The open conflict version of entry [id] stamped exactly [vectorClock],
  /// or null when the entry keeps no such version.
  Future<JournalEntity?> openConflictVersion(
    String id,
    VectorClock vectorClock,
  );

  /// The config flag [flagName], false when unset.
  Future<bool> getConfigFlag(String flagName);
}
