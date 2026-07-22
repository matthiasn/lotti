import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/ai_config_factories.dart';
import 'day_agent_pipeline_harness.dart';

/// End-to-end smoke test for the ADR 0032 durable draft/refine pipeline.
///
/// Unlike the unit tests elsewhere in this branch (which fake or mock the
/// outbox, the executor, or the workflow individually), this drives a draft
/// then a refine through the real production chain assembled by
/// [DayAgentPipelineHarness]. Only the LLM response is scripted (no network
/// call), matching the pattern already used by `day_agent_workflow_test.dart`.
///
/// This is the closest thing to a live manual smoke test that runs in the
/// normal unit-test lane: it proves the new outbox → runtime → executor →
/// orchestrator → workflow → plan-service → outbox-completion round trip
/// genuinely works, not just that each link passes its own mocked unit
/// test. (The `eval/day_agent_draft_live_eval_test.dart` variant runs the
/// same chain against a real model.)
void main() {
  setUpAll(registerAllFallbackValues);

  // Fixed well into the future (rather than tied to whatever "today" is at
  // test-run time) so drafted blocks never trip the real
  // `DayAgentPlanWriter.persistDraftPlan` "must not start before current
  // time" guard, which compares against the real `clock.now()` whenever the
  // plan's day is today's local day.
  final now = DateTime(2030, 1, 15, 9);
  final dayDate = DateTime(2030, 1, 15);
  final dayId = dayAgentIdForDate(dayDate);

  late _ScriptedConversationRepository conversationRepository;
  late DayAgentPipelineHarness harness;

  setUp(() {
    conversationRepository = _ScriptedConversationRepository();
    harness = DayAgentPipelineHarness.create(
      now: now,
      conversationRepository: conversationRepository,
      cloudInferenceRepository: MockCloudInferenceRepository(),
      profile: testInferenceProfile(
        id: 'profile-day',
        thinkingModelId: 'models/day',
      ),
      model: testAiModel(
        id: 'model-day',
        providerModelId: 'models/day',
        inferenceProviderId: 'provider-day',
      ),
      provider: testInferenceProvider(
        id: 'provider-day',
        apiKey: 'provider-key',
      ),
    );
    addTearDown(() => harness.dispose());
  });

  test(
    'draft then refine round-trip through the real outbox/executor/ '
    'orchestrator/workflow chain, with only the LLM response scripted',
    () async {
      // ── Draft ────────────────────────────────────────────────────────────
      conversationRepository.toolCalls = [
        _toolCall(
          id: 'draft-call',
          name: DayAgentToolNames.draftDayPlan,
          args: {
            'dayId': dayId,
            'blocks': [
              {
                'title': 'Deep work',
                'categoryId': 'work',
                'start': dayDate
                    .add(const Duration(hours: 9))
                    .toIso8601String(),
                'end': dayDate.add(const Duration(hours: 10)).toIso8601String(),
                'reason': 'Morning focus window.',
              },
            ],
          },
        ),
      ];

      final draft = await harness.realDayAgent.draftDayPlan(
        captureId: const CaptureId(''),
        decidedTaskIds: const [],
        dayDate: dayDate,
      );

      expect(draft.blocks, hasLength(1));
      expect(draft.blocks.single.title, 'Deep work');
      expect(draft.state, DayState.drafted);

      // The per-day agent identity was created for real, and the durable job
      // it ran through is on disk, terminal, and succeeded — proving the
      // whole round trip, not just the in-memory return value.
      final dayAgentId = perDayAgentId(dayId);
      final draftJob = await harness.outbox.getById(
        DayProcessingOutboxRepository.draftJobId(dayId),
      );
      expect(draftJob, isNotNull);
      expect(draftJob!.isTerminal, isTrue);
      expect(draftJob.status.name, 'succeeded');
      final identity = await harness.agentRepository.getEntity(dayAgentId);
      expect(identity, isA<AgentIdentityEntity>());

      // ── Refine ───────────────────────────────────────────────────────────
      conversationRepository.toolCalls = [
        _toolCall(
          id: 'refine-call',
          name: DayAgentToolNames.proposePlanDiff,
          args: {
            'dayId': dayId,
            'changes': [
              {
                'action': 'added',
                'reason': 'Add a stretch break.',
                'to': {
                  'start': dayDate
                      .add(const Duration(hours: 11))
                      .toIso8601String(),
                  'end': dayDate
                      .add(const Duration(hours: 11, minutes: 15))
                      .toIso8601String(),
                  'title': 'Stretch',
                  'categoryId': 'health',
                },
              },
            ],
          },
        ),
      ];

      final diff = await harness.realDayAgent.proposePlanDiff(
        currentPlan: draft,
        voiceTranscript: 'add a stretch break around 11',
      );

      expect(diff.changes, hasLength(1));
      expect(diff.changes.single.kind, PlanDiffChangeKind.added);

      final refineJobs = (await harness.outbox.getAll())
          .where((job) => job.kind.name == 'refinePlan')
          .toList();
      expect(refineJobs, hasLength(1));
      expect(refineJobs.single.isTerminal, isTrue);
      expect(refineJobs.single.status.name, 'succeeded');
      expect(refineJobs.single.resultEntityId, isNotNull);
    },
  );
}

ChatCompletionMessageToolCall _toolCall({
  required String id,
  required String name,
  required Map<String, Object?> args,
}) {
  return ChatCompletionMessageToolCall(
    id: id,
    type: ChatCompletionMessageToolCallType.function,
    function: ChatCompletionMessageFunctionCall(
      name: name,
      arguments: jsonEncode(args),
    ),
  );
}

/// Fake, in-process [ConversationRepository]: applies the scripted
/// [toolCalls] through the *real* `DayAgentStrategy`/tool dispatch (so real
/// production tool handlers run), without any network call. Mirrors
/// `_ConversationHarness` in `day_agent_workflow_test.dart`.
class _ScriptedConversationRepository extends ConversationRepository {
  final Map<String, ConversationManager> _managers = {};
  int _createdCount = 0;

  List<ChatCompletionMessageToolCall> toolCalls = const [];

  @override
  String createConversation({String? systemMessage, int maxTurns = 20}) {
    _createdCount++;
    final id = 'conversation-$_createdCount';
    _managers[id] = ConversationManager(conversationId: id, maxTurns: maxTurns)
      ..initialize(systemMessage: systemMessage);
    return id;
  }

  @override
  ConversationManager? getConversation(String conversationId) =>
      _managers[conversationId];

  @override
  Future<InferenceUsage?> sendMessage({
    required String conversationId,
    required String message,
    required String model,
    required AiConfigInferenceProvider provider,
    required InferenceRepositoryInterface inferenceRepo,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    double temperature = 0.7,
    ConversationStrategy? strategy,
    String? consumptionAgentId,
    String? consumptionTaskId,
    String? consumptionCategoryId,
    String? consumptionWakeRunKey,
    String? consumptionThreadId,
    bool rethrowInferenceErrors = false,
  }) async {
    final manager = _managers[conversationId]!..addUserMessage(message);
    if (toolCalls.isNotEmpty) {
      manager.addAssistantMessage(toolCalls: toolCalls);
      await strategy!.processToolCalls(toolCalls: toolCalls, manager: manager);
    }
    return null;
  }

  @override
  void deleteConversation(String conversationId) {
    _managers.remove(conversationId)?.dispose();
  }
}
