import 'dart:async';

import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/pending_decryption_pen.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';

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
    required this._queue,
    required this._logging,
    this.highWater = 1000,
    this.backPressureTimeout = const Duration(seconds: 30),
    this._cancelSignal,
    this.pen,
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

  /// Where ciphertext goes while it waits for its Megolm key.
  ///
  /// `InboundQueue.enqueueBatch` refuses still-encrypted events — writing
  /// pre-decryption ciphertext into `raw_json` would lose the payload on the
  /// next `Event.fromJson` round-trip — and reports them as
  /// `deferredPendingDecryption`, whose documented contract is that *the
  /// caller retains the event and re-submits once decryption completes*. The
  /// live producer honours that by penning before it enqueues. Backfill did
  /// not: it handed pages straight to the queue and ignored the count, so
  /// every event the startup bridge replayed while still encrypted was
  /// discarded outright — no row, no pen entry, no ledger, nothing to retry
  /// and nothing to notice.
  ///
  /// Public because Dart forbids named parameters whose name begins with an
  /// underscore, and this reads better at the call sites than a positional.
  final PendingDecryptionPen? pen;
  final int highWater;
  final Duration backPressureTimeout;
  final Future<void>? _cancelSignal;

  bool _cancelled = false;
  int _lastAcceptedCount = 0;

  @override
  int get lastAcceptedCount => _lastAcceptedCount;

  @override
  Future<bool> onPage(List<Event> events, BootstrapPageInfo info) async {
    if (_cancelled) {
      _lastAcceptedCount = 0;
      return false;
    }

    // Pen first, enqueue second — the same order the live producer uses.
    // `hold` returns false for anything already decrypted, so this only
    // diverts the events the queue would otherwise refuse.
    final heldIn = pen;
    final forQueue = heldIn == null
        ? events
        : [
            for (final event in events)
              if (!heldIn.hold(event)) event,
          ];
    final penned = events.length - forQueue.length;

    final enqueue = await _queue.appendBootstrapPage(forQueue);
    _lastAcceptedCount = enqueue.accepted;

    _logging.log(
      LogDomain.sync,
      'queue.bootstrap.page '
      'page=${info.pageIndex} '
      'pageSize=${events.length} '
      'accepted=${enqueue.accepted} '
      'dupes=${enqueue.duplicatesDropped} '
      'filteredOutByType=${enqueue.filteredOutByType} '
      'penned=$penned '
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
