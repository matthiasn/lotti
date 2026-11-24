import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/front_chat_tokens.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/model/front_turn_failure.dart';
import 'package:lotti/features/front_agent/service/front_chat_history_service.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

/// Persists one user-authored front-agent turn, then hands routing to the
/// shared wake runtime (the `GoalChatService` pattern: the chat never owns
/// an inference loop, and the source turn is durable before inference can
/// begin).
///
/// The device the turn was typed on routes it. Every turn also gets a
/// synced, lease-elected recovery record due [frontChatRecoveryGrace] later,
/// which the author's successful wake consumes; if that never happens — the
/// wake failed, the device died — the lease picks exactly one device to
/// route it instead (ADR 0069). No device routes a turn it did not type on
/// sight.
class FrontChatService {
  FrontChatService({
    required AgentRepository repository,
    required AgentSyncService syncService,
    required WakeOrchestrator orchestrator,
    required UpdateNotifications notifications,
    required FrontChatHistoryService historyService,
    required DomainLogger domainLogger,
  }) : this._(
         repository,
         syncService,
         orchestrator,
         notifications,
         historyService,
         domainLogger,
       );

  FrontChatService._(
    this._repository,
    this._syncService,
    this._orchestrator,
    this._notifications,
    this._historyService,
    this._domainLogger,
  );

  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final WakeOrchestrator _orchestrator;
  final UpdateNotifications _notifications;
  final FrontChatHistoryService _historyService;
  final DomainLogger _domainLogger;

  static const _uuid = Uuid();

  /// The run of each turn whose wake this device is waiting on, by the
  /// turn's message id.
  final _waiting = <String, String>{};

  /// The waited-on turns the user is stopping, each to whether its stop was
  /// recorded: a wake that ends unfinished is the stop, not a failure — but
  /// only once the stop is durable, so it waits for the writes to settle.
  final _stopping = <String, _TurnStop>{};

  /// Appends [text] as a durable user turn and runs the routing wake for
  /// it — which routes the turn and walks its doors. Throws
  /// [FrontChatTurnException] when the agent cannot take a turn or the
  /// wake fails; the message is durable either way and [retryMessage]
  /// re-runs it.
  ///
  /// [onAppended] is told the turn's id once it is durable, before its wake
  /// is enqueued — what [stopMessage] takes. A turn edited from a stopped
  /// one names it in [replaces], and the thread shows it in that one's place.
  Future<void> sendMessage({
    required String text,
    required String conversationId,
    Set<String> categoryIds = const {},
    String? replaces,
    void Function(String messageId)? onAppended,
  }) async {
    final messageId = await appendMessage(
      text: text,
      conversationId: conversationId,
      categoryIds: categoryIds,
      replaces: replaces,
    );
    if (messageId == null) return;
    onAppended?.call(messageId);
    await retryMessage(messageId: messageId);
  }

  /// Makes [text] a durable user turn of [conversationId] and arms its
  /// recovery record, without running anything. Returns the message id, or
  /// null for a blank text.
  ///
  /// The conversation is named in the turn's payload, which nothing ever
  /// rewrites — an older build ignores the key and shows the turn in its
  /// one thread. So are the [categoryIds] the conversation is scoped to,
  /// which narrow her answer to them (`frontNarrowedCategories`); none
  /// writes no key. So is the turn it [replaces], if it was edited from one
  /// — an older build shows both — but only a turn of the same
  /// conversation: an edit never reaches into another one, whatever the
  /// caller asked.
  ///
  /// The turn is durable before the wake, so a process that dies while
  /// routing still leaves it a way to be routed — by the lease, after the
  /// grace. A failed recovery write is swallowed on purpose: the record is
  /// only the fallback, and maintenance arms a missing one for the oldest
  /// unanswered turn on its next pass.
  Future<String?> appendMessage({
    required String text,
    required String conversationId,
    Set<String> categoryIds = const {},
    String? replaces,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final identity = usableFrontAgent(
      await _repository.getEntity(frontAgentId),
    );
    if (identity == null) {
      throw const FrontChatTurnException('front agent is not active');
    }

    final replacing =
        replaces != null &&
            await _conversationOfTurn(replaces) == conversationId
        ? replaces
        : null;
    final now = clock.now();
    final payloadId = _uuid.v4();
    final messageId = _uuid.v4();

    await _syncService.upsertEntity(
      AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: frontAgentId,
        createdAt: now,
        vectorClock: null,
        content: <String, Object?>{
          'text': trimmed,
          frontConversationKey: conversationId,
          if (categoryIds.isNotEmpty)
            frontCategoriesKey: [...categoryIds]..sort(),
          frontTurnReplacesKey: ?replacing,
        },
      ),
    );
    final message =
        AgentDomainEntity.agentMessage(
              id: messageId,
              agentId: frontAgentId,
              // The wake gets its own deterministic run/thread id; this
              // source turn is projected by agent and linked to the wake
              // through its trigger token.
              threadId: messageId,
              kind: AgentMessageKind.user,
              createdAt: now,
              vectorClock: null,
              contentEntryId: payloadId,
              metadata: const AgentMessageMetadata(),
            )
            as AgentMessageEntity;
    try {
      await _syncService.upsertEntity(message);
    } on Object {
      // The append can commit and then fail flushing the sync outbox.
      // Reconcile the deterministic id before surfacing a failed append —
      // a retry would otherwise duplicate the turn.
      final persisted = await _repository.getEntity(messageId);
      if (persisted is! AgentMessageEntity ||
          persisted.agentId != frontAgentId ||
          persisted.kind != AgentMessageKind.user ||
          persisted.contentEntryId != payloadId) {
        rethrow;
      }
    }
    // The turn is durable: show it now, before the wake's own notification.
    _notifications.notifyUiOnly({frontAgentId, agentNotification});

    try {
      await _syncService.upsertEntity(
        _recoveryRecord(
          messageId: messageId,
          dueAt: now.toUtc().add(frontChatRecoveryGrace),
          now: now,
        ),
      );
    } on Object {
      // Deliberately swallowed; see above.
    }
    return messageId;
  }

  /// The conversation user turn [messageId] was written in, or null when it
  /// is no such turn.
  Future<String?> _conversationOfTurn(String messageId) async {
    final turn = await _repository.getEntity(messageId);
    if (turn is! AgentMessageEntity || !isFrontUserTurn(turn)) return null;
    final payload = await _repository.getEntity(turn.contentEntryId!);
    return payload is AgentMessagePayloadEntity
        ? frontConversationOf(payload.content)
        : null;
  }

  /// Enqueues the routing wake for an already durable turn and returns its
  /// run key, without waiting for it.
  String enqueueMessage({required String messageId}) =>
      _orchestrator.enqueueManualWake(
        agentId: frontAgentId,
        reason: WakeReason.userMessage.name,
        triggerTokens: {frontChatMessageTriggerToken(messageId)},
        supersede: false,
        initiator: WakeInitiator.user,
      );

  /// Re-enqueues the already durable source turn, waits for its wake and
  /// consumes its recovery record. The wake routes the turn and walks its
  /// doors, so the record is consumed only once the walker has finished —
  /// a wake that dies mid-walk leaves the record pending for the lease.
  ///
  /// Throws [FrontChatTurnException] when the wake fails — including when
  /// the orchestrator shuts down first, which ends the completion stream
  /// without an event for this run, so the future always completes. A wake
  /// the user stopped ([stopMessage]) returns normally: nothing failed.
  Future<void> retryMessage({required String messageId}) async {
    String? runKey;
    final completion = Completer<WakeRunCompletion>();
    final subscription = _orchestrator.runCompletions.listen(
      (event) {
        if (event.runKey == runKey && !completion.isCompleted) {
          completion.complete(event);
        }
      },
      onDone: () {
        if (!completion.isCompleted) {
          completion.completeError(
            FrontChatTurnException(
              'the agent runtime stopped before the turn completed',
              messageId: messageId,
            ),
          );
        }
      },
    );
    try {
      final enqueuedAt = clock.now();
      final enqueued = runKey = enqueueMessage(messageId: messageId);
      _waiting[messageId] = enqueued;
      final result = await completion.future;
      _logTimings(result, enqueuedAt);
      if (result.status != WakeRunStatus.completed) {
        // Stopped: recorded and its recovery consumed by the stop.
        if (await _stopping[messageId]?.recorded ?? false) return;
        throw FrontChatTurnException(
          result.error?.toString(),
          messageId: messageId,
          failure: FrontTurnFailure.fromWakeError(result.error),
          cause: wakeFailureCause(result.error),
        );
      }
    } finally {
      _waiting.remove(messageId);
      _stopping.remove(messageId);
      await subscription.cancel();
    }
    await _consumeRecovery(messageId);
  }

  /// Stops turn [messageId] before she answers it: records the stop, so no
  /// device routes the turn again and the thread shows it stopped, consumes
  /// its recovery record, and cancels its wake when this device is waiting
  /// on one — the waiting [retryMessage] then returns as if it had gone
  /// through. A wake that answers before the cancel lands keeps its answer,
  /// which the thread shows in place of the stop.
  ///
  /// A turn this device is not waiting on is stopped only while it still
  /// needs her ([FrontChatHistoryService.pendingMessageIds]) — a Stop
  /// pressed after she finished stops nothing. Once the stop is recorded,
  /// the wake is cancelled and the thread told even if consuming the
  /// recovery record fails.
  Future<void> stopMessage({required String messageId}) async {
    final runKey = _waiting[messageId];
    if (runKey == null &&
        !(await _historyService.pendingMessageIds()).contains(messageId)) {
      return;
    }
    // One stop per turn, however often Stop is pressed: a write that fails
    // never undoes one that went through.
    final stop = runKey == null
        ? null
        : _stopping.update(
            messageId,
            (stop) => stop.failed ? _TurnStop() : stop,
            ifAbsent: _TurnStop.new,
          );
    stop?.writing();
    try {
      await _recordStop(messageId);
    } on Object {
      stop?.written(recorded: false);
      rethrow;
    }
    stop?.written(recorded: true);
    try {
      await _consumeRecovery(messageId);
    } finally {
      if (runKey != null) _orchestrator.cancelWake(frontAgentId, runKey);
      _notifications.notifyUiOnly({frontAgentId, agentNotification});
    }
  }

  /// Writes the stop of [messageId] as an empty reply to it, marked
  /// [frontTurnStoppedKey], under ids derived from the turn — a stop
  /// pressed twice, or on two devices, is one record.
  Future<void> _recordStop(String messageId) =>
      _syncService.runInTransaction(() async {
        final now = clock.now();
        final payloadId = frontChatStopPayloadId(messageId);
        await _syncService.upsertEntity(
          AgentDomainEntity.agentMessagePayload(
            id: payloadId,
            agentId: frontAgentId,
            createdAt: now,
            vectorClock: null,
            content: const <String, Object?>{frontTurnStoppedKey: true},
          ),
        );
        await _syncService.upsertEntity(
          AgentDomainEntity.agentMessage(
            id: frontChatStopMessageId(messageId),
            agentId: frontAgentId,
            threadId: messageId,
            kind: AgentMessageKind.action,
            createdAt: now,
            vectorClock: null,
            contentEntryId: payloadId,
            metadata: AgentMessageMetadata(
              toolName: FrontAgentToolNames.replyToUser,
              operationId: messageId,
            ),
          ),
        );
      });

  /// How long the turn waited for a wake slot and how long its wake ran —
  /// her own phases are in the workflow's `front turn timings` line.
  void _logTimings(WakeRunCompletion result, DateTime enqueuedAt) {
    final startedAt = result.startedAt;
    final finishedAt = result.finishedAt ?? clock.now();
    _domainLogger.log(
      LogDomain.agentWorkflow,
      'front turn ${result.status.name}: '
      'queued=${startedAt == null ? '-' : '${startedAt.difference(enqueuedAt).inMilliseconds}ms'} '
      'run=${startedAt == null ? '-' : '${finishedAt.difference(startedAt).inMilliseconds}ms'} '
      'total=${finishedAt.difference(enqueuedAt).inMilliseconds}ms',
      subDomain: 'frontChat',
    );
  }

  /// Makes sure the oldest unanswered turn can still be routed: arms its
  /// recovery record when it has none, or the next window of it when the
  /// last recovery ran without answering. Enqueues nothing itself — the
  /// scheduled-wake manager's lease elects the one device that routes.
  ///
  /// Runtime maintenance calls this at startup and before every scheduled
  /// scan, on every device. Returns whether it wrote a record.
  Future<bool> restoreOldestPendingMessage() async {
    final messageId = await _historyService.oldestPendingMessageId();
    if (messageId == null) return false;
    var armed = false;
    await _syncService.runInTransaction(() async {
      final now = clock.now();
      final existing = await _repository.getEntity(
        frontChatRecoveryRecordId(frontAgentId, messageId),
      );
      if (existing is! ScheduledWakeEntity || existing.deletedAt != null) {
        // A turn whose author died before arming it: the grace runs from
        // now. Over a tombstone, the write carries its clock — built from
        // a null clock it would be concurrent with the tombstone, and the
        // local write path (ADR 0068) would keep the deleted row whenever
        // its deadline is the later one.
        await _syncService.upsertEntity(
          _recoveryRecord(
            messageId: messageId,
            dueAt: now.toUtc().add(frontChatRecoveryGrace),
            now: now,
          ).copyWith(
            vectorClock: existing is ScheduledWakeEntity
                ? existing.vectorClock
                : null,
          ),
        );
        armed = true;
        return;
      }
      if (existing.status != ScheduledWakeStatus.consumed) return;
      // The next window is due when the last one's lease lapses — the same
      // UTC instant on every replica. A window the author's own wake
      // consumed carries no lease; it waits a grace past its deadline.
      await _syncService.upsertEntity(
        existing.copyWith(
          status: ScheduledWakeStatus.pending,
          scheduledAt:
              existing.leaseUntil ??
              existing.scheduledAt.add(frontChatRecoveryGrace),
          consumedAt: null,
          leaseHostId: null,
          leaseUntil: null,
          updatedAt: now,
        ),
      );
      armed = true;
    });
    return armed;
  }

  /// Flips [messageId]'s recovery record to consumed if it is still pending.
  Future<void> _consumeRecovery(String messageId) =>
      _syncService.runInTransaction(() async {
        final record = await _repository.getEntity(
          frontChatRecoveryRecordId(frontAgentId, messageId),
        );
        if (record is! ScheduledWakeEntity ||
            record.status != ScheduledWakeStatus.pending) {
          return;
        }
        final now = clock.now();
        await _syncService.upsertEntity(
          record.copyWith(
            status: ScheduledWakeStatus.consumed,
            consumedAt: now,
            updatedAt: now,
          ),
        );
      });

  static ScheduledWakeEntity _recoveryRecord({
    required String messageId,
    required DateTime dueAt,
    required DateTime now,
  }) =>
      AgentDomainEntity.scheduledWake(
            id: frontChatRecoveryRecordId(frontAgentId, messageId),
            agentId: frontAgentId,
            scheduledAt: dueAt,
            status: ScheduledWakeStatus.pending,
            reason: WakeReason.userMessage.name,
            updatedAt: now,
            vectorClock: null,
            workspaceKey: frontChatRecoveryWorkspaceKey(messageId),
            triggerTokens: [frontChatMessageTriggerToken(messageId)],
          )
          as ScheduledWakeEntity;
}

class FrontChatTurnException implements Exception {
  const FrontChatTurnException(
    this.detail, {
    this.messageId,
    this.failure = FrontTurnFailure.unknown,
    this.cause,
  });

  final String? detail;
  final String? messageId;

  /// Why the turn did not go through, for the chat to say.
  final FrontTurnFailure failure;

  /// The exception the failed wake caught, for the chat to relay the
  /// provider's own words; never part of [toString].
  final Object? cause;

  @override
  String toString() => detail ?? 'The front-agent turn failed.';
}

/// The stop of one waited-on turn, however many Stops were pressed for it:
/// recorded once any of their writes went through, failed only once every
/// one of them failed.
class _TurnStop {
  final _recorded = Completer<bool>();
  var _writes = 0;

  /// Whether the stop was recorded, once every write settled or one
  /// went through.
  Future<bool> get recorded => _recorded.future;

  /// Whether every write of this stop failed: a Stop pressed after it
  /// starts a new one.
  bool failed = false;

  void writing() => _writes++;

  void written({required bool recorded}) {
    _writes--;
    if (_recorded.isCompleted) return;
    if (recorded) {
      _recorded.complete(true);
    } else if (_writes == 0) {
      failed = true;
      _recorded.complete(false);
    }
  }
}
