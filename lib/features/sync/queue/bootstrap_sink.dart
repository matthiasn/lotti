import 'dart:async';

import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';

const _logSub = 'queue.bootstrap';

typedef BootstrapEventDecryptor = Future<Event> Function(Event event);

/// [BootstrapSink] implementation that forwards each paginated page to
/// `InboundQueue.appendBootstrapPage` and awaits back-pressure
/// via `waitForDrainAtMostTo` before returning, so the caller-driven
/// `collectHistoryForBootstrap` loop waits for the worker to drain
/// before pulling the next page.
///
/// Supports cooperative cancellation via the optional `cancelSignal`
/// constructor argument (e.g. user taps "Cancel" in the Sync Settings
/// page) and a per-page back-pressure timeout so an apply-wedged
/// worker cannot hang the UI thread indefinitely.
class QueueBootstrapSink implements BootstrapSink {
  QueueBootstrapSink({
    required this._queue,
    required this._logging,
    this.highWater = 1000,
    this.backPressureTimeout = const Duration(seconds: 30),
    this._cancelSignal,
    this.decryptEvent,
  }) {
    // Register the cancel handler eagerly so cancellation that lands
    // between pages (while `_waitForDrain` is not currently awaiting)
    // still flips `_cancelled` before the next `onPage` fires.
    _cancelSignal?.then<void>((_) {
      _cancelled = true;
    });
  }

  final InboundQueue _queue;
  final DomainLogger _logging;
  final int highWater;
  final Duration backPressureTimeout;
  final Future<void>? _cancelSignal;
  final BootstrapEventDecryptor? decryptEvent;

  bool _cancelled = false;
  int _lastAcceptedCount = 0;
  int? _oldestUnresolvedTs;

  @override
  int get lastAcceptedCount => _lastAcceptedCount;

  /// Oldest still-encrypted event observed during this walk.
  ///
  /// The owner reconciles the durable resume floor with this value only after
  /// pagination completes. An incomplete walk must leave the previous floor
  /// untouched because it cannot prove that the missing event was revisited.
  int? get oldestUnresolvedTs => _oldestUnresolvedTs;

  @override
  Future<bool> onPage(List<Event> events, BootstrapPageInfo info) async {
    if (_cancelled) {
      _lastAcceptedCount = 0;
      return false;
    }

    final forQueue = <Event>[];
    final unresolvedFloors = <String, int>{};
    var unresolvedCount = 0;
    for (final originalEvent in events) {
      var event = originalEvent;
      if (event.type == EventTypes.Encrypted && decryptEvent != null) {
        try {
          event = await decryptEvent!(event);
        } catch (error, stackTrace) {
          _logging.error(
            LogDomain.sync,
            error,
            stackTrace: stackTrace,
            subDomain: '$_logSub.decrypt',
          );
        }
      }
      if (event.type != EventTypes.Encrypted) {
        forQueue.add(event);
        continue;
      }
      unresolvedCount++;
      final roomId = event.roomId ?? '';
      final originTs = event.originServerTs.millisecondsSinceEpoch;
      final current = unresolvedFloors[roomId];
      if (current == null || originTs < current) {
        unresolvedFloors[roomId] = originTs;
      }
      final oldest = _oldestUnresolvedTs;
      if (oldest == null || originTs < oldest) {
        _oldestUnresolvedTs = originTs;
      }
    }

    // Persist unresolved work before any later plaintext from this page can
    // apply. The SDK owns the ciphertext; a later bridge makes one fresh
    // decryption attempt, while the durable floor remains the only Lotti-owned
    // retry state if that attempt still cannot succeed.
    for (final MapEntry(key: roomId, value: originTs)
        in unresolvedFloors.entries) {
      await _queue.lowerResumeFloor(
        roomId: roomId,
        originTs: originTs,
      );
    }

    final enqueue = await _queue.appendBootstrapPage(forQueue);

    // Ciphertext counts as observed progress. A zero here means the page was
    // stale/irrelevant and lets the catch-up strategy continue past a cache
    // boundary; an all-encrypted page was neither.
    _lastAcceptedCount = enqueue.accepted + unresolvedCount;

    _logging.log(
      LogDomain.sync,
      'queue.bootstrap.page '
      'page=${info.pageIndex} '
      'pageSize=${events.length} '
      'accepted=${enqueue.accepted} '
      'dupes=${enqueue.duplicatesDropped} '
      'filteredOutByType=${enqueue.filteredOutByType} '
      'unresolvedCiphertext=$unresolvedCount '
      'deferredPendingDecryption=${enqueue.deferredPendingDecryption} '
      'totalEventsSoFar=${info.totalEventsSoFar} '
      'oldestTs=${info.oldestTimestampSoFar} '
      'serverHasMore=${info.serverHasMore} '
      'elapsedMs=${info.elapsed.inMilliseconds}',
      subDomain: _logSub,
    );

    try {
      await _waitForDrain();
    } on TimeoutException {
      _logging.log(
        LogDomain.sync,
        'queue.bootstrap.backPressureTimeout '
        'timeoutMs=${backPressureTimeout.inMilliseconds} '
        'page=${info.pageIndex}',
        subDomain: _logSub,
      );
      // Timing out on back-pressure is a "worker wedged" signal.
      // Stop pagination so the user sees the partial result instead
      // of burning memory on a queue that isn't draining.
      return false;
    }
    return !_cancelled;
  }

  Future<void> _waitForDrain() async {
    final drainFuture = _queue.waitForDrainAtMostTo(
      highWater,
      timeout: backPressureTimeout,
    );
    final cancel = _cancelSignal;
    if (cancel == null) {
      await drainFuture;
      return;
    }
    final cancelWrapped = cancel.then((_) => _cancelled = true);
    await Future.any<void>([drainFuture, cancelWrapped]);
  }
}
