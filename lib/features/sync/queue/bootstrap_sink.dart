import 'dart:async';

import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

const _logDomain = 'sync';
const _logSub = 'queue.bootstrap';

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
    required InboundQueue queue,
    required LoggingService logging,
    this.highWater = 1000,
    this.backPressureTimeout = const Duration(seconds: 30),
    Future<void>? cancelSignal,
  }) : _queue = queue,
       _logging = logging,
       _cancelSignal = cancelSignal {
    // Register the cancel handler eagerly so cancellation that lands
    // between pages (while `_waitForDrain` is not currently awaiting)
    // still flips `_cancelled` before the next `onPage` fires.
    _cancelSignal?.then<void>((_) {
      _cancelled = true;
    });
  }

  final InboundQueue _queue;
  final LoggingService _logging;
  final int highWater;
  final Duration backPressureTimeout;
  final Future<void>? _cancelSignal;

  bool _cancelled = false;

  @override
  Future<bool> onPage(List<Event> events, BootstrapPageInfo info) async {
    if (_cancelled) return false;

    final enqueue = await _queue.appendBootstrapPage(events);

    _logging.captureEvent(
      'queue.bootstrap.page '
      'page=${info.pageIndex} '
      'pageSize=${events.length} '
      'accepted=${enqueue.accepted} '
      'dupes=${enqueue.duplicatesDropped} '
      'filteredOutByType=${enqueue.filteredOutByType} '
      'deferredPendingDecryption=${enqueue.deferredPendingDecryption} '
      'totalEventsSoFar=${info.totalEventsSoFar} '
      'oldestTs=${info.oldestTimestampSoFar} '
      'serverHasMore=${info.serverHasMore} '
      'elapsedMs=${info.elapsed.inMilliseconds}',
      domain: _logDomain,
      subDomain: _logSub,
    );

    try {
      await _waitForDrain();
    } on TimeoutException {
      _logging.captureEvent(
        'queue.bootstrap.backPressureTimeout '
        'timeoutMs=${backPressureTimeout.inMilliseconds} '
        'page=${info.pageIndex}',
        domain: _logDomain,
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
