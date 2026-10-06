import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/services/outbox_service.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// Gives a definition written by an older build — one that carries no
/// vector clock — its first clock, and sends it.
///
/// A stamp is a write with unchanged content and `updatedAt`: the host's
/// next counter, on top of the clock of any clocked copy the row has kept
/// its place against. It is how a clockless row joins the clocked order
/// (DefinitionClocks.tla): the manual migration stamps every clockless row
/// on this device, and the sync receive path stamps one that beat a clocked
/// copy, so its content wins everywhere without the migration running here.
class DefinitionClockStamper {
  DefinitionClockStamper({
    required this._journalDb,
    required this._vectorClockService,
    required this._outboxService,
  });

  final JournalDb _journalDb;
  final VectorClockService _vectorClockService;
  final OutboxService _outboxService;

  /// Stamps the definition stored under [id] if it is still clockless, on
  /// top of [over] when given. Returns the stamped version, or null when
  /// there was nothing to stamp.
  ///
  /// The re-read, the reservation, the write and the enqueue form one
  /// journal transaction: a sync arrival cannot land in between, and a
  /// failed enqueue rolls the write back and burns the reserved counter, so
  /// the row stays clockless and the next run retries it.
  Future<EntityDefinition?> stamp(String id, {VectorClock? over}) {
    return _vectorClockService.withVcScope<EntityDefinition?>(
      () => _journalDb.transaction(() async {
        final stored = await _journalDb.definitionById(id);
        if (stored == null || stored.vectorClock != null) return null;
        final stamped = stored.copyWith(
          vectorClock: await _vectorClockService.getNextVectorClock(
            previous: over,
            payload: (id: id, type: SyncSequencePayloadType.entityDefinition),
          ),
        );
        if (await _journalDb.upsertEntityDefinition(stamped) == 0) {
          return null;
        }
        await _outboxService.enqueueMessageOrThrow(
          SyncMessage.entityDefinition(
            entityDefinition: stamped,
            status: SyncEntryStatus.update,
          ),
        );
        return stamped;
      }),
      commitWhen: (stamped) => stamped != null,
    );
  }
}
