import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_backfill_queries.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_backfill_responder.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_cache.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_gap_materializer.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_missing_notifier.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_receiver.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_sender.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_tracer.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:meta/meta.dart';

/// Service for managing the sync sequence log, which tracks received entries
/// by (hostId, counter) pairs to detect gaps and enable backfill requests.
///
/// This is a thin facade. It instantiates a set of collaborators and delegates
/// every public method to the one that owns it:
///
/// - [SyncSequenceCache] — the SINGLE owner of every mutable in-memory cache
///   (per-host activity / watermark / materialized-bound maps and the
///   last-sent LRU). Injected into every collaborator that records or reads
///   sequence data so dedup and watermark bookkeeping stay coherent.
/// - [SyncSequenceTracer] — sync-domain log routing shared by all collaborators.
/// - [SyncSequenceMissingNotifier] — owns the deferred "missing entries
///   detected" notification state surfaced via [onMissingEntriesDetected] and
///   [runWithDeferredMissingEntries].
/// - [SyncSequenceGapMaterializer] — large-gap materialization and
///   covered-counter bookkeeping.
/// - [SyncSequenceSender] — records entries sent by this device.
/// - [SyncSequenceReceiver] — records received entries and detects gaps.
/// - [SyncSequenceBackfillResponder] — handles incoming backfill responses and
///   pending-hint resolution.
/// - [SyncSequenceBackfillQueries] — read-mostly backfill queries and the
///   journal/link/agent population path.
class SyncSequenceLogService {
  SyncSequenceLogService({
    required SyncDatabase syncDatabase,
    required VectorClockService vectorClockService,
    required DomainLogger loggingService,
    DomainLogger? domainLogger,
  }) {
    _cache = SyncSequenceCache(syncDatabase);
    _tracer = SyncSequenceTracer(
      loggingService: loggingService,
      domainLogger: domainLogger,
    );
    _missingNotifier = SyncSequenceMissingNotifier(tracer: _tracer);
    _gapMaterializer = SyncSequenceGapMaterializer(
      syncDatabase: syncDatabase,
      cache: _cache,
      tracer: _tracer,
    );
    _sender = SyncSequenceSender(
      syncDatabase: syncDatabase,
      vectorClockService: vectorClockService,
      cache: _cache,
      tracer: _tracer,
    );
    _backfillResponder = SyncSequenceBackfillResponder(
      syncDatabase: syncDatabase,
      cache: _cache,
      tracer: _tracer,
    );
    _receiver = SyncSequenceReceiver(
      syncDatabase: syncDatabase,
      vectorClockService: vectorClockService,
      cache: _cache,
      gapMaterializer: _gapMaterializer,
      backfillResponder: _backfillResponder,
      missingNotifier: _missingNotifier,
      tracer: _tracer,
    );
    _backfillQueries = SyncSequenceBackfillQueries(
      syncDatabase: syncDatabase,
      cache: _cache,
      receiver: _receiver,
      tracer: _tracer,
    );
  }

  late final SyncSequenceCache _cache;
  late final SyncSequenceTracer _tracer;
  late final SyncSequenceMissingNotifier _missingNotifier;
  late final SyncSequenceGapMaterializer _gapMaterializer;
  late final SyncSequenceSender _sender;
  late final SyncSequenceReceiver _receiver;
  late final SyncSequenceBackfillResponder _backfillResponder;
  late final SyncSequenceBackfillQueries _backfillQueries;

  // ── Missing-entries notification ────────────────────────────────────────

  /// Invoked when new missing entries are detected (and not currently
  /// deferred). The owner wires the automatic backfill nudge here.
  set onMissingEntriesDetected(void Function()? callback) =>
      _missingNotifier.onMissingEntriesDetected = callback;

  void Function()? get onMissingEntriesDetected =>
      _missingNotifier.onMissingEntriesDetected;

  /// Run [action] with the automatic backfill nudge deferred until the
  /// outermost ordered-replay batch settles.
  Future<T> runWithDeferredMissingEntries<T>(
    Future<T> Function() action,
  ) => _missingNotifier.runWithDeferredMissingEntries(action);

  // ── Send path ───────────────────────────────────────────────────────────

  /// Record an entry being sent by this device.
  Future<void> recordSentEntry({
    required String entryId,
    required VectorClock vectorClock,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
  }) => _sender.recordSentEntry(
    entryId: entryId,
    vectorClock: vectorClock,
    payloadType: payloadType,
  );

  Future<void> recordSentEntryLink({
    required String linkId,
    required VectorClock vectorClock,
  }) => _sender.recordSentEntryLink(linkId: linkId, vectorClock: vectorClock);

  // ── Receive path ──────────────────────────────────────────────────────────

  /// Returns the last sent vector clock for [entryId] from this host's
  /// perspective. Used by the outbox to build covered vector clocks.
  Future<VectorClock?> getLastSentVectorClockForEntry(String entryId) =>
      _receiver.getLastSentVectorClockForEntry(entryId);

  /// Record a received entry and detect gaps in the sequence.
  Future<List<({String hostId, int counter})>> recordReceivedEntry({
    required String entryId,
    required VectorClock vectorClock,
    required String originatingHostId,
    List<VectorClock>? coveredVectorClocks,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
    String? jsonPath,
  }) => _receiver.recordReceivedEntry(
    entryId: entryId,
    vectorClock: vectorClock,
    originatingHostId: originatingHostId,
    coveredVectorClocks: coveredVectorClocks,
    payloadType: payloadType,
    jsonPath: jsonPath,
  );

  Future<List<({String hostId, int counter})>> recordReceivedEntryLink({
    required String linkId,
    required VectorClock vectorClock,
    required String originatingHostId,
    List<VectorClock>? coveredVectorClocks,
  }) => _backfillQueries.recordReceivedEntryLink(
    linkId: linkId,
    vectorClock: vectorClock,
    originatingHostId: originatingHostId,
    coveredVectorClocks: coveredVectorClocks,
  );

  /// Cheap existence probe for any actionable (`missing`/`requested`) row.
  Future<bool> hasActionableEntries() => _receiver.hasActionableEntries();

  /// Get entries marked as missing or requested for sending backfill requests.
  Future<List<SyncSequenceLogItem>> getMissingEntries({
    int limit = 50,
    int maxRequestCount = 10,
    int offset = 0,
    Duration minAge = Duration.zero,
  }) => _receiver.getMissingEntries(
    limit: limit,
    maxRequestCount: maxRequestCount,
    offset: offset,
    minAge: minAge,
  );

  /// Mark entries as requested and increment their request count.
  Future<void> markAsRequested(
    List<({String hostId, int counter})> entries,
  ) => _receiver.markAsRequested(entries);

  /// Mark one of OUR OWN host's counters as permanently unresolvable.
  Future<void> markOwnCounterUnresolvable({
    required String hostId,
    required int counter,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
  }) => _receiver.markOwnCounterUnresolvable(
    hostId: hostId,
    counter: counter,
    payloadType: payloadType,
  );

  /// Return own-host pre-bind crash markers left behind by
  /// `reserveNextVectorClock`.
  Future<List<int>> reservedCountersForHost({required String hostId}) =>
      _receiver.reservedCountersForHost(hostId: hostId);

  /// Return own-host reservations released without a payload whose outbound
  /// unresolvable marker still needs to be retried.
  Future<List<int>> burnPendingCountersForHost({required String hostId}) =>
      _receiver.burnPendingCountersForHost(hostId: hostId);

  // ── Backfill responses ──────────────────────────────────────────────────

  /// Handle a backfill response from another device.
  Future<void> handleBackfillResponse({
    required String hostId,
    required int counter,
    required bool deleted,
    bool unresolvable = false,
    String? entryId,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
  }) => _backfillResponder.handleBackfillResponse(
    hostId: hostId,
    counter: counter,
    deleted: deleted,
    unresolvable: unresolvable,
    entryId: entryId,
    payloadType: payloadType,
  );

  /// Verify that we have an entry locally and its VC covers the requested
  /// (hostId, counter), then mark as backfilled.
  Future<bool> verifyAndMarkBackfilled({
    required String hostId,
    required int counter,
    required String entryId,
    required VectorClock entryVectorClock,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
  }) => _backfillResponder.verifyAndMarkBackfilled(
    hostId: hostId,
    counter: counter,
    entryId: entryId,
    entryVectorClock: entryVectorClock,
    payloadType: payloadType,
  );

  /// Resolve any pending backfill hints for the given entryId.
  Future<int> resolvePendingHints({
    required SyncSequencePayloadType payloadType,
    required String payloadId,
    required VectorClock payloadVectorClock,
  }) => _backfillResponder.resolvePendingHints(
    payloadType: payloadType,
    payloadId: payloadId,
    payloadVectorClock: payloadVectorClock,
  );

  /// Reset unresolvable entries that now have a known payload back to missing.
  Future<int> resetUnresolvableEntries() =>
      _backfillResponder.resetUnresolvableEntries();

  /// Reset every `unresolvable` row back to `missing`.
  Future<int> resetAllUnresolvableEntries() =>
      _backfillResponder.resetAllUnresolvableEntries();

  // ── Backfill queries & population ─────────────────────────────────────────

  Future<int> retireExhaustedRequestedEntries({
    int maxRequestCount = 10,
    Duration grace = const Duration(minutes: 5),
  }) => _backfillQueries.retireExhaustedRequestedEntries(
    maxRequestCount: maxRequestCount,
    grace: grace,
  );

  Future<int> retireAgedOutRequestedEntries({
    Duration amnestyWindow = const Duration(days: 7),
  }) => _backfillQueries.retireAgedOutRequestedEntries(
    amnestyWindow: amnestyWindow,
  );

  /// Get entry by host ID and counter (for responding to backfill requests).
  Future<SyncSequenceLogItem?> getEntryByHostAndCounter(
    String hostId,
    int counter,
  ) => _backfillQueries.getEntryByHostAndCounter(hostId, counter);

  /// Find the nearest covering entry for a host with counter >= [counter].
  Future<SyncSequenceLogItem?> getNearestCoveringEntry(
    String hostId,
    int counter,
  ) => _backfillQueries.getNearestCoveringEntry(hostId, counter);

  /// Get backfill statistics grouped by host.
  Future<BackfillStats> getBackfillStats() =>
      _backfillQueries.getBackfillStats();

  /// Get missing entries with age and per-host limits for automatic backfill.
  Future<List<SyncSequenceLogItem>> getMissingEntriesWithLimits({
    int limit = 50,
    int maxRequestCount = 10,
    Duration? maxAge,
    Duration minAge = Duration.zero,
    int? maxPerHost,
    int offset = 0,
  }) => _backfillQueries.getMissingEntriesWithLimits(
    limit: limit,
    maxRequestCount: maxRequestCount,
    maxAge: maxAge,
    minAge: minAge,
    maxPerHost: maxPerHost,
    offset: offset,
  );

  /// Get entries with status 'requested' for re-requesting.
  Future<List<SyncSequenceLogItem>> getRequestedEntries({
    int limit = 50,
    int offset = 0,
  }) => _backfillQueries.getRequestedEntries(limit: limit, offset: offset);

  /// Reset request counts for specified entries to allow re-requesting.
  Future<void> resetRequestCounts(
    List<({String hostId, int counter})> entries,
  ) => _backfillQueries.resetRequestCounts(entries);

  /// Populate the sequence log from existing journal entries.
  Future<int> populateFromJournal({
    required Stream<List<({String id, Map<String, int>? vectorClock})>>
    entryStream,
    required Future<int> Function() getTotalCount,
    void Function(double progress)? onProgress,
  }) => _backfillQueries.populateFromJournal(
    entryStream: entryStream,
    getTotalCount: getTotalCount,
    onProgress: onProgress,
  );

  /// Populate the sequence log from existing entry links.
  Future<int> populateFromEntryLinks({
    required Stream<List<({String id, Map<String, int>? vectorClock})>>
    linkStream,
    required Future<int> Function() getTotalCount,
    void Function(double progress)? onProgress,
  }) => _backfillQueries.populateFromEntryLinks(
    linkStream: linkStream,
    getTotalCount: getTotalCount,
    onProgress: onProgress,
  );

  /// Populate the sequence log from existing agent entities.
  Future<int> populateFromAgentEntities({
    required Stream<List<({String id, Map<String, int>? vectorClock})>>
    entityStream,
    required Future<int> Function() getTotalCount,
    void Function(double progress)? onProgress,
  }) => _backfillQueries.populateFromAgentEntities(
    entityStream: entityStream,
    getTotalCount: getTotalCount,
    onProgress: onProgress,
  );

  /// Populate the sequence log from existing agent links.
  Future<int> populateFromAgentLinks({
    required Stream<List<({String id, Map<String, int>? vectorClock})>>
    linkStream,
    required Future<int> Function() getTotalCount,
    void Function(double progress)? onProgress,
  }) => _backfillQueries.populateFromAgentLinks(
    linkStream: linkStream,
    getTotalCount: getTotalCount,
    onProgress: onProgress,
  );

  // ── Testing ───────────────────────────────────────────────────────────────

  /// Force-expire every cache. Used in tests to verify that expired caches are
  /// cleared and the DB is re-queried.
  @visibleForTesting
  void expireCacheForTesting() => _cache.expireCacheForTesting();
}
