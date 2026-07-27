import 'dart:async';

import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// Requester half of media self-healing: turns "this entry's blob is missing
/// locally" into a broadcast [SyncMediaRequest] that peers answer with the
/// blob.
///
/// The signal comes from `SmartJournalEntityLoader.onMissingMedia`, which
/// fires whenever an image or audio entry is applied or loaded and its file is
/// absent. That is deliberately non-fatal — the JSON is the authoritative
/// state and the entry must apply regardless — so without this service the
/// miss is observed and then dropped, leaving an entry that can never render
/// and nothing anywhere trying to fix it.
///
/// Three bounds keep a device that is missing a lot of media from flooding the
/// room:
///
/// - **Debounce** ([SyncTuning.mediaRepairDebounce]) — a catch-up reports its
///   misses in a burst; they coalesce into one request rather than one per
///   photo.
/// - **Batch cap** ([SyncTuning.mediaRepairMaxBatchSize]) — surplus ids wait
///   for the next request instead of growing one envelope without bound.
/// - **Attempt cap** ([SyncTuning.mediaRepairMaxAttemptsPerEntry]) — an entry
///   nobody can answer for (a blob deleted on every device) is abandoned
///   instead of being asked for forever.
///
/// A repaired blob simply arrives as an attachment event and is written by the
/// inbound attachment pipeline; there is no response envelope to wait for and
/// nothing to re-apply. The service therefore never learns that a request
/// succeeded — it stops asking because the file now exists, so the loader
/// stops reporting it missing.
class MediaRepairService {
  MediaRepairService({
    required OutboxService outboxService,
    required VectorClockService vectorClockService,
    required DomainLogger loggingService,
    Duration? debounce,
    int? maxBatchSize,
    int? maxAttemptsPerEntry,
    int? maxTrackedEntries,
  }) : _outbox = outboxService,
       _vectorClock = vectorClockService,
       _logging = loggingService,
       _debounce = debounce ?? SyncTuning.mediaRepairDebounce,
       _maxBatchSize = maxBatchSize ?? SyncTuning.mediaRepairMaxBatchSize,
       _maxAttempts =
           maxAttemptsPerEntry ?? SyncTuning.mediaRepairMaxAttemptsPerEntry,
       _maxTracked =
           maxTrackedEntries ?? SyncTuning.mediaRepairMaxTrackedEntries;

  final OutboxService _outbox;
  final VectorClockService _vectorClock;
  final DomainLogger _logging;
  final Duration _debounce;
  final int _maxBatchSize;
  final int _maxAttempts;
  final int _maxTracked;

  /// Entry ids waiting to be requested. Insertion-ordered, so a burst is
  /// requested roughly in the order the misses were observed.
  final Set<String> _pending = <String>{};

  /// Requests already sent per entry id, including entries no longer pending.
  /// Insertion-ordered so the oldest tracked entries can be evicted first.
  final Map<String, int> _attempts = <String, int>{};

  Timer? _timer;
  bool _disposed = false;

  /// Entry ids currently waiting for their next request — test seam.
  Set<String> get debugPending => Set.unmodifiable(_pending);

  /// Records that [entryId]'s media file is missing locally and schedules a
  /// request for it. Safe to call repeatedly for the same entry: duplicates
  /// coalesce, and an entry that has exhausted its attempts is ignored.
  ///
  /// [relativePath] is used only for diagnostics — the request travels by
  /// entry id so the responder never resolves a wire-supplied path against
  /// its own filesystem.
  void reportMissing({required String entryId, required String relativePath}) {
    if (_disposed) return;

    final attempts = _attempts[entryId] ?? 0;
    if (attempts >= _maxAttempts) {
      _logging.log(
        LogDomain.sync,
        'mediaRepair.giveUp id=$entryId path=$relativePath '
        'attempts=$attempts',
        subDomain: 'mediaRepair.giveUp',
      );
      return;
    }

    if (!_pending.add(entryId)) return; // already queued for the next request

    _logging.log(
      LogDomain.sync,
      'mediaRepair.missing id=$entryId path=$relativePath '
      'pending=${_pending.length}',
      subDomain: 'mediaRepair.missing',
    );

    _evictIfOverCapacity();
    _timer ??= Timer(_debounce, () {
      _timer = null;
      unawaited(_flush());
    });
  }

  /// Sends the pending ids as one request, up to the batch cap. Surplus ids
  /// stay pending and a fresh debounce window is armed for them, so a large
  /// backlog drains in successive requests instead of one oversized envelope.
  Future<void> _flush() async {
    if (_disposed || _pending.isEmpty) return;

    final batch = _pending.take(_maxBatchSize).toList();
    final requesterId = await _vectorClock.getHost();
    if (requesterId == null) {
      // No host id yet (first run, before the vector clock is initialised).
      // Keep the ids pending and try again on the next miss rather than
      // sending a request nobody can attribute.
      _logging.log(
        LogDomain.sync,
        'mediaRepair.noHost pending=${_pending.length}',
        subDomain: 'mediaRepair.send',
      );
      return;
    }

    _pending.removeAll(batch);
    for (final id in batch) {
      _attempts[id] = (_attempts[id] ?? 0) + 1;
    }

    try {
      await _outbox.enqueueMessage(
        SyncMessage.mediaRequest(entryIds: batch, requesterId: requesterId),
      );
      _logging.log(
        LogDomain.sync,
        'mediaRepair.requested count=${batch.length} '
        'remaining=${_pending.length}',
        subDomain: 'mediaRepair.send',
      );
    } catch (error, stackTrace) {
      // Put the batch back so a transient enqueue failure does not burn the
      // entries' attempt budget for nothing.
      _pending.addAll(batch);
      for (final id in batch) {
        _attempts[id] = (_attempts[id] ?? 1) - 1;
      }
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'mediaRepair.send',
      );
    }

    if (_pending.isNotEmpty) {
      _timer ??= Timer(_debounce, () {
        _timer = null;
        unawaited(_flush());
      });
    }
  }

  /// Drops the oldest tracked entries once the set exceeds its cap, so a
  /// device missing tens of thousands of blobs cannot grow this unbounded.
  /// Dropped entries are not lost permanently — the next time one of them is
  /// loaded, the loader reports it missing again.
  void _evictIfOverCapacity() {
    while (_pending.length > _maxTracked) {
      _pending.remove(_pending.first);
    }
    while (_attempts.length > _maxTracked) {
      _attempts.remove(_attempts.keys.first);
    }
  }

  /// Cancels the pending debounce. Called from `MatrixService.dispose` so a
  /// test teardown or app shutdown leaves no timer behind.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _pending.clear();
    _attempts.clear();
  }
}
