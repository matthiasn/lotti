import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_agent_trigger_tokens.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/ai_config_factories.dart';
import 'day_agent_pipeline_harness.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  test(
    'a length-truncated but parseable draft tool call never reaches '
    'persistence',
    () async {
      final now = DateTime(2030, 1, 15, 9);
      final dayDate = DateTime(2030, 1, 15);
      final dayId = dayAgentIdForDate(dayDate);
      final cloudRepository = MockCloudInferenceRepository();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final subscription = container.listen(
        conversationRepositoryProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final conversationRepository = container.read(
        conversationRepositoryProvider.notifier,
      );

      when(
        () => cloudRepository.generateWithMessages(
          messages: any(named: 'messages'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          provider: any(named: 'provider'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          tools: any(named: 'tools'),
          toolChoice: any(named: 'toolChoice'),
          thoughtSignatures: any(named: 'thoughtSignatures'),
          signatureCollector: any(named: 'signatureCollector'),
          turnIndex: any(named: 'turnIndex'),
          geminiThinkingMode: any(named: 'geminiThinkingMode'),
          reasoningEffort: any(named: 'reasoningEffort'),
          impactCollector: any(named: 'impactCollector'),
        ),
      ).thenAnswer(
        (_) => Stream.value(
          CreateChatCompletionStreamResponse(
            id: 'truncated-draft',
            created: 0,
            model: 'models/day',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                finishReason: ChatCompletionFinishReason.length,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0,
                      id: 'draft-call',
                      type:
                          ChatCompletionStreamMessageToolCallChunkType.function,
                      function: ChatCompletionStreamMessageFunctionCall(
                        name: DayAgentToolNames.draftDayPlan,
                        arguments: jsonEncode({
                          'dayId': dayId,
                          'blocks': [
                            {
                              'title': 'This must not be persisted',
                              'categoryId': 'work',
                              'start': DateTime(
                                2030,
                                1,
                                15,
                                9,
                              ).toIso8601String(),
                              'end': DateTime(
                                2030,
                                1,
                                15,
                                10,
                              ).toIso8601String(),
                              'reason':
                                  'The provider marked this response truncated.',
                            },
                          ],
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            usage: const CompletionUsage(
              promptTokens: 2048,
              completionTokens: 8192,
              totalTokens: 10240,
            ),
          ),
        ),
      );

      final harness = DayAgentPipelineHarness.create(
        now: now,
        conversationRepository: conversationRepository,
        cloudInferenceRepository: cloudRepository,
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
      addTearDown(harness.dispose);
      final identity = await harness.dayAgentService.getOrCreateDayAgentForDate(
        dayDate,
      );

      final result = await withClock(
        Clock.fixed(now),
        () => harness.dayWorkflow.execute(
          agentIdentity: identity,
          runKey: 'run-truncated-draft',
          triggerTokens: {
            dayAgentPlanningDayToken(dayId),
            dayAgentDraftingToken(dayId),
          },
          threadId: 'thread-truncated-draft',
        ),
      );

      expect(result.success, isFalse);
      expect(
        result.error,
        contains('DayAgentOutputLimitExceededException'),
      );
      expect(
        await harness.planService.draftPlanForDay(
          agentId: identity.agentId,
          dayId: dayId,
        ),
        isNull,
        reason:
            'ConversationRepository must not dispatch a buffered tool call '
            'after the provider reports output truncation.',
      );
      verify(
        () => cloudRepository.generateWithMessages(
          messages: any(named: 'messages'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          provider: any(named: 'provider'),
          maxCompletionTokens: 8192,
          tools: any(named: 'tools'),
          toolChoice: any(named: 'toolChoice'),
          thoughtSignatures: any(named: 'thoughtSignatures'),
          signatureCollector: any(named: 'signatureCollector'),
          turnIndex: any(named: 'turnIndex'),
          geminiThinkingMode: any(named: 'geminiThinkingMode'),
          reasoningEffort: any(named: 'reasoningEffort'),
          impactCollector: any(named: 'impactCollector'),
        ),
      ).called(1);
    },
  );
}
