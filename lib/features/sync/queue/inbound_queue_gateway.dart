import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_queue_settlement.dart';

/// How the apply side reaches the inbound queue's owner (ADR 0142).
///
/// `InboundWorker` leases the next entries, applies them, and acknowledges
/// each with its outcome; whoever owns `inbound_event_queue` records the
/// result. In-process that owner is the UI isolate's own `InboundQueue`
/// ([LocalInboundQueueGateway]); with `use_isolate_sync` on it is the sync
/// isolate, reached through its host. An entry whose lease expires without
/// an acknowledgement is leased again, so apply stays idempotent.
abstract interface class InboundQueueGateway {
  /// Leases up to [maxBatch] ready entries, oldest first. Empty when nothing
  /// is ready, or when the owner cannot be reached right now.
  Future<List<InboundQueueEntry>> lease({required int maxBatch});

  /// Acknowledges [outcomes]; the owner records each entry's next state.
  /// Returns how many were applied.
  Future<int> settle(List<InboundEntryOutcome> outcomes);

  /// When the earliest active row becomes ready, in epoch milliseconds, or
  /// null when the queue holds nothing to drain.
  Future<int?> earliestReadyAt();

  /// Fires whenever the queue may have work: a row was enqueued, retried,
  /// resurrected — or, across the isolate boundary, the owner became
  /// reachable again.
  Stream<void> get changes;
}

/// The queue owner in-process: the UI isolate's own `InboundQueue`, with the
/// shared settlement rules.
class LocalInboundQueueGateway implements InboundQueueGateway {
  LocalInboundQueueGateway({
    required this._queue,
    required this._settlement,
  });

  final InboundQueue _queue;
  final InboundQueueSettlement _settlement;

  @override
  Future<List<InboundQueueEntry>> lease({required int maxBatch}) =>
      _queue.peekBatchReady(maxBatch: maxBatch);

  @override
  Future<int> settle(List<InboundEntryOutcome> outcomes) =>
      _settlement.settle(outcomes);

  @override
  Future<int?> earliestReadyAt() => _queue.earliestReadyAt();

  @override
  Stream<void> get changes => _queue.depthChanges;
}
