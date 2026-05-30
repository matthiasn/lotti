import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_strategy.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';

const _agentId = 'day-agent-001';
const _threadId = 'thread-001';
const _runKey = 'run-key-001';

ChatCompletionMessageToolCall _toolCall({
  required String name,
  required Map<String, dynamic> args,
  String id = 'call-1',
  String? rawArguments,
}) {
  return ChatCompletionMessageToolCall(
    id: id,
    type: ChatCompletionMessageToolCallType.function,
    function: ChatCompletionMessageFunctionCall(
      name: name,
      arguments: rawArguments ?? jsonEncode(args),
    ),
  );
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentSyncService syncService;
  late MockConversationManager manager;
  late MockDomainLogger domainLogger;

  DayAgentStrategy strategy({
    DayAgentToolHandler? handler,
  }) {
    return DayAgentStrategy(
      syncService: syncService,
      agentId: _agentId,
      threadId: _threadId,
      runKey: _runKey,
      domainLogger: domainLogger,
      executeToolHandler:
          handler ??
          (_, _, _) async => const DayAgentToolResult(
            success: true,
            output: 'ok',
          ),
    );
  }

  setUp(() {
    syncService = MockAgentSyncService();
    manager = MockConversationManager();
    domainLogger = MockDomainLogger();
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
  });

  group('DayAgentStrategy', () {
    test('records structured and string observations', () async {
      final sut = strategy();

      await sut.processToolCalls(
        toolCalls: [
          _toolCall(
            name: DayAgentToolNames.recordObservations,
            args: {
              'observations': [
                '  User starts planning around coffee. ',
                {
                  'text': 'Morning wake was useful.',
                  'priority': 'notable',
                  'category': 'operational',
                },
              ],
            },
          ),
        ],
        manager: manager,
      );

      final observations = sut.extractObservations();
      expect(observations, hasLength(2));
      expect(observations[0].text, 'User starts planning around coffee.');
      expect(observations[0].priority, ObservationPriority.routine);
      expect(observations[1].text, 'Morning wake was useful.');
      expect(observations[1].priority, ObservationPriority.notable);
      expect(observations[1].category, ObservationCategory.operational);
      verify(
        () => manager.addToolResponse(
          toolCallId: 'call-1',
          response: 'Recorded 2 observation(s).',
        ),
      ).called(1);
    });

    test('rejects empty observation lists', () async {
      final sut = strategy();

      await sut.processToolCalls(
        toolCalls: [
          _toolCall(
            name: DayAgentToolNames.recordObservations,
            args: {'observations': <Object?>[]},
          ),
        ],
        manager: manager,
      );

      expect(sut.extractObservations(), isEmpty);
      final response =
          verify(
                () => manager.addToolResponse(
                  toolCallId: 'call-1',
                  response: captureAny(named: 'response'),
                ),
              ).captured.single
              as String;
      expect(response, contains('non-empty array'));
    });

    test('rejects tool arguments that are not a JSON object', () async {
      final sut = strategy();

      await sut.processToolCalls(
        toolCalls: [
          _toolCall(
            name: DayAgentToolNames.recordObservations,
            args: const {},
            rawArguments: '[]',
          ),
        ],
        manager: manager,
      );

      expect(sut.extractObservations(), isEmpty);
      final response =
          verify(
                () => manager.addToolResponse(
                  toolCallId: 'call-1',
                  response: captureAny(named: 'response'),
                ),
              ).captured.single
              as String;
      expect(response, contains('invalid arguments format'));
      expect(response, contains('FormatException'));
    });

    test('rejects observation lists without valid text', () async {
      final sut = strategy();

      await sut.processToolCalls(
        toolCalls: [
          _toolCall(
            name: DayAgentToolNames.recordObservations,
            args: const {
              'observations': [
                '   ',
                {'text': '  ', 'priority': 'notable'},
                {'category': 'operational'},
                42,
              ],
            },
          ),
        ],
        manager: manager,
      );

      expect(sut.extractObservations(), isEmpty);
      final response =
          verify(
                () => manager.addToolResponse(
                  toolCallId: 'call-1',
                  response: captureAny(named: 'response'),
                ),
              ).captured.single
              as String;
      expect(response, contains('no valid observations'));
    });

    test('delegates set_next_wake to the workflow handler', () async {
      final seen = <String, Map<String, dynamic>>{};
      final sut = strategy(
        handler: (toolName, args, _) async {
          seen[toolName] = args;
          return const DayAgentToolResult(
            success: true,
            output: 'scheduled',
          );
        },
      );

      await sut.processToolCalls(
        toolCalls: [
          _toolCall(
            name: DayAgentToolNames.setNextWake,
            args: {
              'at': '2026-05-25T06:30:00',
              'reason': 'Warm the day before capture.',
            },
          ),
        ],
        manager: manager,
      );

      expect(
        seen[DayAgentToolNames.setNextWake],
        {
          'at': '2026-05-25T06:30:00',
          'reason': 'Warm the day before capture.',
        },
      );
      verify(
        () => manager.addToolResponse(
          toolCallId: 'call-1',
          response: 'scheduled',
        ),
      ).called(1);
    });

    test('delegates capture/reconcile tools to the workflow handler', () async {
      final seen = <String, Map<String, dynamic>>{};
      final sut = strategy(
        handler: (toolName, args, _) async {
          seen[toolName] = args;
          return const DayAgentToolResult(
            success: true,
            output: '{"candidates":[]}',
          );
        },
      );

      await sut.processToolCalls(
        toolCalls: [
          _toolCall(
            name: DayAgentToolNames.matchToCorpus,
            args: {'phrase': 'prep demo'},
          ),
        ],
        manager: manager,
      );

      expect(
        seen[DayAgentToolNames.matchToCorpus],
        {'phrase': 'prep demo'},
      );
      verify(
        () => manager.addToolResponse(
          toolCallId: 'call-1',
          response: '{"candidates":[]}',
        ),
      ).called(1);
    });

    test('unknown tools receive an error response', () async {
      final sut = strategy();

      await sut.processToolCalls(
        toolCalls: [
          _toolCall(name: 'missing_tool', args: const {}),
        ],
        manager: manager,
      );

      final response =
          verify(
                () => manager.addToolResponse(
                  toolCallId: 'call-1',
                  response: captureAny(named: 'response'),
                ),
              ).captured.single
              as String;
      expect(response, contains('unknown tool'));
    });

    test('uses the conversation manager continuation policy', () {
      final sut = strategy();
      when(() => manager.canContinue()).thenReturn(true);

      expect(sut.shouldContinue(manager), isTrue);
      expect(
        sut.getContinuationPrompt(manager),
        contains('schedule the next wake'),
      );
    });

    test(
      'continues tool processing when assistant message persistence fails',
      () async {
        var writeCount = 0;
        when(() => syncService.upsertEntity(any())).thenAnswer((_) async {
          writeCount++;
          if (writeCount == 1) {
            throw StateError('assistant write failed');
          }
        });
        final sut = strategy();

        await sut.processToolCalls(
          toolCalls: [
            _toolCall(
              name: DayAgentToolNames.recordObservations,
              args: {
                'observations': ['Keep the wake useful.'],
              },
            ),
          ],
          manager: manager,
        );

        expect(sut.extractObservations().single.text, 'Keep the wake useful.');
        verify(
          () => manager.addToolResponse(
            toolCallId: 'call-1',
            response: 'Recorded 1 observation(s).',
          ),
        ).called(1);
        final errorMessage =
            verify(
                  () => domainLogger.error(
                    any(),
                    any(),
                    message: captureAny(named: 'message'),
                    stackTrace: any(named: 'stackTrace'),
                    subDomain: any(named: 'subDomain'),
                  ),
                ).captured.single
                as String;
        expect(errorMessage, contains('assistant/thought'));
      },
    );

    test(
      'continues tool processing when action message persistence fails',
      () async {
        var writeCount = 0;
        when(() => syncService.upsertEntity(any())).thenAnswer((_) async {
          writeCount++;
          if (writeCount == 2) {
            throw StateError('action write failed');
          }
        });
        final sut = strategy();

        await sut.processToolCalls(
          toolCalls: [
            _toolCall(
              name: DayAgentToolNames.recordObservations,
              args: {
                'observations': ['Keep action logging best-effort.'],
              },
            ),
          ],
          manager: manager,
        );

        expect(
          sut.extractObservations().single.text,
          'Keep action logging best-effort.',
        );
        verify(
          () => manager.addToolResponse(
            toolCallId: 'call-1',
            response: 'Recorded 1 observation(s).',
          ),
        ).called(1);
        final errorMessage =
            verify(
                  () => domainLogger.error(
                    any(),
                    any(),
                    message: captureAny(named: 'message'),
                    stackTrace: any(named: 'stackTrace'),
                    subDomain: any(named: 'subDomain'),
                  ),
                ).captured.single
                as String;
        expect(errorMessage, contains('action message'));
      },
    );

    test(
      'continues tool processing when tool-result persistence fails',
      () async {
        var writeCount = 0;
        when(() => syncService.upsertEntity(any())).thenAnswer((_) async {
          writeCount++;
          if (writeCount == 4) {
            throw StateError('tool result write failed');
          }
        });
        final sut = strategy();

        await sut.processToolCalls(
          toolCalls: [
            _toolCall(name: 'missing_tool', args: const {}),
          ],
          manager: manager,
        );

        final response =
            verify(
                  () => manager.addToolResponse(
                    toolCallId: 'call-1',
                    response: captureAny(named: 'response'),
                  ),
                ).captured.single
                as String;
        expect(response, contains('unknown tool'));
        final errorMessage =
            verify(
                  () => domainLogger.error(
                    any(),
                    any(),
                    message: captureAny(named: 'message'),
                    stackTrace: any(named: 'stackTrace'),
                    subDomain: any(named: 'subDomain'),
                  ),
                ).captured.single
                as String;
        expect(errorMessage, contains('tool-result'));
      },
    );
  });
}
