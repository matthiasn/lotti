part of 'sync_sequence_log_service.dart';

mixin _SyncSeq1 on _SyncSequenceLogServiceBase {
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
    _hostCacheExpiry[hostId] = clock.now().add(_cacheTtl);
  }

  @override
  void _invalidateLastSentCacheIfExpired() {
    final now = clock.now();
    if (_lastSentCacheExpiry != null && now.isAfter(_lastSentCacheExpiry!)) {
      _lastSentCounterByEntry.clear();
      _lastSentCacheExpiry = null;
    }
  }

  @override
  void _ensureLastSentCacheWindow() {
    _lastSentCacheExpiry ??= clock.now().add(_cacheTtl);
  }

  @override
  String _lastSentCacheKey(String hostId, String entryId) =>
      '$hostId::$entryId';

  @override
  void _touchLastSentCache(String key, int? value) {
    _lastSentCounterByEntry
      ..remove(key)
      ..[key] = value;
    while (_lastSentCounterByEntry.length > _lastSentCounterCacheCapacity) {
      _lastSentCounterByEntry.remove(_lastSentCounterByEntry.keys.first);
    }
  }

  @override
  Future<DateTime?> _getCachedHostLastSeen(String hostId) async {
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

  @override
  Future<int?> _getCachedLastCounterForHost(String hostId) async {
    // Per-host expiry is enforced by `_getCachedHostLastSeen`, which
    // every caller of this helper invokes first for the same hostId
    // (see `recordReceivedEntry`). `_evictHost` clears every per-host
    // map together, so by the time we get here the cache is either
    // fresh or absent — no need to re-check the window.
    if (_lastCounterCache.containsKey(hostId)) {
      return _lastCounterCache[hostId];
    }
    final result = await _syncDatabase.getLastCounterForHost(hostId);
    _lastCounterCache[hostId] = result;
    _refreshHostCacheWindow(hostId);
    return result;
  }

  /// Invalidate cache entries for a specific host after recording new data.
  @override
  void _invalidateCacheForHost(String hostId) {
    _lastCounterCache.remove(hostId);
    // Don't remove host activity — it's updated via updateHostActivity
    // which we track separately.
  }

  /// Conservatively advance [_lastCounterCache] for [hostId] after a
  /// successful insert/update of [counter] in a watermark-eligible status.
  /// Replaces the per-record `_invalidateCacheForHost` previously fired on
  /// every recorded counter — under heavy backfill that was the dominant
  /// source of slow-query traffic on the watermark CTE
  /// (`getLastCounterForHost`), because every child of an outbox bundle
  /// invalidated the cache and the next child's `_getCachedLastCounterForHost`
  /// re-ran the slow CTE end-to-end. With 50 children sharing one host,
  /// 50 cache misses became 1 miss + 49 hits.
  ///
  /// Correctness: the cache stores the highest contiguous resolved counter
  /// from 1 for [hostId]. We only advance when [counter] is exactly
  /// `current + 1` (or `1` from a `null`/cold-cache state), which is the
  /// only case where the contiguous prefix is provably extended without a
  /// DB query. Counters that skip ahead (gap) or fall inside an existing
  /// gap leave the cache alone — under-reporting is safe (it just causes
  /// extra-cautious gap detection on the next read). Over-reporting would
  /// be unsafe (we could miss real gaps); this helper never does that.
  ///
  /// Status transitions that could shorten the prefix (e.g. a record
  /// flipping back to a non-watermark status) still flow through
  /// [_invalidateCacheForHost] from their own call sites, so we do not
  /// need to worry about that case here.
  @override
  void _advanceLastCounterCache(String hostId, int counter) {
    if (!_lastCounterCache.containsKey(hostId)) {
      // Cache slot is cold — leave it that way so the next read computes
      // the true watermark via SQL. Pre-populating from a single record
      // would over-report when earlier counters are still missing.
      return;
    }
    final current = _lastCounterCache[hostId];
    if (current == null) {
      if (counter == 1) {
        _lastCounterCache[hostId] = 1;
        // Active host — push the per-host TTL out so a long backfill
        // does not expire the cache mid-run.
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
    // counter > current + 1: gap (truth might extend further if other
    // counters were resolved out-of-order, but we cannot prove it without
    // a query). Leave the cache at its safe lower-bound value.
  }

  /// Force-expire every cache. Used in tests to verify that expired
  /// caches are cleared and the DB is re-queried.
  ///
  /// Wipes both the per-host caches (host activity, last counter,
  /// materialized upper bound) and the entry-keyed last-sent counter
  /// LRU so existing tests that assert re-query behaviour after
  /// expiry see a fully cold cache regardless of which lookup
  /// surface they exercise.
  @visibleForTesting
  void expireCacheForTesting() {
    _hostActivityCache.clear();
    _lastCounterCache.clear();
    _materializedUpperBound.clear();
    _hostCacheExpiry.clear();
    _lastSentCounterByEntry.clear();
    _lastSentCacheExpiry = null;
  }

  /// Record an entry being sent by this device.
  /// This allows us to respond to backfill requests from other devices.
  Future<void> recordSentEntry({
    required String entryId,
    required VectorClock vectorClock,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
  }) async {
    final myHost = await _vectorClockService.getHost();

    for (final entry in vectorClock.vclock.entries) {
      final hostId = entry.key;
      final counter = entry.value;

      // Only record entries for our own host when sending
      if (hostId != myHost) continue;

      final now = DateTime.now();
      await _syncDatabase.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: Value(hostId),
          counter: Value(counter),
          entryId: Value(entryId),
          payloadType: Value(payloadType.index),
          originatingHostId: Value(myHost),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Keep the cache consistent with the write we just issued so a
      // subsequent `getLastSentVectorClockForEntry` does not race back to
      // the DB for a value we already know.
      final cacheKey = _lastSentCacheKey(hostId, entryId);
      final previous = _lastSentCounterByEntry[cacheKey];
      if (previous == null || counter > previous) {
        _touchLastSentCache(cacheKey, counter);
      }

      _trace(
        'recordSentEntry type=$payloadType hostId=$hostId counter=$counter entryId=$entryId',
        subDomain: 'sequence.recordSent',
      );
    }
  }

  Future<void> recordSentEntryLink({
    required String linkId,
    required VectorClock vectorClock,
  }) async {
    await recordSentEntry(
      entryId: linkId,
      vectorClock: vectorClock,
      payloadType: SyncSequencePayloadType.entryLink,
    );
  }

  /// Returns the last sent vector clock for [entryId] from this host's
  /// perspective.  Used by the outbox to build covered vector clocks when a
  /// new version is enqueued but the previous version was already sent.
}
