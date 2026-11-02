import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/event_agent_strategy.dart';
import 'package:lotti/features/agents/workflow/event_people_directory.dart';
import 'package:lotti/services/domain_logging.dart';
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
  late MockDomainLogger mockDomainLogger;
  late int peopleLoads;
  late Future<EventPeopleDirectory> Function() loadPeople;

  /// Pip is free to suggest; Rocko is with the event already; Oona was
  /// suggested and still waits; Kai was dismissed.
  final directory = EventPeopleDirectory(
    people: const [
      EventKnownPerson(id: 'kai', name: 'Kai'),
      EventKnownPerson(id: 'oona', name: 'Oona'),
      EventKnownPerson(id: 'pip', name: 'Pip Penguin', nickname: 'Pip'),
      EventKnownPerson(id: 'rocko', name: 'Rocko'),
    ],
    withEventIds: {'rocko'},
    suggestedIds: {'oona'},
    dismissedIds: {'kai'},
  );

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockSyncService = MockAgentSyncService();
    mockManager = MockConversationManager();

    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});

    mockDomainLogger = MockDomainLogger();
    peopleLoads = 0;
    loadPeople = () async {
      peopleLoads++;
      return directory;
    };
    strategy = EventAgentStrategy(
      domainLogger: mockDomainLogger,
      syncService: mockSyncService,
      agentId: _agentId,
      threadId: _threadId,
      runKey: _runKey,
      loadPeople: () => loadPeople(),
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

    test(
      'rejects a non-empty array whose items are all blank/invalid',
      () async {
        await strategy.processToolCalls(
          toolCalls: [
            _makeToolCall(
              name: EventAgentToolNames.recordObservations,
              args: {
                'observations': [
                  '   ',
                  {'text': ''},
                  42, // wrong type
                ],
              },
            ),
          ],
          manager: mockManager,
        );

        // Nothing accepted → reject instead of acknowledging a no-op success.
        expect(strategy.extractObservations(), isEmpty);
        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call-1',
            response:
                'Error: no valid observations found. '
                'Provide non-empty observation text.',
          ),
        ).called(1);
        verifyNever(
          () => mockManager.addToolResponse(
            toolCallId: 'call-1',
            response: 'Recorded 0 observation(s).',
          ),
        );
      },
    );
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

  group('list_people', () {
    test('answers the directory, read once per wake', () async {
      for (final id in ['call-1', 'call-2']) {
        await strategy.processToolCalls(
          toolCalls: [
            _makeToolCall(
              id: id,
              name: EventAgentToolNames.listPeople,
              args: const {},
            ),
          ],
          manager: mockManager,
        );
      }

      final responses = verify(
        () => mockManager.addToolResponse(
          toolCallId: any(named: 'toolCallId'),
          response: captureAny(named: 'response'),
        ),
      ).captured.cast<String>();
      expect(responses, hasLength(2));
      expect(responses.first, directory.render());
      expect(responses.first, contains('- pip: Pip Penguin (called "Pip")'));
      expect(peopleLoads, 1);
    });

    test('narrows to a query', () async {
      await strategy.processToolCalls(
        toolCalls: [
          _makeToolCall(
            name: EventAgentToolNames.listPeople,
            args: const {'query': 'pip'},
          ),
        ],
        manager: mockManager,
      );

      verify(
        () => mockManager.addToolResponse(
          toolCallId: 'call-1',
          response: directory.render(query: 'pip'),
        ),
      ).called(1);
    });

    test('a failed read says so, and the next call reads again', () async {
      var fail = true;
      loadPeople = () async {
        peopleLoads++;
        if (fail) throw StateError('db down');
        return directory;
      };

      await strategy.processToolCalls(
        toolCalls: [
          _makeToolCall(name: EventAgentToolNames.listPeople, args: const {}),
        ],
        manager: mockManager,
      );
      verify(
        () => mockManager.addToolResponse(
          toolCallId: 'call-1',
          response: 'Error: the people could not be read (StateError).',
        ),
      ).called(1);

      fail = false;
      await strategy.processToolCalls(
        toolCalls: [
          _makeToolCall(
            id: 'call-2',
            name: EventAgentToolNames.listPeople,
            args: const {},
          ),
        ],
        manager: mockManager,
      );
      verify(
        () => mockManager.addToolResponse(
          toolCallId: 'call-2',
          response: directory.render(),
        ),
      ).called(1);
      expect(peopleLoads, 2);
    });
  });

  group('suggest_person (deferred)', () {
    Future<String> suggest(Map<String, dynamic> args, {String id = 'c'}) async {
      await strategy.processToolCalls(
        toolCalls: [
          _makeToolCall(
            id: id,
            name: EventAgentToolNames.suggestPerson,
            args: args,
          ),
        ],
        manager: mockManager,
      );
      return verify(
            () => mockManager.addToolResponse(
              toolCallId: id,
              response: captureAny(named: 'response'),
            ),
          ).captured.single
          as String;
    }

    test('queues an open person, carrying their name for the row', () async {
      final response = await suggest({
        'personId': ' pip ',
        'mention': 'Pip brought the sardines',
      });

      expect(
        response,
        'Queued the suggestion to add Pip Penguin for user review.',
      );
      expect(strategy.extractDeferredItems(), [
        {
          'toolName': EventAgentToolNames.suggestPerson,
          'args': {
            'personId': 'pip',
            'mention': 'Pip brought the sardines',
            'personName': 'Pip Penguin',
          },
        },
      ]);
    });

    final refusals = {
      'rocko': 'Not suggested: Rocko is already with this event.',
      'oona': 'Not suggested: Oona is already suggested, awaiting the user.',
      'kai':
          'Not suggested: Kai is dismissed by the user for this event — do '
          'not suggest again.',
      'ghost':
          'Error: no person has the id "ghost" — use an id exactly as '
          '`list_people` gave it.',
      '  ': 'Error: "personId" is required — use an id from `list_people`.',
    };
    for (final MapEntry(key: personId, value: refusal) in refusals.entries) {
      test('refuses "$personId", queueing nothing', () async {
        expect(await suggest({'personId': personId}), refusal);
        expect(strategy.extractDeferredItems(), isEmpty);
      });
    }

    test('refuses the same person twice in one wake', () async {
      await suggest({'personId': 'pip'}, id: 'c1');
      final second = await suggest({'personId': 'pip'}, id: 'c2');

      expect(
        second,
        'Not suggested: Pip Penguin is already suggested in this wake.',
      );
      expect(strategy.extractDeferredItems(), hasLength(1));
    });

    test('a failed directory read refuses, queueing nothing', () async {
      loadPeople = () async => throw StateError('db down');

      expect(
        await suggest({'personId': 'pip'}),
        'Error: the people could not be read (StateError).',
      );
      expect(strategy.extractDeferredItems(), isEmpty);
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
      verify(
        () => mockDomainLogger.log(
          LogDomain.agentWorkflow,
          any(
            that: allOf(
              contains('Failed to parse tool call arguments'),
              contains('errorType=FormatException'),
            ),
          ),
          subDomain: 'EventAgentStrategy',
          level: InsightLevel.warn,
        ),
      ).called(1);
      verifyNever(
        () => mockDomainLogger.error(
          any(),
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
          message: any(named: 'message'),
        ),
      );
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

    test('shouldContinue delegates to the manager', () {
      when(() => mockManager.canContinue()).thenReturn(true);
      expect(strategy.shouldContinue(mockManager), isTrue);

      when(() => mockManager.canContinue()).thenReturn(false);
      expect(strategy.shouldContinue(mockManager), isFalse);
    });
  });
}
