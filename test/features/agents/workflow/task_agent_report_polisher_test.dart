import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_report_polisher.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  const draft = TaskAgentReportDraft(
    oneLiner: 'Release blocked on review',
    tldr: 'Release 42 is blocked until July 14.',
    content:
        '## Blockers\nLegal review blocks release 42 until July 14.\n\n'
        '## Links\n[Review](https://example.com/review/42)',
  );
  const sourceContext = '''
{"id":"task-internal-42","itemId":"check-secret","languageCode":"en"}
''';
  final provider = AiConfigInferenceProvider(
    id: 'provider',
    baseUrl: 'https://example.com/v1',
    apiKey: 'test-key',
    name: 'Test provider',
    createdAt: DateTime(2026, 7, 11),
    inferenceProviderType: InferenceProviderType.genericOpenAi,
  );
  const reportTool = ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: TaskAgentToolNames.updateReport,
      description: 'Update report',
      parameters: {
        'type': 'object',
        'properties': {
          'oneLiner': {'type': 'string'},
          'tldr': {'type': 'string'},
          'content': {'type': 'string'},
        },
        'required': ['oneLiner', 'tldr', 'content'],
      },
    ),
  );

  group('TaskAgentReportDraft', () {
    test('reports completeness and serializes fields', () {
      expect(draft.isComplete, isTrue);
      expect(draft.toJson(), {
        'oneLiner': draft.oneLiner,
        'tldr': draft.tldr,
        'content': draft.content,
      });
      expect(
        const TaskAgentReportDraft(
          oneLiner: ' ',
          tldr: 'summary',
          content: 'content',
        ).isComplete,
        isFalse,
      );
    });
  });

  group('TaskAgentReportPolishValidator', () {
    const validator = TaskAgentReportPolishValidator();

    test('accepts a concise rewrite that preserves protected facts', () {
      const candidate = TaskAgentReportDraft(
        oneLiner: 'Review blocks release 42',
        tldr: 'Legal review blocks release 42 until July 14.',
        content:
            '## Blockers\nLegal review blocks release 42 until July 14.\n\n'
            '## Links\n[Legal review](https://example.com/review/42)',
      );

      expect(
        validator.rejectionReason(
          draft: draft,
          candidate: candidate,
          sourceContext: sourceContext,
        ),
        isNull,
      );
    });

    test('rejects every unsafe rewrite shape', () {
      final cases = <({TaskAgentReportDraft candidate, String reason})>[
        (
          candidate: const TaskAgentReportDraft(
            oneLiner: '',
            tldr: 'Summary',
            content: 'A sufficiently long report body for this test case.',
          ),
          reason: 'missing report fields',
        ),
        (
          candidate: const TaskAgentReportDraft(
            oneLiner: 'Short',
            tldr: 'Short.',
            content: 'Too short',
          ),
          reason: 'report content is too short',
        ),
        (
          candidate: TaskAgentReportDraft(
            oneLiner: 'Verbose',
            tldr: 'Verbose.',
            content: 'x' * 1000,
          ),
          reason: 'report content grew beyond the allowed limit',
        ),
        (
          candidate: const TaskAgentReportDraft(
            oneLiner: 'ID leaked',
            tldr: 'The internal task is task-internal-42.',
            content:
                '## Progress\nThe internal task-internal-42 identifier leaked.',
          ),
          reason: 'report exposes an internal ID',
        ),
        (
          candidate: const TaskAgentReportDraft(
            oneLiner: 'Release blocked',
            tldr: 'Release 42 is blocked until July 14.',
            content:
                '## Blockers\nLegal review blocks release 42 until July 14.',
          ),
          reason: 'report dropped an external URL',
        ),
        (
          candidate: const TaskAgentReportDraft(
            oneLiner: 'Release blocked',
            tldr: 'The release remains blocked.',
            content:
                '## Blockers\nLegal review is pending.\n\n'
                '## Links\n[Review](https://example.com/review/42)',
          ),
          reason: 'report dropped a number',
        ),
      ];

      for (final testCase in cases) {
        expect(
          validator.rejectionReason(
            draft: draft,
            candidate: testCase.candidate,
            sourceContext: sourceContext,
          ),
          testCase.reason,
          reason: testCase.reason,
        );
      }
    });

    test('rejects camel-case, snake-case, and plural source IDs', () {
      final cases = <({String context, String leakedId})>[
        (
          context: '{"categoryId":"category-secret"}',
          leakedId: 'category-secret',
        ),
        (
          context: '{"project_id":"project-secret"}',
          leakedId: 'project-secret',
        ),
        (
          context: '{"checklistIds":["checklist-secret","checklist-other"]}',
          leakedId: 'checklist-secret',
        ),
      ];

      for (final testCase in cases) {
        final candidate = TaskAgentReportDraft(
          oneLiner: testCase.leakedId,
          tldr: draft.tldr,
          content: draft.content,
        );
        expect(
          validator.rejectionReason(
            draft: draft,
            candidate: candidate,
            sourceContext: testCase.context,
          ),
          'report exposes an internal ID',
          reason: testCase.context,
        );
      }
    });
  });

  group('TaskAgentReportPolisher', () {
    test('skips inference for an incomplete draft', () async {
      final inference = _RecordingInferenceRepository(const []);
      final polisher = _polisher(inference);

      final attempt = await polisher.polish(
        draft: const TaskAgentReportDraft(
          oneLiner: '',
          tldr: 'Summary',
          content: 'Content',
        ),
        sourceContext: sourceContext,
        model: 'test-model',
        provider: provider,
        reportTool: reportTool,
      );

      expect(attempt.report, isNull);
      expect(attempt.usage, isNull);
      expect(attempt.rejectionReason, 'draft report is incomplete');
      expect(inference.requests, isEmpty);
    });

    test(
      'accepts a valid report-only response and constrains the request',
      () async {
        final inference = _RecordingInferenceRepository([
          _toolResponse(
            name: TaskAgentToolNames.updateReport,
            arguments: {
              'oneLiner': 'Review blocks release 42',
              'tldr': 'Legal review blocks release 42 until July 14.',
              'content':
                  '## Blockers\nLegal review blocks release 42 until July 14.\n\n'
                  '## Links\n[Legal review](https://example.com/review/42)',
            },
          ),
        ]);
        final polisher = _polisher(inference);

        final attempt = await polisher.polish(
          draft: draft,
          sourceContext: sourceContext,
          model: 'test-model',
          provider: provider,
          reportTool: reportTool,
          consumptionAgentId: 'agent',
          consumptionTaskId: 'task',
          consumptionCategoryId: 'category',
          consumptionWakeRunKey: 'run',
          consumptionThreadId: 'thread',
        );

        expect(attempt.report?.oneLiner, 'Review blocks release 42');
        expect(attempt.rejectionReason, isNull);
        expect(inference.requests, hasLength(1));
        expect(inference.requests.single.model, 'test-model');
        expect(inference.requests.single.toolNames, [
          TaskAgentToolNames.updateReport,
        ]);
        expect(inference.requests.single.temperature, 0.2);
        expect(
          inference.requests.single.toolChoice,
          const ChatCompletionToolChoiceOption.tool(
            ChatCompletionNamedToolChoice(
              type: ChatCompletionNamedToolChoiceType.function,
              function: ChatCompletionFunctionCallOption(
                name: TaskAgentToolNames.updateReport,
              ),
            ),
          ),
        );
        expect(
          inference.requests.single.messages.last.content.toString(),
          contains('task-internal-42'),
        );
      },
    );

    test('falls back when the model omits or returns an unsafe report', () async {
      final responses = [
        _toolResponse(name: 'unknown_tool', arguments: const {}),
        _toolResponse(
          name: TaskAgentToolNames.updateReport,
          arguments: const {
            'oneLiner': 'Unsafe',
            'tldr': 'Release 42 changed.',
            'content':
                '## Progress\nThe task-internal-42 identifier is exposed in this report.',
          },
        ),
      ];

      for (final response in responses) {
        final attempt =
            await _polisher(
              _RecordingInferenceRepository([response]),
            ).polish(
              draft: draft,
              sourceContext: sourceContext,
              model: 'test-model',
              provider: provider,
              reportTool: reportTool,
            );

        expect(attempt.report, isNull);
        expect(attempt.rejectionReason, isNotNull);
      }
    });
  });

  test('report polish strategy is terminal after its report-only turn', () {
    final manager = ConversationManager(
      conversationId: 'polish-strategy-test',
      maxTurns: 2,
    );
    addTearDown(manager.dispose);
    final strategy = TaskAgentReportPolishStrategy();

    expect(strategy.shouldContinue(manager), isFalse);
    expect(strategy.getContinuationPrompt(manager), isNull);
  });
}

TaskAgentReportPolisher _polisher(
  _RecordingInferenceRepository inference,
) {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return TaskAgentReportPolisher(
    conversationRepository: container.read(
      conversationRepositoryProvider.notifier,
    ),
    inferenceRepository: inference,
  );
}

class _RecordedRequest {
  const _RecordedRequest({
    required this.messages,
    required this.model,
    required this.temperature,
    required this.toolNames,
    required this.toolChoice,
  });

  final List<ChatCompletionMessage> messages;
  final String model;
  final double temperature;
  final List<String> toolNames;
  final ChatCompletionToolChoiceOption? toolChoice;
}

class _RecordingInferenceRepository extends InferenceRepositoryInterface {
  _RecordingInferenceRepository(this.responses);

  final List<CreateChatCompletionStreamResponse> responses;
  final requests = <_RecordedRequest>[];

  @override
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    Map<String, String>? thoughtSignatures,
    ThoughtSignatureCollector? signatureCollector,
    InferenceImpactCollector? impactCollector,
    int? turnIndex,
  }) {
    requests.add(
      _RecordedRequest(
        messages: messages,
        model: model,
        temperature: temperature,
        toolNames: tools?.map((tool) => tool.function.name).toList() ?? [],
        toolChoice: toolChoice,
      ),
    );
    return Stream.fromIterable(responses);
  }
}

CreateChatCompletionStreamResponse _toolResponse({
  required String name,
  required Map<String, Object?> arguments,
}) {
  return CreateChatCompletionStreamResponse(
    id: 'response',
    object: 'chat.completion.chunk',
    created: 0,
    choices: [
      ChatCompletionStreamResponseChoice(
        index: 0,
        delta: ChatCompletionStreamResponseDelta.fromJson({
          'tool_calls': [
            {
              'index': 0,
              'id': 'report-call',
              'type': 'function',
              'function': {
                'name': name,
                'arguments': jsonEncode(arguments),
              },
            },
          ],
        }),
      ),
    ],
  );
}
