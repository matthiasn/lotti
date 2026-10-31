import 'package:clock/clock.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/agents/query/query_answer_builder.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/service/front_owner_titles.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_workflow.dart';
import 'package:lotti/features/goals/service/goal_chat_service.dart';
import 'package:lotti/features/relationships/model/relationship_agent_identity.dart';
import 'package:lotti/features/relationships/service/relationship_chat_service.dart';
import 'package:lotti/services/domain_logging.dart';

/// Finds the agent that owns a task or project, or null when it has none.
typedef FrontOwnerAgentLookup =
    Future<AgentIdentityEntity?> Function(String ownerId);

/// Walks the doors a dispatch names, one claimed segment at a time.
///
/// Runs after the routing wake produced the dispatch record — from the wake
/// runner, so a lease-elected recovery walks too — and never awaits a
/// specialist's wake: a goal or person segment is appended to that agent's
/// thread and its wake enqueued, and the reply arrives through the
/// projection when it lands. A task or project question is answered here,
/// by the query pipeline, headless; so is a journal question, which the
/// front agent answers herself from the journal within her allow-list.
/// Every other segment is recorded as skipped with its reason; nothing
/// writes to the journal.
///
/// Each segment is claimed under its deterministic record id before its
/// door is invoked (the `ChangeDispatchIntents` discipline), so a retry or
/// a second device finds the claim and moves on; a claim older than
/// [frontDoorClaimGrace] belongs to a walker that died and is taken over.
class FrontDoorWalker {
  const FrontDoorWalker({
    required AgentRepository repository,
    required AgentSyncService syncService,
    required QueryBuilderFactory queryBuilderFactory,
    required FrontOwnerAgentLookup taskAgentFor,
    required FrontOwnerAgentLookup projectAgentFor,
    required GoalChatService goalChat,
    required RelationshipChatService personChat,
    required FrontOwnerTitles ownerTitles,
    required DomainLogger domainLogger,
  }) : this._(
         repository,
         syncService,
         queryBuilderFactory,
         taskAgentFor,
         projectAgentFor,
         goalChat,
         personChat,
         ownerTitles,
         domainLogger,
       );

  const FrontDoorWalker._(
    this._repository,
    this._syncService,
    this._queryBuilderFactory,
    this._taskAgentFor,
    this._projectAgentFor,
    this._goalChat,
    this._personChat,
    this._ownerTitles,
    this._domainLogger,
  );

  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final QueryBuilderFactory _queryBuilderFactory;
  final FrontOwnerAgentLookup _taskAgentFor;
  final FrontOwnerAgentLookup _projectAgentFor;
  final GoalChatService _goalChat;
  final RelationshipChatService _personChat;
  final FrontOwnerTitles _ownerTitles;
  final DomainLogger _domainLogger;

  /// Walks every unwalked segment of the dispatch that answered
  /// [messageId]. A turn that ended in a question or a reply has no
  /// dispatch and nothing to walk.
  Future<void> walk(String messageId) async {
    final dispatchRecord = await _dispatchRecordFor(messageId);
    if (dispatchRecord == null || dispatchRecord.contentEntryId == null) {
      return;
    }
    final payload = await _repository.getEntity(dispatchRecord.contentEntryId!);
    if (payload is! AgentMessagePayloadEntity) return;
    final dispatch = frontDispatchFromPayload(payload);
    if (dispatch == null) return;

    for (var index = 0; index < dispatch.segments.length; index++) {
      final segment = dispatch.segments[index];
      final claim = await _claim(
        dispatchRecord: dispatchRecord,
        sourceMessageId: messageId,
        index: index,
        segment: segment,
      );
      if (claim == null) continue;
      FrontDoorOutcome outcome;
      try {
        outcome = await _walkSegment(segment, sourceMessageId: messageId);
      } catch (error, stackTrace) {
        // A door's failure is its own: recorded by type, never by text, and
        // never a reason to stop the other segments.
        _domainLogger.error(
          LogDomain.agentWorkflow,
          error,
          stackTrace: stackTrace,
          subDomain: 'FrontDoorWalker',
          message: 'door ${segment.kind.wireName} failed',
        );
        outcome = FrontDoorFailed(error.runtimeType.toString());
      }
      await _record(claim.id, claim.record.done(outcome), dispatchRecord);
    }
  }

  /// The newest dispatch record keyed to [messageId], or null.
  Future<AgentMessageEntity?> _dispatchRecordFor(String messageId) async {
    final messages = await _repository.getAgentMessages(frontAgentId);
    AgentMessageEntity? newest;
    for (final message in messages) {
      if (message.kind != AgentMessageKind.action ||
          message.deletedAt != null ||
          message.metadata.toolName != FrontAgentToolNames.dispatch ||
          message.metadata.operationId != messageId) {
        continue;
      }
      if (newest == null || message.createdAt.isAfter(newest.createdAt)) {
        newest = message;
      }
    }
    return newest;
  }

  /// Claims segment [index] in one transaction: writes a `claimed` record
  /// unless one exists that is done or freshly claimed. Returns the claim
  /// to walk, or null when another walker owns the segment.
  Future<({String id, FrontDoorRecord record})?> _claim({
    required AgentMessageEntity dispatchRecord,
    required String sourceMessageId,
    required int index,
    required FrontDispatchSegment segment,
  }) async {
    final id = frontDoorRecordId(dispatchRecord.id, index);
    FrontDoorRecord? claimed;
    await _syncService.runInTransaction(() async {
      final now = clock.now();
      final existing = await _repository.getEntity(id);
      if (existing is AgentMessageEntity && existing.contentEntryId != null) {
        final payload = await _repository.getEntity(existing.contentEntryId!);
        final record = payload is AgentMessagePayloadEntity
            ? FrontDoorRecord.fromJson(payload.content)
            : null;
        if (record != null && !record.isStaleClaimAt(now)) return;
      }
      final title = segment.destinationId == null
          ? null
          : await _ownerTitles.titleFor(segment.kind, segment.destinationId!);
      claimed = FrontDoorRecord(
        segmentIndex: index,
        text: segment.text,
        kind: segment.kind,
        destinationId: segment.destinationId,
        ownerTitle: title,
        status: FrontDoorStatus.claimed,
        claimedAt: now.toUtc(),
      );
      await _write(id, claimed!, dispatchRecord, now);
    });
    final record = claimed;
    return record == null ? null : (id: id, record: record);
  }

  Future<void> _record(
    String id,
    FrontDoorRecord record,
    AgentMessageEntity dispatchRecord,
  ) => _syncService.runInTransaction(
    () => _write(id, record, dispatchRecord, clock.now()),
  );

  /// The door record and its payload under deterministic ids, so a rewrite
  /// replaces rather than duplicates.
  Future<void> _write(
    String id,
    FrontDoorRecord record,
    AgentMessageEntity dispatchRecord,
    DateTime now,
  ) async {
    final payloadId = '$id:payload';
    await _syncService.upsertEntity(
      AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: frontAgentId,
        createdAt: now,
        vectorClock: null,
        content: record.toJson(),
      ),
    );
    await _syncService.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: id,
        agentId: frontAgentId,
        threadId: dispatchRecord.threadId,
        kind: AgentMessageKind.action,
        createdAt: now,
        vectorClock: null,
        contentEntryId: payloadId,
        metadata: AgentMessageMetadata(
          runKey: dispatchRecord.metadata.runKey,
          toolName: frontDoorToolName,
          operationId: dispatchRecord.metadata.operationId,
        ),
      ),
    );
  }

  Future<FrontDoorOutcome> _walkSegment(
    FrontDispatchSegment segment, {
    required String sourceMessageId,
  }) async {
    final id = segment.destinationId;
    final question = segment.intent == FrontSegmentIntent.question;
    switch (segment.kind) {
      case FrontDestinationKind.task:
        if (!question) {
          // A statement or instruction becomes a text entry under the
          // task — but only on the user's tap (decision 1): the door
          // proposes and waits.
          return FrontDoorProposal(ownerId: id!);
        }
        return _askOwner(segment.kind, id!, segment.text, sourceMessageId);
      case FrontDestinationKind.project:
        if (!question) {
          // No project door yet (decision 5): the router was told to ask
          // which task; what still arrives here waits in the inbox.
          return const FrontDoorInbox();
        }
        return _askOwner(segment.kind, id!, segment.text, sourceMessageId);
      case FrontDestinationKind.goal:
        // A goal takes questions and statements alike as a chat turn; its
        // own proposals stay gated in its own thread.
        final identity = await _repository.getEntity(id!);
        if (identity is! AgentIdentityEntity ||
            identity.kind != AgentKinds.goalAgent ||
            identity.lifecycle != AgentLifecycle.active) {
          return const FrontDoorSkipped(FrontDoorSkipReason.noAgent);
        }
        final messageId = await _goalChat.appendMessage(
          agentId: id,
          text: segment.text,
        );
        _goalChat.enqueueMessage(agentId: id, messageId: messageId!);
        return FrontDoorChatTurn(
          specialistAgentId: id,
          specialistMessageId: messageId,
        );
      case FrontDestinationKind.person:
        final agentId = relationshipAgentIdFor(id!);
        if (usableRelationshipAgent(await _repository.getEntity(agentId)) ==
            null) {
          return const FrontDoorSkipped(FrontDoorSkipReason.noAgent);
        }
        final messageId = await _personChat.appendMessage(
          agentId: agentId,
          text: segment.text,
        );
        _personChat.enqueueMessage(agentId: agentId, messageId: messageId!);
        return FrontDoorChatTurn(
          specialistAgentId: agentId,
          specialistMessageId: messageId,
        );
      case FrontDestinationKind.newThing:
        return FrontDoorInbox(newKind: segment.newKind);
      case FrontDestinationKind.journal:
        // A question about the record that no single owner holds is hers
        // to answer, from the journal; anything else is kept as a note.
        if (question) {
          return _answerFromJournal(segment.text, sourceMessageId);
        }
        return const FrontDoorInbox();
      case FrontDestinationKind.unrouted:
        return const FrontDoorInbox();
      case FrontDestinationKind.day:
        return const FrontDoorSkipped(FrontDoorSkipReason.noDoor);
    }
  }

  /// The query pipeline, headless: the owner's agent answers from its
  /// maintained reports, with no query chat created and nothing written —
  /// the answer lives in the front thread, attributed to the owner.
  Future<FrontDoorOutcome> _askOwner(
    FrontDestinationKind kind,
    String ownerId,
    String question,
    String sourceMessageId,
  ) async {
    final lookup = kind == FrontDestinationKind.task
        ? _taskAgentFor
        : _projectAgentFor;
    final agent = await lookup(ownerId);
    if (agent == null || agent.lifecycle != AgentLifecycle.active) {
      return const FrontDoorSkipped(FrontDoorSkipReason.noAgent);
    }
    final scope = QueryScope(
      kind: kind == FrontDestinationKind.task
          ? QueryScopeKind.task
          : QueryScopeKind.project,
      id: ownerId,
    );
    final built = await _build(
      scope,
      agentId: agent.agentId,
      question: question,
      sourceMessageId: sourceMessageId,
    );
    if (built == null) {
      return const FrontDoorSkipped(FrontDoorSkipReason.inferenceUnavailable);
    }
    return FrontDoorAnswer(
      text: built.answer.text,
      summaryBased: built.answer.summaryBased,
      incomplete: built.answer.coverage.incomplete,
      ownerIds: built.answer.summaryOwnerIds,
    );
  }

  /// The front agent answers from the journal herself: the query pipeline
  /// over every category in her allow-list (decision 4; an empty allow-list
  /// is unrestricted), which a category named in the question narrows. The
  /// answer keeps its evidence and its dependencies, so the surface can show
  /// the passages and hide all of it once a source is no longer visible.
  Future<FrontDoorOutcome> _answerFromJournal(
    String question,
    String sourceMessageId,
  ) async {
    final identity = await _repository.getEntity(frontAgentId);
    final allowed = identity is AgentIdentityEntity
        ? identity.allowedCategoryIds
        : const <String>{};
    final built = await _build(
      QueryScope.journalIn(allowed),
      agentId: frontAgentId,
      question: question,
      sourceMessageId: sourceMessageId,
    );
    if (built == null) {
      return const FrontDoorSkipped(FrontDoorSkipReason.inferenceUnavailable);
    }
    final answer = built.answer;
    return FrontDoorAnswer(
      text: answer.text,
      summaryBased: answer.summaryBased,
      incomplete: answer.coverage.incomplete,
      fromJournal: true,
      private: answer.private,
      evidence: answer.evidence,
      dependencies: answer.dependencies,
    );
  }

  /// Runs the query pipeline headless for [question] in [scope]: no query
  /// chat is created and nothing is written. Null when no model can answer.
  Future<QueryBuiltAnswer?> _build(
    QueryScope scope, {
    required String agentId,
    required String question,
    required String sourceMessageId,
  }) async {
    final QueryAnswerBuilder builder;
    try {
      // The front turn's id is the chat id: it only names the consumption
      // thread, and this is the thread the answer belongs to.
      builder = await _queryBuilderFactory(scope, agentId, sourceMessageId);
    } on QueryInferenceUnavailable {
      return null;
    }
    final now = clock.now();
    final event =
        AgentDomainEntity.queryChatEvent(
              id: '$sourceMessageId:${scope.kind.name}:${scope.id}:question',
              agentId: agentId,
              chatId: sourceMessageId,
              data: QueryChatEventData.question(text: question),
              createdAt: now,
              vectorClock: null,
            )
            as AgentQueryChatEventEntity;
    return builder.build(
      chat: QueryChatHistory(
        id: sourceMessageId,
        scope: scope,
        title: question,
        private: false,
        archived: false,
        lastActivity: now,
        events: [event],
        unread: false,
      ),
      question: event,
      memories: const [],
      cancellation: QueryCancellation(),
      onProgress: (_, {required expanded}) {},
    );
  }
}
