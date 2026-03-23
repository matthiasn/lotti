import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/observation_record.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/project_agent_strategy.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

const _agentId = 'agent-001';
const _threadId = 'thread-001';
const _runKey = 'run-key-001';
const _projectId = 'project-001';

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

void main() {
  late MockAgentSyncService mockSyncService;
  late MockConversationManager mockManager;
  late ProjectAgentStrategy strategy;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockSyncService = MockAgentSyncService();
    mockManager = MockConversationManager();

    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});

    strategy = ProjectAgentStrategy(
      syncService: mockSyncService,
      agentId: _agentId,
      threadId: _threadId,
      runKey: _runKey,
      projectId: _projectId,
    );
  });

  group('ProjectAgentStrategy', () {
    group('update_project_report', () {
      test('accumulates report content and tldr', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.updateProjectReport,
            args: {
              'markdown': '# Project Report\nAll good.',
              'tldr': 'Everything is on track.',
              'health_band': 'on_track',
              'health_rationale': 'Recent work is landing cleanly.',
              'health_confidence': 0.82,
            },
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractReportContent(), '# Project Report\nAll good.');
        expect(strategy.extractReportTldr(), 'Everything is on track.');
        expect(strategy.extractReportHealthBand(), 'on_track');
        expect(
          strategy.extractReportHealthRationale(),
          'Recent work is landing cleanly.',
        );
        expect(strategy.extractReportHealthConfidence(), 0.82);

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-1',
            response: 'Report updated successfully.',
          ),
        ).called(1);
      });

      test('returns error when markdown is empty', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.updateProjectReport,
            args: {
              'markdown': '',
              'health_band': 'watch',
              'health_rationale': 'Progress has slowed down.',
            },
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractReportContent(), isEmpty);

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-1',
            response: any(
              named: 'response',
              that: contains('required'),
            ),
          ),
        ).called(1);
      });

      test('returns error when health fields are missing', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.updateProjectReport,
            args: {
              'markdown': 'Some content',
              'tldr': 'Short summary.',
            },
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractReportContent(), isEmpty);
        expect(strategy.extractReportHealthBand(), isNull);

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-1',
            response: any(
              named: 'response',
              that: contains('health_band'),
            ),
          ),
        ).called(1);
      });

      test('returns error when tldr is missing', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.updateProjectReport,
            args: {
              'markdown': 'Some content',
              'health_band': 'watch',
              'health_rationale': 'There is still uncertainty.',
            },
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractReportContent(), isEmpty);
        expect(strategy.extractReportTldr(), isNull);

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-1',
            response: any(
              named: 'response',
              that: contains('tldr'),
            ),
          ),
        ).called(1);
      });
    });

    group('record_observations', () {
      test('accumulates string observations', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.recordObservations,
            args: {
              'observations': ['First observation', 'Second observation'],
            },
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        final observations = strategy.extractObservations();
        expect(observations, hasLength(2));
        expect(observations[0].text, 'First observation');
        expect(observations[1].text, 'Second observation');
        expect(observations[0].priority, ObservationPriority.routine);
        expect(observations[0].category, ObservationCategory.operational);
      });

      test(
        'accumulates structured observations with priority and category',
        () async {
          final toolCalls = [
            _makeToolCall(
              name: ProjectAgentToolNames.recordObservations,
              args: {
                'observations': [
                  {
                    'text': 'Critical blocker found',
                    'priority': 'critical',
                    'category': 'grievance',
                  },
                  {
                    'text': 'Good progress on delivery',
                    'priority': 'notable',
                    'category': 'excellence',
                  },
                ],
              },
            ),
          ];

          await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: mockManager,
          );

          final observations = strategy.extractObservations();
          expect(observations, hasLength(2));
          expect(observations[0].text, 'Critical blocker found');
          expect(observations[0].priority, ObservationPriority.critical);
          expect(observations[0].category, ObservationCategory.grievance);
          expect(observations[1].priority, ObservationPriority.notable);
          expect(observations[1].category, ObservationCategory.excellence);
        },
      );

      test('returns error when observations is empty', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.recordObservations,
            args: {'observations': <String>[]},
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractObservations(), isEmpty);

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-1',
            response: any(
              named: 'response',
              that: contains('non-empty'),
            ),
          ),
        ).called(1);
      });

      test('skips blank string observations', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.recordObservations,
            args: {
              'observations': ['   ', 'Valid observation'],
            },
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        final observations = strategy.extractObservations();
        expect(observations, hasLength(1));
        expect(observations[0].text, 'Valid observation');
      });

      test('skips structured observations with empty text', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.recordObservations,
            args: {
              'observations': [
                {'text': '', 'priority': 'critical'},
                {'text': 'Valid', 'priority': 'routine'},
              ],
            },
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        final observations = strategy.extractObservations();
        expect(observations, hasLength(1));
        expect(observations[0].text, 'Valid');
      });

      test('defaults unknown priority to routine', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.recordObservations,
            args: {
              'observations': [
                {'text': 'Test', 'priority': 'unknown_value'},
              ],
            },
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(
          strategy.extractObservations()[0].priority,
          ObservationPriority.routine,
        );
      });

      test('defaults unknown category to operational', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.recordObservations,
            args: {
              'observations': [
                {'text': 'Test', 'category': 'unknown_category'},
              ],
            },
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(
          strategy.extractObservations()[0].category,
          ObservationCategory.operational,
        );
      });
    });

    group('deferred tools', () {
      test('queues recommend_next_steps for user review', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.recommendNextSteps,
            args: {
              'steps': [
                {
                  'title': 'Prioritize API redesign',
                  'rationale': 'Current API has scaling issues',
                  'priority': 'high',
                },
              ],
            },
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        final deferred = strategy.extractDeferredItems();
        expect(deferred, hasLength(1));
        expect(
          deferred[0]['toolName'],
          ProjectAgentToolNames.recommendNextSteps,
        );
        expect(deferred[0]['args'], isA<Map<String, dynamic>>());

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-1',
            response: any(
              named: 'response',
              that: contains('Queued'),
            ),
          ),
        ).called(1);
      });

      test('queues update_project_status for user review', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.updateProjectStatus,
            args: {
              'status': 'at_risk',
              'reason': 'Key dependency delayed',
            },
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        final deferred = strategy.extractDeferredItems();
        expect(deferred, hasLength(1));
        expect(
          deferred[0]['toolName'],
          ProjectAgentToolNames.updateProjectStatus,
        );
      });

      test('queues create_task for user review', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.createTask,
            args: {
              'title': 'Set up monitoring',
              'description': 'Add alerting for API latency',
              'priority': 'HIGH',
            },
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        final deferred = strategy.extractDeferredItems();
        expect(deferred, hasLength(1));
        expect(deferred[0]['toolName'], ProjectAgentToolNames.createTask);
        final args = deferred[0]['args'] as Map<String, dynamic>;
        expect(args['title'], 'Set up monitoring');
      });

      test('accumulates multiple deferred items', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.updateProjectStatus,
            args: {'status': 'on_track', 'reason': 'Good progress'},
          ),
          _makeToolCall(
            id: 'call-2',
            name: ProjectAgentToolNames.createTask,
            args: {'title': 'Write docs'},
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractDeferredItems(), hasLength(2));
      });
    });

    group('unknown tools', () {
      test('returns error for unknown tool names', () async {
        final toolCalls = [
          _makeToolCall(
            name: 'nonexistent_tool',
            args: {'foo': 'bar'},
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-1',
            response: any(
              named: 'response',
              that: contains('unknown tool'),
            ),
          ),
        ).called(1);
      });
    });

    group('invalid arguments', () {
      test('returns error for malformed JSON arguments', () async {
        final toolCalls = [
          const ChatCompletionMessageToolCall(
            id: 'call-1',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: ProjectAgentToolNames.updateProjectReport,
              arguments: 'not valid json {{{',
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-1',
            response: any(
              named: 'response',
              that: contains('invalid arguments'),
            ),
          ),
        ).called(1);
      });

      test('parses markdown-wrapped JSON arguments', () async {
        const wrappedJson = '''
```json
{
  "markdown": "# Report",
  "tldr": "Quick summary.",
  "health_band": "watch",
  "health_rationale": "There is still some uncertainty."
}
```''';
        final toolCalls = [
          const ChatCompletionMessageToolCall(
            id: 'call-1',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: ProjectAgentToolNames.updateProjectReport,
              arguments: wrappedJson,
            ),
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.extractReportContent(), '# Report');
        expect(strategy.extractReportHealthBand(), 'watch');
      });
    });

    group('shouldContinue', () {
      test('delegates to manager.canContinue()', () {
        when(() => mockManager.canContinue()).thenReturn(true);
        expect(strategy.shouldContinue(mockManager), isTrue);

        when(() => mockManager.canContinue()).thenReturn(false);
        expect(strategy.shouldContinue(mockManager), isFalse);
      });
    });

    group('getContinuationPrompt', () {
      test('returns prompt when no report has been submitted', () {
        final prompt = strategy.getContinuationPrompt(mockManager);
        expect(prompt, isNotNull);
        expect(prompt, contains('update_project_report'));
      });

      test('returns null after report has been submitted', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.updateProjectReport,
            args: {
              'markdown': 'Report content',
              'tldr': 'Things are moving.',
              'health_band': 'on_track',
              'health_rationale': 'The work is in a good place.',
            },
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(strategy.getContinuationPrompt(mockManager), isNull);
      });
    });

    group('recordFinalResponse', () {
      test('stores non-empty response', () {
        strategy.recordFinalResponse('Final answer text');
        expect(strategy.finalResponse, 'Final answer text');
      });

      test('ignores null response', () {
        strategy.recordFinalResponse(null);
        expect(strategy.finalResponse, isNull);
      });

      test('ignores empty response', () {
        strategy.recordFinalResponse('');
        expect(strategy.finalResponse, isNull);
      });
    });

    group('processToolCalls return value', () {
      test('always returns continueConversation', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.updateProjectReport,
            args: {
              'markdown': 'Report',
              'tldr': 'Mixed signals overall.',
              'health_band': 'watch',
              'health_rationale': 'The signal is mixed.',
            },
          ),
        ];

        final action = await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        expect(action, ConversationAction.continueConversation);
      });
    });

    group('message persistence', () {
      test('persists assistant and tool result messages', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.updateProjectReport,
            args: {
              'markdown': 'Report',
              'tldr': 'Mixed signals overall.',
              'health_band': 'watch',
              'health_rationale': 'The signal is mixed.',
            },
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        // Should persist: assistant message + action message + tool result
        verify(() => mockSyncService.upsertEntity(any())).called(3);
      });

      test('continues processing even if persistence fails', () async {
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenThrow(Exception('DB error'));

        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.updateProjectReport,
            args: {
              'markdown': 'Report',
              'tldr': 'Mixed signals overall.',
              'health_band': 'watch',
              'health_rationale': 'The signal is mixed.',
            },
          ),
        ];

        // Should not throw — persistence errors are caught internally.
        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        // Report should still be accumulated despite persistence failure.
        expect(strategy.extractReportContent(), 'Report');
      });
    });

    group('extractors return unmodifiable collections', () {
      test('extractObservations returns unmodifiable list', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.recordObservations,
            args: {
              'observations': ['Test observation'],
            },
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        final observations = strategy.extractObservations();
        expect(
          () => observations.add(const ObservationRecord(text: 'extra')),
          throwsUnsupportedError,
        );
      });

      test('extractDeferredItems returns unmodifiable list', () async {
        final toolCalls = [
          _makeToolCall(
            name: ProjectAgentToolNames.createTask,
            args: {'title': 'Test'},
          ),
        ];

        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: mockManager,
        );

        final deferred = strategy.extractDeferredItems();
        expect(
          () => deferred.add({'extra': true}),
          throwsUnsupportedError,
        );
      });
    });
  });
}
