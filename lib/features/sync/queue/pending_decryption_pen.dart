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

  /// When this entry was last looked up against the room. Zero means never,
  /// so the first sweep after holding always looks.
  int lastLookupAtMs = 0;

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
/// Spacing the countdown costs almost nothing in recovery latency: the room
/// is still polled for a decrypted copy on its own, much shorter
/// [lookupInterval], and the event is enqueued the moment one exists. Both
/// cadences are needed — one bounds how long ciphertext is kept, the other
/// bounds how much work keeping it costs.
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
    this.lookupInterval = const Duration(seconds: 1),
    this.sweepInterval,
  });

  final DomainLogger _logging;
  final int capacity;
  final int maxAttempts;

  /// Minimum real time between two attempts against the same entry. Set to
  /// [Duration.zero] to make every sweep count, which is only useful for
  /// tests that model the budget directly.
  final Duration attemptInterval;

  /// Minimum real time between two `room.getEventById` lookups for the same
  /// entry.
  ///
  /// The lookup is the expensive half of a sweep, and sweeps are frequent:
  /// `InboundWorker` flushes the whole pen before every batch and
  /// `SyncTuning.inboundWorkerBatchSize` is 1, so draining 10k rows with a
  /// full 256-entry pen would otherwise issue ~2.5M sequential lookups. That
  /// used to be self-limiting only because entries were dropped after 20
  /// sweeps; holding them for a real ten minutes makes the load persist, so
  /// the lookup needs its own cadence rather than inheriting the sweep's.
  ///
  /// Kept far shorter than [attemptInterval] so decryption is still noticed
  /// within about a second of the key landing.
  final Duration lookupInterval;

  final Duration? sweepInterval;

  final LinkedHashMap<String, _HeldEvent> _held =
      LinkedHashMap<String, _HeldEvent>();

  Timer? _timer;
  Future<void>? _inFlightSweep;

  int get size => _held.length;

  /// Whether [eventId] is already held. A re-hold costs no capacity, so
  /// admission checks must not count one against the remaining slots.
  bool holds(String eventId) => _held.containsKey(eventId);

  /// How many entries are held for [roomId].
  ///
  /// Admission budgets are per room. The pen's capacity is global and its
  /// eviction is global LRU, so entries left over from a room the user has
  /// switched away from would otherwise consume the whole budget and stop the
  /// active room's bootstrap without admitting anything — `onRoomChanged`
  /// prunes queue rows but not the pen, and the worker only ever sweeps the
  /// current room, so those entries linger until their attempt budget runs
  /// out. Measuring the active room's own occupancy lets its events in, and
  /// the LRU then reclaims the stale ones, which is the right trade.
  int sizeForRoom(String roomId) {
    var count = 0;
    for (final held in _held.values) {
      if (held.event.roomId == roomId) count++;
    }
    return count;
  }

  /// Oldest `origin_server_ts` still held for [roomId], or null when the pen
  /// holds nothing for that room.
  ///
  /// The marker clamp needs this. A held entry is received-but-not-applied,
  /// exactly like a row sitting in `enqueued`/`leased`/`retrying` — but it has
  /// no row, so `QueueMarkerAdvancer` cannot see it in the queue table. Left
  /// invisible, a newer event applying moves `last_applied_ts` past the held
  /// one, and the next startup's strictly-forward bridge never re-fetches it.
  int? oldestHeldOriginTs(String roomId) {
    int? oldest;
    for (final held in _held.values) {
      if (held.event.roomId != roomId) continue;
      final ts = held.event.originServerTs.millisecondsSinceEpoch;
      if (oldest == null || ts < oldest) oldest = ts;
    }
    return oldest;
  }

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
    _protectedRoomId = event.roomId;

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
        lookups: 0,
      );
    }

    var stillEncrypted = 0;
    var dropped = 0;
    var lookups = 0;
    final decrypted = <({String id, Event event})>[];

    final ids = _held.keys.toList(growable: false);
    for (final id in ids) {
      final held = _held[id];
      if (held == null) continue;

      // Rate-limit the lookup itself, not just the countdown it feeds. An
      // entry that was checked a moment ago cannot have decrypted since
      // without the SDK having done work we would see on the next tick.
      final nowMs = clock.now().millisecondsSinceEpoch;
      if (nowMs - held.lastLookupAtMs < lookupInterval.inMilliseconds) {
        stillEncrypted++;
        continue;
      }
      held.lastLookupAtMs = nowMs;
      lookups++;

      final latest = await _fetchLatest(room, id);
      final candidate = latest ?? held.event;

      if (candidate.type != EventTypes.Encrypted) {
        // Do not drop from `_held` yet — if `enqueueBatch` throws
        // later, a removed-and-unqueued event would silently vanish.
        // Removal only happens after the batch lands.
        decrypted.add((id: id, event: candidate));
        continue;
      }

      // Sweeps are unbounded in frequency; attempts are not. An entry only
      // pays when `attemptInterval` has elapsed since it last paid.
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
      lookups: lookups,
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

  /// The room whose entry was most recently held. Eviction prefers any other
  /// room's entry over this one.
  String? _protectedRoomId;

  void _enforceCapacity() {
    while (_held.length > capacity) {
      final victim = _pickVictim();
      _held.remove(victim);
      _logging.log(
        LogDomain.sync,
        'queue.decryptionPen.evict eventId=$victim reason=capacity',
        subDomain: _logSub,
      );
    }
  }

  /// Oldest entry belonging to a room other than the one being held for, or
  /// the oldest entry overall when every entry belongs to it.
  ///
  /// Plain LRU is wrong once admission is budgeted per room. Switching
  /// A → B → A can leave an A entry as the global oldest while a B entry is
  /// newer; the per-room budget then admits another A event and LRU evicts
  /// the *active* room's ciphertext — losing both the event and the marker
  /// clamp that protects it, so later A commits advance straight past it. The
  /// inactive room's entry is the right victim: nothing is sweeping it.
  String _pickVictim() {
    final protectedRoom = _protectedRoomId;
    if (protectedRoom != null) {
      for (final entry in _held.entries) {
        if (entry.value.event.roomId != protectedRoom) return entry.key;
      }
    }
    return _held.keys.first;
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
    required this.lookups,
  });

  final int enqueued;
  final int stillEncrypted;
  final int dropped;

  /// How many entries were actually re-queried this sweep.
  ///
  /// Zero means every held entry was inside its [PendingDecryptionPen
  /// .lookupInterval] and the sweep could not have discovered a decryption
  /// even if one had happened. Callers that give up after N unproductive
  /// sweeps must not count those, or a caller whose own cadence is faster
  /// than the lookup interval gives up without ever having looked.
  final int lookups;
}
