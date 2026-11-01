import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/util/agent_error_logging.dart';
import 'package:lotti/features/agents/workflow/carrierless_attribution.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/agents/workflow/wake_token_usage.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/service/front_routing_index_builder.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_model_resolution.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_strategy.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

/// Stable output ids per agent and run, so a wake can recognise that its
/// reply's transaction committed even when the deferred sync-outbox flush
/// failed (the goal-workflow durable-turn pattern), and a retried
/// transaction overwrites rather than duplicates.
@visibleForTesting
String frontAgentReplyMessageId(String agentId, String runKey) => const Uuid()
    .v5(Namespace.url.value, 'lotti://front-agent/$agentId/$runKey/reply');
String _replyPayloadId(String agentId, String runKey) => const Uuid().v5(
  Namespace.url.value,
  'lotti://front-agent/$agentId/$runKey/reply-payload',
);

/// The id of the one dispatch record a run writes.
@visibleForTesting
String frontAgentDispatchMessageId(String agentId, String runKey) =>
    const Uuid().v5(
      Namespace.url.value,
      'lotti://front-agent/$agentId/$runKey/dispatch',
    );
String _dispatchPayloadId(String agentId, String runKey) => const Uuid().v5(
  Namespace.url.value,
  'lotti://front-agent/$agentId/$runKey/dispatch-payload',
);

/// The id of the one question a run may end with.
@visibleForTesting
String frontAgentAskMessageId(String agentId, String runKey) => const Uuid().v5(
  Namespace.url.value,
  'lotti://front-agent/$agentId/$runKey/ask',
);
String _askPayloadId(String agentId, String runKey) => const Uuid().v5(
  Namespace.url.value,
  'lotti://front-agent/$agentId/$runKey/ask-payload',
);

/// How many recent turns the prompt carries, so a short answer to the
/// agent's own question ("the first one") resolves.
const int frontRecentTurns = 6;

/// Runs one front-agent turn: the durable user message in, a dispatch
/// record (or a question, or a reply) out — and nothing else.
///
/// The wake writes only to the agent's own thread. Walking the doors a
/// dispatch names — the query pipeline, a goal or person chat, a filed
/// entry — is the chat service's job *after* this run completes, outside
/// any wake slot: a door that enqueues a specialist wake and awaits it
/// would deadlock from inside this one at concurrency 1.
class FrontAgentWorkflow with AgentErrorLogging {
  FrontAgentWorkflow({
    required this._repository,
    required this._syncService,
    required this._conversationRepository,
    required this._cloudInferenceRepository,
    required this._aiConfigRepository,
    required this._indexBuilder,
    required this._domainLogger,
    FrontRoutingScope Function(AgentIdentityEntity identity)? scopeFor,
    CompanionSass Function()? sass,
  }) : _scopeFor = scopeFor ?? _defaultScope,
       _sass = sass ?? _defaultSass;

  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final ConversationRepository _conversationRepository;
  final CloudInferenceRepository _cloudInferenceRepository;
  final AiConfigRepository _aiConfigRepository;
  final FrontRoutingIndexBuilder _indexBuilder;
  final DomainLogger _domainLogger;

  /// What this identity may see. The default is the identity's own
  /// allow-list with goals and without people (decision 4).
  final FrontRoutingScope Function(AgentIdentityEntity identity) _scopeFor;

  /// How much sass she speaks with: the companion's, as the user set it.
  final CompanionSass Function() _sass;

  static CompanionSass _defaultSass() => CompanionSass.cheeky;

  static FrontRoutingScope _defaultScope(AgentIdentityEntity identity) =>
      FrontRoutingScope(categoryIds: identity.allowedCategoryIds);

  @override
  DomainLogger get domainLogger => _domainLogger;

  @override
  LogDomain get errorLogDomain => LogDomain.agentWorkflow;

  /// Resolves the durable source turn the wake token names, then routes it.
  Future<WakeResult> executeUserMessage({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
    required String messageId,
  }) async {
    final message = await _repository.getEntity(messageId);
    if (message is! AgentMessageEntity ||
        message.agentId != agentIdentity.agentId ||
        message.kind != AgentMessageKind.user ||
        message.contentEntryId == null) {
      return const WakeResult(
        success: false,
        error: 'front chat source message is unavailable',
      );
    }
    final payload = await _repository.getEntity(message.contentEntryId!);
    final text =
        payload is AgentMessagePayloadEntity &&
            payload.agentId == agentIdentity.agentId
        ? payload.content['text']
        : null;
    if (text is! String || text.trim().isEmpty) {
      return const WakeResult(
        success: false,
        error: 'front chat source payload is unavailable',
      );
    }
    return execute(
      agentIdentity: agentIdentity,
      runKey: runKey,
      threadId: threadId,
      sourceMessageId: messageId,
      input: text.trim(),
    );
  }

  /// One routing turn over [input].
  Future<WakeResult> execute({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required String threadId,
    required String sourceMessageId,
    required String input,
  }) async {
    final agentId = agentIdentity.agentId;
    final now = clock.now();
    final recordConsumption = canRecordAgentConsumption;
    String? conversationId;
    try {
      final resolved = await resolveFrontAgentModel(
        agentIdentity: agentIdentity,
        aiConfigRepository: _aiConfigRepository,
        domainLogger: _domainLogger,
      );
      if (resolved == null) {
        return const WakeResult(
          success: false,
          error: 'front agent inference setup is unavailable',
        );
      }

      final scope = _scopeFor(agentIdentity);
      final index = await _indexBuilder.build(scope: scope, now: now);
      final recent = await _recentTurns(agentId, sourceMessageId);
      final strategy = FrontAgentStrategy(
        syncService: _syncService,
        domainLogger: _domainLogger,
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
        input: input,
        index: index,
        corpusMatcher: _indexBuilder.corpusMatcher(scope),
      );
      final tools = [
        for (final tool in frontAgentTools) tool.toChatCompletionTool(),
      ];
      final inferenceRepo = CloudInferenceWrapper(
        cloudRepository: _cloudInferenceRepository,
        geminiThinkingMode: resolved.geminiThinkingMode,
      );
      conversationId = _conversationRepository.createConversation(
        systemMessage:
            '$frontAgentSystemPrompt\n\n${frontAgentPersonality(_sass())}',
        maxTurns: agentIdentity.config.maxTurnsPerWake,
      );

      var usage = await _conversationRepository.sendMessage(
        conversationId: conversationId,
        message: renderFrontTurn(
          index: index,
          recent: recent,
          input: input,
          now: now,
        ),
        model: resolved.modelId,
        provider: resolved.provider,
        inferenceRepo: inferenceRepo,
        tools: tools,
        temperature: 0,
        strategy: strategy,
        consumptionAgentId: recordConsumption ? agentId : null,
        consumptionWakeRunKey: recordConsumption ? runKey : null,
        consumptionThreadId: recordConsumption ? threadId : null,
        rethrowInferenceErrors: true,
        turnBudget: frontProviderCallsPerTurn,
      );

      // The one repair the budget allows: a turn that ended without a
      // terminal call, or whose dispatch was invalid, gets the instruction
      // once — and only while a call is left of the three.
      final manager = _conversationRepository.getConversation(conversationId);
      final callsSoFar = manager?.turnCount ?? frontProviderCallsPerTurn;
      if (!strategy.hasTerminalOutput &&
          callsSoFar < frontProviderCallsPerTurn) {
        usage = _merge(
          usage,
          await _conversationRepository.sendMessage(
            conversationId: conversationId,
            message: frontDispatchRepairInstruction,
            model: resolved.modelId,
            provider: resolved.provider,
            inferenceRepo: inferenceRepo,
            tools: tools,
            temperature: 0,
            strategy: strategy,
            consumptionAgentId: recordConsumption ? agentId : null,
            consumptionWakeRunKey: recordConsumption ? runKey : null,
            consumptionThreadId: recordConsumption ? threadId : null,
            rethrowInferenceErrors: true,
            turnBudget: frontProviderCallsPerTurn - callsSoFar,
          ),
        );
      }
      if (!strategy.hasTerminalOutput) {
        // Fail closed: no reply is invented. The message stays retryable
        // and the chat shows its retry bubble.
        throw StateError('front turn produced no dispatch, question or reply');
      }

      try {
        await _persistOutputs(
          agentId: agentId,
          runKey: runKey,
          threadId: threadId,
          sourceMessageId: sourceMessageId,
          strategy: strategy,
          now: now,
        );
      } catch (error, stackTrace) {
        // runInTransaction commits the whole batch before its deferred
        // outbox flush: the durable records are the transaction marker, so
        // a turn the user already received is not re-run into a duplicate.
        final committed = await _outputsCommitted(
          agentId: agentId,
          runKey: runKey,
          strategy: strategy,
        );
        if (!committed) rethrow;
        logError(
          'front outputs committed before deferred outbox flush failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
      // No report artifact carries a routing turn's attribution yet, so the
      // envelope is closed carrierless, as a no-report relationship wake is.
      if (recordConsumption) {
        await finalizeCarrierlessAgentAttribution(
          runKey: runKey,
          logger: this,
          status: AiWorkStatus.partial,
          errorCode: 'output_carrier_unavailable',
        );
      }
      await persistWakeTokenUsage(
        syncService: _syncService,
        usage: usage,
        agentId: agentId,
        runKey: runKey,
        threadId: threadId,
        modelId: resolved.modelId,
        now: now,
        logError: logError,
      );
      return const WakeResult(success: true);
    } catch (error, stackTrace) {
      _domainLogger.error(
        LogDomain.agentWorkflow,
        error,
        subDomain: 'frontAgent',
        message: 'front agent turn failed',
        stackTrace: stackTrace,
      );
      if (recordConsumption) {
        await finalizeCarrierlessAgentAttribution(
          runKey: runKey,
          logger: this,
          status: AiWorkStatus.failed,
          errorCode: error.runtimeType.toString(),
          errorSummary: error.toString(),
        );
      }
      return WakeResult.failed(kind: 'Front agent', error: error);
    } finally {
      if (conversationId != null) {
        _conversationRepository.deleteConversation(conversationId);
      }
    }
  }

  /// Whether every record this turn produced exists under its deterministic
  /// id, written by this agent and run with the tool name it carries — the
  /// `isInteractiveReplyCommitted` check, over the three carriers a front
  /// turn can have instead of the one reply.
  Future<bool> _outputsCommitted({
    required String agentId,
    required String runKey,
    required FrontAgentStrategy strategy,
  }) async {
    final expected = <(String, String)>[
      if (strategy.dispatch != null)
        (
          frontAgentDispatchMessageId(agentId, runKey),
          FrontAgentToolNames.dispatch,
        ),
      if (strategy.askUser != null)
        (frontAgentAskMessageId(agentId, runKey), FrontAgentToolNames.askUser),
      if (strategy.replyToUser != null)
        (
          frontAgentReplyMessageId(agentId, runKey),
          FrontAgentToolNames.replyToUser,
        ),
    ];
    for (final (id, toolName) in expected) {
      final entity = await _repository.getEntity(id);
      if (entity is! AgentMessageEntity ||
          entity.agentId != agentId ||
          entity.metadata.runKey != runKey ||
          entity.metadata.toolName != toolName) {
        return false;
      }
    }
    return expected.isNotEmpty;
  }

  /// The last [frontRecentTurns] visible turns before the pending message —
  /// user messages, replies, questions, dispatches — oldest first, from the
  /// pending message's own conversation only: another chat is another
  /// subject, and its turns would steer the routing.
  ///
  /// A persisted output carries the source message as its `operationId`;
  /// the strategy's own tool-call log rows share the tool name but not
  /// that, which is what keeps them out of the tail.
  Future<List<FrontRecentTurn>> _recentTurns(
    String agentId,
    String sourceMessageId,
  ) async {
    final messages = await _repository.getAgentMessages(agentId);
    final userTurns = [
      for (final m in messages)
        if (m.kind == AgentMessageKind.user &&
            m.metadata.runKey == null &&
            m.contentEntryId != null)
          m,
    ];
    final turnPayloads = await _repository.getEntitiesByIds({
      for (final turn in userTurns) turn.contentEntryId!,
    });
    final conversationOf = <String, String>{
      for (final turn in userTurns)
        if (turnPayloads[turn.contentEntryId]
            case final AgentMessagePayloadEntity payload)
          turn.id: frontConversationOf(payload.content),
    };
    final conversation =
        conversationOf[sourceMessageId] ?? earlierConversationId;
    final visible =
        messages.where((m) {
          if (m.id == sourceMessageId || m.deletedAt != null) return false;
          if (m.contentEntryId == null) return false;
          if (m.kind == AgentMessageKind.user) {
            return m.metadata.runKey == null &&
                conversationOf[m.id] == conversation;
          }
          return m.kind == AgentMessageKind.action &&
              conversationOf[m.metadata.operationId] == conversation &&
              m.metadata.operationId != null &&
              const {
                FrontAgentToolNames.replyToUser,
                FrontAgentToolNames.askUser,
                FrontAgentToolNames.dispatch,
              }.contains(m.metadata.toolName);
        }).toList()..sort((a, b) {
          final byTime = a.createdAt.compareTo(b.createdAt);
          return byTime != 0 ? byTime : a.id.compareTo(b.id);
        });
    final tail = visible.length <= frontRecentTurns
        ? visible
        : visible.sublist(visible.length - frontRecentTurns);
    if (tail.isEmpty) return const [];
    final payloads = await _repository.getEntitiesByIds({
      for (final message in tail) message.contentEntryId!,
    });
    return [
      for (final message in tail)
        if (payloads[message.contentEntryId]
            case final AgentMessagePayloadEntity payload)
          ?frontRecentTurnOf(message, payload),
    ];
  }

  /// Everything the model reads, in one transaction, under deterministic
  /// ids: the dispatch record (the audit trail), the question, the reply.
  Future<void> _persistOutputs({
    required String agentId,
    required String runKey,
    required String threadId,
    required String sourceMessageId,
    required FrontAgentStrategy strategy,
    required DateTime now,
  }) async {
    await _syncService.runInTransaction(() async {
      Future<void> action({
        required String messageId,
        required String payloadId,
        required String toolName,
        required Map<String, Object?> content,
      }) async {
        await _syncService.upsertEntity(
          AgentDomainEntity.agentMessagePayload(
            id: payloadId,
            agentId: agentId,
            createdAt: now,
            vectorClock: null,
            content: content,
          ),
        );
        await _syncService.upsertEntity(
          AgentDomainEntity.agentMessage(
            id: messageId,
            agentId: agentId,
            threadId: threadId,
            kind: AgentMessageKind.action,
            createdAt: now,
            vectorClock: null,
            contentEntryId: payloadId,
            metadata: AgentMessageMetadata(
              runKey: runKey,
              toolName: toolName,
              operationId: sourceMessageId,
            ),
          ),
        );
      }

      if (strategy.dispatch case final dispatch?) {
        await action(
          messageId: frontAgentDispatchMessageId(agentId, runKey),
          payloadId: _dispatchPayloadId(agentId, runKey),
          toolName: FrontAgentToolNames.dispatch,
          content: {'input': strategy.input, ...dispatch.toJson()},
        );
      }
      if (strategy.askUser case final ask?) {
        await action(
          messageId: frontAgentAskMessageId(agentId, runKey),
          payloadId: _askPayloadId(agentId, runKey),
          toolName: FrontAgentToolNames.askUser,
          content: {
            'question': ask.question,
            'options': [
              for (final option in ask.options)
                {
                  'kind': option.kind.wireName,
                  'id': option.id,
                  'label': option.label,
                },
            ],
          },
        );
      }
      if (strategy.replyToUser case final reply?) {
        await action(
          messageId: frontAgentReplyMessageId(agentId, runKey),
          payloadId: _replyPayloadId(agentId, runKey),
          toolName: FrontAgentToolNames.replyToUser,
          content: {'text': reply},
        );
      }
    });
  }

  InferenceUsage? _merge(InferenceUsage? a, InferenceUsage? b) =>
      a == null ? b : (b == null ? a : a.merge(b));
}

/// The wake's user turn, by volatility: the index (changes when the record
/// does), the recent turns (append-only), then the clock and the pending
/// message (always new). The system prompt above them is constant.
@visibleForTesting
String renderFrontTurn({
  required FrontRoutingIndex index,
  required List<FrontRecentTurn> recent,
  required String input,
  required DateTime now,
}) {
  final buffer = StringBuffer()
    ..writeln(index.render())
    ..writeln()
    ..writeln('<recent_turns>');
  for (final turn in recent) {
    buffer.writeln('- ${turn.role}: ${turn.text}');
  }
  buffer
    ..writeln('</recent_turns>')
    ..writeln()
    ..writeln(
      '<current_local_time>${now.toIso8601String()}</current_local_time>',
    )
    ..writeln()
    ..writeln(frontPendingUserMessageHeader)
    ..writeln(input)
    ..write(frontPendingUserMessageFooter);
  return buffer.toString();
}

/// Reads a stored dispatch record's payload back.
FrontDispatch? frontDispatchFromPayload(AgentMessagePayloadEntity payload) {
  if (payload.content['segments'] is! List) return null;
  return FrontDispatch.fromJson(payload.content);
}

/// One earlier turn as the model reads it: who spoke, and what was said —
/// the words themselves, so a short answer to the agent's own question
/// ("the first one") can resolve against the question and its options.
typedef FrontRecentTurn = ({String role, String text});

/// How much of one earlier turn the prompt carries; the tail is bounded
/// so a long note cannot crowd out the index.
const int frontRecentTurnMaxChars = 400;

/// Renders a persisted message and its payload as a recent turn, or null
/// when the payload is not the shape the message's kind writes.
@visibleForTesting
FrontRecentTurn? frontRecentTurnOf(
  AgentMessageEntity message,
  AgentMessagePayloadEntity payload,
) {
  String clip(String text) {
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length <= frontRecentTurnMaxChars
        ? flat
        : '${flat.substring(0, frontRecentTurnMaxChars)}…';
  }

  final content = payload.content;
  if (message.kind == AgentMessageKind.user) {
    return switch (content['text']) {
      final String text => (role: 'user', text: clip(text)),
      _ => null,
    };
  }
  switch (message.metadata.toolName) {
    case FrontAgentToolNames.replyToUser:
      return switch (content['text']) {
        final String text => (role: 'reply', text: clip(text)),
        _ => null,
      };
    case FrontAgentToolNames.askUser:
      final question = content['question'];
      if (question is! String) return null;
      final options = content['options'];
      final labels = [
        if (options is List)
          for (final option in options)
            if (option is Map && option['label'] is String)
              '${option['label']} (${option['kind']}:${option['id']})',
      ];
      return (
        role: 'question',
        text: clip(
          labels.isEmpty
              ? question
              : '$question — options: ${labels.join(', ')}',
        ),
      );
    case FrontAgentToolNames.dispatch:
      final dispatch = frontDispatchFromPayload(payload);
      if (dispatch == null) return null;
      return (
        role: 'dispatch',
        text: clip(
          [
            for (final segment in dispatch.segments)
              '"${segment.text}" → ${switch (segment.kind) {
                FrontDestinationKind.newThing => 'new ${segment.newKind?.name}',
                final kind when kind.needsId => '${kind.wireName}:${segment.destinationId}',
                final kind => kind.wireName,
              }}',
          ].join('; '),
        ),
      );
    default:
      return null;
  }
}
