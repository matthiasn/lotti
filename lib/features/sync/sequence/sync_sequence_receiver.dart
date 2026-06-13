import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_backfill_responder.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_cache.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_gap_materializer.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_gap_model.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_missing_notifier.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_tracer.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// Records received entries and detects gaps in the sync sequence log — the
/// orchestration core of the receive path.
///
/// Collaborates with the shared [SyncSequenceCache] (watermark and last-sent
/// caches), the [SyncSequenceGapMaterializer] (large-gap and covered-counter
/// bookkeeping), the [SyncSequenceBackfillResponder] (pending-hint resolution
/// after recording), and the [SyncSequenceMissingNotifier] (deferred
/// missing-entries nudge).
class SyncSequenceReceiver {
  SyncSequenceReceiver({
    required this._syncDatabase,
    required this._vectorClockService,
    required this._cache,
    required this._gapMaterializer,
    required this._backfillResponder,
    required this._missingNotifier,
    required this._tracer,
  });

  final SyncDatabase _syncDatabase;
  final VectorClockService _vectorClockService;
  final SyncSequenceCache _cache;
  final SyncSequenceGapMaterializer _gapMaterializer;
  final SyncSequenceBackfillResponder _backfillResponder;
  final SyncSequenceMissingNotifier _missingNotifier;
  final SyncSequenceTracer _tracer;

  Future<VectorClock?> getLastSentVectorClockForEntry(String entryId) async {
    final myHost = await _vectorClockService.getHost();
    if (myHost == null) return null;
    _cache
      ..invalidateLastSentCacheIfExpired()
      ..ensureLastSentCacheWindow();
    final cacheKey = _cache.lastSentCacheKey(myHost, entryId);
    int? counter;
    if (_cache.containsLastSent(cacheKey)) {
      counter = _cache.getLastSent(cacheKey);
      // Refresh LRU position on hit so active entries stay resident.
      _cache.touchLastSentCache(cacheKey, counter);
    } else {
      counter = await _syncDatabase.getLastSentCounterForEntry(
        myHost,
        entryId,
      );
      _cache.touchLastSentCache(cacheKey, counter);
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
    final gaps = GapAccumulator();
    var newMissingDetected = false;
    final myHost = await _vectorClockService.getHost();
    final now = DateTime.now();

    // Update host activity for the originating host - they're online!
    await _syncDatabase.updateHostActivity(originatingHostId, now);
    // Update cache so subsequent checks in this batch see the new activity
    _cache.setHostActivity(originatingHostId, now);

    // IMPORTANT: Process covered vector clocks BEFORE gap detection.
    // This prevents false positives: covered counters are pre-emptively marked
    // as received, so gap detection (which checks `existing == null`) will
    // skip them instead of incorrectly marking them as missing.
    final filteredCovered = _gapMaterializer.filterCoveredVectorClocks(
      coveredVectorClocks,
      vectorClock,
    );
    if (filteredCovered.isNotEmpty && myHost != null) {
      _tracer.trace(
        'recordReceivedEntry: coveredVCs count=${filteredCovered.length} '
        'clocks=${filteredCovered.map((vc) => vc.vclock).toList()} '
        'entryId=$entryId type=$payloadType',
        subDomain: 'sequence.coveredClocks',
      );
      await _gapMaterializer.markCoveredCountersAsReceived(
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
      final hostLastOnline = await _cache.getCachedHostLastSeen(hostId);
      final shouldDetectGaps =
          hostLastOnline != null || hostId == originatingHostId;

      if (!shouldDetectGaps) {
        _tracer.trace(
          'skipGapDetection hostId=$hostId counter=$counter - host never seen online',
          subDomain: 'sequence.skipGap',
        );
      }

      final lastSeen = await _cache.getCachedLastCounterForHost(hostId);
      // For hosts that are currently considered online, an unknown contiguous
      // prefix still means "we have not resolved counter 1 yet", not "there can
      // be no gap". Treat that as watermark 0 so the first observed counter can
      // materialize the missing prefix instead of silently skipping it.
      final gapBaseline = shouldDetectGaps ? (lastSeen ?? 0) : null;
      var smallGapRangeResolvedBeforeObserved = false;

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
          final previousBound = _cache.getMaterializedUpperBound(hostId);
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
              _tracer.trace(
                'largeGapDetected hostId=$hostId gapSize=$gapSize (lastSeen=$gapBaseline, counter=$counter) - recording full gap',
                subDomain: 'sequence.largeGap',
              );
            }
            final insertedCount = await _gapMaterializer.materializeLargeGap(
              hostId: hostId,
              startCounter: effectiveStart,
              endCounter: endCounter,
              gapSize: effectiveSize,
              originatingHostId: originatingHostId,
              now: now,
            );
            // `previousBound < endCounter` on this branch, so direct assignment
            // is the max — no `math.max` needed.
            _cache.setMaterializedUpperBound(hostId, endCounter);
            if (insertedCount > 0) {
              // Any newly inserted missing rows must drive a backfill nudge,
              // including the incremental-extension case where the observed
              // counter jumps past `previousBound` by more than one. Only the
              // noisy `sequence.gapDetected` trace is suppressed for the
              // one-counter-at-a-time incremental case.
              newMissingDetected = true;
              if (!isIncrementalExtension) {
                _tracer.trace(
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
          // Small gap (≤ SyncTuning.maxGapSize). The cached watermark is a
          // conservative lower bound, so it can lag behind already-resolved
          // out-of-order counters. Only return counters that are absent or
          // still unresolved; otherwise callers log stale false gaps.
          final existingCounters = await _syncDatabase
              .getCountersForHostInRange(
                hostId,
                startCounter,
                counter - 1,
              );
          final missingEntries = <SyncSequenceLogCompanion>[];
          var unresolvedGapDetected = false;
          for (var i = startCounter; i < counter; i++) {
            // Keep the small-gap path explicit because the per-counter logging
            // is still useful when debugging ordinary out-of-order delivery.
            if (!existingCounters.contains(i)) {
              unresolvedGapDetected = true;
              gaps.addRange(hostId: hostId, startCounter: i, endCounter: i);
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

              _tracer.trace(
                'gapDetected hostId=$hostId counter=$i (last seen: $gapBaseline, observed: $counter) from=$originatingHostId',
                subDomain: 'sequence.gapDetected',
              );
            } else {
              final existing = await _syncDatabase.getEntryByHostAndCounter(
                hostId,
                i,
              );
              if (existing == null ||
                  !isResolvedSequenceStatusIndex(existing.status)) {
                unresolvedGapDetected = true;
                gaps.addRange(hostId: hostId, startCounter: i, endCounter: i);
              }
            }
          }
          smallGapRangeResolvedBeforeObserved = !unresolvedGapDetected;
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

        if (existing != null &&
            existing.status == SyncSequenceStatus.burned.index) {
          // burned is the authoritative terminal non-event: never reopen it,
          // and never overwrite its empty payload mapping with the received
          // entity's id. The originator re-sending its own burnt counter is a
          // contradiction we ignore. Mirrors the handleBackfillResponse hint
          // guard so burned has no outgoing edges on any receive path. The row
          // is already resolved, so the forward-only watermark-cache advance we
          // skip here is a no-op.
          _tracer.trace(
            'recordReceivedEntry: burned preserved (originator) '
            'hostId=$hostId counter=$counter',
            subDomain: 'sequence.burnPreserved',
          );
          continue;
        }

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
          _tracer
            ..trace(
              'recordReceivedEntry: backfilled hostId=$hostId counter=$counter entryId=$entryId',
              subDomain: 'sequence.backfillArrived',
            )
            ..trace(
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

        if (existing != null &&
            existing.status == SyncSequenceStatus.burned.index) {
          // burned is the authoritative terminal non-event. A different host's
          // entry that merely covers this counter in its vector clock must not
          // reopen the burn or stamp its own entry id onto it (covering an
          // own-host burn from a different entity is unsound). The row is
          // already resolved, so skipping the forward-only watermark-cache
          // advance below is a no-op.
          _tracer.trace(
            'recordReceivedEntry: burned preserved (covered) '
            'hostId=$hostId counter=$counter',
            subDomain: 'sequence.burnPreserved',
          );
          continue;
        }

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
          _tracer
            ..trace(
              'recordReceivedEntry: backfilled (non-originator) hostId=$hostId counter=$counter entryId=$entryId',
              subDomain: 'sequence.backfillArrived',
            )
            ..trace(
              'recordReceivedEntry: requestedResolved (non-originator) hostId=$hostId counter=$counter entryId=$entryId type=$payloadType',
              subDomain: 'sequence.requestedResolved',
            );
        }
      }

      // Conservatively advance the watermark cache instead of invalidating
      // it. Under heavy backfill (50 children per outbox bundle), the old
      // unconditional invalidate forced the next child to re-run the
      // slow `getLastCounterForHost` CTE — that query dominated the
      // mobile slow-query log under load. The advance is a strict
      // forward-only update that never over-reports the prefix.
      _cache.advanceLastCounterCache(hostId, counter);
      if (smallGapRangeResolvedBeforeObserved &&
          _cache.containsLastCounter(hostId)) {
        // The small-gap scan proved every counter between the cached
        // watermark and the observed counter already resolves the sequence.
        // After upserting [counter], the cache can safely catch up instead of
        // re-scanning the same stale range on each subsequent event.
        final cachedCounter = _cache.getLastCounter(hostId) ?? 0;
        if (counter > cachedCounter) {
          _cache.setLastCounter(hostId, counter);
        }
      }
    }

    // Only log the gap summary when we actually recorded new missing rows.
    // A permanent pre-history gap keeps `gaps` non-empty on every event, so
    // an unconditional log line fires thousands of times for no new signal.
    if (gaps.isNotEmpty && newMissingDetected) {
      _tracer.trace(
        'recordReceivedEntry type=$payloadType entryId=$entryId detected ${gaps.count} gaps',
        subDomain: 'sequence.recordReceived',
      );
    }

    // After processing the VC, check for any pending backfill hints.
    // This handles the case where a BackfillResponse arrived before the
    // actual entry. The hint contains the entryId, and now that we have
    // the entry, we can verify and mark it as backfilled.
    await _backfillResponder.resolvePendingHints(
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
      _missingNotifier.flagMissingEntriesDetected();
    }

    return gaps.toGapList();
  }

  /// Cheap existence probe for any actionable (`missing` or `requested`)
  /// sequence row. Used by the backfill request service to short-circuit
  /// the periodic timer body when nothing is missing — see
  /// [SyncDatabase.hasActionableEntries] for the rationale.
  Future<bool> hasActionableEntries() {
    return _syncDatabase.hasActionableEntries();
  }

  /// Get entries marked as missing or requested that haven't exceeded
  /// the maximum request count, for sending backfill requests.
  ///
  /// [minAge] defers returning rows freshly flagged as missing for that long
  /// — see [SyncDatabase.getMissingEntries] for the rationale.
  Future<List<SyncSequenceLogItem>> getMissingEntries({
    int limit = 50,
    int maxRequestCount = 10,
    int offset = 0,
    Duration minAge = Duration.zero,
  }) {
    return _syncDatabase.getMissingEntries(
      limit: limit,
      maxRequestCount: maxRequestCount,
      offset: offset,
      minAge: minAge,
    );
  }

  /// Mark entries as requested and increment their request count.
  /// Uses batch operations for efficiency.
  Future<void> markAsRequested(
    List<({String hostId, int counter})> entries,
  ) async {
    await _syncDatabase.batchIncrementRequestCounts(entries);
  }

  /// Mark one of OUR OWN host's counters as permanently unresolvable.
  ///
  /// Called by paths that know authoritatively that a counter was assigned by
  /// our [VectorClockService] but will never carry a Matrix event — burns
  /// from [VectorClockService.reserveNextVectorClock] that released without
  /// a matching write, and own-host miss/stale cases in
  /// `backfill_response_handler` that answer peers with `unresolvable`.
  ///
  /// Why an upsert (not just [SyncDatabase.updateSequenceStatus]): the burn
  /// case usually has no row in our sequence log at all (we never
  /// `recordSentEntry`-ed the counter), so an update-only call would silently
  /// no-op. Insert-or-update pins the row to `status=unresolvable` with
  /// `entry_id` explicitly null — asserting "no entity was ever bound to this
  /// counter on this host." Subsequent paths that might have otherwise
  /// inserted the row with the wrong entity_id (covered-VC hints referring
  /// to our own host, if any skip is ever relaxed) will then see an existing
  /// authoritative row and leave it alone.
  ///
  /// The authoritative-row guard is implemented inside
  /// [SyncDatabase.recordOwnUnresolvableSequenceCounter] so the check and
  /// mutation happen in one database transaction.
  ///
  /// Not wired through `handleBackfillResponse` because that is the handler
  /// for INCOMING responses, and own-host broadcasts never flow through it
  /// on the originator — self-echoes are suppressed in the Matrix pipeline.
  /// Going through the receiver handler on the sender side would misrepresent
  /// the call's intent and break the moment someone tightens the handler
  /// contract (e.g. gates it on a pending request).
  Future<void> markOwnCounterUnresolvable({
    required String hostId,
    required int counter,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
  }) async {
    final recorded = await _syncDatabase.recordOwnUnresolvableSequenceCounter(
      hostId: hostId,
      counter: counter,
      payloadType: payloadType,
    );
    _tracer.trace(
      recorded
          ? 'markOwnCounterUnresolvable hostId=$hostId counter=$counter'
          : 'markOwnCounterUnresolvable skipped hostId=$hostId '
                'counter=$counter',
      subDomain: 'sequence.ownUnresolvable',
    );
  }

  /// Return own-host pre-bind crash markers left behind by
  /// `reserveNextVectorClock`.
  ///
  /// Rows returned from [reservedCountersForHost] are diagnostic only and must
  /// not be automatically converted via [markOwnCounterUnresolvable]. A crash
  /// can happen after the payload commits but before `recordSentEntry`
  /// replaces the `reserved` row, so treating plain reservations as
  /// unresolvable could burn a real payload mapping. Only rows in
  /// [SyncSequenceStatus.burnPending] carry the "released without payload"
  /// guarantee and are safe for startup reconciliation.
  Future<List<int>> reservedCountersForHost({
    required String hostId,
  }) async {
    final counters = await _syncDatabase.reservedSequenceCountersForHost(
      hostId: hostId,
    );
    if (counters.isNotEmpty) {
      _tracer.trace(
        'reservedCountersForHost hostId=$hostId '
        'count=${counters.length} counters=$counters',
        subDomain: 'sequence.reservedCounters',
      );
    }
    return counters;
  }

  /// Return own-host reservations that were explicitly released without a
  /// payload, but whose outbound unresolvable marker still needs to be retried.
  Future<List<int>> burnPendingCountersForHost({
    required String hostId,
  }) async {
    final counters = await _syncDatabase.burnPendingSequenceCountersForHost(
      hostId: hostId,
    );
    if (counters.isNotEmpty) {
      _tracer.trace(
        'burnPendingCountersForHost hostId=$hostId '
        'count=${counters.length} counters=$counters',
        subDomain: 'sequence.burnPendingCounters',
      );
    }
    return counters;
  }
}
