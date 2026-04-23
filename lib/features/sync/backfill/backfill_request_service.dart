import 'dart:async';
import 'dart:io';

import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/state/backfill_config_controller.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as p;

/// Service responsible for periodically sending backfill requests
/// for missing entries detected in the sync sequence log.
///
/// By default, automatic backfill is bounded to recent entries (last day,
/// max 250 per host). For full historical backfill, use [processFullBackfill].
class BackfillRequestService {
  BackfillRequestService({
    required SyncSequenceLogService sequenceLogService,
    required SyncDatabase syncDatabase,
    required OutboxService outboxService,
    required VectorClockService vectorClockService,
    required LoggingService loggingService,
    this.documentsDirectory,
    this.queueCoordinator,
    DomainLogger? domainLogger,
    Duration? requestInterval,
    int? maxBatchSize,
    int? maxRequestCount,
    Duration? maxAge,
    int? maxPerHost,
    Duration? amnestyWindow,
  }) : _sequenceLogService = sequenceLogService,
       _syncDatabase = syncDatabase,
       _outboxService = outboxService,
       _vectorClockService = vectorClockService,
       _loggingService = loggingService,
       _domainLogger = domainLogger,
       _requestInterval = requestInterval ?? SyncTuning.backfillRequestInterval,
       // Use processing batch size for per-cycle limits (smaller to avoid
       // overwhelming the network). backfillBatchSize is for DB fetch limits.
       _maxBatchSize = maxBatchSize ?? SyncTuning.backfillProcessingBatchSize,
       _maxRequestCount = maxRequestCount ?? SyncTuning.backfillMaxRequestCount,
       _maxAge = maxAge ?? SyncTuning.defaultBackfillMaxAge,
       _maxPerHost = maxPerHost ?? SyncTuning.defaultBackfillMaxEntriesPerHost,
       _amnestyWindow = amnestyWindow ?? SyncTuning.backfillAmnestyWindow;

  /// The documents directory for resolving local attachment paths.
  /// When provided, re-requests will sweep (delete) local zombie files
  /// for agent entities/links to allow fresh downloads.
  final Directory? documentsDirectory;

  /// The queue pipeline coordinator, read for the bridge-walk gate.
  /// While the bridge is in flight we are still forward-reading fresh
  /// timeline events, so any gap observed now may be closed by an
  /// event already in the pipe — analysing + dispatching would race
  /// ahead of the inbound path and produce bogus missing-items
  /// requests. Optional so tests that do not exercise the gate can
  /// omit it.
  final QueuePipelineCoordinator? queueCoordinator;

  final SyncSequenceLogService _sequenceLogService;
  final SyncDatabase _syncDatabase;
  final OutboxService _outboxService;
  final VectorClockService _vectorClockService;
  final LoggingService _loggingService;
  final DomainLogger? _domainLogger;
  final Duration _requestInterval;
  final int _maxBatchSize;
  final int _maxRequestCount;
  final Duration _maxAge;
  final int _maxPerHost;
  final Duration _amnestyWindow;

  Timer? _timer;
  bool _isProcessing = false;
  bool _isDisposed = false;

  /// Log a backfill trace message to the sync domain logger (separate file).
  void _trace(String message, {String? subDomain}) {
    _domainLogger?.log(
      LogDomains.sync,
      message,
      subDomain: subDomain ?? 'backfill',
    );
  }

  /// Start the periodic backfill request processing.
  /// Uses bounded limits (age and per-host) for automatic backfill.
  void start() {
    if (_isDisposed) return;

    _timer?.cancel();
    _timer = Timer.periodic(
      _requestInterval,
      (_) => _processBackfillRequests(useLimits: true),
    );

    _trace(
      'start interval=${_requestInterval.inSeconds}s batchSize=$_maxBatchSize maxRetries=$_maxRequestCount',
      subDomain: 'backfill.start',
    );
  }

  /// Process full historical backfill without age/per-host limits.
  /// This should be triggered manually from the UI.
  /// Note: This ignores the enabled flag since it's a manual trigger.
  Future<int> processFullBackfill() async {
    return _processBackfillRequests(useLimits: false, ignoreEnabledFlag: true);
  }

  /// Trigger an immediate automatic backfill pass instead of waiting for the
  /// next periodic timer tick.
  void nudge() {
    if (_isDisposed) return;
    _trace('nudge immediate automatic pass', subDomain: 'backfill.nudge');
    unawaited(_processBackfillRequests(useLimits: true));
  }

  /// Re-request entries that are in 'requested' status but haven't been received.
  /// This resets their request counts and sends new backfill requests.
  /// Uses pagination to process all requested entries, not just the batch size.
  Future<int> processReRequest() async {
    if (_isDisposed || _isProcessing) return 0;

    _isProcessing = true;
    var totalProcessed = 0;

    try {
      final requesterId = await _vectorClockService.getHost();
      if (requesterId == null) {
        _trace(
          'processReRequest: no host ID available, skipping',
          subDomain: 'backfill.reRequest',
        );
        return 0;
      }

      // Process in stable createdAt order, paging past rows that are already
      // queued or in-flight instead of stopping at the first filtered page.
      var offset = 0;
      while (true) {
        var requested = await _sequenceLogService.getRequestedEntries(
          limit: _maxBatchSize,
          offset: offset,
        );

        if (requested.isEmpty) break;
        offset += requested.length;

        final alreadyQueued = await _syncDatabase.getPendingBackfillEntries();
        final filteredCount = requested.length;
        requested = _filterAlreadyQueuedEntries(requested, alreadyQueued);

        if (requested.isEmpty) {
          if (filteredCount > 0 && alreadyQueued.isNotEmpty) {
            _trace(
              'processReRequest: skipped $filteredCount already-queued entries at offset=${offset - filteredCount}',
              subDomain: 'backfill.reRequest',
            );
          }
          continue;
        }

        // Sweep local zombie files for agent payloads so the next
        // download attempt starts fresh instead of hitting the
        // "file exists, skip" guard.
        _sweepLocalFiles(requested);

        // Reset request counts for these entries
        final entries = requested
            .map((item) => (hostId: item.hostId, counter: item.counter))
            .toList();
        await _sequenceLogService.resetRequestCounts(entries);

        // Build request entries
        final requestEntries = requested
            .map(
              (item) => BackfillRequestEntry(
                hostId: item.hostId,
                counter: item.counter,
              ),
            )
            .toList();

        // Send backfill request message
        await _outboxService.enqueueMessage(
          SyncMessage.backfillRequest(
            entries: requestEntries,
            requesterId: requesterId,
          ),
        );

        // Mark all as requested (increments request count and sets lastRequestedAt)
        await _sequenceLogService.markAsRequested(entries);

        totalProcessed += requested.length;

        _trace(
          'processReRequest: sent ${requested.length} re-requests (total: $totalProcessed)',
          subDomain: 'backfill.reRequest',
        );
      }

      _trace(
        'processReRequest: completed, total $totalProcessed entries re-requested',
        subDomain: 'backfill.reRequest',
      );

      return totalProcessed;
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'SYNC_BACKFILL',
        subDomain: 'reRequest',
        stackTrace: st,
      );
      return totalProcessed;
    } finally {
      _isProcessing = false;
    }
  }

  /// Main processing logic - fetch missing entries and send backfill requests.
  /// [useLimits] - If true, apply age and per-host limits for automatic backfill.
  /// [ignoreEnabledFlag] - If true, process even when backfill is disabled (for manual trigger).
  Future<int> _processBackfillRequests({
    required bool useLimits,
    bool ignoreEnabledFlag = false,
  }) async {
    if (_isDisposed || _isProcessing) return 0;

    // Check if backfill is enabled (skip check for manual triggers)
    if (!ignoreEnabledFlag) {
      final enabled = await isBackfillEnabled();
      if (!enabled) {
        _trace(
          'processBackfillRequests: backfill is disabled, skipping',
          subDomain: 'backfill.process',
        );
        return 0;
      }
    }

    // Suppress automatic analysis+dispatch while the reconnect bridge
    // is forward-walking the timeline. Any "missing" counter seen now
    // may be closed by an event already in the pipe; asking peers for
    // it would race ahead of the inbound path and generate a bogus
    // request. Manual triggers (`ignoreEnabledFlag`) bypass this.
    if (!ignoreEnabledFlag && (queueCoordinator?.isBridgeInFlight ?? false)) {
      _trace(
        'processBackfillRequests: bridge walk in flight, skipping',
        subDomain: 'backfill.bridgeWalk',
      );
      return 0;
    }

    _isProcessing = true;

    try {
      // Retire missing/requested rows that have hit the request-count cap.
      // Without this, rows for counters that can never be resolved (e.g.
      // pre-history entries, purged payloads, permanently VC-behind
      // mappings) stay in `missing` forever and block the contiguous
      // watermark in `getLastCounterForHost`, which in turn forces every
      // incoming event on the same host to re-enter gap detection.
      await _sequenceLogService.retireExhaustedRequestedEntries(
        maxRequestCount: _maxRequestCount,
      );

      // Age-based companion: rows that slipped into `requested` via the
      // backfill-response-hint path (which never sets
      // `last_requested_at`) OR aged out of the active request window
      // ([_maxAge]) before hitting the exhaustion cap are retired after
      // [_amnestyWindow]. Otherwise they stay in a non-terminal status
      // forever, blocking the watermark and re-triggering gap detection
      // on every subsequent apply for the same host.
      await _sequenceLogService.retireAgedOutRequestedEntries(
        amnestyWindow: _amnestyWindow,
      );

      final missing = await _loadNextUnqueuedMissingBatch(useLimits: useLimits);

      if (missing.isEmpty) {
        _trace(
          'processBackfillRequests: no missing entries (useLimits=$useLimits)',
          subDomain: 'backfill.process',
        );
        return 0;
      }

      final requesterId = await _vectorClockService.getHost();
      if (requesterId == null) {
        _trace(
          'processBackfillRequests: no host ID available, skipping',
          subDomain: 'backfill.process',
        );
        return 0;
      }

      // Build request entries
      final entries = missing
          .map(
            (item) => BackfillRequestEntry(
              hostId: item.hostId,
              counter: item.counter,
            ),
          )
          .toList();

      // Send single backfill request message
      await _outboxService.enqueueMessage(
        SyncMessage.backfillRequest(
          entries: entries,
          requesterId: requesterId,
        ),
      );

      // Mark all as requested (increments request count and sets lastRequestedAt)
      await _sequenceLogService.markAsRequested(
        missing.map((m) => (hostId: m.hostId, counter: m.counter)).toList(),
      );

      _trace(
        'processBackfillRequests: sent ${missing.length} requests (useLimits=$useLimits)',
        subDomain: 'backfill.process',
      );

      return missing.length;
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'SYNC_BACKFILL',
        subDomain: 'process',
        stackTrace: st,
      );
      return 0;
    } finally {
      _isProcessing = false;
    }
  }

  /// Deletes local files for entries that are about to be re-requested.
  /// This breaks the zombie-file cycle where a file exists on disk (non-empty)
  /// but contains stale or corrupt data, causing the attachment ingestor to
  /// skip re-downloading indefinitely.
  ///
  /// Uses `jsonPath` from the sequence log when available (any payload type).
  /// Falls back to deriving the path from `entryId` for agent entities/links.
  void _sweepLocalFiles(List<SyncSequenceLogItem> entries) {
    final docDir = documentsDirectory;
    if (docDir == null) return;

    var swept = 0;
    for (final entry in entries) {
      var relativePath = entry.jsonPath;

      // Fall back to deriving path from entryId for agent payloads
      if (relativePath == null) {
        final entryId = entry.entryId;
        if (entryId == null) continue;

        final payloadType = SyncSequencePayloadType.values.elementAtOrNull(
          entry.payloadType,
        );

        if (payloadType == SyncSequencePayloadType.agentEntity) {
          relativePath = relativeAgentEntityPath(entryId);
        } else if (payloadType == SyncSequencePayloadType.agentLink) {
          relativePath = relativeAgentLinkPath(entryId);
        }
      }

      if (relativePath == null) continue;

      try {
        final file = _resolveSafeLocalFile(docDir, relativePath);
        if (file == null) {
          _trace(
            'sweepLocalFiles: blocked path traversal for $relativePath',
            subDomain: 'backfill.sweep',
          );
          continue;
        }
        if (file.existsSync()) {
          file.deleteSync();
          swept++;
        }
      } catch (e) {
        _trace(
          'sweepLocalFiles: failed to delete $relativePath err=$e',
          subDomain: 'backfill.sweep',
        );
      }
    }

    if (swept > 0) {
      _trace(
        'sweepLocalFiles: deleted $swept zombie files',
        subDomain: 'backfill.sweep',
      );
    }
  }

  List<SyncSequenceLogItem> _filterAlreadyQueuedEntries(
    List<SyncSequenceLogItem> entries,
    Set<({String hostId, int counter})> alreadyQueued,
  ) {
    if (alreadyQueued.isEmpty) {
      return entries;
    }
    return entries
        .where(
          (entry) => !alreadyQueued.contains((
            hostId: entry.hostId,
            counter: entry.counter,
          )),
        )
        .toList();
  }

  Future<List<SyncSequenceLogItem>> _loadNextUnqueuedMissingBatch({
    required bool useLimits,
  }) async {
    final alreadyQueued = await _syncDatabase.getPendingBackfillEntries();
    final selected = <SyncSequenceLogItem>[];
    var offset = 0;
    var filteredCount = 0;

    while (selected.length < _maxBatchSize) {
      final remaining = _maxBatchSize - selected.length;
      final page = useLimits
          ? await _sequenceLogService.getMissingEntriesWithLimits(
              limit: remaining,
              maxRequestCount: _maxRequestCount,
              maxAge: _maxAge,
              maxPerHost: _maxPerHost,
              offset: offset,
            )
          : await _sequenceLogService.getMissingEntries(
              limit: remaining,
              maxRequestCount: _maxRequestCount,
              offset: offset,
            );

      if (page.isEmpty) {
        break;
      }
      offset += page.length;

      final filteredPage = _filterAlreadyQueuedEntries(page, alreadyQueued);
      filteredCount += page.length - filteredPage.length;
      selected.addAll(filteredPage);

      if (page.length < remaining) {
        break;
      }
    }

    if (filteredCount > 0) {
      _trace(
        'processBackfillRequests: filtered $filteredCount already-queued entries',
        subDomain: 'backfill.process',
      );
    }

    return selected;
  }

  File? _resolveSafeLocalFile(Directory docDir, String relativePath) {
    var rel = relativePath;
    if (p.isAbsolute(rel)) {
      final prefix = p.rootPrefix(rel);
      rel = rel.substring(prefix.length);
    }
    final resolved = p.normalize(p.join(docDir.path, rel));
    if (!p.isWithin(docDir.path, resolved)) {
      return null;
    }
    return File(resolved);
  }

  /// Dispose of the service and cancel the timer.
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
