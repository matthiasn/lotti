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
    //
    // Admission is checked per event and *before* holding, never after.
    // `hold` enforces capacity itself by evicting the oldest entry, so a
    // page that overshoots has already destroyed something by the time any
    // after-the-fact size check runs: a 255-entry pen taking two new events
    // evicts one, then reports 256 to a guard that thinks it stopped in time.
    final heldIn = pen;
    final forQueue = <Event>[];
    var penned = 0;
    var newlyPenned = 0;
    var penExhausted = false;
    final overflowFloors = <({String roomId, int originTs})>[];

    if (heldIn == null) {
      forQueue.addAll(events);
    } else {
      for (final event in events) {
        if (event.type != EventTypes.Encrypted) {
          forQueue.add(event);
          continue;
        }
        // Budget per room, not globally. The pen's capacity and LRU are
        // global, so ciphertext left over from a room the user switched away
        // from would otherwise eat the whole budget and stop the active
        // room's bootstrap without admitting a single event.
        final roomId = event.roomId ?? '';
        // A re-hold of something already held costs no slot.
        if (!heldIn.holds(event.eventId) &&
            heldIn.sizeForRoom(roomId) >= heldIn.capacity) {
          // No slot for it, so record it durably and keep going. The floor
          // is what makes that safe: an omitted event has no row and no pen
          // entry, so nothing in memory protects it, but
          // `queue_markers.resume_floor_ts` now says a resume must reach
          // back to it — and the bridge refuses a forward anchor that sits
          // ahead of the floor. Later events from this page can therefore be
          // queued without the marker stepping over the gap.
          //
          // Before the floor existed this had to choose between discarding
          // the rest of an already-fetched page and letting the marker
          // advance past a dropped event. Neither was good; both were fixed
          // here in turn, and the real answer was durable state.
          penExhausted = true;
          overflowFloors.add((
            roomId: roomId,
            originTs: event.originServerTs.millisecondsSinceEpoch,
          ));
          continue;
        }
        final sizeBefore = heldIn.size;
        heldIn.hold(event);
        penned++;
        if (heldIn.size > sizeBefore) newlyPenned++;
      }
    }

    // Record the floors *before* anything from this page becomes a queue
    // row, so no commit can advance the marker in the window between.
    for (final floor in overflowFloors) {
      await _queue.lowerResumeFloor(
        roomId: floor.roomId,
        originTs: floor.originTs,
      );
    }

    final enqueue = await _queue.appendBootstrapPage(forQueue);

    // Retained ciphertext counts as accepted. `collectHistoryForBootstrapImpl`
    // reads `lastAcceptedCount == 0` as a stale-cache signal and pulls up to
    // five more pages past the boundary; on an all-encrypted page that would
    // be a lie, and those extra pages are exactly what pushes the pen over
    // capacity and evicts the boundary events we were trying to keep.
    _lastAcceptedCount = enqueue.accepted + newlyPenned;

    if (newlyPenned > 0 || penExhausted) {
      // No rows means no depth signal, so an idle worker would not look at
      // the pen until its 60s empty-queue tick.
      //
      // Exhaustion signals too, and that case matters more: a page that adds
      // nothing new is exactly the one where the pen is stuck, and
      // `BridgeCoordinator` gives up after ~10s of retries — well inside that
      // idle tick. Without a nudge every retry meets the same full pen and
      // the bridge abandons the walk even if a key landed seconds earlier.
      _queue.signalPendingWork();
    }

    _logging.log(
      LogDomain.sync,
      'queue.bootstrap.page '
      'page=${info.pageIndex} '
      'pageSize=${events.length} '
      'accepted=${enqueue.accepted} '
      'dupes=${enqueue.duplicatesDropped} '
      'filteredOutByType=${enqueue.filteredOutByType} '
      'penned=$penned '
      'newlyPenned=$newlyPenned '
      'deferredPendingDecryption=${enqueue.deferredPendingDecryption} '
      'totalEventsSoFar=${info.totalEventsSoFar} '
      'oldestTs=${info.oldestTimestampSoFar} '
      'serverHasMore=${info.serverHasMore} '
      'elapsedMs=${info.elapsed.inMilliseconds}',
      subDomain: _logSub,
    );

    // Ciphertext creates no queue rows, so `_waitForDrain` — which watches
    // queue depth — applies no back-pressure to an all-encrypted run at all.
    // Catch-up walks can emit far more than the 256-entry LRU pen can hold:
    // without this the walk silently evicts the oldest ciphertext long before
    // it finishes, recreating exactly the loss this sink was changed to
    // prevent.
    //
    // Stopping is safe now that held events clamp the sync marker: the marker
    // cannot advance past what the pen is holding, so the next run resumes
    // from the right anchor instead of skipping the gap. Evicting is not
    // safe, so prefer the bounded stop.
    if (penExhausted) {
      _logging.log(
        LogDomain.sync,
        'queue.bootstrap.penFull '
        'page=${info.pageIndex} '
        'penSize=${heldIn?.size} '
        'capacity=${heldIn?.capacity}',
        subDomain: _logSub,
      );
      return false;
    }

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
