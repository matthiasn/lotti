import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// In-memory aggregation buffer for one agent wake run.
///
/// The interceptor accepts outbound agent sync messages while a wake is active,
/// keeps the latest payload per entity/link id, and preserves superseded vector
/// clocks in each child message's `coveredVectorClocks` field. Flushing creates
/// one [SyncAgentBundle] that receivers can apply as the same agent entity/link
/// mutations they already understand.
class AgentWakeSyncInterceptor {
  AgentWakeSyncInterceptor({
    required this.agentId,
    required this.wakeRunKey,
  });

  final String agentId;
  final String wakeRunKey;

  final Map<String, SyncAgentEntity> _entities = {};
  final Map<String, SyncAgentLink> _links = {};

  int get entityCount => _entities.length;
  int get linkCount => _links.length;
  int get bufferedMessageCount => entityCount + linkCount;
  bool get isEmpty => _entities.isEmpty && _links.isEmpty;
  bool get isNotEmpty => !isEmpty;

  List<SyncAgentEntity> get entities => List.unmodifiable(_entities.values);
  List<SyncAgentLink> get links => List.unmodifiable(_links.values);

  /// Adds [message] when it is an agent entity/link payload.
  ///
  /// Returns `true` when the message was intercepted and should not be
  /// enqueued independently.
  bool add(SyncMessage message) {
    switch (message) {
      case final SyncAgentEntity msg:
        final entity = msg.agentEntity;
        if (entity == null) return false;
        _entities[entity.id] = _mergeEntity(_entities[entity.id], msg);
        return true;
      case final SyncAgentLink msg:
        final link = msg.agentLink;
        if (link == null) return false;
        _links[link.id] = _mergeLink(_links[link.id], msg);
        return true;
      default:
        return false;
    }
  }

  SyncAgentBundle? buildBundle() {
    if (isEmpty) return null;
    return SyncMessage.agentBundle(
          agentId: agentId,
          wakeRunKey: wakeRunKey,
          entities: entities,
          links: links,
        )
        as SyncAgentBundle;
  }

  void clear() {
    _entities.clear();
    _links.clear();
  }

  // Merge helpers only carry the SUPERSEDED previous vector clock into
  // `coveredVectorClocks`. The current (`next`) clock is added later by
  // `OutboxService._prepareAgentEntity` / `_prepareAgentLink` (reason
  // `ensure_current_clock_covered`), and the receiver
  // `SyncSequenceLogService._filterCoveredVectorClocks` strips the current
  // clock again before pre-marking covered counters. Adding `next.vc` here
  // would just be redundant with that pipeline.
  SyncAgentEntity _mergeEntity(
    SyncAgentEntity? previous,
    SyncAgentEntity next,
  ) {
    if (previous == null) return next;

    final covered = VectorClock.mergeUniqueClocks([
      ...?previous.coveredVectorClocks,
      ...?next.coveredVectorClocks,
      previous.agentEntity?.vectorClock,
    ]);

    return next.copyWith(
      originatingHostId: next.originatingHostId ?? previous.originatingHostId,
      coveredVectorClocks: covered,
    );
  }

  SyncAgentLink _mergeLink(
    SyncAgentLink? previous,
    SyncAgentLink next,
  ) {
    if (previous == null) return next;

    final covered = VectorClock.mergeUniqueClocks([
      ...?previous.coveredVectorClocks,
      ...?next.coveredVectorClocks,
      previous.agentLink?.vectorClock,
    ]);

    return next.copyWith(
      originatingHostId: next.originatingHostId ?? previous.originatingHostId,
      coveredVectorClocks: covered,
    );
  }
}
