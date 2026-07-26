import 'dart:async';
import 'dart:collection';

import 'package:clock/clock.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';

const _logSub = 'queue.decryptionPen';

class _HeldEvent {
  _HeldEvent({required this.event, required this.heldAtMs})
    : lastAttemptAtMs = heldAtMs;

  Event event;
  int heldAtMs;

  /// When this entry last *spent* an attempt. Distinct from the sweep that
  /// merely looked at it: sweeps are as frequent as the worker's drain loop,
  /// attempts are meant to be spaced in real time.
  int lastAttemptAtMs;
  int attempts = 0;
}

/// In-memory holding pen for `m.room.encrypted` events that reach the
/// live producer before their Megolm session key has propagated
/// (F3 — review §3.3). Holding the event instead of enqueuing it
/// keeps pre-decryption ciphertext out of `inbound_event_queue.raw_json`,
/// where a subsequent `Event.fromJson` round-trip would re-materialise
/// an undecrypted Event and silently drop the payload.
///
/// The pen is bounded (default 256 entries, LRU eviction) so a wave
/// of undecryptable events cannot grow memory unboundedly. Entries
/// that exceed [maxAttempts] attempts without decrypting are dropped
/// with a diagnostic log line so operations can notice a stuck
/// key-rotation scenario.
///
/// **An attempt is a unit of time, not a unit of work.** A sweep only
/// spends one once [attemptInterval] has elapsed since the last one that
/// counted, so the budget is `maxAttempts * attemptInterval` of real time
/// (10 minutes by default) no matter how often the pen is swept. Without
/// that spacing the budget is meaningless: the `InboundWorker` sweeps at
/// the top of every drain iteration and loops straight back after a
/// non-empty batch, so a burst draining at speed once burned all 20
/// attempts in ~2ms — dropping ciphertext whose Megolm key was still in
/// flight, on exactly the slow links where keys take longest to arrive.
///
/// The spacing costs nothing in recovery latency: every sweep still asks
/// the room for a decrypted copy and enqueues it the moment one exists.
/// Only the countdown to giving up is rate-limited.
///
/// The window is per session, not absolute: the pen is in memory, so a
/// teardown discards whatever it still holds. That is not a loss path —
/// held entries have no queue row yet, and the startup bridge re-fetches
/// them from the server on the next run. `drainUntilEmptyImpl` therefore
/// does not wait for the pen to empty before tearing down, which it could
/// no longer do inside a 30s shutdown now that attempts are spaced.
///
/// The pen does not schedule its own timer in production — the
/// `InboundWorker` ticks it on every drain iteration. Tests may call
/// [flushInto] directly or pass a custom [sweepInterval] to start its
/// internal timer.
class PendingDecryptionPen {
  PendingDecryptionPen({
    required this._logging,
    this.capacity = 256,
    this.maxAttempts = 20,
    this.attemptInterval = const Duration(seconds: 30),
    this.sweepInterval,
  });

  final DomainLogger _logging;
  final int capacity;
  final int maxAttempts;

  /// Minimum real time between two attempts against the same entry. Set to
  /// [Duration.zero] to make every sweep count, which is only useful for
  /// tests that model the budget directly.
  final Duration attemptInterval;

  final Duration? sweepInterval;

  final LinkedHashMap<String, _HeldEvent> _held =
      LinkedHashMap<String, _HeldEvent>();

  Timer? _timer;
  Future<void>? _inFlightSweep;

  int get size => _held.length;

  /// Starts the internal sweep timer if [sweepInterval] was provided.
  /// Optional — the `InboundWorker` can drive [flushInto] by calling
  /// it directly.
  void startSweeping({
    required Future<Room?> Function() resolveRoom,
    required InboundQueue queue,
  }) {
    final interval = sweepInterval;
    if (interval == null || _timer != null) return;
    _timer = Timer.periodic(interval, (_) async {
      // Timer.periodic fires on its cadence regardless of whether the
      // previous async callback resolved; skip overlapping sweeps so
      // `_held.attempts` cannot be double-incremented and shutdown can
      // cleanly await the final in-flight sweep.
      if (_inFlightSweep != null) return;
      final room = await resolveRoom();
      if (room == null) return;
      final future = flushInto(queue: queue, room: room);
      _inFlightSweep = future.then((_) {}, onError: (_) {});
      try {
        await future;
      } finally {
        _inFlightSweep = null;
      }
    });
  }

  /// Cancels the periodic sweep timer and awaits any in-flight sweep so no
  /// flush lands after shutdown is considered complete.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    final pending = _inFlightSweep;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // Errors inside the in-flight sweep are already logged via
        // `_logging.captureException` on the flush path.
      }
    }
  }

  /// Hold an encrypted event (or, defensively, any event) in the pen.
  /// Events that are already decrypted at hold time are passed
  /// through to the caller so the producer can enqueue them directly.
  ///
  /// Returns `true` if the event was held, `false` if it was already
  /// decrypted and the caller should proceed with normal enqueue.
  bool hold(Event event) {
    if (event.type != EventTypes.Encrypted) return false;

    final id = event.eventId;
    final existing = _held.remove(id);
    if (existing != null) {
      existing
        ..event = event
        ..heldAtMs = clock.now().millisecondsSinceEpoch;
      _held[id] = existing;
    } else {
      _held[id] = _HeldEvent(
        event: event,
        heldAtMs: clock.now().millisecondsSinceEpoch,
      );
    }
    _enforceCapacity();
    return true;
  }

  /// Sweeps held events. For each one, asks [room] for the latest
  /// cached version via `room.getEventById`; if the SDK has since
  /// decrypted it, the decrypted event is forwarded to
  /// `queue.enqueueLive` and the held entry dropped. Entries that
  /// exceed [maxAttempts] without decrypting are dropped with a
  /// diagnostic; their ciphertext is never written to the queue.
  Future<PenFlushOutcome> flushInto({
    required InboundQueue queue,
    required Room room,
  }) async {
    if (_held.isEmpty) {
      return const PenFlushOutcome(
        enqueued: 0,
        stillEncrypted: 0,
        dropped: 0,
      );
    }

    var stillEncrypted = 0;
    var dropped = 0;
    final decrypted = <({String id, Event event})>[];

    final ids = _held.keys.toList(growable: false);
    for (final id in ids) {
      final held = _held[id];
      if (held == null) continue;

      final latest = await _fetchLatest(room, id);
      final candidate = latest ?? held.event;

      if (candidate.type != EventTypes.Encrypted) {
        // Do not drop from `_held` yet — if `enqueueBatch` throws
        // later, a removed-and-unqueued event would silently vanish.
        // Removal only happens after the batch lands.
        decrypted.add((id: id, event: candidate));
        continue;
      }

      // Sweeps are unbounded in frequency; attempts are not. Looking again
      // costs nothing, so an entry only pays when `attemptInterval` has
      // elapsed since it last paid.
      final nowMs = clock.now().millisecondsSinceEpoch;
      if (nowMs - held.lastAttemptAtMs < attemptInterval.inMilliseconds) {
        stillEncrypted++;
        continue;
      }
      held.lastAttemptAtMs = nowMs;
      held.attempts++;
      if (held.attempts >= maxAttempts) {
        _held.remove(id);
        dropped++;
        _logging.log(
          LogDomain.sync,
          'queue.decryptionPen.drop eventId=$id '
          'attempts=${held.attempts}',
          subDomain: _logSub,
        );
      } else {
        stillEncrypted++;
      }
    }

    // Single-transaction enqueue for everything that decrypted this
    // sweep, so a 10-event wave is one sync_db commit instead of 10.
    if (decrypted.isNotEmpty) {
      await queue.enqueueBatch(
        [for (final d in decrypted) d.event],
        producer: InboundEventProducer.live,
      );
      for (final d in decrypted) {
        _held.remove(d.id);
      }
    }

    return PenFlushOutcome(
      enqueued: decrypted.length,
      stillEncrypted: stillEncrypted,
      dropped: dropped,
    );
  }

  Future<Event?> _fetchLatest(Room room, String eventId) async {
    try {
      return await room.getEventById(eventId);
    } catch (error, stackTrace) {
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_logSub.fetch',
      );
      return null;
    }
  }

  void _enforceCapacity() {
    while (_held.length > capacity) {
      final victim = _held.keys.first;
      _held.remove(victim);
      _logging.log(
        LogDomain.sync,
        'queue.decryptionPen.evict eventId=$victim reason=capacity',
        subDomain: _logSub,
      );
    }
  }
}

/// Tally of one pen flush: how many held events decrypted and were [enqueued],
/// how many were [stillEncrypted] (kept for a later sweep), and how many were
/// [dropped] (e.g. evicted past the pen's capacity).
class PenFlushOutcome {
  const PenFlushOutcome({
    required this.enqueued,
    required this.stillEncrypted,
    required this.dropped,
  });

  final int enqueued;
  final int stillEncrypted;
  final int dropped;
}
