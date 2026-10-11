import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_link.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/services/outbox_service.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// Gives an agent entity or link saved without a vector clock its first
/// clock — the agent counterpart of `DefinitionClockStamper`.
///
/// The stored row is read again inside the agent database transaction that
/// writes the stamp. A caller's copy may be stale: stamping it would give an
/// older version a newer clock than an edit made, or a copy received, since
/// it was read, and that older version would then win on every device. A
/// row that has a clock by now is left as it is.
class AgentClockStamper {
  AgentClockStamper({
    required this._agentRepository,
    required this._vectorClockService,
    required this._outboxService,
  });

  final AgentRepository _agentRepository;
  final VectorClockService _vectorClockService;
  final OutboxService _outboxService;

  /// The entity stored under [id] as it now stands: stamped here if it was
  /// still clockless, as stored if it had a clock; null when it is gone.
  /// With [send], a stamp is enqueued in the same transaction, so a failed
  /// enqueue leaves the row clockless for the next run.
  Future<AgentDomainEntity?> stampEntity(String id, {bool send = true}) =>
      _stamp(
        read: () => _agentRepository.getEntityIncludingDeleted(id),
        clockOf: (entity) => entity.vectorClock,
        stamp: (entity) async => entity.copyWith(
          vectorClock: await _vectorClockService.getNextVectorClock(
            payload: (id: id, type: SyncSequencePayloadType.agentEntity),
          ),
        ),
        write: _agentRepository.upsertEntity,
        message: (entity) => SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        ),
        send: send,
      );

  /// [stampEntity] for the agent link stored under [id].
  Future<AgentLink?> stampLink(String id, {bool send = true}) => _stamp(
    read: () => _agentRepository.getLinkByIdIncludingDeleted(id),
    clockOf: (link) => link.vectorClock,
    stamp: (link) async => link.copyWith(
      vectorClock: await _vectorClockService.getNextVectorClock(
        payload: (id: id, type: SyncSequencePayloadType.agentLink),
      ),
    ),
    write: _agentRepository.upsertLink,
    message: (link) => SyncMessage.agentLink(
      agentLink: link,
      status: SyncEntryStatus.update,
    ),
    send: send,
  );

  Future<T?> _stamp<T>({
    required Future<T?> Function() read,
    required Object? Function(T row) clockOf,
    required Future<T> Function(T row) stamp,
    required Future<void> Function(T row) write,
    required SyncMessage Function(T row) message,
    required bool send,
  }) async {
    final result = await _vectorClockService
        .withVcScope<({T? row, bool stamped})>(
          () => _agentRepository.runInTransaction(() async {
            final stored = await read();
            if (stored == null || clockOf(stored) != null) {
              return (row: stored, stamped: false);
            }
            final stamped = await stamp(stored);
            await write(stamped);
            if (send) {
              await _outboxService.enqueueMessageOrThrow(message(stamped));
            }
            return (row: stamped, stamped: true);
          }),
          commitWhen: (result) => result.stamped,
        );
    return result.row;
  }
}
