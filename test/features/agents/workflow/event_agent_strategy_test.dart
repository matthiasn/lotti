import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/event_agent_strategy.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

const _agentId = 'agent-001';
const _threadId = 'thread-001';
const _runKey = 'run-key-001';

ChatCompletionMessageToolCall _makeToolCall({
  required String name,
  required Map<String, dynamic> args,
  String id = 'call-1',
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

ChatCompletionMessageToolCall _makeRawToolCall({
  required String name,
  required String rawArguments,
  String id = 'call-1',
}) {
  return ChatCompletionMessageToolCall(
    id: id,
    type: ChatCompletionMessageToolCallType.function,
    function: ChatCompletionMessageFunctionCall(
      name: name,
      arguments: rawArguments,
    ),
  );
}

void main() {
  late MockAgentSyncService mockSyncService;
  late MockConversationManager mockManager;
  late EventAgentStrategy strategy;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockSyncService = MockAgentSyncService();
    mockManager = MockConversationManager();

    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});

    strategy = EventAgentStrategy(
      syncService: mockSyncService,
      agentId: _agentId,
      threadId: _threadId,
      runKey: _runKey,
    );
  });

  group('update_report', () {
    test('accumulates oneLiner, tldr, and content', () async {
      await strategy.processToolCalls(
        toolCalls: [
          _makeToolCall(
            name: EventAgentToolNames.updateReport,
            args: {
              'oneLiner': "Maya's 30th, rooftop at dusk.",
              'tldr': 'A warm rooftop birthday with old friends. 🎂',
              'content': '# The night\nEveryone showed up...',
            },
          ),
        ],
        manager: mockManager,
      );

      expect(strategy.extractReportOneLiner(), "Maya's 30th, rooftop at dusk.");
      expect(
        strategy.extractReportTldr(),
        'A warm rooftop birthday with old friends. 🎂',
      );
      expect(
        strategy.extractReportContent(),
        '# The night\nEveryone showed up...',
      );
      verify(
        () => mockManager.addToolResponse(
          toolCallId: 'call-1',
          response: 'Recap updated successfully.',
        ),
      ).called(1);
    });

    for (final missing in EventAgentReportToolArgs.required) {
      test(
        'rejects when "$missing" is blank and keeps the report unset',
        () async {
          final args = {
            'oneLiner': 'tag',
            'tldr': 'summary',
            'content': 'body',
          }..[missing] = '   ';

          await strategy.processToolCalls(
            toolCalls: [
              _makeToolCall(name: EventAgentToolNames.updateReport, args: args),
            ],
            manager: mockManager,
          );

          // No report was published, so a forced-report retry would still fire.
          expect(strategy.extractReportContent(), '');
          final captured =
              verify(
                    () => mockManager.addToolResponse(
                      toolCallId: 'call-1',
                      response: captureAny(named: 'response'),
                    ),
                  ).captured.single
                  as String;
          expect(captured, startsWith('Error:'));
          expect(captured, contains(missing));
        },
      );
    }
  });

  group('record_observations', () {
    test(
      'accepts plain strings and structured items with priority/category',
      () async {
        await strategy.processToolCalls(
          toolCalls: [
            _makeToolCall(
              name: EventAgentToolNames.recordObservations,
              args: {
                'observations': [
                  'send the album link to the group',
                  {
                    'text': 'book the rooftop again next year',
                    'priority': 'notable',
                    'category': 'operational',
                  },
                  {'text': '   '}, // blank → skipped
                ],
              },
            ),
          ],
          manager: mockManager,
        );

        final observations = strategy.extractObservations();
        expect(observations, hasLength(2));
        expect(observations[0].text, 'send the album link to the group');
        expect(observations[0].priority, ObservationPriority.routine);
        expect(observations[1].text, 'book the rooftop again next year');
        expect(observations[1].priority, ObservationPriority.notable);
        expect(observations[1].category, ObservationCategory.operational);
        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-1',
            response: 'Recorded 2 observation(s).',
          ),
        ).called(1);
      },
    );

    test('rejects a non-array observations argument', () async {
      await strategy.processToolCalls(
        toolCalls: [
          _makeToolCall(
            name: EventAgentToolNames.recordObservations,
            args: {'observations': 'not a list'},
          ),
        ],
        manager: mockManager,
      );

      expect(strategy.extractObservations(), isEmpty);
      verify(
        () => mockManager.addToolResponse(
          toolCallId: 'call-1',
          response: 'Error: "observations" must be a non-empty array.',
        ),
      ).called(1);
    });
  });

  group('suggest_follow_up_task (deferred)', () {
    test('accumulates the proposal and queues it for review', () async {
      await strategy.processToolCalls(
        toolCalls: [
          _makeToolCall(
            name: EventAgentToolNames.suggestFollowUpTask,
            args: {
              'title': 'Share the album with the group',
              'notes': 'Everyone asked for the photos.',
            },
          ),
        ],
        manager: mockManager,
      );

      final deferred = strategy.extractDeferredItems();
      expect(deferred, hasLength(1));
      expect(
        deferred.single['toolName'],
        EventAgentToolNames.suggestFollowUpTask,
      );
      expect(
        (deferred.single['args'] as Map)['title'],
        'Share the album with the group',
      );
      // It is not published as a report — it awaits user review.
      expect(strategy.extractReportContent(), '');
      verify(
        () => mockManager.addToolResponse(
          toolCallId: 'call-1',
          response: 'Queued suggest_follow_up_task for user review.',
        ),
      ).called(1);
    });
  });

  group('error handling', () {
    test('responds with an error for an unknown tool', () async {
      await strategy.processToolCalls(
        toolCalls: [
          _makeToolCall(name: 'set_event_cover', args: {'x': 1}),
        ],
        manager: mockManager,
      );

      verify(
        () => mockManager.addToolResponse(
          toolCallId: 'call-1',
          response: 'Error: unknown tool "set_event_cover".',
        ),
      ).called(1);
    });

    test('responds with an error for unparseable arguments', () async {
      await strategy.processToolCalls(
        toolCalls: [
          _makeRawToolCall(
            name: EventAgentToolNames.updateReport,
            rawArguments: 'not json at all',
          ),
        ],
        manager: mockManager,
      );

      final captured =
          verify(
                () => mockManager.addToolResponse(
                  toolCallId: 'call-1',
                  response: captureAny(named: 'response'),
                ),
              ).captured.single
              as String;
      expect(captured, contains('invalid arguments format'));
      expect(strategy.extractReportContent(), '');
    });

    test('parses markdown-fenced JSON arguments', () {
      final parsed = strategy.debugParseToolArguments(
        '```json\n{"oneLiner":"x","tldr":"y","content":"z"}\n```',
      );
      expect(parsed, {'oneLiner': 'x', 'tldr': 'y', 'content': 'z'});
    });
  });

  group('continuation + final response', () {
    test('asks for the report until one is published, then stops', () async {
      expect(
        strategy.getContinuationPrompt(mockManager),
        contains('update_report'),
      );

      await strategy.processToolCalls(
        toolCalls: [
          _makeToolCall(
            name: EventAgentToolNames.updateReport,
            args: {'oneLiner': 'a', 'tldr': 'b', 'content': 'c'},
          ),
        ],
        manager: mockManager,
      );

      expect(strategy.getContinuationPrompt(mockManager), isNull);
    });

    test('records a non-empty final response', () {
      strategy.recordFinalResponse('');
      expect(strategy.finalResponse, isNull);
      strategy.recordFinalResponse('done narrating');
      expect(strategy.finalResponse, 'done narrating');
    });
  });
}
