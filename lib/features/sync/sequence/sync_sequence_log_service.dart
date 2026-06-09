import 'dart:collection';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:meta/meta.dart';

part 'sync_sequence_gap_materializer.dart';
part 'sync_sequence_gap_model.dart';
part 'sync_seq1.dart';
part 'sync_seq2.dart';
part 'sync_seq3.dart';
part 'sync_seq4.dart';

typedef _GapRange = ({String hostId, int startCounter, int endCounter});

/// Service for managing the sync sequence log, which tracks received entries
/// by (hostId, counter) pairs to detect gaps and enable backfill requests.
const int _lastSentCounterCacheCapacity = 2048;
const _cacheTtl = Duration(minutes: 5);

abstract class _SyncSequenceLogServiceBase {
  // Positional field formals (not named) because a named parameter cannot be a
  // private initializing formal in Dart; the public named API lives on the
  // concrete [SyncSequenceLogService], which forwards to this base.
  _SyncSequenceLogServiceBase(
    this._syncDatabase,
    this._vectorClockService,
    this._loggingService,
    this._domainLogger,
  );

  final SyncDatabase _syncDatabase;
  final VectorClockService _vectorClockService;
  final DomainLogger _loggingService;
  final DomainLogger? _domainLogger;
  void Function()? onMissingEntriesDetected;
  int _deferredMissingEntriesDepth = 0;
  bool _pendingMissingEntriesDetected = false;

  void _trace(String message, {String? subDomain}) {
    final sub = subDomain ?? 'sequence';
    final domainLogger = _domainLogger;
    if (domainLogger != null) {
      domainLogger.log(LogDomain.sync, message, subDomain: sub);
      return;
    }
    // Fallback for callers that did not inject a DomainLogger (e.g. tests).
    // Emitting directly under the `sync` domain keeps sync-file routing in
    // DomainLogger working so the log line still lands in the sync file.
    _loggingService.log(
      LogDomain.sync,
      message,
      subDomain: sub,
    );
  }

  Future<T> runWithDeferredMissingEntries<T>(
    Future<T> Function() action,
  ) async {
    _deferredMissingEntriesDepth++;
    try {
      return await action();
    } finally {
      _deferredMissingEntriesDepth--;
      if (_deferredMissingEntriesDepth == 0 && _pendingMissingEntriesDetected) {
        _pendingMissingEntriesDetected = false;
        _emitMissingEntriesDetected();
      }
    }
  }

  void _emitMissingEntriesDetected() {
    final callback = onMissingEntriesDetected;
    if (callback == null) return;
    try {
      callback();
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'missingEntriesDetected',
      );
    }
  }

  // ============ Host Activity Cache ============
  // Reduces O(hosts_in_VC) DB queries per incoming entry by caching
  // getHostLastSeen() and getLastCounterForHost() results with a short TTL.

  final _hostActivityCache = <String, DateTime?>{};
  final _lastCounterCache = <String, int?>{};
  // Highest counter per host for which we have already materialized the
  // `(gapBaseline + 1 .. counter - 1)` missing range into the sequence log.
  // Each incoming entry whose observed counter is not strictly greater than
  // this bound describes a gap that is already recorded, so the full
  // `getCountersForHostInRange` + batch-insert pass would scan thousands of
  // rows just to produce `inserted=0`. Skipping it removes the dominant
  // redundant DB cost on hosts that carry a pre-history gap.
  final _materializedUpperBound = <String, int>{};

  // Last-sent counter per (myHost, entryId). The outbox calls
  // `getLastSentVectorClockForEntry` on every enqueue to build covered
  // vector clocks; without this cache each call hit the UI isolate with a
  // `SELECT ... FROM sync_sequence_log` that, on a 329k-row table with hot
  // entry_ids, routinely took 40–600 ms and dominated the image-paste
  // freeze. LRU-bounded; entries are added on lookup and refreshed on
  // `recordSentEntry` so the cached value cannot lag a concurrent write.
  final LinkedHashMap<String, int?> _lastSentCounterByEntry =
      LinkedHashMap<String, int?>();

  // Per-host TTL for `_hostActivityCache`, `_lastCounterCache`, and
  // `_materializedUpperBound` (all keyed by hostId). The earlier shape
  // tracked a single global `_cacheExpiry` and dropped every host's
  // entry when the wall-clock timer ticked over — which produced the
  // 200–500 ms `getLastCounterForHost` waves visible in the
  // 2026-05-10 super-slow log: a quiet host's cached watermark got
  // wiped just because some unrelated host had been active 5 minutes
  // earlier. With per-host expiry, an inactive host stays cached
  // until it's actually queried again.
  final Map<String, DateTime> _hostCacheExpiry = <String, DateTime>{};

  // Separate global TTL for the entry-keyed `_lastSentCounterByEntry`
  // LRU. It is keyed by `host::entryId` and is also size-bounded by
  // [_lastSentCounterCacheCapacity], so eviction is dominated by LRU
  // pressure under normal load. The TTL stays as a belt-and-braces
  // guard against rare cross-process drift and matches the semantics
  // a test in this file pins (`expireCacheForTesting()` re-queries on
  // the next call).
  DateTime? _lastSentCacheExpiry;

  // Cross-mixin contracts implemented by the method-group mixins.
  void _advanceLastCounterCache(String hostId, int counter);

  void _ensureLastSentCacheWindow();

  List<VectorClock> _filterCoveredVectorClocks(
    List<VectorClock>? coveredVectorClocks,
    VectorClock current,
  );

  Future<DateTime?> _getCachedHostLastSeen(String hostId);

  Future<int?> _getCachedLastCounterForHost(String hostId);

  void _invalidateLastSentCacheIfExpired();

  String _lastSentCacheKey(String hostId, String entryId);

  Future<void> _markCoveredCountersAsReceived({
    required List<VectorClock> coveredVectorClocks,
    required String entryId,
    required SyncSequencePayloadType payloadType,
    required String myHost,
  });

  Future<int> _materializeLargeGap({
    required String hostId,
    required int startCounter,
    required int endCounter,
    required int gapSize,
    required String originatingHostId,
    required DateTime now,
  });

  Future<int> resolvePendingHints({
    required SyncSequencePayloadType payloadType,
    required String payloadId,
    required VectorClock payloadVectorClock,
  });

  void _touchLastSentCache(String key, int? value);

  Future<List<({String hostId, int counter})>> recordReceivedEntry({
    required String entryId,
    required VectorClock vectorClock,
    required String originatingHostId,
    List<VectorClock>? coveredVectorClocks,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
    String? jsonPath,
  });

  void _invalidateCacheForHost(String hostId);
}

class SyncSequenceLogService extends _SyncSequenceLogServiceBase
    with
        _SyncSequenceGapMaterializer,
        _SyncSeq1,
        _SyncSeq2,
        _SyncSeq3,
        _SyncSeq4 {
  SyncSequenceLogService({
    required SyncDatabase syncDatabase,
    required VectorClockService vectorClockService,
    required DomainLogger loggingService,
    DomainLogger? domainLogger,
  }) : super(
         syncDatabase,
         vectorClockService,
         loggingService,
         domainLogger,
       );
}
