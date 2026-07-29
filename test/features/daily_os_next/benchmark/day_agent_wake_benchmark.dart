import 'dart:convert';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_trigger_tokens.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_directive_models.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow_models.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_data/ai_config_factories.dart';
import '../integration/day_agent_pipeline_harness.dart';
import '../integration/scripted_conversation_repository.dart';

/// One offline full-workflow measurement for a model-facing wake.
class DayAgentWakeMetric {
  const DayAgentWakeMetric({
    required this.promptBytes,
    required this.stablePrefixBytes,
    required this.inputTokens,
    required this.outputTokens,
    required this.durationMicros,
    required this.agentRepositoryReads,
    required this.outputTokenCeiling,
    required this.providerTurns,
  });

  final int promptBytes;
  final int stablePrefixBytes;
  final int inputTokens;
  final int outputTokens;
  final int durationMicros;
  final int agentRepositoryReads;
  final int outputTokenCeiling;
  final int providerTurns;

  Map<String, int> toJson() => {
    'promptBytes': promptBytes,
    'stablePrefixBytes': stablePrefixBytes,
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    'durationMicros': durationMicros,
    'agentRepositoryReads': agentRepositoryReads,
    'outputTokenCeiling': outputTokenCeiling,
    'providerTurns': providerTurns,
  };
}

/// Deterministic aged-corpus runner for parse/draft/refine/digest wakes.
///
/// Corpus data and provider turns are fixed. The only non-deterministic value
/// is elapsed execution time, measured with a monotonic [Stopwatch] exactly as
/// in the storage benchmark. No wall-clock value enters prompts or entities.
class DayAgentWakeBenchmark {
  DayAgentWakeBenchmark({required this.days});

  final int days;

  static final DateTime baseDay = DateTime(2030, 1, 15);
  static final DateTime wakeTime = DateTime(2030, 1, 15, 9);

  final _metrics = <String, DayAgentWakeMetric>{};
  final _modelPrompts = <String, StringBuffer>{};
  String? _activeWake;
  late final ScriptedConversationRepository _conversationRepository;
  late final DayAgentPipelineHarness _harness;

  /// Complete model-facing request payloads observed for each wake.
  Map<String, String> get modelPrompts => Map.unmodifiable({
    for (final entry in _modelPrompts.entries)
      entry.key: entry.value.toString(),
  });

  Future<Map<String, DayAgentWakeMetric>> run() async {
    _conversationRepository = ScriptedConversationRepository(
      onSend: _observeSend,
      honorContinuationActions: true,
    );
    _harness = DayAgentPipelineHarness.create(
      now: wakeTime,
      conversationRepository: _conversationRepository,
      cloudInferenceRepository: _unusedCloudRepository(),
      profile: testInferenceProfile(
        id: 'profile-benchmark',
        thinkingModelId: 'models/benchmark',
      ),
      model: testAiModel(
        id: 'model-benchmark',
        providerModelId: 'models/benchmark',
        inferenceProviderId: 'provider-benchmark',
      ),
      provider: testInferenceProvider(
        id: 'provider-benchmark',
        apiKey: 'offline',
      ),
    );
    try {
      final dayId = dayAgentIdForDate(baseDay);
      final dayAgent = await _harness.dayAgentService
          .getOrCreateDayAgentForDate(baseDay);
      final coordinator = await _harness.dayAgentService
          .getOrCreatePlannerAgent();
      _seedAgedHistory();
      _harness.agentRepository.seed([
        AgentDomainEntity.capture(
          id: 'capture-benchmark',
          agentId: dayAgent.agentId,
          transcript: 'Plan one focused work block.',
          capturedAt: wakeTime,
          createdAt: wakeTime,
          dayId: dayId,
          vectorClock: null,
        ),
      ]);

      await _runDigest(coordinator, dayId);
      await _runParse(dayAgent, dayId);
      await _runDraft(dayAgent, dayId);
      await _runRefine(dayAgent, dayId);

      return Map.unmodifiable(_metrics);
    } finally {
      await _harness.dispose();
    }
  }

  MockCloudInferenceRepository _unusedCloudRepository() =>
      MockCloudInferenceRepository();

  InferenceUsage _observeSend(
    String systemMessage,
    List<ChatCompletionMessage> requestMessages,
    ScriptedModelTurn turn,
    List<ChatCompletionTool> tools,
  ) {
    final wake = _activeWake;
    if (wake == null) {
      throw StateError('A scripted send occurred outside a measured wake.');
    }
    final prompt = jsonEncode([
      for (final message in requestMessages) message.toJson(),
    ]);
    _modelPrompts.putIfAbsent(wake, StringBuffer.new).writeln(prompt);
    final toolSchema = jsonEncode([
      for (final tool in tools) tool.toJson(),
    ]);
    final output = jsonEncode({
      'content': turn.content,
      'toolCalls': [
        for (final call in turn.toolCalls)
          {
            'name': call.function.name,
            'arguments': call.function.arguments,
          },
      ],
    });
    final inputTokens = _estimateTokens('$prompt\n$toolSchema');
    final outputTokens = _estimateTokens(output);
    const policy = DayAgentOutputTokenBudgetPolicy();
    final kind = switch (wake) {
      'parse' => DayAgentWakeKind.capture,
      'draft' => DayAgentWakeKind.draft,
      'refine' => DayAgentWakeKind.refine,
      'digest' => DayAgentWakeKind.digest,
      _ => throw StateError('Unknown wake kind $wake.'),
    };
    final previous = _metrics[wake];
    _metrics[wake] = DayAgentWakeMetric(
      promptBytes: (previous?.promptBytes ?? 0) + utf8.encode(prompt).length,
      // The system message is the conservative byte-identical prefix. The
      // user payload follows it and contains per-wake volatile context.
      stablePrefixBytes:
          previous?.stablePrefixBytes ?? utf8.encode(systemMessage).length,
      inputTokens: (previous?.inputTokens ?? 0) + inputTokens,
      outputTokens: (previous?.outputTokens ?? 0) + outputTokens,
      durationMicros: 0,
      agentRepositoryReads: 0,
      outputTokenCeiling: policy.forKind(kind),
      providerTurns: (previous?.providerTurns ?? 0) + 1,
    );
    return InferenceUsage(
      inputTokens: inputTokens,
      outputTokens: outputTokens,
    );
  }

  int _estimateTokens(String text) => max(
    TextChunker.estimateTokens(text),
    (utf8.encode(text).length + 3) ~/ 4,
  );

  Future<void> _runMeasured({
    required String wake,
    required AgentIdentityEntity identity,
    required Set<String> triggerTokens,
  }) async {
    _activeWake = wake;
    _harness.agentRepository.resetReadCount();
    final stopwatch = Stopwatch()..start();
    final result = await withClock(
      Clock.fixed(wakeTime),
      () => _harness.dayWorkflow.execute(
        agentIdentity: identity,
        runKey: 'benchmark-$wake-$days',
        triggerTokens: triggerTokens,
        threadId: 'benchmark-$wake',
      ),
    );
    stopwatch.stop();
    _activeWake = null;
    if (!result.success) {
      throw StateError('$wake benchmark wake failed: ${result.error}');
    }
    final observed = _metrics[wake];
    if (observed == null) {
      throw StateError('$wake benchmark wake made no scripted model call.');
    }
    _metrics[wake] = DayAgentWakeMetric(
      promptBytes: observed.promptBytes,
      stablePrefixBytes: observed.stablePrefixBytes,
      inputTokens: observed.inputTokens,
      outputTokens: observed.outputTokens,
      durationMicros: stopwatch.elapsedMicroseconds,
      agentRepositoryReads: _harness.agentRepository.readCount,
      outputTokenCeiling: observed.outputTokenCeiling,
      providerTurns: observed.providerTurns,
    );
  }

  Future<void> _runDigest(
    AgentIdentityEntity coordinator,
    String dayId,
  ) async {
    _conversationRepository
      ..script([
        scriptedToolCall(
          id: 'digest-status',
          name: DayAgentToolNames.raiseDayStatus,
          args: {
            'dayId': dayId,
            'status': 'onTrack',
            'note': 'Offline benchmark digest.',
          },
        ),
      ])
      ..scriptText('Digest complete.');
    await _runMeasured(
      wake: 'digest',
      identity: coordinator,
      triggerTokens: {dayAgentDigestToken(dayId)},
    );
  }

  Future<void> _runParse(AgentIdentityEntity dayAgent, String dayId) async {
    _conversationRepository.script([
      scriptedToolCall(
        id: 'parse-capture',
        name: DayAgentToolNames.parseCaptureToItems,
        args: {'captureId': 'capture-benchmark', 'items': const []},
      ),
    ]);
    await _runMeasured(
      wake: 'parse',
      identity: dayAgent,
      triggerTokens: {
        dayAgentPlanningDayToken(dayId),
        dayAgentCaptureSubmittedToken('capture-benchmark'),
      },
    );
  }

  Future<void> _runDraft(AgentIdentityEntity dayAgent, String dayId) async {
    _conversationRepository.script([
      scriptedToolCall(
        id: 'draft-plan',
        name: DayAgentToolNames.draftDayPlan,
        args: {
          'dayId': dayId,
          'blocks': [
            {
              'title': 'Focused work',
              'categoryId': 'work',
              'start': DateTime(2030, 1, 15, 9).toIso8601String(),
              'end': DateTime(2030, 1, 15, 10).toIso8601String(),
              'reason': 'Representative scripted benchmark output.',
            },
          ],
        },
      ),
    ]);
    await _runMeasured(
      wake: 'draft',
      identity: dayAgent,
      triggerTokens: {
        dayAgentPlanningDayToken(dayId),
        dayAgentDraftingToken(dayId),
      },
    );
  }

  Future<void> _runRefine(AgentIdentityEntity dayAgent, String dayId) async {
    _harness.agentRepository.seed([
      AgentDomainEntity.capture(
        id: 'capture-refine-benchmark',
        agentId: dayAgent.agentId,
        transcript: 'Add a short break after focused work.',
        capturedAt: wakeTime,
        createdAt: wakeTime,
        dayId: dayId,
        vectorClock: null,
      ),
    ]);
    _conversationRepository
      ..script([
        scriptedToolCall(
          id: 'refine-plan',
          name: DayAgentToolNames.proposePlanDiff,
          args: {
            'dayId': dayId,
            'changes': [
              {
                'action': 'added',
                'reason': 'User requested a break.',
                'to': {
                  'title': 'Short break',
                  'categoryId': 'health',
                  'start': DateTime(2030, 1, 15, 10).toIso8601String(),
                  'end': DateTime(
                    2030,
                    1,
                    15,
                    10,
                    15,
                  ).toIso8601String(),
                },
              },
            ],
          },
        ),
      ])
      ..scriptText('Plan refinement proposed.');
    await _runMeasured(
      wake: 'refine',
      identity: dayAgent,
      triggerTokens: {
        dayAgentPlanningDayToken(dayId),
        dayAgentRefineToken(dayId),
        dayAgentCaptureSubmittedToken('capture-refine-benchmark'),
      },
    );
  }

  void _seedAgedHistory() {
    final entities = <AgentDomainEntity>[];
    for (var offset = 0; offset < days; offset++) {
      final day = DateTime(
        baseDay.year,
        baseDay.month,
        baseDay.day - offset,
      );
      final dayId = dayPlanId(day);
      final planEntityId = dayAgentPlanEntityId(dayId);
      final at = DateTime(day.year, day.month, day.day, 8);
      entities.add(
        AgentDomainEntity.dayPlan(
          id: planEntityId,
          agentId: dailyOsPlannerAgentId,
          dayId: dayId,
          planDate: day,
          data: DayPlanData(
            planDate: day,
            status: const DayPlanStatus.draft(),
          ),
          createdAt: at,
          updatedAt: at,
          vectorClock: null,
        ),
      );
      for (var i = 0; i < 3; i++) {
        entities.add(
          AgentDomainEntity.capture(
            id: 'benchmark-capture-$dayId-$i',
            agentId: dailyOsPlannerAgentId,
            transcript: 'Historic capture $i for $dayId',
            capturedAt: at,
            createdAt: at,
            dayId: dayId,
            vectorClock: null,
          ),
        );
      }
      for (var i = 0; i < 6; i++) {
        entities.add(
          AgentDomainEntity.dayStatusEvent(
            id: 'benchmark-status-$dayId-$i',
            agentId: dailyOsPlannerAgentId,
            dayId: dayId,
            status: DayStatusKind.onTrack,
            raisedAt: at,
            createdAt: at,
            vectorClock: null,
          ),
        );
      }
      for (var i = 0; i < 2; i++) {
        entities.add(
          AgentDomainEntity.changeSet(
            id: 'benchmark-diff-$dayId-$i',
            agentId: dailyOsPlannerAgentId,
            taskId: planEntityId,
            threadId: 'benchmark-history',
            runKey: 'benchmark-history-$dayId-$i',
            status: i.isEven
                ? ChangeSetStatus.resolved
                : ChangeSetStatus.expired,
            items: const [],
            createdAt: at,
            vectorClock: null,
          ),
        );
      }
      entities.add(
        AgentDomainEntity.agentMessage(
          id: 'benchmark-message-$dayId',
          agentId: dailyOsPlannerAgentId,
          threadId: 'benchmark-history',
          kind: AgentMessageKind.observation,
          createdAt: at,
          vectorClock: null,
          metadata: const AgentMessageMetadata(),
        ),
      );
      if (offset % 7 == 0) {
        final weekStart = weekStartFor(day);
        entities.add(
          AgentDomainEntity.weekRollup(
            id: weekRollupEntityId(weekStart),
            agentId: dailyOsPlannerAgentId,
            weekStart: weekStart,
            createdAt: at,
            updatedAt: at,
            vectorClock: null,
            plannedMinutesByCategory: const {'work': 1200},
            recordedMinutesByCategory: const {'work': 900},
            daysWithPlans: 5,
          ),
        );
      }
    }
    _harness.agentRepository.seed(entities);
  }
}
