import 'dart:convert';

import 'package:crypto/crypto.dart';

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
import 'package:lotti/features/goals/model/goal_checkin_summary.dart';
import 'package:lotti/get_it.dart';
import 'package:openai_dart/openai_dart.dart';

/// Tool name marking a stored check-in summary in the agent log.
const goalCheckInSummaryToolName = 'goal_compact_check_in';

/// Fingerprint of the words a summary was distilled from.
///
/// Cheap and stable: it only has to change when the text does, so a
/// re-transcription or an edit is recognised as new words rather than as the
/// same check-in already handled.
String goalCheckInSourceDigest(String text) =>
    sha256.convert(utf8.encode(text.trim())).toString();

/// Deterministic id for the summary of one check-in.
///
/// Keyed by `(agentId, entryId)` so compacting the same recording twice — a
/// retry, or two devices reacting to the same synced entry — converges on one
/// row instead of appending a second summary of the same words.
String goalCheckInSummaryId(String agentId, String entryId) =>
    'goal_checkin_summary:$agentId:$entryId';

/// Distills one check-in into the bounded, structured form the agent reads.
///
/// Raw transcripts never enter agent context. A daily check-in is ~150 words;
/// dumping them into every wake would cost roughly 100k tokens a year against
/// a goal wake budgeted at 8k input tokens (ADR 0057). The user's own words
/// stay in the journal, in full, and remain the thing they can play back.
///
/// The distillation is faithful, not interpretive: it records what was said
/// and what was promised. Forming an opinion about it is the coach's job at
/// wake time, with the deterministic FACTS in front of it.
class GoalCheckInCompactor {
  GoalCheckInCompactor({
    required CloudInferenceRepository inferenceRepository,
    required this._syncService,
    this.maxSummaryTokens = 500,
  }) : _inference = inferenceRepository;

  final CloudInferenceRepository _inference;
  final AgentSyncService _syncService;

  /// Roughly the handover's ~500-token cap. Generous enough to keep the
  /// commitment slot intact, tight enough that a decade of check-ins stays
  /// inside a cold-prefill wake budget.
  final int maxSummaryTokens;

  static const double _temperature = 0.3;

  static const String _systemMessage =
      'You compact one spoken check-in about a personal goal into a short, '
      'faithful record. Return ONLY a JSON object with the keys '
      '"whatHappened", "committedTo", "blockers", "mood" and "asks". '
      'whatHappened is required, one or two sentences. committedTo is what '
      'the person said they WILL do, in their own terms, or null if they '
      'committed to nothing. blockers is what they said is in the way, or '
      'null. mood is a short energy/mood signal, or null. asks is anything '
      'they asked of you, or null. Keep only what matters to THIS goal and '
      'drop the rest. Write in the language the person spoke. Never infer, '
      'never advise, never judge — record.';

  /// Compacts [transcript] for [agentId] and persists the result.
  ///
  /// Returns the stored summary, or null when nothing could be produced.
  /// Never throws: a check-in that failed to compact is still a check-in the
  /// user can play back, and the failure must not take the recording, the UI
  /// or the wake down with it.
  Future<GoalCheckInSummary?> compact({
    required String agentId,
    required String entryId,
    required DateTime recordedAt,
    required String transcript,
    required String goalStatement,
    required String model,
    required AiConfigInferenceProvider provider,
  }) async {
    final text = transcript.trim();
    if (text.isEmpty) return null;
    try {
      final decoded = await _distill(
        agentId: agentId,
        entryId: entryId,
        transcript: text,
        goalStatement: goalStatement,
        model: model,
        provider: provider,
      );
      if (decoded == null) return null;

      final summary = GoalCheckInSummary(
        id: goalCheckInSummaryId(agentId, entryId),
        sourceEntryId: entryId,
        recordedAt: recordedAt,
        whatHappened: decoded.whatHappened,
        committedTo: decoded.committedTo,
        blockers: decoded.blockers,
        mood: decoded.mood,
        asks: decoded.asks,
        sourceDigest: goalCheckInSourceDigest(text),
      );
      await _persist(agentId: agentId, summary: summary);
      return summary;
    } on Object {
      return null;
    }
  }

  Future<void> _persist({
    required String agentId,
    required GoalCheckInSummary summary,
  }) async {
    final payloadId = '${summary.id}:payload';
    await _syncService.runInTransaction(() async {
      await _syncService.upsertEntity(
        AgentDomainEntity.agentMessagePayload(
          id: payloadId,
          agentId: agentId,
          createdAt: summary.recordedAt,
          vectorClock: null,
          content: summary.toContent(),
        ),
      );
      await _syncService.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: summary.id,
          agentId: agentId,
          threadId: summary.id,
          // An ACTION, not an observation — the reflection precedent. The
          // observation lookback takes the newest N rows and only then drops
          // payloads without `text`, so filing summaries as observations let
          // a dozen check-ins push every real coaching observation out of
          // FACTS entirely.
          kind: AgentMessageKind.action,
          createdAt: summary.recordedAt,
          vectorClock: null,
          metadata: const AgentMessageMetadata(
            toolName: goalCheckInSummaryToolName,
          ),
          contentEntryId: payloadId,
        ),
      );
    });
  }

  Future<GoalCheckInSummary?> _distill({
    required String agentId,
    required String entryId,
    required String transcript,
    required String goalStatement,
    required String model,
    required AiConfigInferenceProvider provider,
  }) async {
    final prompt =
        'Goal: $goalStatement\n\n'
        'Check-in, verbatim:\n$transcript';

    final captureRegistered = getIt.isRegistered<AiInteractionCapture>();
    final impactCollector = InferenceImpactCollector();
    Stream<CreateChatCompletionStreamResponse> invoke() => _inference.generate(
      prompt,
      model: model,
      temperature: _temperature,
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
      systemMessage: _systemMessage,
      maxCompletionTokens: maxSummaryTokens,
      provider: provider,
      impactCollector: captureRegistered ? impactCollector : null,
    );

    // Attributed like every other inference call, so compaction shows up in
    // the goal's lifetime cost pills rather than being invisible spend.
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
            automationId: 'automation:goal-check-in-compaction',
            automationDisplayName: 'Goal check-in compaction',
            // Without the agent id the row lands with a null agent and the
            // goal's lifetime cost pills — which total by agent — never show
            // what compaction actually spent.
            interactionContext: AiCapturedContext(
              agentId: agentId,
              entryId: entryId,
            ),
          )
        : invoke();

    final buffer = StringBuffer();
    await for (final response in stream) {
      final content = response.choices?.firstOrNull?.delta?.content;
      if (content != null) buffer.write(content);
    }
    return _decode(buffer.toString());
  }

  /// Parses the model's JSON, tolerating the fenced block some providers wrap
  /// it in. A response that cannot be read yields null rather than a summary
  /// built from guesses.
  GoalCheckInSummary? _decode(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded =
          jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      final happened = (decoded['whatHappened'] as String?)?.trim();
      if (happened == null || happened.isEmpty) return null;
      String? slot(String key) {
        final value = decoded[key];
        if (value is! String) return null;
        final trimmed = value.trim();
        return trimmed.isEmpty || trimmed.toLowerCase() == 'null'
            ? null
            : trimmed;
      }

      return GoalCheckInSummary(
        id: '',
        sourceEntryId: '',
        recordedAt: DateTime.fromMillisecondsSinceEpoch(0),
        whatHappened: happened,
        committedTo: slot('committedTo'),
        blockers: slot('blockers'),
        mood: slot('mood'),
        asks: slot('asks'),
      );
    } on Object {
      return null;
    }
  }
}
