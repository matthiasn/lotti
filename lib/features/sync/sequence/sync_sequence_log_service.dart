import 'dart:collection';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:meta/meta.dart';

typedef _GapRange = ({String hostId, int startCounter, int endCounter});

class _GapAccumulator {
  final List<_GapRange> _ranges = [];
  int _count = 0;

  bool get isNotEmpty => _count > 0;
  int get count => _count;

  void addRange({
    required String hostId,
    required int startCounter,
    required int endCounter,
  }) {
    if (endCounter < startCounter) return;
    _ranges.add((
      hostId: hostId,
      startCounter: startCounter,
      endCounter: endCounter,
    ));
    _count += endCounter - startCounter + 1;
  }

  List<({String hostId, int counter})> toGapList() => _GapEntriesView(_ranges);
}

class _GapEntriesView extends ListBase<({String hostId, int counter})> {
  _GapEntriesView(List<_GapRange> ranges)
    : _ranges = List.unmodifiable(ranges),
      _rangeEnds = _buildRangeEnds(ranges),
      _length = _computeLength(ranges);

  final List<_GapRange> _ranges;
  final List<int> _rangeEnds;
  final int _length;

  static List<int> _buildRangeEnds(List<_GapRange> ranges) {
    final ends = <int>[];
    var total = 0;
    for (final range in ranges) {
      total += range.endCounter - range.startCounter + 1;
      ends.add(total);
    }
    return ends;
  }

  static int _computeLength(List<_GapRange> ranges) {
    var total = 0;
    for (final range in ranges) {
      total += range.endCounter - range.startCounter + 1;
    }
    return total;
  }

  @override
  int get length => _length;

  @override
  set length(int newLength) {
    throw UnsupportedError('GapEntriesView is read-only');
  }

  @override
  ({String hostId, int counter}) operator [](int index) {
    RangeError.checkValidIndex(index, this, null, _length);
    var low = 0;
    var high = _rangeEnds.length - 1;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (index < _rangeEnds[mid]) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }

    final rangeIndex = low;
    final previousEnd = rangeIndex == 0 ? 0 : _rangeEnds[rangeIndex - 1];
    final range = _ranges[rangeIndex];
    return (
      hostId: range.hostId,
      counter: range.startCounter + index - previousEnd,
    );
  }

  @override
  void operator []=(int index, ({String hostId, int counter}) value) {
    throw UnsupportedError('GapEntriesView is read-only');
  }
}

/// Service for managing the sync sequence log, which tracks received entries
/// by (hostId, counter) pairs to detect gaps and enable backfill requests.
class SyncSequenceLogService {
  SyncSequenceLogService({
    required SyncDatabase syncDatabase,
    required VectorClockService vectorClockService,
    required LoggingService loggingService,
    DomainLogger? domainLogger,
  }) : _syncDatabase = syncDatabase,
       _vectorClockService = vectorClockService,
       _loggingService = loggingService,
       _domainLogger = domainLogger;

  final SyncDatabase _syncDatabase;
  final VectorClockService _vectorClockService;
  final LoggingService _loggingService;
  final DomainLogger? _domainLogger;
  void Function()? onMissingEntriesDetected;
  int _deferredMissingEntriesDepth = 0;
  bool _pendingMissingEntriesDetected = false;

  void _trace(String message, {String? subDomain}) {
    final sub = subDomain ?? 'sequence';
    final domainLogger = _domainLogger;
    if (domainLogger != null) {
      domainLogger.log(LogDomains.sync, message, subDomain: sub);
      return;
    }
    // Fallback for callers that did not inject a DomainLogger (e.g. tests).
    // Emitting directly under the `sync` domain keeps sync-file routing in
    // LoggingService working so the log line still lands in the sync file.
    _loggingService.captureEvent(
      message,
      domain: LogDomains.sync,
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
      _loggingService.captureException(
        e,
        domain: 'SYNC_SEQUENCE',
        subDomain: 'missingEntriesDetected',
        stackTrace: st,
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
  static const int _lastSentCounterCacheCapacity = 2048;

  DateTime? _cacheExpiry;
  static const _cacheTtl = Duration(minutes: 5);

  void _invalidateCacheIfExpired() {
    final now = DateTime.now();
    if (_cacheExpiry != null && now.isAfter(_cacheExpiry!)) {
      _hostActivityCache.clear();
      _lastCounterCache.clear();
      _materializedUpperBound.clear();
      _lastSentCounterByEntry.clear();
      _cacheExpiry = null;
    }
  }

  String _lastSentCacheKey(String hostId, String entryId) =>
      '$hostId::$entryId';

  void _touchLastSentCache(String key, int? value) {
    _lastSentCounterByEntry
      ..remove(key)
      ..[key] = value;
    while (_lastSentCounterByEntry.length > _lastSentCounterCacheCapacity) {
      _lastSentCounterByEntry.remove(_lastSentCounterByEntry.keys.first);
    }
  }

  void _ensureCacheWindow() {
    _cacheExpiry ??= DateTime.now().add(_cacheTtl);
  }

  Future<DateTime?> _getCachedHostLastSeen(String hostId) async {
    _invalidateCacheIfExpired();
    _ensureCacheWindow();
    if (_hostActivityCache.containsKey(hostId)) {
      return _hostActivityCache[hostId];
    }
    final result = await _syncDatabase.getHostLastSeen(hostId);
    _hostActivityCache[hostId] = result;
    return result;
  }

  Future<int?> _getCachedLastCounterForHost(String hostId) async {
    _invalidateCacheIfExpired();
    _ensureCacheWindow();
    if (_lastCounterCache.containsKey(hostId)) {
      return _lastCounterCache[hostId];
    }
    final result = await _syncDatabase.getLastCounterForHost(hostId);
    _lastCounterCache[hostId] = result;
    return result;
  }

  /// Invalidate cache entries for a specific host after recording new data.
  void _invalidateCacheForHost(String hostId) {
    _lastCounterCache.remove(hostId);
    // Don't remove host activity — it's updated via updateHostActivity
    // which we track separately.
  }

  /// Force-expire the host activity cache. Used in tests to verify
  /// that expired caches are cleared and DB is re-queried.
  @visibleForTesting
  void expireCacheForTesting() {
    // Set expiry to the past so the next cache access triggers invalidation.
    _cacheExpiry = DateTime.now().subtract(const Duration(seconds: 1));
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
  Future<VectorClock?> getLastSentVectorClockForEntry(String entryId) async {
    final myHost = await _vectorClockService.getHost();
    if (myHost == null) return null;
    _invalidateCacheIfExpired();
    _ensureCacheWindow();
    final cacheKey = _lastSentCacheKey(myHost, entryId);
    int? counter;
    if (_lastSentCounterByEntry.containsKey(cacheKey)) {
      counter = _lastSentCounterByEntry[cacheKey];
      // Refresh LRU position on hit so active entries stay resident.
      _touchLastSentCache(cacheKey, counter);
    } else {
      counter = await _syncDatabase.getLastSentCounterForEntry(
        myHost,
        entryId,
      );
      _touchLastSentCache(cacheKey, counter);
    }
    if (counter == null) return null;
    return VectorClock({myHost: counter});
  }

  /// Record a received entry and detect gaps in the sequence.
  /// Returns a read-only list of detected gaps as `(hostId, counter)` records.
  /// The list may be backed by logical ranges so very large gaps do not
  /// allocate one in-memory record per missing counter.
  ///
  /// The [originatingHostId] identifies which host created/modified this entry.
  /// This must be provided by the sender in the sync message.
  ///
  /// Gap detection is performed for ALL hosts in the vector clock (except our
  /// own host). This allows us to detect missing entries even from hosts other
  /// than the originator - the VC tells us what counters exist.
  ///
  /// Only the originating host's counter is recorded with the entryId.
  /// Other hosts' counters are tracked for gap detection only.
  ///
  /// [coveredVectorClocks] contains vector clocks for this payload, including
  /// superseded outbox entries and the current vector clock. The current vector
  /// clock is ignored when pre-marking covered counters to avoid suppressing
  /// genuine gap detection for the payload itself.
  Future<List<({String hostId, int counter})>> recordReceivedEntry({
    required String entryId,
    required VectorClock vectorClock,
    required String originatingHostId,
    List<VectorClock>? coveredVectorClocks,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
    String? jsonPath,
  }) async {
    final gaps = _GapAccumulator();
    var newMissingDetected = false;
    final myHost = await _vectorClockService.getHost();
    final now = DateTime.now();

    // Update host activity for the originating host - they're online!
    await _syncDatabase.updateHostActivity(originatingHostId, now);
    // Update cache so subsequent checks in this batch see the new activity
    _hostActivityCache[originatingHostId] = now;

    // IMPORTANT: Process covered vector clocks BEFORE gap detection.
    // This prevents false positives: covered counters are pre-emptively marked
    // as received, so gap detection (which checks `existing == null`) will
    // skip them instead of incorrectly marking them as missing.
    final filteredCovered = _filterCoveredVectorClocks(
      coveredVectorClocks,
      vectorClock,
    );
    if (filteredCovered.isNotEmpty && myHost != null) {
      _trace(
        'recordReceivedEntry: coveredVCs count=${filteredCovered.length} '
        'clocks=${filteredCovered.map((vc) => vc.vclock).toList()} '
        'entryId=$entryId type=$payloadType',
        subDomain: 'sequence.coveredClocks',
      );
      await _markCoveredCountersAsReceived(
        coveredVectorClocks: filteredCovered,
        entryId: entryId,
        payloadType: payloadType,
        myHost: myHost,
      );
    }

    // Check gaps for ALL hosts in the VC (except ourselves)
    for (final entry in vectorClock.vclock.entries) {
      final hostId = entry.key;
      final counter = entry.value;

      // Skip our own host
      if (hostId == myHost) continue;

      // Only detect gaps for hosts that have been seen "online" (i.e., have
      // sent us a message directly). This prevents false positive gaps for
      // hosts we've never communicated with - we may see their counters in
      // vector clocks from other hosts, but we can't know if entries are
      // actually missing without having established communication with them.
      // The originating host is always considered online (we just updated
      // their activity above).
      //
      // Note: We still record the sequence entry for offline hosts (below),
      // just skip gap detection. This allows us to respond to backfill
      // requests later if the host comes online.
      final hostLastOnline = await _getCachedHostLastSeen(hostId);
      final shouldDetectGaps =
          hostLastOnline != null || hostId == originatingHostId;

      if (!shouldDetectGaps) {
        _trace(
          'skipGapDetection hostId=$hostId counter=$counter - host never seen online',
          subDomain: 'sequence.skipGap',
        );
      }

      final lastSeen = await _getCachedLastCounterForHost(hostId);
      // For hosts that are currently considered online, an unknown contiguous
      // prefix still means "we have not resolved counter 1 yet", not "there can
      // be no gap". Treat that as watermark 0 so the first observed counter can
      // materialize the missing prefix instead of silently skipping it.
      final gapBaseline = shouldDetectGaps ? (lastSeen ?? 0) : null;

      if (gapBaseline != null && counter > gapBaseline + 1) {
        // Gap detected! Mark missing counters for this host.
        //
        // The returned `gaps` list is only consumed by callers for logging
        // (`apply.*.gapsDetected`). Adding the full `startCounter..counter-1`
        // range every time causes that log line to re-fire on every event
        // for a permanent pre-history gap (we saw `count=7344` per event in
        // production). Push the actual range-add down into the branches
        // below so an incremental extension contributes only the newly
        // materialised sub-range.
        final gapSize = counter - gapBaseline - 1;
        final startCounter = gapBaseline + 1;

        if (gapSize > SyncTuning.maxGapSize) {
          // Skip re-materialization when the observed range is fully covered
          // by a previously materialized one for this host. Without this
          // guard, every incoming event on a host that carries a permanent
          // pre-history gap re-runs a multi-chunk scan of the sequence log
          // just to discover `inserted=0`, which dominates the mobile sync
          // cost and the desktop log volume.
          final previousBound = _materializedUpperBound[hostId];
          final endCounter = counter - 1;
          final alreadyMaterialized =
              previousBound != null && previousBound >= endCounter;
          if (!alreadyMaterialized) {
            final effectiveStart = previousBound == null
                ? startCounter
                : math.max(startCounter, previousBound + 1);
            final effectiveSize = endCounter - effectiveStart + 1;
            // Only treat this as an "incremental extension" when the current
            // gap actually overlaps the previously materialised range
            // (`startCounter <= previousBound`). A disjoint new large gap on
            // the same host — e.g. after the host recovered and regressed
            // again — must re-emit the log and re-nudge backfill instead of
            // being silently rolled into the prior range's bookkeeping.
            final isIncrementalExtension =
                previousBound != null && startCounter <= previousBound;
            gaps.addRange(
              hostId: hostId,
              startCounter: effectiveStart,
              endCounter: endCounter,
            );
            // On a permanent pre-history gap, every new event advances the
            // bound by one counter. Logging the 7000+ "gap size" every time
            // dominates desktop log volume and says nothing new. Only log the
            // first materialisation of the range; subsequent incremental
            // extensions stay silent.
            if (!isIncrementalExtension) {
              _trace(
                'largeGapDetected hostId=$hostId gapSize=$gapSize (lastSeen=$gapBaseline, counter=$counter) - recording full gap',
                subDomain: 'sequence.largeGap',
              );
            }
            final insertedCount = await _materializeLargeGap(
              hostId: hostId,
              startCounter: effectiveStart,
              endCounter: endCounter,
              gapSize: effectiveSize,
              originatingHostId: originatingHostId,
              now: now,
            );
            // `previousBound < endCounter` on this branch, so direct assignment
            // is the max — no `math.max` needed.
            _materializedUpperBound[hostId] = endCounter;
            if (insertedCount > 0) {
              // Any newly inserted missing rows must drive a backfill nudge,
              // including the incremental-extension case where the observed
              // counter jumps past `previousBound` by more than one. Only the
              // noisy `sequence.gapDetected` trace is suppressed for the
              // one-counter-at-a-time incremental case.
              newMissingDetected = true;
              if (!isIncrementalExtension) {
                _trace(
                  'gapDetectedRange hostId=$hostId start=$effectiveStart end=$endCounter '
                  'inserted=$insertedCount (last seen: $gapBaseline, observed: $counter) from=$originatingHostId',
                  subDomain: 'sequence.gapDetected',
                );
              }
            }
          }
          // Fall through to the originator/other-host record block below so
          // the incoming `(hostId, counter)` row is still upserted; skipping
          // it would itself block the watermark from ever advancing.
        } else {
          // Small gap (≤ SyncTuning.maxGapSize). Report the full VC-implied
          // range via `gaps` so the caller's `apply.*.gapsDetected` log is
          // consistent with the historical contract; the per-counter log
          // below still only fires for actually-missing counters, and the
          // batch insert only contains new rows.
          gaps.addRange(
            hostId: hostId,
            startCounter: startCounter,
            endCounter: counter - 1,
          );
          final existingCounters = await _syncDatabase
              .getCountersForHostInRange(
                hostId,
                startCounter,
                counter - 1,
              );
          final missingEntries = <SyncSequenceLogCompanion>[];
          for (var i = startCounter; i < counter; i++) {
            // Keep the small-gap path explicit because the per-counter logging
            // is still useful when debugging ordinary out-of-order delivery.
            if (!existingCounters.contains(i)) {
              missingEntries.add(
                SyncSequenceLogCompanion(
                  hostId: Value(hostId),
                  counter: Value(i),
                  originatingHostId: Value(originatingHostId),
                  status: Value(SyncSequenceStatus.missing.index),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
              newMissingDetected = true;

              _trace(
                'gapDetected hostId=$hostId counter=$i (last seen: $gapBaseline, observed: $counter) from=$originatingHostId',
                subDomain: 'sequence.gapDetected',
              );
            }
          }
          if (missingEntries.isNotEmpty) {
            await _syncDatabase.batchInsertSequenceEntries(missingEntries);
          }
        }
      }

      // For the originator, record the actual entry with entryId
      if (hostId == originatingHostId) {
        final existing = await _syncDatabase.getEntryByHostAndCounter(
          hostId,
          counter,
        );

        // Determine the new status:
        // - If already received/backfilled → keep existing status (don't downgrade)
        // - If we explicitly requested this entry → backfilled (request fulfilled)
        // - If it was missing but not yet requested → received (arrived via normal sync)
        // - Otherwise → received
        final SyncSequenceStatus status;
        if (existing != null &&
            (existing.status == SyncSequenceStatus.received.index ||
                existing.status == SyncSequenceStatus.backfilled.index)) {
          // Already received or backfilled - keep the existing status
          status = SyncSequenceStatus.values[existing.status];
        } else if (existing != null &&
            existing.status == SyncSequenceStatus.requested.index) {
          // Explicitly requested - mark as backfilled
          status = SyncSequenceStatus.backfilled;
        } else {
          // New entry or was missing - mark as received
          status = SyncSequenceStatus.received;
        }

        await _syncDatabase.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: Value(hostId),
            counter: Value(counter),
            entryId: Value(entryId),
            payloadType: Value(payloadType.index),
            originatingHostId: Value(originatingHostId),
            status: Value(status.index),
            jsonPath: jsonPath != null ? Value(jsonPath) : const Value.absent(),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        if (status == SyncSequenceStatus.backfilled &&
            existing?.status == SyncSequenceStatus.requested.index) {
          _trace(
            'recordReceivedEntry: backfilled hostId=$hostId counter=$counter entryId=$entryId',
            subDomain: 'sequence.backfillArrived',
          );
          _trace(
            'recordReceivedEntry: requestedResolved hostId=$hostId counter=$counter entryId=$entryId type=$payloadType',
            subDomain: 'sequence.requestedResolved',
          );
        }
      } else {
        // For other hosts in the VC, also record with entryId.
        // This is crucial because:
        // 1. It allows us to respond to backfill requests for any counter in the VC
        // 2. It updates missing/requested entries when we receive a newer version
        //    of an entry that includes this (host, counter) in its VC
        final existing = await _syncDatabase.getEntryByHostAndCounter(
          hostId,
          counter,
        );

        // Determine the new status (same logic as for originator)
        final SyncSequenceStatus status;
        if (existing != null &&
            (existing.status == SyncSequenceStatus.received.index ||
                existing.status == SyncSequenceStatus.backfilled.index)) {
          // Already received or backfilled - keep the existing status
          status = SyncSequenceStatus.values[existing.status];
        } else if (existing != null &&
            existing.status == SyncSequenceStatus.requested.index) {
          // Explicitly requested - mark as backfilled
          status = SyncSequenceStatus.backfilled;
        } else {
          // New entry or was missing - mark as received
          status = SyncSequenceStatus.received;
        }

        // Always upsert (insert or update) with entryId
        await _syncDatabase.recordSequenceEntry(
          SyncSequenceLogCompanion(
            hostId: Value(hostId),
            counter: Value(counter),
            entryId: Value(entryId),
            payloadType: Value(payloadType.index),
            originatingHostId: Value(originatingHostId),
            status: Value(status.index),
            jsonPath: jsonPath != null ? Value(jsonPath) : const Value.absent(),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        if (status == SyncSequenceStatus.backfilled &&
            existing?.status == SyncSequenceStatus.requested.index) {
          _trace(
            'recordReceivedEntry: backfilled (non-originator) hostId=$hostId counter=$counter entryId=$entryId',
            subDomain: 'sequence.backfillArrived',
          );
          _trace(
            'recordReceivedEntry: requestedResolved (non-originator) hostId=$hostId counter=$counter entryId=$entryId type=$payloadType',
            subDomain: 'sequence.requestedResolved',
          );
        }
      }

      // Invalidate counter cache for this host since we just recorded entries
      _invalidateCacheForHost(hostId);
    }

    // Only log the gap summary when we actually recorded new missing rows.
    // A permanent pre-history gap keeps `gaps` non-empty on every event, so
    // an unconditional log line fires thousands of times for no new signal.
    if (gaps.isNotEmpty && newMissingDetected) {
      _trace(
        'recordReceivedEntry type=$payloadType entryId=$entryId detected ${gaps.count} gaps',
        subDomain: 'sequence.recordReceived',
      );
    }

    // After processing the VC, check for any pending backfill hints.
    // This handles the case where a BackfillResponse arrived before the
    // actual entry. The hint contains the entryId, and now that we have
    // the entry, we can verify and mark it as backfilled.
    await resolvePendingHints(
      payloadType: payloadType,
      payloadId: entryId,
      payloadVectorClock: vectorClock,
    );

    // Note: Covered vector clocks are processed at the START of this method,
    // BEFORE gap detection, to prevent false positives.

    if (newMissingDetected) {
      // Preserve gaps immediately, but defer the automatic backfill nudge
      // until the surrounding ordered replay batch settles. This prevents
      // transient in-burst holes from triggering redundant repair chatter.
      if (_deferredMissingEntriesDepth > 0) {
        _pendingMissingEntriesDetected = true;
      } else {
        _emitMissingEntriesDetected();
      }
    }

    return gaps.toGapList();
  }

  Future<int> _materializeLargeGap({
    required String hostId,
    required int startCounter,
    required int endCounter,
    required int gapSize,
    required String originatingHostId,
    required DateTime now,
  }) async {
    if (gapSize >= SyncTuning.extremeGapWarningSize) {
      _trace(
        'extremeGapDetected hostId=$hostId gapSize=$gapSize '
        'start=$startCounter end=$endCounter '
        'chunkSize=${SyncTuning.gapMaterializationChunkSize}',
        subDomain: 'sequence.extremeGap',
      );
    }

    var insertedCount = 0;
    for (
      var chunkStart = startCounter;
      chunkStart <= endCounter;
      chunkStart += SyncTuning.gapMaterializationChunkSize
    ) {
      final chunkEnd = math.min(
        endCounter,
        chunkStart + SyncTuning.gapMaterializationChunkSize - 1,
      );
      final existingCounters = await _syncDatabase.getCountersForHostInRange(
        hostId,
        chunkStart,
        chunkEnd,
      );
      final missingEntries = <SyncSequenceLogCompanion>[];

      for (var counter = chunkStart; counter <= chunkEnd; counter++) {
        if (!existingCounters.contains(counter)) {
          missingEntries.add(
            SyncSequenceLogCompanion(
              hostId: Value(hostId),
              counter: Value(counter),
              originatingHostId: Value(originatingHostId),
              status: Value(SyncSequenceStatus.missing.index),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
      }

      if (missingEntries.isNotEmpty) {
        insertedCount += missingEntries.length;
        await _syncDatabase.batchInsertSequenceEntries(missingEntries);
      }
    }

    return insertedCount;
  }

  List<VectorClock> _filterCoveredVectorClocks(
    List<VectorClock>? coveredVectorClocks,
    VectorClock current,
  ) {
    if (coveredVectorClocks == null || coveredVectorClocks.isEmpty) {
      return const [];
    }
    final filtered = <VectorClock>[];
    for (final clock in coveredVectorClocks) {
      final isCurrent =
          VectorClock.compare(clock, current) == VclockStatus.equal;
      if (!isCurrent) {
        filtered.add(clock);
      }
    }
    return filtered;
  }

  Future<List<({String hostId, int counter})>> recordReceivedEntryLink({
    required String linkId,
    required VectorClock vectorClock,
    required String originatingHostId,
    List<VectorClock>? coveredVectorClocks,
  }) {
    return recordReceivedEntry(
      entryId: linkId,
      vectorClock: vectorClock,
      originatingHostId: originatingHostId,
      coveredVectorClocks: coveredVectorClocks,
      payloadType: SyncSequencePayloadType.entryLink,
    );
  }

  /// Mark counters from covered vector clocks as received.
  /// These are counters that were "spent" on superseded versions of the entry
  /// before the final version was sent.
  ///
  /// This method inserts records for covered counters even if they don't exist
  /// yet in the sequence log. This pre-emptively marks them as received before
  /// gap detection can mark them as missing, preventing unnecessary backfill
  /// requests for counters that were superseded before being sent.
  Future<void> _markCoveredCountersAsReceived({
    required List<VectorClock> coveredVectorClocks,
    required String entryId,
    required SyncSequencePayloadType payloadType,
    required String myHost,
  }) async {
    final now = DateTime.now();
    var markedCount = 0;
    final affectedHosts = <String>{};

    for (final coveredClock in coveredVectorClocks) {
      for (final entry in coveredClock.vclock.entries) {
        final hostId = entry.key;
        final counter = entry.value;

        // Skip our own host
        if (hostId == myHost) continue;

        // Check if this counter already exists in the sequence log
        final existing = await _syncDatabase.getEntryByHostAndCounter(
          hostId,
          counter,
        );

        // Insert or update record for covered counter:
        // - If doesn't exist: insert as received (pre-empt gap detection)
        // - If exists with missing/requested: update to received
        // - If exists with received/backfilled: skip (don't downgrade)
        if (existing == null) {
          // Counter doesn't exist - insert as received to pre-empt gap detection
          await _syncDatabase.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: Value(hostId),
              counter: Value(counter),
              entryId: Value(entryId),
              payloadType: Value(payloadType.index),
              status: Value(SyncSequenceStatus.received.index),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
          markedCount++;
          affectedHosts.add(hostId);
        } else if (existing.status == SyncSequenceStatus.missing.index ||
            existing.status == SyncSequenceStatus.requested.index) {
          // Existing record with missing/requested - update to received
          await _syncDatabase.recordSequenceEntry(
            SyncSequenceLogCompanion(
              hostId: Value(hostId),
              counter: Value(counter),
              entryId: Value(entryId),
              payloadType: Value(payloadType.index),
              status: Value(SyncSequenceStatus.received.index),
              createdAt: Value(existing.createdAt),
              updatedAt: Value(now),
            ),
          );
          markedCount++;
          affectedHosts.add(hostId);
          if (existing.status == SyncSequenceStatus.requested.index) {
            _trace(
              'recordReceivedEntry: requestedResolved (covered) hostId=$hostId counter=$counter entryId=$entryId type=$payloadType',
              subDomain: 'sequence.requestedResolved',
            );
          }
        }
        // If already received/backfilled, skip - don't downgrade status
      }
    }

    if (markedCount > 0) {
      // Invalidate the watermark cache for affected hosts so that subsequent
      // gap detection in the same recordReceivedEntry call sees the updated
      // contiguous watermark. Without this, the stale cached watermark causes
      // repeated gap detection events for counters that were just resolved.
      affectedHosts.forEach(_invalidateCacheForHost);
      _trace(
        'markCoveredCountersAsReceived: marked $markedCount counters as received for entry=$entryId',
        subDomain: 'sequence.coveredClocks',
      );
    }
  }

  /// Get entries marked as missing or requested that haven't exceeded
  /// the maximum request count, for sending backfill requests.
  Future<List<SyncSequenceLogItem>> getMissingEntries({
    int limit = 50,
    int maxRequestCount = 10,
    int offset = 0,
  }) {
    return _syncDatabase.getMissingEntries(
      limit: limit,
      maxRequestCount: maxRequestCount,
      offset: offset,
    );
  }

  /// Mark entries as requested and increment their request count.
  /// Uses batch operations for efficiency.
  Future<void> markAsRequested(
    List<({String hostId, int counter})> entries,
  ) async {
    await _syncDatabase.batchIncrementRequestCounts(entries);
  }

  /// Handle a backfill response from another device.
  ///
  /// For deleted responses: marks the entry as deleted (cannot be backfilled).
  ///
  /// For unresolvable responses: marks the entry as unresolvable - the
  /// originating host confirmed it cannot resolve its own counter (e.g., it
  /// was superseded before being recorded).
  ///
  /// For non-deleted responses: stores the entryId as a "hint" mapping
  /// (hostId, counter) → entryId. The actual status update to "backfilled"
  /// happens only when we verify the entry exists locally - either via
  /// [verifyAndMarkBackfilled] or when the entry arrives via normal sync.
  ///
  /// This two-phase approach ensures we don't mark entries as backfilled
  /// until we actually have the data locally.
  Future<void> handleBackfillResponse({
    required String hostId,
    required int counter,
    required bool deleted,
    bool unresolvable = false,
    String? entryId,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
  }) async {
    if (deleted) {
      // Mark as deleted - the entry was purged and cannot be backfilled
      await _syncDatabase.updateSequenceStatus(
        hostId,
        counter,
        SyncSequenceStatus.deleted,
      );

      _trace(
        'handleBackfillResponse hostId=$hostId counter=$counter deleted=true',
        subDomain: 'sequence.backfillResponse',
      );
      return;
    }

    if (unresolvable) {
      // Mark as unresolvable - the originating host cannot resolve its own
      // counter. This is permanent; the entry will never be backfilled.
      await _syncDatabase.updateSequenceStatus(
        hostId,
        counter,
        SyncSequenceStatus.unresolvable,
      );

      _trace(
        'handleBackfillResponse hostId=$hostId counter=$counter unresolvable=true',
        subDomain: 'sequence.backfillResponse',
      );
      return;
    }

    // Non-deleted response: store the entryId hint without changing status.
    // The actual backfill confirmation happens when we verify the entry exists.
    final existing = await _syncDatabase.getEntryByHostAndCounter(
      hostId,
      counter,
    );

    if (existing == null) {
      // Entry doesn't exist in our log - insert with entryId hint and mark
      // as "requested" since we're receiving a response to a backfill request.
      // The actual backfilled status is set when we verify the entry exists.
      final now = DateTime.now();
      await _syncDatabase.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: Value(hostId),
          counter: Value(counter),
          entryId: Value(entryId),
          payloadType: Value(payloadType.index),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      _trace(
        'handleBackfillResponse: stored hint hostId=$hostId counter=$counter entryId=$entryId (new entry)',
        subDomain: 'sequence.backfillHint',
      );
      return;
    }

    // Don't overwrite already received/backfilled/deleted entries
    if (existing.status == SyncSequenceStatus.received.index ||
        existing.status == SyncSequenceStatus.backfilled.index ||
        existing.status == SyncSequenceStatus.deleted.index) {
      _trace(
        'handleBackfillResponse: entry already has status=${SyncSequenceStatus.values[existing.status]} hostId=$hostId counter=$counter',
        subDomain: 'sequence.backfillResponse',
      );
      return;
    }

    // When an unresolvable entry receives a valid hint, reset to requested
    // so it can be verified. This handles the case where the first response
    // incorrectly marked it unresolvable but a later response has the answer.
    final newStatus = existing.status == SyncSequenceStatus.unresolvable.index
        ? SyncSequenceStatus.requested.index
        : existing.status;

    final now = DateTime.now();
    await _syncDatabase.recordSequenceEntry(
      SyncSequenceLogCompanion(
        hostId: Value(hostId),
        counter: Value(counter),
        entryId: Value(entryId),
        payloadType: Value(payloadType.index),
        status: Value(newStatus),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(now),
      ),
    );

    if (existing.status == SyncSequenceStatus.unresolvable.index) {
      _trace(
        'handleBackfillResponse: reopened unresolvable entry hostId=$hostId counter=$counter entryId=$entryId',
        subDomain: 'sequence.backfillReopened',
      );
    }

    _trace(
      'handleBackfillResponse: stored hint hostId=$hostId counter=$counter entryId=$entryId (status=${SyncSequenceStatus.values[newStatus]})',
      subDomain: 'sequence.backfillHint',
    );
  }

  /// Verify that we have an entry locally and its VC covers the requested
  /// (hostId, counter), then mark as backfilled.
  ///
  /// Returns true if verified and marked as backfilled.
  Future<bool> verifyAndMarkBackfilled({
    required String hostId,
    required int counter,
    required String entryId,
    required VectorClock entryVectorClock,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
  }) async {
    // Verify the entry's VC covers the requested (hostId, counter)
    final vcCounter = entryVectorClock.vclock[hostId];
    if (vcCounter == null || vcCounter < counter) {
      _trace(
        'verifyAndMarkBackfilled: entry $entryId VC does not cover $hostId:$counter (vc[$hostId]=$vcCounter)',
        subDomain: 'sequence.backfillVerify',
      );
      return false;
    }

    // Look up the sequence log entry
    final existing = await _syncDatabase.getEntryByHostAndCounter(
      hostId,
      counter,
    );

    if (existing == null ||
        (existing.status != SyncSequenceStatus.missing.index &&
            existing.status != SyncSequenceStatus.requested.index)) {
      // Already processed or doesn't exist
      return false;
    }

    // Mark as backfilled
    final now = DateTime.now();
    await _syncDatabase.recordSequenceEntry(
      SyncSequenceLogCompanion(
        hostId: Value(hostId),
        counter: Value(counter),
        entryId: Value(entryId),
        payloadType: Value(payloadType.index),
        status: Value(SyncSequenceStatus.backfilled.index),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    _trace(
      'verifyAndMarkBackfilled: confirmed hostId=$hostId counter=$counter entryId=$entryId',
      subDomain: 'sequence.backfillVerified',
    );
    return true;
  }

  /// Resolve any pending backfill hints for the given entryId.
  /// Called after receiving an entry via sync to check if it resolves
  /// any pending (hostId, counter) requests.
  Future<int> resolvePendingHints({
    required SyncSequencePayloadType payloadType,
    required String payloadId,
    required VectorClock payloadVectorClock,
  }) async {
    final pendingEntries = await _syncDatabase.getPendingEntriesByPayloadId(
      payloadType: payloadType,
      payloadId: payloadId,
    );

    var resolved = 0;
    for (final pending in pendingEntries) {
      final verified = await verifyAndMarkBackfilled(
        hostId: pending.hostId,
        counter: pending.counter,
        entryId: payloadId,
        entryVectorClock: payloadVectorClock,
        payloadType: payloadType,
      );
      if (verified) {
        resolved++;
      }
    }

    if (resolved > 0) {
      _trace(
        'resolvePendingHints: resolved $resolved pending entries for type=$payloadType id=$payloadId',
        subDomain: 'sequence.backfillResolved',
      );
    }

    return resolved;
  }

  /// Reset entries marked as unresolvable that now have a known payload
  /// (entryId) back to "missing" so they can be re-requested.
  /// Returns the number of entries reset.
  Future<int> resetUnresolvableEntries() async {
    final count = await _syncDatabase.resetUnresolvableWithKnownPayload();

    if (count > 0) {
      _trace(
        'resetUnresolvableEntries: reset $count entries back to missing',
        subDomain: 'sequence.resetUnresolvable',
      );
    }

    return count;
  }

  /// Flip missing/requested rows that have been asked for at least
  /// [maxRequestCount] times to `unresolvable` so the contiguous-prefix
  /// watermark can advance past them. Without this step, a permanent
  /// pre-history gap keeps `getLastCounterForHost` stuck, which then
  /// forces every incoming entry on that host to re-enter the gap
  /// materialization pass (see `_materializeLargeGap`). Invalidates the
  /// per-host watermark and materialized-bound caches so the next event
  /// sees the updated state.
  ///
  /// The [grace] window gives a backfill request still queued in the
  /// outbox or in flight to a peer time to land before the row is
  /// promoted terminal; tests may pass a smaller value to bypass the
  /// wait.
  Future<int> retireExhaustedRequestedEntries({
    int maxRequestCount = 10,
    Duration grace = const Duration(minutes: 5),
  }) async {
    final count = await _syncDatabase.retireExhaustedRequestedEntries(
      maxRequestCount: maxRequestCount,
      grace: grace,
    );

    if (count > 0) {
      _lastCounterCache.clear();
      _materializedUpperBound.clear();
      _trace(
        'retireExhaustedRequestedEntries: retired $count entries to unresolvable',
        subDomain: 'sequence.retireExhausted',
      );
    }

    return count;
  }

  /// Get entry by host ID and counter (for responding to backfill requests).
  Future<SyncSequenceLogItem?> getEntryByHostAndCounter(
    String hostId,
    int counter,
  ) {
    return _syncDatabase.getEntryByHostAndCounter(hostId, counter);
  }

  /// Find the nearest covering entry for a host with counter >= [counter].
  /// Used when the exact counter is missing from the sequence log (superseded).
  Future<SyncSequenceLogItem?> getNearestCoveringEntry(
    String hostId,
    int counter,
  ) {
    return _syncDatabase.getNearestCoveringEntry(hostId, counter);
  }

  /// Get backfill statistics grouped by host.
  Future<BackfillStats> getBackfillStats() {
    return _syncDatabase.getBackfillStats();
  }

  /// Get missing entries with age and per-host limits for automatic backfill.
  /// This is used for bounded automatic backfill that only looks at recent gaps.
  Future<List<SyncSequenceLogItem>> getMissingEntriesWithLimits({
    int limit = 50,
    int maxRequestCount = 10,
    Duration? maxAge,
    int? maxPerHost,
    int offset = 0,
  }) {
    return _syncDatabase.getMissingEntriesWithLimits(
      limit: limit,
      maxRequestCount: maxRequestCount,
      maxAge: maxAge,
      maxPerHost: maxPerHost,
      offset: offset,
    );
  }

  /// Get entries with status 'requested' for re-requesting.
  /// These are entries that were requested but never received.
  Future<List<SyncSequenceLogItem>> getRequestedEntries({
    int limit = 50,
    int offset = 0,
  }) {
    return _syncDatabase.getRequestedEntries(limit: limit, offset: offset);
  }

  /// Reset request counts for specified entries to allow re-requesting.
  Future<void> resetRequestCounts(
    List<({String hostId, int counter})> entries,
  ) async {
    await _syncDatabase.resetRequestCounts(entries);

    _trace(
      'resetRequestCounts: reset ${entries.length} entries for re-request',
      subDomain: 'sequence.reRequest',
    );
  }

  /// Populate the sequence log from existing journal entries.
  /// Returns the number of sequence log entries populated.
  Future<int> populateFromJournal({
    required Stream<List<({String id, Map<String, int>? vectorClock})>>
    entryStream,
    required Future<int> Function() getTotalCount,
    void Function(double progress)? onProgress,
  }) {
    return _populateFromStream(
      dataStream: entryStream,
      getTotalCount: getTotalCount,
      onProgress: onProgress,
      payloadType: SyncSequencePayloadType.journalEntity,
      label: 'populateFromJournal',
    );
  }

  /// Populate the sequence log from existing entry links.
  /// Returns the number of sequence log entries populated.
  Future<int> populateFromEntryLinks({
    required Stream<List<({String id, Map<String, int>? vectorClock})>>
    linkStream,
    required Future<int> Function() getTotalCount,
    void Function(double progress)? onProgress,
  }) {
    return _populateFromStream(
      dataStream: linkStream,
      getTotalCount: getTotalCount,
      onProgress: onProgress,
      payloadType: SyncSequencePayloadType.entryLink,
      label: 'populateFromEntryLinks',
    );
  }

  /// Populate the sequence log from existing agent entities.
  /// Returns the number of sequence log entries populated.
  Future<int> populateFromAgentEntities({
    required Stream<List<({String id, Map<String, int>? vectorClock})>>
    entityStream,
    required Future<int> Function() getTotalCount,
    void Function(double progress)? onProgress,
  }) {
    return _populateFromStream(
      dataStream: entityStream,
      getTotalCount: getTotalCount,
      onProgress: onProgress,
      payloadType: SyncSequencePayloadType.agentEntity,
      label: 'populateFromAgentEntities',
    );
  }

  /// Populate the sequence log from existing agent links.
  /// Returns the number of sequence log entries populated.
  Future<int> populateFromAgentLinks({
    required Stream<List<({String id, Map<String, int>? vectorClock})>>
    linkStream,
    required Future<int> Function() getTotalCount,
    void Function(double progress)? onProgress,
  }) {
    return _populateFromStream(
      dataStream: linkStream,
      getTotalCount: getTotalCount,
      onProgress: onProgress,
      payloadType: SyncSequencePayloadType.agentLink,
      label: 'populateFromAgentLinks',
    );
  }

  /// Shared implementation for populating the sequence log from a paginated
  /// stream of records with vector clocks. Used by all four populate methods.
  Future<int> _populateFromStream({
    required Stream<List<({String id, Map<String, int>? vectorClock})>>
    dataStream,
    required Future<int> Function() getTotalCount,
    required SyncSequencePayloadType payloadType,
    required String label,
    void Function(double progress)? onProgress,
  }) async {
    final total = await getTotalCount();
    var processed = 0;
    var populated = 0;
    final now = DateTime.now();

    // Cache of existing (hostId, counter) pairs to avoid duplicates
    final existingByHost = <String, Set<int>>{};

    await for (final batch in dataStream) {
      final toInsert = <SyncSequenceLogCompanion>[];

      for (final record in batch) {
        processed++;

        final vc = record.vectorClock;
        if (vc == null || vc.isEmpty) continue;

        // Find the originating host (the one with the highest counter).
        // Sort entries by host ID for deterministic tie-breaking.
        String? originatingHost;
        var maxCounter = -1;
        final sortedEntries = vc.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        for (final e in sortedEntries) {
          if (e.value > maxCounter) {
            maxCounter = e.value;
            originatingHost = e.key;
          }
        }

        // Record entry for each host in the vector clock
        for (final vcEntry in vc.entries) {
          final hostId = vcEntry.key;
          final counter = vcEntry.value;

          // Lazily load existing counters for this host
          if (!existingByHost.containsKey(hostId)) {
            existingByHost[hostId] = await _syncDatabase.getCountersForHost(
              hostId,
            );
          }

          final existing = existingByHost[hostId]!;

          // Skip if already exists
          if (existing.contains(counter)) continue;

          // Mark as existing to avoid duplicates within this run
          existing.add(counter);

          toInsert.add(
            SyncSequenceLogCompanion(
              hostId: Value(hostId),
              counter: Value(counter),
              entryId: Value(record.id),
              payloadType: Value(payloadType.index),
              originatingHostId: Value(originatingHost ?? hostId),
              status: Value(SyncSequenceStatus.received.index),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
      }

      // Batch insert
      if (toInsert.isNotEmpty) {
        await _syncDatabase.batchInsertSequenceEntries(toInsert);
        populated += toInsert.length;
      }

      // Report progress after each batch
      if (onProgress != null && total > 0) {
        onProgress(processed / total);
      }
    }

    if (populated > 0) {
      _trace(
        '$label: added $populated sequence log entries',
        subDomain: 'sequence.populate',
      );
    }

    return populated;
  }
}
