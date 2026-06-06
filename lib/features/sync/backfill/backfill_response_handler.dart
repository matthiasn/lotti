import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/state/backfill_config_controller.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:meta/meta.dart';

part 'backfill_request_processor.dart';

/// Handler for incoming backfill requests and responses.
/// Responds to backfill requests from other devices by looking up entries
/// in the sequence log and sending them (or a "deleted" response if purged).
///
/// Includes a per-counter response cooldown to prevent the same counter from
/// being responded to repeatedly across multiple request cycles (N-device
/// amplification prevention).
class BackfillResponseHandler {
  BackfillResponseHandler({
    required this._journalDb,
    required this._sequenceLogService,
    required this._outboxService,
    required this._loggingService,
    required this._vectorClockService,
    this._domainLogger,
    this._notificationsDb,
    @visibleForTesting Duration? responseCooldown,
  }) : _responseCooldown =
           responseCooldown ?? SyncTuning.backfillResponseCooldown;

  final JournalDb _journalDb;
  final SyncSequenceLogService _sequenceLogService;
  final OutboxService _outboxService;
  final DomainLogger _loggingService;
  final VectorClockService _vectorClockService;
  final DomainLogger? _domainLogger;
  final NotificationsDb? _notificationsDb;
  final Duration _responseCooldown;

  /// Agent repository, injected after construction to avoid circular
  /// dependency. When set, backfill can look up agent entities and links.
  AgentRepository? agentRepository;

  /// Tracks recently-responded (hostId, counter) pairs with their timestamp
  /// to prevent duplicate responses across request cycles.
  @visibleForTesting
  final recentlyResponded = <String, DateTime>{};

  /// Track total responses in the current time window for rate limiting.
  @visibleForTesting
  int responsesInWindow = 0;
  @visibleForTesting
  DateTime? windowStart;

  /// Log a backfill trace message to the sync domain logger (separate file).
  void _trace(String message, {String? subDomain}) {
    _domainLogger?.log(
      LogDomain.sync,
      message,
      subDomain: subDomain ?? 'backfill',
    );
  }

  /// Build the cooldown cache key for a (hostId, counter) pair.
  static String _cooldownKey(String hostId, int counter) => '$hostId:$counter';

  /// Check if a (hostId, counter) pair was recently responded to.
  /// Returns true if the pair is within the cooldown period.
  bool _isRecentlyResponded(String hostId, int counter) {
    final lastResponse = recentlyResponded[_cooldownKey(hostId, counter)];
    if (lastResponse == null) return false;
    return clock.now().difference(lastResponse) < _responseCooldown;
  }

  /// Record that a (hostId, counter) pair was responded to.
  void _recordResponse(String hostId, int counter) {
    recentlyResponded[_cooldownKey(hostId, counter)] = clock.now();
  }

  /// Periodically clean expired entries from the cooldown cache.
  /// Called at the start of each request batch.
  void _cleanExpiredCooldowns() {
    final now = clock.now();
    recentlyResponded.removeWhere(
      (_, timestamp) => now.difference(timestamp) >= _responseCooldown,
    );
  }

  /// Check if the rate limit has been reached for the current time window.
  bool _isRateLimited() {
    final now = clock.now();
    if (windowStart == null ||
        now.difference(windowStart!) >= SyncTuning.backfillResponseRateWindow) {
      // Start a new window
      windowStart = now;
      responsesInWindow = 0;
      return false;
    }
    return responsesInWindow >= SyncTuning.backfillResponseRateLimit;
  }

  /// Send a "deleted" backfill response indicating the payload no longer exists.
  Future<void> _sendDeletedResponse({
    required String hostId,
    required int counter,
    required SyncSequencePayloadType payloadType,
  }) async {
    await _outboxService.enqueueMessage(
      SyncMessage.backfillResponse(
        hostId: hostId,
        counter: counter,
        deleted: true,
        payloadType: payloadType,
      ),
    );
  }

  /// Send an "unresolvable" backfill response indicating the originating host
  /// cannot resolve its own counter (e.g., it was superseded before being
  /// recorded, burnt, or the payload VC regressed below the counter).
  ///
  /// Always called on our own host — the callers in [_processBackfillEntry]
  /// and [_sendHintOrUnresolvable] gate on `hostId == myHost`. Enqueue the
  /// outbound marker before terminalizing the local sequence row so a failed
  /// outbox write leaves a retryable reservation/miss instead of silently
  /// dropping the proactive repair signal.
  Future<void> _sendUnresolvableResponse({
    required String hostId,
    required int counter,
    SyncSequencePayloadType? payloadType,
  }) async {
    await _outboxService.enqueueMessage(
      SyncMessage.backfillResponse(
        hostId: hostId,
        counter: counter,
        deleted: false,
        unresolvable: true,
        payloadType: payloadType,
      ),
    );
    await _sequenceLogService.markOwnCounterUnresolvable(
      hostId: hostId,
      counter: counter,
      payloadType: payloadType ?? SyncSequencePayloadType.journalEntity,
    );

    _trace(
      'sendUnresolvableResponse hostId=$hostId counter=$counter payloadType=$payloadType',
      subDomain: 'backfill.unresolvable',
    );
  }

  /// Load the vector clock for a payload by type and ID.
  /// Used to verify covering entries before using them.
  Future<VectorClock?> _loadPayloadVectorClock({
    required String payloadId,
    required SyncSequencePayloadType payloadType,
  }) async {
    switch (payloadType) {
      case SyncSequencePayloadType.journalEntity:
        final entry = await _journalDb.journalEntityById(payloadId);
        return entry?.meta.vectorClock;
      case SyncSequencePayloadType.entryLink:
        final link = await _journalDb.entryLinkById(payloadId);
        return link?.vectorClock;
      case SyncSequencePayloadType.agentEntity:
        return (await agentRepository?.getEntity(payloadId))?.vectorClock;
      case SyncSequencePayloadType.agentLink:
        return (await agentRepository?.getLinkById(payloadId))?.vectorClock;
      case SyncSequencePayloadType.notification:
      case SyncSequencePayloadType.notificationStateUpdate:
        return (await _notificationsDb?.notificationById(
          payloadId,
        ))?.meta.vectorClock;
    }
  }

  Future<SyncSequenceLogItem?> _findVerifiedCoveringEntry({
    required String hostId,
    required int requestedCounter,
    required int searchFromCounter,
  }) async {
    var nextCounter = searchFromCounter;

    while (true) {
      final covering = await _sequenceLogService.getNearestCoveringEntry(
        hostId,
        nextCounter,
      );

      if (covering == null || covering.entryId == null) {
        return null;
      }

      final payloadType = SyncSequencePayloadType.values.elementAt(
        covering.payloadType,
      );
      final coveringVc = await _loadPayloadVectorClock(
        payloadId: covering.entryId!,
        payloadType: payloadType,
      );
      final coveringVcCounter = coveringVc?.vclock[hostId];

      if (coveringVcCounter != null && coveringVcCounter >= requestedCounter) {
        _trace(
          'using verified covering entry '
          'hostId=$hostId requestedCounter=$requestedCounter '
          'coveringCounter=${covering.counter} '
          'coveringVcCounter=$coveringVcCounter '
          'payloadId=${covering.entryId}',
          subDomain: 'backfill.coveringFallback',
        );
        return covering;
      }

      _trace(
        'covering entry VC does not cover counter, skipping to next '
        'hostId=$hostId requestedCounter=$requestedCounter '
        'coveringCounter=${covering.counter} '
        'payloadId=${covering.entryId} '
        'coveringVcCounter=$coveringVcCounter',
        subDomain: 'backfill.coveringRejected',
      );

      nextCounter = covering.counter + 1;
    }
  }

  /// When the VC doesn't contain the exact counter, decide whether to send
  /// a hint (VC is ahead, so the entry supersedes the counter) or an
  /// unresolvable response (VC is behind, so the mapping is permanently
  /// wrong and will never self-heal).
  Future<void> _sendHintOrUnresolvable({
    required String hostId,
    required int counter,
    required String payloadId,
    required SyncSequencePayloadType payloadType,
    required int? vcCounter,
    String? legacyEntryId,
  }) async {
    final myHost = await _vectorClockService.getHost();
    if (myHost != null &&
        hostId == myHost &&
        (vcCounter == null || vcCounter < counter)) {
      _trace(
        'VC permanently behind counter, sending unresolvable '
        'hostId=$hostId counter=$counter '
        'payloadId=$payloadId vcCounter=$vcCounter',
        subDomain: 'backfill.vcBehind',
      );
      await _sendUnresolvableResponse(
        hostId: hostId,
        counter: counter,
        payloadType: payloadType,
      );
      return;
    }

    await _outboxService.enqueueMessage(
      SyncMessage.backfillResponse(
        hostId: hostId,
        counter: counter,
        deleted: false,
        entryId: legacyEntryId,
        payloadType: payloadType,
        payloadId: payloadId,
      ),
    );
  }

  /// Attempt to verify a payload exists locally and mark as backfilled.
  /// Loads the payload using [loadPayload], extracts its vector clock using
  /// [getVectorClock], and verifies/marks backfilled if found.
  Future<void> _tryVerifyAndMarkBackfilled<T>({
    required String hostId,
    required int counter,
    required String payloadId,
    required SyncSequencePayloadType payloadType,
    required Future<T?> Function() loadPayload,
    required VectorClock? Function(T) getVectorClock,
    required String payloadTypeName,
  }) async {
    final payload = await loadPayload();

    if (payload != null) {
      final vc = getVectorClock(payload);
      if (vc != null) {
        await _sequenceLogService.verifyAndMarkBackfilled(
          hostId: hostId,
          counter: counter,
          entryId: payloadId,
          entryVectorClock: vc,
          payloadType: payloadType,
        );
      }
    } else {
      _trace(
        '$payloadTypeName $payloadId not found locally, hint stored for when payload arrives',
        subDomain: 'backfill.response',
      );
    }
  }

  /// Processes an inbound backfill request; see [BackfillRequestProcessor].
  Future<void> handleBackfillRequest(SyncBackfillRequest request) =>
      handleBackfillRequestImpl(request);

  /// Handle an incoming backfill response from another device.
  ///
  /// For deleted responses: marks the entry as deleted (cannot be backfilled).
  ///
  /// For non-deleted responses: stores the entryId as a "hint", then verifies
  /// the entry exists locally and its VC covers the requested (hostId, counter)
  /// before marking as backfilled. This ensures we don't mark entries as
  /// backfilled until we actually have the data.
  Future<void> handleBackfillResponse(SyncBackfillResponse response) async {
    try {
      final payloadType =
          response.payloadType ?? SyncSequencePayloadType.journalEntity;
      final payloadId = response.payloadId ?? response.entryId;

      _trace(
        'handleResponse hostId=${response.hostId} counter=${response.counter} deleted=${response.deleted} unresolvable=${response.unresolvable} payloadType=$payloadType payloadId=$payloadId entryId=${response.entryId}',
        subDomain: 'backfill.response',
      );

      // First, store the hint (or mark as deleted/unresolvable for those responses)
      await _sequenceLogService.handleBackfillResponse(
        hostId: response.hostId,
        counter: response.counter,
        deleted: response.deleted,
        unresolvable: response.unresolvable ?? false,
        entryId: payloadId,
        payloadType: payloadType,
      );

      // For non-deleted, non-unresolvable responses, verify the entry exists
      // locally before marking as backfilled
      if (!response.deleted &&
          !(response.unresolvable ?? false) &&
          payloadId != null) {
        switch (payloadType) {
          case SyncSequencePayloadType.journalEntity:
            await _tryVerifyAndMarkBackfilled(
              hostId: response.hostId,
              counter: response.counter,
              payloadId: payloadId,
              payloadType: payloadType,
              loadPayload: () => _journalDb.journalEntityById(payloadId),
              getVectorClock: (entry) => entry.meta.vectorClock,
              payloadTypeName: 'journal entry',
            );
          case SyncSequencePayloadType.entryLink:
            await _tryVerifyAndMarkBackfilled(
              hostId: response.hostId,
              counter: response.counter,
              payloadId: payloadId,
              payloadType: payloadType,
              loadPayload: () => _journalDb.entryLinkById(payloadId),
              getVectorClock: (link) => link.vectorClock,
              payloadTypeName: 'entryLink',
            );
          case SyncSequencePayloadType.agentEntity:
            if (agentRepository != null) {
              await _tryVerifyAndMarkBackfilled(
                hostId: response.hostId,
                counter: response.counter,
                payloadId: payloadId,
                payloadType: payloadType,
                loadPayload: () => agentRepository!.getEntity(payloadId),
                getVectorClock: (entity) => entity.vectorClock,
                payloadTypeName: 'agentEntity',
              );
            }
          case SyncSequencePayloadType.agentLink:
            if (agentRepository != null) {
              await _tryVerifyAndMarkBackfilled(
                hostId: response.hostId,
                counter: response.counter,
                payloadId: payloadId,
                payloadType: payloadType,
                loadPayload: () => agentRepository!.getLinkById(payloadId),
                getVectorClock: (link) => link.vectorClock,
                payloadTypeName: 'agentLink',
              );
            }
          case SyncSequencePayloadType.notification:
            if (_notificationsDb != null) {
              await _tryVerifyAndMarkBackfilled(
                hostId: response.hostId,
                counter: response.counter,
                payloadId: payloadId,
                payloadType: payloadType,
                loadPayload: () => _notificationsDb.notificationById(
                  payloadId,
                ),
                getVectorClock: (notification) => notification.meta.vectorClock,
                payloadTypeName: 'notification',
              );
            }
          case SyncSequencePayloadType.notificationStateUpdate:
            if (_notificationsDb != null) {
              await _tryVerifyAndMarkBackfilled(
                hostId: response.hostId,
                counter: response.counter,
                payloadId: payloadId,
                payloadType: payloadType,
                loadPayload: () => _notificationsDb.notificationById(
                  payloadId,
                ),
                getVectorClock: (notification) => notification.meta.vectorClock,
                payloadTypeName: 'notificationStateUpdate',
              );
            }
        }
      }
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'handleResponse',
      );
    }
  }
}
