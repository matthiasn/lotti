import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/features/goals/logic/goal_checkin_compaction_strategy.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';

/// Tool name marking a stored span digest in the agent log.
const goalCheckInDigestToolName = 'goal_checkin_digest';

/// How many spans one wake may digest. Bounds the wake: a goal whose two
/// years of check-ins are digested for the first time pays for a few spans
/// per wake and finishes over the following wakes, rather than turning one
/// report refresh into a dozen inference calls.
const goalCheckInDigestsPerWake = 4;

/// Deterministic id for the digest of one span — the calendar period is the
/// key, so a span digested on two devices converges on one row.
String goalCheckInDigestId(String agentId, String periodLabel) =>
    'goal_checkin_digest:$agentId:$periodLabel';

/// Fingerprint of what a span digest was written from: its layer and every
/// member summary's identity and words. A check-in that syncs in late, a
/// re-transcription, or a span ageing from monthly to quarterly all change
/// it, and the digest is rewritten instead of standing stale.
String goalCheckInDigestSourceKey(GoalCheckInDigestRequest request) {
  final buffer = StringBuffer(request.layer.name);
  for (final c in request.checkIns) {
    buffer
      ..write('\n')
      ..write(c.sourceEntryId)
      ..write('|')
      ..write(c.sourceDigest ?? c.whatHappened);
  }
  return sha256.convert(utf8.encode(buffer.toString())).toString();
}

/// A stored span digest.
class GoalCheckInDigest {
  const GoalCheckInDigest({
    required this.periodLabel,
    required this.layer,
    required this.sourceKey,
    required this.checkInCount,
    required this.text,
    required this.writtenAt,
  });

  final String periodLabel;
  final String layer;
  final String sourceKey;
  final int checkInCount;
  final String text;
  final DateTime writtenAt;

  Map<String, Object?> toContent() => {
    'periodLabel': periodLabel,
    'layer': layer,
    'sourceKey': sourceKey,
    'checkInCount': checkInCount,
    'text': text,
    'writtenAt': writtenAt.toUtc().toIso8601String(),
  };

  static GoalCheckInDigest? fromContent(Map<String, Object?> content) {
    final periodLabel = content['periodLabel'];
    final layer = content['layer'];
    final sourceKey = content['sourceKey'];
    final checkInCount = content['checkInCount'];
    final text = content['text'];
    final writtenAt = DateTime.tryParse(content['writtenAt'] as String? ?? '');
    if (periodLabel is! String ||
        layer is! String ||
        sourceKey is! String ||
        checkInCount is! int ||
        text is! String ||
        text.trim().isEmpty ||
        writtenAt == null) {
      return null;
    }
    return GoalCheckInDigest(
      periodLabel: periodLabel,
      layer: layer,
      sourceKey: sourceKey,
      checkInCount: checkInCount,
      text: text,
      writtenAt: writtenAt,
    );
  }
}

/// Writes and stores the span digests the hierarchical compaction reads.
///
/// One row per calendar span, keyed by `(agentId, periodLabel)`; the
/// [goalCheckInDigestSourceKey] decides whether the stored text is still the
/// digest of the span's current members. Inference runs only on wakes that
/// allow it (automatic report wakes, like check-in compaction) and at most
/// [goalCheckInDigestsPerWake] times per wake; every other span reads its
/// stored digest, or a plain placeholder naming what is not yet digested.
/// Never throws: the user's voice is additive context, and a digest that
/// could not be written must not cost the wake.
class GoalCheckInDigestService {
  GoalCheckInDigestService({
    required CloudInferenceRepository inferenceRepository,
    required this._repository,
    required this._syncService,
    this.maxDigestTokens = 400,
    this._domainLogger,
  }) : _inference = inferenceRepository;

  final CloudInferenceRepository _inference;
  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final DomainLogger? _domainLogger;

  /// Output cap per digest. The layer's word limit is in the prompt; this is
  /// the hard stop behind it.
  final int maxDigestTokens;

  static const double _temperature = 0.3;

  static const String _systemMessage =
      "You condense a span of a person's spoken check-ins about one personal "
      'goal into a faithful digest that a coach will read months or years '
      'later instead of the originals. Preserve, with dates where they were '
      'given: what actually happened to the numbers over the span; every '
      'commitment made and whether it was kept; setbacks, injuries, medical '
      'advice, and life changes; anything that changed about the goal itself; '
      "how the person's mood related to their results. Drop routine "
      'repetition. Write in plain prose within the word limit given, in the '
      'language the person spoke. Never infer, advise or judge — record.';

  /// The writer for one wake of [agentId].
  GoalCheckInDigestWriter forWake({
    required String agentId,
    required String goalStatement,
    required String model,
    required AiConfigInferenceProvider provider,
    required bool allowInference,
  }) => _WakeDigestWriter(
    service: this,
    agentId: agentId,
    goalStatement: goalStatement,
    model: model,
    provider: provider,
    allowInference: allowInference,
  );

  Future<GoalCheckInDigest?> _stored(String agentId, String periodLabel) async {
    final message = await _repository.getEntity(
      goalCheckInDigestId(agentId, periodLabel),
    );
    final payloadId = message is AgentMessageEntity
        ? message.contentEntryId
        : null;
    if (payloadId == null) return null;
    final payload = await _repository.getEntity(payloadId);
    if (payload is! AgentMessagePayloadEntity) return null;
    return GoalCheckInDigest.fromContent(payload.content);
  }

  Future<void> _persist(String agentId, GoalCheckInDigest digest) async {
    final id = goalCheckInDigestId(agentId, digest.periodLabel);
    final payloadId = '$id:payload';
    await _syncService.runInTransaction(() async {
      await _syncService.upsertEntity(
        AgentDomainEntity.agentMessagePayload(
          id: payloadId,
          agentId: agentId,
          createdAt: digest.writtenAt,
          vectorClock: null,
          content: digest.toContent(),
        ),
      );
      await _syncService.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: id,
          agentId: agentId,
          threadId: id,
          // An action, like the check-in summaries: filed as observations
          // these would push real coaching observations out of FACTS.
          kind: AgentMessageKind.action,
          createdAt: digest.writtenAt,
          vectorClock: null,
          metadata: const AgentMessageMetadata(
            toolName: goalCheckInDigestToolName,
          ),
          contentEntryId: payloadId,
        ),
      );
    });
  }

  Future<String> _write({
    required String agentId,
    required String goalStatement,
    required String model,
    required AiConfigInferenceProvider provider,
    required GoalCheckInDigestRequest request,
  }) async {
    final prompt = _prompt(goalStatement, request);
    final captureRegistered = getIt.isRegistered<AiInteractionCapture>();
    final impactCollector = InferenceImpactCollector();
    Stream<CreateChatCompletionStreamResponse> invoke() => _inference.generate(
      prompt,
      model: model,
      temperature: _temperature,
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
      systemMessage: _systemMessage,
      maxCompletionTokens: maxDigestTokens,
      geminiThinkingMode: GeminiThinkingMode.minimal,
      reasoningEffort: ReasoningEffort.minimal,
      provider: provider,
      impactCollector: captureRegistered ? impactCollector : null,
    );
    final stream = captureRegistered
        ? getIt<AiInteractionCapture>().captureStream(
            workType: AiWorkType.internalInference,
            interactionKind: AiInteractionKind.textGeneration,
            responseType: AiConsumptionResponseType.textGeneration,
            providerType: provider.inferenceProviderType,
            modelId: model,
            requestText: prompt,
            invoke: invoke,
            responseText: (chunk) =>
                chunk.choices?.firstOrNull?.delta?.content ?? '',
            usageForChunk: (chunk) {
              final usage = chunk.usage;
              if (usage == null) return null;
              return AiCapturedUsage(
                inputTokens: usage.promptTokens,
                outputTokens: usage.completionTokens,
                cachedInputTokens: usage.promptTokensDetails?.cachedTokens,
                thoughtsTokens: usage.completionTokensDetails?.reasoningTokens,
                totalTokens: usage.totalTokens,
              );
            },
            impact: () => impactCollector.impact,
            triggerType: AiTriggerType.automatic,
            automationId: 'automation:goal-check-in-digest',
            automationDisplayName: 'Goal check-in digest',
            interactionContext: AiCapturedContext(agentId: agentId),
          )
        : invoke();

    final buffer = StringBuffer();
    await for (final response in stream) {
      final content = response.choices?.firstOrNull?.delta?.content;
      if (content != null) buffer.write(content);
    }
    return buffer.toString().trim();
  }

  String _prompt(String goalStatement, GoalCheckInDigestRequest request) {
    final buffer = StringBuffer()
      ..writeln('Goal: $goalStatement')
      ..writeln()
      ..writeln(
        'Span: ${request.periodLabel} (${request.layer.name}; '
        '${_day(request.from)} to ${_day(request.to)}), '
        '${request.checkIns.length} check-ins, oldest first. '
        'Word limit: ${request.maxWords}.',
      )
      ..writeln();
    for (final c in request.checkIns) {
      buffer.writeln('${_day(c.recordedAt)}: ${c.whatHappened}');
      if (c.committedTo != null) {
        buffer.writeln('  committed to: ${c.committedTo}');
      }
      if (c.blockers != null) buffer.writeln('  blockers: ${c.blockers}');
      if (c.mood != null) buffer.writeln('  mood: ${c.mood}');
    }
    return buffer.toString();
  }

  static String _day(DateTime at) =>
      at.toLocal().toIso8601String().substring(0, 10);
}

/// Placeholder for a span whose digest is not yet written. Honest and
/// short: the agent learns that a stretch of history exists and is not yet
/// readable, which beats silently omitting it.
String goalCheckInDigestPlaceholder(GoalCheckInDigestRequest request) =>
    '(${request.checkIns.length} check-ins from this span are not yet '
    'digested)';

class _WakeDigestWriter implements GoalCheckInDigestWriter {
  _WakeDigestWriter({
    required this.service,
    required this.agentId,
    required this.goalStatement,
    required this.model,
    required this.provider,
    required this.allowInference,
  });

  final GoalCheckInDigestService service;
  final String agentId;
  final String goalStatement;
  final String model;
  final AiConfigInferenceProvider provider;
  final bool allowInference;
  int _written = 0;

  @override
  Future<String> write(GoalCheckInDigestRequest request) async {
    final sourceKey = goalCheckInDigestSourceKey(request);
    GoalCheckInDigest? stored;
    try {
      stored = await service._stored(agentId, request.periodLabel);
    } catch (error, stackTrace) {
      service._domainLogger?.error(
        LogDomain.agentWorkflow,
        error,
        subDomain: 'goalCheckInDigest',
        message: 'failed to read digest ${request.periodLabel}',
        stackTrace: stackTrace,
      );
    }
    if (stored != null && stored.sourceKey == sourceKey) return stored.text;

    if (!allowInference || _written >= goalCheckInDigestsPerWake) {
      // A stale digest still describes most of the span; better than a
      // placeholder, and rewritten on the next wake that may infer.
      return stored?.text ?? goalCheckInDigestPlaceholder(request);
    }

    _written++;
    try {
      final text = await service._write(
        agentId: agentId,
        goalStatement: goalStatement,
        model: model,
        provider: provider,
        request: request,
      );
      if (text.isEmpty) {
        throw const FormatException('check-in digest returned no text');
      }
      await service._persist(
        agentId,
        GoalCheckInDigest(
          periodLabel: request.periodLabel,
          layer: request.layer.name,
          sourceKey: sourceKey,
          checkInCount: request.checkIns.length,
          text: text,
          writtenAt: clock.now(),
        ),
      );
      return text;
    } catch (error, stackTrace) {
      service._domainLogger?.error(
        LogDomain.agentWorkflow,
        error,
        subDomain: 'goalCheckInDigest',
        message: 'goal check-in digest failed for ${request.periodLabel}',
        stackTrace: stackTrace,
      );
      return stored?.text ?? goalCheckInDigestPlaceholder(request);
    }
  }
}
