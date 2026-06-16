import 'dart:collection';

import 'package:clock/clock.dart';
import 'package:lotti/database/sync_db.dart';

/// In-memory cache layer in front of [SyncDatabase] for the sync sequence log.
///
/// This is the SINGLE owner of every mutable per-host / per-entry cache used
/// across the sync-sequence collaborators. Each collaborator that records or
/// reads sequence data is injected with the same [SyncSequenceCache] instance
/// so dedup and watermark bookkeeping stay coherent across the receive, send,
/// and backfill paths — duplicating any of these maps would silently break
/// gap-detection dedup.
///
/// ## Host activity cache
/// Reduces O(hosts_in_VC) DB queries per incoming entry by caching
/// `getHostLastSeen()` and `getLastCounterForHost()` results with a short
/// per-host TTL. The earlier shape tracked a single global expiry and dropped
/// every host's entry when the wall-clock timer ticked over — which produced
/// the 200–500 ms `getLastCounterForHost` waves visible in the 2026-05-10
/// super-slow log: a quiet host's cached watermark got wiped just because some
/// unrelated host had been active 5 minutes earlier. With per-host expiry, an
/// inactive host stays cached until it's actually queried again.
///
/// ## Materialized upper bound
/// Highest counter per host for which the `(gapBaseline + 1 .. counter - 1)`
/// missing range has already been materialized into the sequence log. Each
/// incoming entry whose observed counter is not strictly greater than this
/// bound describes a gap that is already recorded, so the full
/// `getCountersForHostInRange` + batch-insert pass would scan thousands of
/// rows just to produce `inserted=0`. Skipping it removes the dominant
/// redundant DB cost on hosts that carry a pre-history gap.
///
/// ## Last-sent counter LRU
/// Last-sent counter per `(myHost, entryId)`. The outbox calls
/// `getLastSentVectorClockForEntry` on every enqueue to build covered vector
/// clocks; without this cache each call hit the UI isolate with a
/// `SELECT ... FROM sync_sequence_log` that, on a 329k-row table with hot
/// entry_ids, routinely took 40–600 ms and dominated the image-paste freeze.
/// LRU-bounded; entries are added on lookup and refreshed on `recordSentEntry`
/// so the cached value cannot lag a concurrent write.
class SyncSequenceCache {
  SyncSequenceCache(this._syncDatabase);

  final SyncDatabase _syncDatabase;

  /// LRU capacity for [_lastSentCounterByEntry].
  static const int lastSentCounterCacheCapacity = 2048;

  /// TTL applied to every per-host and the last-sent cache window.
  static const cacheTtl = Duration(minutes: 5);

  final _hostActivityCache = <String, DateTime?>{};
  final _lastCounterCache = <String, int?>{};
  final _materializedUpperBound = <String, int>{};

  // Per-host TTL for the three host-keyed caches above. With per-host expiry,
  // an inactive host stays cached until it's actually queried again.
  final Map<String, DateTime> _hostCacheExpiry = <String, DateTime>{};

  final LinkedHashMap<String, int?> _lastSentCounterByEntry =
      LinkedHashMap<String, int?>();

  // Separate global TTL for the entry-keyed [_lastSentCounterByEntry] LRU. It
  // is keyed by `host::entryId` and is also size-bounded by
  // [lastSentCounterCacheCapacity], so eviction is dominated by LRU pressure
  // under normal load. The TTL stays as a belt-and-braces guard against rare
  // cross-process drift and matches the semantics a test in this file pins
  // (`expireCacheForTesting()` re-queries on the next call).
  DateTime? _lastSentCacheExpiry;

  // ── Host activity / last-counter caches ───────────────────────────────────

  bool _isHostCacheExpired(String hostId, DateTime now) {
    final expiry = _hostCacheExpiry[hostId];
    return expiry != null && now.isAfter(expiry);
  }

  void _evictHost(String hostId) {
    _hostActivityCache.remove(hostId);
    _lastCounterCache.remove(hostId);
    _materializedUpperBound.remove(hostId);
    _hostCacheExpiry.remove(hostId);
  }

  void _refreshHostCacheWindow(String hostId) {
    _hostCacheExpiry[hostId] = clock.now().add(cacheTtl);
  }

  /// Overwrite the cached host activity timestamp for [hostId].
  ///
  /// Called from the receive path right after `updateHostActivity` so
  /// subsequent checks in the same batch see the new activity.
  void setHostActivity(String hostId, DateTime now) {
    _hostActivityCache[hostId] = now;
  }

  /// Read-through accessor for a host's last-seen time. Evicts the host's
  /// cache slots first if the per-host TTL window has expired, then serves from
  /// cache or falls back to the DB (caching the result and refreshing the
  /// window). Callers of [getCachedLastCounterForHost] invoke this first so the
  /// per-host expiry is enforced once per read.
  Future<DateTime?> getCachedHostLastSeen(String hostId) async {
    if (_isHostCacheExpired(hostId, clock.now())) {
      _evictHost(hostId);
    }
    if (_hostActivityCache.containsKey(hostId)) {
      return _hostActivityCache[hostId];
    }
    final result = await _syncDatabase.getHostLastSeen(hostId);
    _hostActivityCache[hostId] = result;
    _refreshHostCacheWindow(hostId);
    return result;
  }

  /// Read-through accessor for a host's contiguous-from-1 resolved counter
  /// watermark, backed by the expensive `getLastCounterForHost` CTE. Assumes
  /// [getCachedHostLastSeen] already ran the per-host expiry check for the same
  /// host this read, so it serves from cache or fills from the DB without
  /// re-checking the window.
  Future<int?> getCachedLastCounterForHost(String hostId) async {
    // Per-host expiry is enforced by [getCachedHostLastSeen], which every
    // caller of this helper invokes first for the same hostId (see
    // `recordReceivedEntry`). [_evictHost] clears every per-host map together,
    // so by the time we get here the cache is either fresh or absent — no need
    // to re-check the window.
    if (_lastCounterCache.containsKey(hostId)) {
      return _lastCounterCache[hostId];
    }
    final result = await _syncDatabase.getLastCounterForHost(hostId);
    _lastCounterCache[hostId] = result;
    _refreshHostCacheWindow(hostId);
    return result;
  }

  /// Invalidate cache entries for a specific host after recording new data.
  void invalidateCacheForHost(String hostId) {
    _lastCounterCache.remove(hostId);
    // Don't remove host activity — it's updated via updateHostActivity which
    // we track separately.
  }

  /// Conservatively advance [_lastCounterCache] for [hostId] after a
  /// successful insert/update of [counter] in a watermark-eligible status.
  /// Replaces the per-record `invalidateCacheForHost` previously fired on
  /// every recorded counter — under heavy backfill that was the dominant
  /// source of slow-query traffic on the watermark CTE
  /// (`getLastCounterForHost`), because every child of an outbox bundle
  /// invalidated the cache and the next child's `getCachedLastCounterForHost`
  /// re-ran the slow CTE end-to-end. With 50 children sharing one host,
  /// 50 cache misses became 1 miss + 49 hits.
  ///
  /// Correctness: the cache stores the highest contiguous resolved counter
  /// from 1 for [hostId]. We only advance when [counter] is exactly
  /// `current + 1` (or `1` from a `null`/cold-cache state), which is the only
  /// case where the contiguous prefix is provably extended without a DB query.
  /// Counters that skip ahead (gap) or fall inside an existing gap leave the
  /// cache alone — under-reporting is safe (it just causes extra-cautious gap
  /// detection on the next read). Over-reporting would be unsafe (we could
  /// miss real gaps); this helper never does that.
  ///
  /// Status transitions that could shorten the prefix (e.g. a record flipping
  /// back to a non-watermark status) still flow through [invalidateCacheForHost]
  /// from their own call sites, so we do not need to worry about that case here.
  void advanceLastCounterCache(String hostId, int counter) {
    if (!_lastCounterCache.containsKey(hostId)) {
      // Cache slot is cold — leave it that way so the next read computes the
      // true watermark via SQL. Pre-populating from a single record would
      // over-report when earlier counters are still missing.
      return;
    }
    final current = _lastCounterCache[hostId];
    if (current == null) {
      if (counter == 1) {
        _lastCounterCache[hostId] = 1;
        // Active host — push the per-host TTL out so a long backfill does not
        // expire the cache mid-run.
        _refreshHostCacheWindow(hostId);
      }
      return;
    }
    if (counter <= current) {
      // Already covered by the cached prefix — no change.
      return;
    }
    if (counter == current + 1) {
      _lastCounterCache[hostId] = counter;
      _refreshHostCacheWindow(hostId);
    }
    // counter > current + 1: gap (truth might extend further if other counters
    // were resolved out-of-order, but we cannot prove it without a query).
    // Leave the cache at its safe lower-bound value.
  }

  /// Whether the contiguous-watermark cache holds an entry for [hostId].
  bool containsLastCounter(String hostId) =>
      _lastCounterCache.containsKey(hostId);

  /// Read the cached contiguous watermark for [hostId] (may be `null`).
  int? getLastCounter(String hostId) => _lastCounterCache[hostId];

  /// Overwrite the cached contiguous watermark for [hostId]. Used by the
  /// small-gap catch-up path which has proven the range resolves.
  void setLastCounter(String hostId, int counter) {
    _lastCounterCache[hostId] = counter;
  }

  /// Clear the entire contiguous-watermark cache. Used by reset/retire paths
  /// that may have shortened many hosts' prefixes at once.
  void clearLastCounterCache() {
    _lastCounterCache.clear();
  }

  // ── Materialized upper bound ──────────────────────────────────────────────

  /// Highest already-materialized gap upper bound for [hostId], or `null`.
  int? getMaterializedUpperBound(String hostId) =>
      _materializedUpperBound[hostId];

  /// Record [endCounter] as the highest materialized gap bound for [hostId].
  void setMaterializedUpperBound(String hostId, int endCounter) {
    _materializedUpperBound[hostId] = endCounter;
  }

  /// Clear all materialized gap bounds. Paired with [clearLastCounterCache]
  /// from the reset/retire paths.
  void clearMaterializedUpperBound() {
    _materializedUpperBound.clear();
  }

  // ── Last-sent counter LRU ─────────────────────────────────────────────────

  String lastSentCacheKey(String hostId, String entryId) => '$hostId::$entryId';

  void invalidateLastSentCacheIfExpired() {
    final now = clock.now();
    if (_lastSentCacheExpiry != null && now.isAfter(_lastSentCacheExpiry!)) {
      _lastSentCounterByEntry.clear();
      _lastSentCacheExpiry = null;
    }
  }

  void ensureLastSentCacheWindow() {
    _lastSentCacheExpiry ??= clock.now().add(cacheTtl);
  }

  bool containsLastSent(String key) => _lastSentCounterByEntry.containsKey(key);

  int? getLastSent(String key) => _lastSentCounterByEntry[key];

  void touchLastSentCache(String key, int? value) {
    _lastSentCounterByEntry
      ..remove(key)
      ..[key] = value;
    while (_lastSentCounterByEntry.length > lastSentCounterCacheCapacity) {
      _lastSentCounterByEntry.remove(_lastSentCounterByEntry.keys.first);
    }
  }

  // ── Testing ───────────────────────────────────────────────────────────────

  /// Force-expire every cache. Surfaced through
  /// `SyncSequenceLogService.expireCacheForTesting` (which carries the
  /// `@visibleForTesting` annotation) so tests can verify that expired caches
  /// are cleared and the DB is re-queried.
  ///
  /// Wipes both the per-host caches (host activity, last counter, materialized
  /// upper bound) and the entry-keyed last-sent counter LRU so existing tests
  /// that assert re-query behaviour after expiry see a fully cold cache
  /// regardless of which lookup surface they exercise.
  void expireCacheForTesting() {
    _hostActivityCache.clear();
    _lastCounterCache.clear();
    _materializedUpperBound.clear();
    _hostCacheExpiry.clear();
    _lastSentCounterByEntry.clear();
    _lastSentCacheExpiry = null;
  }
}
