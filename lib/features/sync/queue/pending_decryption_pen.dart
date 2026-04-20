import 'dart:async';
import 'dart:collection';

import 'package:clock/clock.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

const _logDomain = 'sync';
const _logSub = 'queue.decryptionPen';

class _HeldEvent {
  _HeldEvent({required this.event, required this.heldAtMs});

  Event event;
  int heldAtMs;
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
/// that exceed [maxAttempts] sweep cycles without decrypting are
/// dropped with a diagnostic log line so operations can notice a
/// stuck key-rotation scenario.
///
/// The pen does not schedule its own timer in production — the
/// `InboundWorker` ticks it on every drain iteration. Tests may call
/// [flushInto] directly or pass a custom [sweepInterval] to start its
/// internal timer.
class PendingDecryptionPen {
  PendingDecryptionPen({
    required LoggingService logging,
    this.capacity = 256,
    this.maxAttempts = 20,
    this.sweepInterval,
  }) : _logging = logging;

  final LoggingService _logging;
  final int capacity;
  final int maxAttempts;
  final Duration? sweepInterval;

  final LinkedHashMap<String, _HeldEvent> _held =
      LinkedHashMap<String, _HeldEvent>();

  Timer? _timer;

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
      final room = await resolveRoom();
      if (room == null) return;
      await flushInto(queue: queue, room: room);
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
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

    var enqueued = 0;
    var stillEncrypted = 0;
    var dropped = 0;

    final ids = _held.keys.toList(growable: false);
    for (final id in ids) {
      final held = _held[id];
      if (held == null) continue;

      final latest = await _fetchLatest(room, id);
      final candidate = latest ?? held.event;

      if (candidate.type != EventTypes.Encrypted) {
        _held.remove(id);
        await queue.enqueueLive(candidate);
        enqueued++;
        continue;
      }

      held.attempts++;
      if (held.attempts >= maxAttempts) {
        _held.remove(id);
        dropped++;
        _logging.captureEvent(
          'queue.decryptionPen.drop eventId=$id '
          'attempts=${held.attempts}',
          domain: _logDomain,
          subDomain: _logSub,
        );
      } else {
        stillEncrypted++;
      }
    }

    return PenFlushOutcome(
      enqueued: enqueued,
      stillEncrypted: stillEncrypted,
      dropped: dropped,
    );
  }

  Future<Event?> _fetchLatest(Room room, String eventId) async {
    try {
      return await room.getEventById(eventId);
    } catch (error, stackTrace) {
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.fetch',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  void _enforceCapacity() {
    while (_held.length > capacity) {
      final victim = _held.keys.first;
      _held.remove(victim);
      _logging.captureEvent(
        'queue.decryptionPen.evict eventId=$victim reason=capacity',
        domain: _logDomain,
        subDomain: _logSub,
      );
    }
  }
}

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
