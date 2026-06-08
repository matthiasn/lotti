import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

extension _AnyObservationStrings on glados.Any {
  /// A non-empty list (1–6) of non-empty letter/digit strings. Letter/digit
  /// only means `trim()` is a no-op, so each generated string is accepted
  /// verbatim by `record_observations`.
  glados.Generator<List<String>> get nonEmptyObservationStrings =>
      glados.ListAnys(this).listWithLengthInRange(
        1,
        6,
        glados.StringAnys(this).nonEmptyLetterOrDigits,
      );
}

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

    // Property: a record_observations call with any non-empty list of
    // already-trimmed strings yields exactly those strings as observations,
    // in input order, with defaults applied. This also pins that the projection
    // does NOT de-duplicate — identical strings each produce an observation
    // (correcting the "no duplicates" claim; the source keeps every accepted
    // item). Generated strings are letter/digit only, so trim() is a no-op.
    glados.Glados(glados.any.nonEmptyObservationStrings).test(
      'extractObservations returns every accepted string in order',
      (strings) async {
        final sut = strategy();

        await sut.processToolCalls(
          toolCalls: [
            _toolCall(
              name: DayAgentToolNames.recordObservations,
              args: {'observations': strings},
            ),
          ],
          manager: manager,
        );

        final observations = sut.extractObservations();
        expect(
          observations.map((o) => o.text).toList(),
          equals(strings),
          reason: 'strings=$strings',
        );
        expect(
          observations.every(
            (o) =>
                o.priority == ObservationPriority.routine &&
                o.category == ObservationCategory.operational,
          ),
          isTrue,
          reason: 'strings=$strings',
        );
      },
      tags: 'glados',
    );

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

      // The strategy must mirror the manager verdict in both directions, not
      // just hard-code `true`: when the manager is exhausted, the wake stops.
      when(() => manager.canContinue()).thenReturn(false);
      expect(sut.shouldContinue(manager), isFalse);

      expect(
        sut.getContinuationPrompt(manager),
        contains('schedule the next wake'),
      );
    });

    // Tool processing persists four entities in order — assistant/thought
    // (write 1), the action payload + action message (writes 2 and 3), and the
    // tool-result (write 4). A failure at any single write must be absorbed:
    // the tool response still reaches the manager and the failure is logged.
    // The three positions exercise the three distinct error-logging branches
    // (`_logPersistenceError` for thought/tool-result, the dedicated catch for
    // the action message) without copy-pasting the surrounding harness.
    for (final scenario in [
      const _PersistenceFailureScenario(
        failAt: 1,
        observationText: 'Keep the wake useful.',
        expectedResponse: 'Recorded 1 observation(s).',
        expectedLog: 'assistant/thought',
      ),
      const _PersistenceFailureScenario(
        failAt: 2,
        observationText: 'Keep action logging best-effort.',
        expectedResponse: 'Recorded 1 observation(s).',
        expectedLog: 'action message',
      ),
      const _PersistenceFailureScenario(
        failAt: 4,
        toolName: 'missing_tool',
        expectedResponse: 'unknown tool',
        expectedLog: 'tool-result',
      ),
    ]) {
      test(
        'continues processing when write ${scenario.failAt} fails '
        '(${scenario.expectedLog})',
        () async {
          final writes = stubWritesFailingAt(scenario.failAt, syncService);
          final sut = strategy();

          await sut.processToolCalls(
            toolCalls: [
              if (scenario.observationText != null)
                _toolCall(
                  name: DayAgentToolNames.recordObservations,
                  args: {
                    'observations': [scenario.observationText],
                  },
                )
              else
                _toolCall(name: scenario.toolName!, args: const {}),
            ],
            manager: manager,
          );

          // The whole write sequence is attempted even though one throws.
          expect(writes.attempts, greaterThanOrEqualTo(scenario.failAt));
          // record_observations still accumulates the observation; the
          // unknown-tool case records nothing.
          if (scenario.observationText != null) {
            expect(
              sut.extractObservations().single.text,
              scenario.observationText,
            );
          } else {
            expect(sut.extractObservations(), isEmpty);
          }
          // Processing did not abort on the persistence failure: the tool
          // response still reached the manager with the expected content.
          final response =
              verify(
                    () => manager.addToolResponse(
                      toolCallId: 'call-1',
                      response: captureAny(named: 'response'),
                    ),
                  ).captured.single
                  as String;
          expect(response, contains(scenario.expectedResponse));
          // …and the failed write was logged from the correct branch.
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
          expect(errorMessage, contains(scenario.expectedLog));
        },
      );
    }
  });
}

/// Parameterizes the three single-write persistence-failure positions in
/// [DayAgentStrategy.processToolCalls]: thought (1), action message (2), and
/// tool-result (4). Either [observationText] (a `record_observations` call) or
/// [toolName] (any other tool) drives the call.
class _PersistenceFailureScenario {
  const _PersistenceFailureScenario({
    required this.failAt,
    required this.expectedResponse,
    required this.expectedLog,
    this.observationText,
    this.toolName,
  });

  final int failAt;
  final String? observationText;
  final String? toolName;
  final String expectedResponse;
  final String expectedLog;
}

/// Counts `upsertEntity` calls and throws on the `failAt`-th write so a single
/// persistence failure can be injected at a known position in the write order.
class _WriteCounter {
  int attempts = 0;
}

// ignore: library_private_types_in_public_api
_WriteCounter stubWritesFailingAt(int failAt, MockAgentSyncService sync) {
  final counter = _WriteCounter();
  when(() => sync.upsertEntity(any())).thenAnswer((_) async {
    counter.attempts++;
    if (counter.attempts == failAt) {
      throw StateError('write $failAt failed');
    }
  });
  return counter;
}
