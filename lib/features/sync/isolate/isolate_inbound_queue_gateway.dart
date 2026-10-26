import 'package:async/async.dart' show StreamGroup;
import 'package:lotti/features/sync/isolate/sync_isolate_host.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_protocol.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_queue_gateway.dart';
import 'package:lotti/features/sync/queue/inbound_queue_settlement.dart';

/// The inbound queue's owner reached across the isolate boundary (ADR 0142):
/// the sync isolate leases and settles, the UI isolate applies.
///
/// Reads stay local — `sync.sqlite` is one file, and the UI isolate's own
/// connection sees every committed row — so the next ready time comes from
/// the local queue. Writes go to the worker. While the worker is not running —
/// starting, or respawning after a crash — a lease answers empty, no ready
/// time is reported, and the loop waits; [changes] fires when the worker is
/// back, when it reports the queue tables written, and when the UI isolate
/// itself enqueues.
class IsolateInboundQueueGateway implements InboundQueueGateway {
  IsolateInboundQueueGateway({
    required this._host,
    required this._localQueue,
  }) {
    // Every queue write the worker reports reaches the UI isolate's depth
    // subscribers, who cannot see the other connection's writes — whether or
    // not the request that caused it got its reply (a settlement can commit
    // and still time out). The host closes this stream when it is disposed,
    // which ends the subscription with the sync stack that owns both.
    _host.tablesChanged
        .where(_touchesTheQueue)
        .listen((_) => _localQueue.noteExternalChange());
  }

  final SyncIsolateHost _host;
  final InboundQueue _localQueue;

  static bool _touchesTheQueue(List<String> tables) =>
      tables.any(inboundQueueTables.contains);

  @override
  Future<List<InboundQueueEntry>> lease({required int maxBatch}) async {
    if (_host.state != SyncIsolateState.running) {
      return const <InboundQueueEntry>[];
    }
    final List<InboundQueueEntry> leased;
    try {
      leased = await _host.lease(maxBatch: maxBatch);
    } on SyncIsolateFailure catch (failure) {
      // The worker went away between the state check and the answer: no
      // rows were handed out, so there is nothing to drain until it is back.
      // A failure the worker itself reported is a real error and propagates.
      if (failure.code == SyncIsolateErrorCode.failed) rethrow;
      return const <InboundQueueEntry>[];
    }
    return leased;
  }

  @override
  Future<int> settle(List<InboundEntryOutcome> outcomes) async =>
      _host.settle(outcomes);

  /// The local queue's next ready time — or none while the worker is not
  /// running: a ready row the worker cannot lease yet would otherwise have the
  /// inbound loop re-lease every millisecond until the worker shakes hands.
  /// [changes] fires when it does.
  @override
  Future<int?> earliestReadyAt() async {
    if (_host.state != SyncIsolateState.running) return null;
    return _localQueue.earliestReadyAt();
  }

  /// The local queue's depth signal — which the relay above feeds with the
  /// worker's queue writes too — and the worker coming back.
  @override
  Stream<void> get changes => StreamGroup.mergeBroadcast<void>([
    _localQueue.depthChanges,
    _host.states.where((state) => state == SyncIsolateState.running),
  ]);
}
