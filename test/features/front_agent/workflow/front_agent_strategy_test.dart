import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/front_agent/model/front_closed_task_card.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_strategy.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

ChatCompletionMessageToolCall _call(
  String name,
  Map<String, dynamic> args, {
  String id = 'call-1',
}) => ChatCompletionMessageToolCall(
  id: id,
  type: ChatCompletionMessageToolCallType.function,
  function: ChatCompletionMessageFunctionCall(
    name: name,
    arguments: jsonEncode(args),
  ),
);

ChatCompletionMessageToolCall _rawCall(String name, String arguments) =>
    ChatCompletionMessageToolCall(
      id: 'call-raw',
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: name,
        arguments: arguments,
      ),
    );

void main() {
  setUpAll(registerAllFallbackValues);

  const input = 'Buy the hose. Ask Pip.';
  //             0123456789012345678901
  late MockAgentSyncService syncService;
  late MockConversationManager manager;
  late MockDomainLogger domainLogger;
  late List<Object?> upserts;

  final index = FrontRoutingIndex(
    tasks: const [
      FrontIndexRow(
        kind: FrontDestinationKind.task,
        id: 'garden',
        title: 'Garden',
        status: 'OPEN',
        tldr: 'The hose is the last thing to buy.',
      ),
    ],
    people: const [
      FrontIndexRow(kind: FrontDestinationKind.person, id: 'pip', title: 'Pip'),
    ],
  );

  FrontAgentStrategy strategy({
    FrontCorpusMatcher? matcher,
    FrontDueTaskLister? dueLister,
    FrontLoggedTimeSummarizer? timeSummarizer,
    FrontClosedTaskLister? closedLister,
    FrontPullRequestSummarizer? pullRequestSummarizer,
    FrontRoutingIndex? routingIndex,
    List<FrontIndexRow> conversationTasks = const [],
  }) => FrontAgentStrategy(
    syncService: syncService,
    domainLogger: domainLogger,
    agentId: 'front_agent',
    threadId: 'thread-1',
    runKey: 'run-1',
    input: input,
    index: routingIndex ?? index,
    now: DateTime(2026, 11, 2, 9),
    corpusMatcher: matcher,
    dueTaskLister: dueLister,
    loggedTimeSummarizer: timeSummarizer,
    closedTaskLister: closedLister,
    pullRequestSummarizer: pullRequestSummarizer,
    conversationTasks: conversationTasks,
  );

  Map<String, dynamic> segment({
    required int start,
    required int end,
    String kind = 'task',
    String? id = 'garden',
    String intent = 'instruction',
    double confidence = 0.9,
  }) => {
    'start': start,
    'end': end,
    'text': input.substring(start, end),
    'intent': intent,
    'destination': {'kind': kind, 'id': ?id},
    'confidence': confidence,
  };

  Map<String, dynamic> fullDispatch() => {
    'segments': [
      segment(start: 0, end: 13),
      segment(
        start: 14,
        end: 22,
        kind: 'person',
        id: 'pip',
        intent: 'question',
      ),
    ],
  };

  List<String> responses() => verify(
    () => manager.addToolResponse(
      toolCallId: any(named: 'toolCallId'),
      response: captureAny(named: 'response'),
    ),
  ).captured.cast<String>();

  setUp(() {
    syncService = MockAgentSyncService();
    manager = MockConversationManager();
    domainLogger = MockDomainLogger();
    upserts = [];
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserts.add(invocation.positionalArguments.first);
    });
    when(() => manager.canContinue()).thenReturn(true);
  });

  group('dispatch', () {
    test("a dictated start counts back from the turn's clock, not from "
        'when a slow dispatch lands', () async {
      final turnNow = DateTime(2026, 11, 2, 10);
      final s = FrontAgentStrategy(
        syncService: syncService,
        domainLogger: domainLogger,
        agentId: 'front_agent',
        threadId: 'thread-1',
        runKey: 'run-1',
        input: input,
        index: index,
        now: turnNow,
      );
      // The prompt said 10:00; inference took two minutes.
      await withClock(
        Clock.fixed(turnNow.add(const Duration(minutes: 2))),
        () => s.processToolCalls(
          toolCalls: [
            _call('dispatch', {
              'segments': [
                {
                  ...segment(start: 0, end: input.length, id: null),
                  'destination': {'kind': 'new', 'newKind': 'task'},
                  'task': {'title': 'Fix the gate', 'startedMinutesAgo': 45},
                },
              ],
            }),
          ],
          manager: manager,
        ),
      );
      expect(
        s.dispatch!.segments.single.task!.startedAt,
        DateTime(2026, 11, 2, 9, 15),
      );
    });

    test("a new task's category stands when listed, and only among the "
        'chosen ones when the conversation is narrowed', () async {
      Future<String?> categoryOf(
        String categoryId, {
        required bool narrowed,
      }) async {
        final s = strategy(
          routingIndex: FrontRoutingIndex(
            categories: [
              FrontCategory(id: 'work', name: 'Work', chosen: narrowed),
              const FrontCategory(id: 'home', name: 'Home'),
            ],
          ),
        );
        await s.processToolCalls(
          toolCalls: [
            _call('dispatch', {
              'segments': [
                {
                  ...segment(
                    start: 0,
                    end: input.length,
                    kind: 'new',
                    id: null,
                  ),
                  'destination': {'kind': 'new', 'newKind': 'task'},
                  'task': {'title': 'Fix the gate', 'categoryId': categoryId},
                },
              ],
            }),
          ],
          manager: manager,
        );
        return s.dispatch!.segments.single.task!.categoryId;
      }

      expect(await categoryOf('home', narrowed: false), 'home');
      expect(await categoryOf('home', narrowed: true), isNull);
      expect(await categoryOf('work', narrowed: true), 'work');
      expect(await categoryOf('nope', narrowed: false), isNull);
    });

    test('a follow-up may follow a listed task or a closed one the '
        'conversation named, never an invented one', () async {
      Future<String?> followedBy(String id) async {
        final s = strategy(
          conversationTasks: const [
            FrontIndexRow(
              kind: FrontDestinationKind.task,
              id: 'roses',
              title: 'Prune the roses',
              status: 'DONE',
            ),
          ],
        );
        await s.processToolCalls(
          toolCalls: [
            _call('dispatch', {
              'segments': [
                {
                  ...segment(
                    start: 0,
                    end: input.length,
                    kind: 'new',
                    id: null,
                  ),
                  'destination': {'kind': 'new', 'newKind': 'task'},
                  'task': {'title': 'Mulch the roses', 'followsUpTaskId': id},
                },
              ],
            }),
          ],
          manager: manager,
        );
        return s.dispatch!.segments.single.task!.followsUpTaskId;
      }

      expect(await followedBy('roses'), 'roses');
      expect(await followedBy('garden'), 'garden');
      expect(await followedBy('invented'), isNull);
    });

    test('a valid dispatch is accumulated and ends the turn', () async {
      final s = strategy();
      final action = await s.processToolCalls(
        toolCalls: [_call('dispatch', fullDispatch())],
        manager: manager,
      );

      expect(action, ConversationAction.complete);
      expect(s.hasTerminalOutput, isTrue);
      expect(s.dispatch!.segments.map((x) => x.destinationId), [
        'garden',
        'pip',
      ]);
      expect(s.shouldContinue(manager), isFalse);
      expect(responses().single, 'Dispatched 2 segment(s).');
      expect(s.rejectedDispatches, 0);
      // Nothing is persisted mid-conversation beyond the message log.
      expect(upserts.length, 3); // assistant thought, action, tool result
    });

    test("an invalid dispatch is rejected with the validator's reason and "
        'the turn continues', () async {
      final s = strategy();
      final action = await s.processToolCalls(
        toolCalls: [
          _call('dispatch', {
            'segments': [segment(start: 0, end: 13, id: 'nope')],
          }),
        ],
        manager: manager,
      );

      expect(action, ConversationAction.continueConversation);
      expect(s.dispatch, isNull);
      expect(s.rejectedDispatches, 1);
      expect(responses().single, contains('task:nope'));
      expect(s.shouldContinue(manager), isTrue);
    });

    test('a second dispatch in one turn is refused', () async {
      final s = strategy();
      await s.processToolCalls(
        toolCalls: [
          _call('dispatch', fullDispatch()),
          _call('dispatch', fullDispatch(), id: 'call-2'),
        ],
        manager: manager,
      );
      expect(responses().last, contains('at most once per turn'));
    });

    test('malformed JSON arguments are rejected, not thrown', () async {
      final s = strategy();
      final action = await s.processToolCalls(
        toolCalls: [_rawCall('dispatch', '{not json')],
        manager: manager,
      );
      expect(action, ConversationAction.continueConversation);
      expect(responses().single, contains('invalid arguments format'));
    });

    test('an unknown tool is rejected by name', () async {
      await strategy().processToolCalls(
        toolCalls: [_call('update_report', const {})],
        manager: manager,
      );
      expect(responses().single, contains('unknown tool "update_report"'));
    });
  });

  group('read_tldr', () {
    test('answers from the index and refuses a second read with the '
        'exhausted answer — the tool is never removed', () async {
      final s = strategy();
      await s.processToolCalls(
        toolCalls: [
          _call('read_tldr', {
            'ids': [
              'task:garden',
              'person:pip',
              'task:unknown',
              'garbage',
              'hologram:x',
            ],
          }),
          _call('read_tldr', {
            'ids': ['task:garden'],
          }, id: 'call-2'),
        ],
        manager: manager,
      );

      final answers = responses();
      expect(answers.first, '''
task:garden: The hose is the last thing to buy.
person:pip: no TL;DR yet
task:unknown: not listed
garbage: not listed
hologram:x: not listed''');
      expect(answers.last, frontTldrExhaustedAnswer);
      expect(s.lookupCalls, 1);
    });

    test('needs one to five ids', () async {
      await strategy().processToolCalls(
        toolCalls: [
          _call('read_tldr', {'ids': const <String>[]}),
          _call('read_tldr', {
            'ids': [for (var i = 0; i < 6; i++) 'task:$i'],
          }, id: 'call-2'),
        ],
        manager: manager,
      );
      expect(responses(), everyElement(contains('1 to 5 ids')));
    });
  });

  group('match_to_corpus', () {
    test(
      'lookup rows become valid destinations for the rest of the turn',
      () async {
        final s = strategy(
          matcher: (phrase) async => [
            FrontIndexRow(
              kind: FrontDestinationKind.task,
              id: 'found-$phrase',
              title: 'Found',
              status: 'OPEN',
            ),
          ],
        );
        await s.processToolCalls(
          toolCalls: [
            _call('match_to_corpus', {'phrase': 'shed'}),
          ],
          manager: manager,
        );
        expect(responses().single, 'task:found-shed | Found | OPEN');

        final action = await s.processToolCalls(
          toolCalls: [
            _call('dispatch', {
              'segments': [segment(start: 0, end: 13, id: 'found-shed')],
            }, id: 'call-2'),
          ],
          manager: manager,
        );
        expect(action, ConversationAction.complete);
        expect(s.dispatch!.segments.first.destinationId, 'found-shed');
      },
    );

    test('refuses a second match, an empty phrase, and reports an unwired '
        'matcher', () async {
      final s = strategy(matcher: (_) async => const []);
      await s.processToolCalls(
        toolCalls: [
          _call('match_to_corpus', {'phrase': ' '}),
          _call('match_to_corpus', {'phrase': 'x'}, id: 'call-2'),
          _call('match_to_corpus', {'phrase': 'y'}, id: 'call-3'),
        ],
        manager: manager,
      );
      expect(responses(), [
        'Error: match_to_corpus needs a phrase.',
        'No open task matches "x".',
        frontCorpusMatchExhaustedAnswer,
      ]);

      await strategy().processToolCalls(
        toolCalls: [
          _call('match_to_corpus', {'phrase': 'z'}),
        ],
        manager: manager,
      );
      expect(responses().last, contains('unavailable this turn'));
    });
  });

  group('list_due_tasks', () {
    final today = DateTime(2026, 11, 2);
    const shed = FrontIndexRow(
      kind: FrontDestinationKind.task,
      id: 'shed',
      title: 'Paint the shed',
      status: 'OPEN',
    );

    // A record compares its set by identity: the query as one string.
    String described(FrontDueQuery q) =>
        '${q.window.name}/${q.daysAhead}/${(q.categoryIds.toList()..sort()).join(',')}';

    FrontDueTasks none(FrontDueQuery query) => FrontDueTasks(
      window: query.window,
      today: today,
      through: today,
      rows: const [],
    );

    test('answers with the tasks due, which the reply may then link and the '
        'dispatch route to', () async {
      final asked = <FrontDueQuery>[];
      final s = strategy(
        dueLister: (query) async {
          asked.add(query);
          return FrontDueTasks(
            window: query.window,
            today: today,
            through: today,
            rows: [
              FrontIndexRow(
                kind: shed.kind,
                id: shed.id,
                title: shed.title,
                status: shed.status,
                due: today,
              ),
            ],
          );
        },
      );
      await s.processToolCalls(
        toolCalls: [
          _call('list_due_tasks', {'which': 'today'}),
        ],
        manager: manager,
      );
      expect(asked.map(described), ['today/0/']);
      expect(
        responses().single,
        'Open tasks due today (2026-11-02) (1):\n'
        '- task:shed | Paint the shed | OPEN | due 2026-11-02',
      );
      expect(s.lookupCalls, 1);

      final action = await s.processToolCalls(
        toolCalls: [
          _call('reply_to_user', {
            'message': 'Due today: task:shed — and Garden (task:garden).',
          }, id: 'call-2'),
        ],
        manager: manager,
      );
      expect(action, ConversationAction.complete);
      // A listed id she recites becomes a link titled as listed.
      expect(
        s.replyToUser,
        'Due today: [Paint the shed](lotti://task/shed) — and '
        '[Garden](lotti://task/garden).',
      );
    });

    test('a task the list returned is linked when she names it by title '
        'alone', () async {
      final s = strategy(
        dueLister: (query) async => FrontDueTasks(
          window: query.window,
          today: today,
          through: today,
          rows: [shed],
        ),
      );
      await s.processToolCalls(
        toolCalls: [
          _call('list_due_tasks', {'which': 'overdue'}),
          _call('reply_to_user', {
            'message': 'Overdue:\n- Paint the shed',
          }, id: 'call-2'),
        ],
        manager: manager,
      );
      expect(
        s.replyToUser,
        'Overdue:\n- [Paint the shed](lotti://task/shed)',
      );
    });

    test('refuses a missing window, a reach past a week, a second list, and '
        'reports an unwired lister', () async {
      final s = strategy(dueLister: (query) async => none(query));
      await s.processToolCalls(
        toolCalls: [
          _call('list_due_tasks', const <String, dynamic>{}),
          _call('list_due_tasks', {'which': 'soon'}, id: 'call-2'),
          _call('list_due_tasks', {
            'which': 'upcoming',
            'daysAhead': frontDueMaxDaysAhead + 1,
          }, id: 'call-3'),
          _call('list_due_tasks', {
            'which': 'all',
            'daysAhead': 1.5,
          }, id: 'call-4'),
          _call('list_due_tasks', {'which': 'overdue'}, id: 'call-5'),
          _call('list_due_tasks', {'which': 'today'}, id: 'call-6'),
        ],
        manager: manager,
      );
      expect(responses(), [
        contains('needs which: one of today, overdue, upcoming, all'),
        contains('needs which'),
        contains('whole number from 0 (today) to $frontDueMaxDaysAhead'),
        contains('whole number'),
        'None: no open task overdue (due before 2026-11-02).',
        frontDueListExhaustedAnswer,
      ]);

      await strategy().processToolCalls(
        toolCalls: [
          _call('list_due_tasks', {'which': 'today'}),
        ],
        manager: manager,
      );
      expect(responses().last, contains('unavailable this turn'));
    });

    test('a named category is passed on by id; an unknown one, or one '
        'outside the chosen chips, is refused', () async {
      final asked = <FrontDueQuery>[];
      FrontAgentStrategy narrowed() => strategy(
        routingIndex: FrontRoutingIndex(
          categories: const [
            FrontCategory(id: 'work', name: 'Work', chosen: true),
            FrontCategory(id: 'home', name: 'Home'),
          ],
        ),
        dueLister: (query) async {
          asked.add(query);
          return none(query);
        },
      );

      final s = narrowed();
      await s.processToolCalls(
        toolCalls: [
          _call('list_due_tasks', {
            'which': 'today',
            'categoryIds': 'work',
          }),
          _call('list_due_tasks', {
            'which': 'today',
            'categoryIds': ['nope'],
          }, id: 'call-2'),
          _call('list_due_tasks', {
            'which': 'today',
            'categoryIds': ['home'],
          }, id: 'call-3'),
          _call('list_due_tasks', {
            'which': 'overdue',
            'categoryIds': ['work'],
          }, id: 'call-4'),
        ],
        manager: manager,
      );

      expect(responses(), [
        contains('categoryIds is a list of ids'),
        contains('nope is not a category id'),
        startsWith('Home is outside the categories this conversation'),
        'None: no open task overdue (due before 2026-11-02).',
      ]);
      expect(asked.map(described), ['overdue/0/work']);
    });

    test('without chips any listed category may be named', () async {
      final asked = <FrontDueQuery>[];
      await strategy(
        routingIndex: FrontRoutingIndex(
          categories: const [FrontCategory(id: 'home', name: 'Home')],
        ),
        dueLister: (query) async {
          asked.add(query);
          return none(query);
        },
      ).processToolCalls(
        toolCalls: [
          _call('list_due_tasks', {
            'which': 'upcoming',
            'daysAhead': 3,
            'categoryIds': ['home'],
          }),
        ],
        manager: manager,
      );
      expect(asked.map(described), ['upcoming/3/home']);
    });
  });

  group('summarize_logged_time', () {
    const chart = FrontLoggedTimeChart(
      range: InsightsRange(startDay: 20398, endDayExclusive: 20399),
      categoryIds: {'work'},
    );
    FrontLoggedTime logged(
      FrontTimePeriod? period, {
      List<({String? name, int seconds})> byCategory = const [
        (name: 'Work', seconds: 7200),
        (name: 'Health', seconds: 5400),
      ],
    }) => FrontLoggedTime(
      period: period,
      from: DateTime(2026, 11, 6),
      through: DateTime(2026, 11, 6),
      byCategory: byCategory,
      chart: chart,
    );

    test('answers with the summary for the period asked; the reply then '
        'ends the turn', () async {
      final asked = <FrontTimePeriod?>[];
      final s = strategy(
        timeSummarizer: (query) async {
          asked.add(query.period);
          return logged(query.period);
        },
      );
      await s.processToolCalls(
        toolCalls: [
          _call('summarize_logged_time', {'period': 'yesterday'}),
        ],
        manager: manager,
      );
      expect(asked, [FrontTimePeriod.yesterday]);
      expect(
        responses().single,
        'Time logged yesterday (2026-11-06): 3h 30m in total, by category, '
        'largest first:\n'
        '- Work: 2h\n'
        '- Health: 1h 30m',
      );
      expect(s.lookupCalls, 1);
      expect(s.hasTerminalOutput, isFalse);

      final action = await s.processToolCalls(
        toolCalls: [
          _call('reply_to_user', {
            'message': 'Yesterday: 3h 30m — 2h Work, 1h 30m Health.',
          }, id: 'call-2'),
        ],
        manager: manager,
      );
      expect(action, ConversationAction.complete);
      expect(s.replyToUser, 'Yesterday: 3h 30m — 2h Work, 1h 30m Health.');
      expect(s.dispatch, isNull);
      // Her reply charts the days summed, in the turn's scope.
      expect(s.loggedTimeChart, chart);
    });

    test(
      'a named category reaches the summary, and a task it lists is linked '
      'when she names it by title alone',
      () async {
        const roses = FrontIndexRow(
          kind: FrontDestinationKind.task,
          id: 'roses',
          title: 'Prune the roses',
          status: 'OPEN',
        );
        final asked = <Set<String>>[];
        final s = strategy(
          routingIndex: FrontRoutingIndex(
            categories: const [
              FrontCategory(id: 'work', name: 'Work'),
              FrontCategory(id: 'home', name: 'Home'),
            ],
          ),
          timeSummarizer: (query) async {
            asked.add(query.categoryIds);
            return FrontLoggedTime(
              period: query.period,
              from: DateTime(2026, 11, 2),
              through: DateTime(2026, 11, 8),
              byCategory: const [
                (name: FrontLoggedTime.otherCategories, seconds: 7200),
                (name: 'Home', seconds: 3600),
              ],
              named: const ['Home'],
              tasks: const [(row: roses, seconds: 3600)],
              chart: chart,
            );
          },
        );
        await s.processToolCalls(
          toolCalls: [
            _call('summarize_logged_time', {
              'period': 'past_7_days',
              'categoryIds': ['home'],
            }),
          ],
          manager: manager,
        );
        expect(asked, [
          {'home'},
        ]);
        expect(
          responses().single,
          'Time logged past 7 days (2026-11-02 through 2026-11-08): 3h in '
          'total, by category, largest first (Home named; every other '
          'category is "Other categories", never to be broken down):\n'
          '- Other categories: 2h\n'
          '- Home: 1h\n'
          'Tasks the time went to in Home (1), largest first:\n'
          '- task:roses | Prune the roses | OPEN | 1h',
        );

        await s.processToolCalls(
          toolCalls: [
            _call('reply_to_user', {
              'message': 'In Home:\n- Prune the roses',
            }, id: 'call-2'),
          ],
          manager: manager,
        );
        expect(
          s.replyToUser,
          'In Home:\n- [Prune the roses](lotti://task/roses)',
        );
      },
    );

    test(
      'refuses a category it may not name, the same as list_due_tasks',
      () async {
        var calls = 0;
        final s = strategy(
          timeSummarizer: (query) async {
            calls++;
            return logged(query.period);
          },
        );
        await s.processToolCalls(
          toolCalls: [
            _call('summarize_logged_time', {
              'period': 'today',
              'categoryIds': ['nope'],
            }),
          ],
          manager: manager,
        );
        expect(calls, 0);
        expect(
          responses().single,
          contains('nope is not a category id listed under ## Categories'),
        );
      },
    );

    test('a period with nothing logged gets no chart', () async {
      final s = strategy(
        timeSummarizer: (query) async =>
            logged(query.period, byCategory: const []),
      );
      expect(s.loggedTimeChart, isNull);
      await s.processToolCalls(
        toolCalls: [
          _call('summarize_logged_time', {'period': 'yesterday'}),
        ],
        manager: manager,
      );
      expect(responses().single, startsWith('None: no time logged'));
      expect(s.loggedTimeChart, isNull);
    });

    test('sums the past N days or the first through the last day asked, '
        'and refuses a window that runs backwards, is too long or is '
        'given twice', () async {
      Future<List<(FrontTimePeriod?, InsightsRange?)>> asked(
        Map<String, dynamic> args,
      ) async {
        final queries = <(FrontTimePeriod?, InsightsRange?)>[];
        await strategy(
          timeSummarizer: (query) async {
            queries.add((query.period, query.range));
            return logged(query.period);
          },
        ).processToolCalls(
          toolCalls: [_call('summarize_logged_time', args)],
          manager: manager,
        );
        return queries;
      }

      // The strategy's day is 2026-11-02.
      final today = epochDay(DateTime(2026, 11, 2));
      expect((await asked({'pastDays': 14})).single, (
        null,
        InsightsRange(startDay: today - 13, endDayExclusive: today + 1),
      ));
      expect(
        (await asked({'from': '2026-06-01', 'through': '2026-06-05'})).single,
        (
          null,
          InsightsRange(
            startDay: epochDay(DateTime(2026, 6)),
            endDayExclusive: epochDay(DateTime(2026, 6, 6)),
          ),
        ),
      );
      // A whole leap year is the longest window.
      expect(
        (await asked({
          'from': '2024-01-01',
          'through': '2024-12-31',
        })).single.$2?.dayCount,
        frontLoggedTimeMaxDays,
      );

      for (final args in <Map<String, dynamic>>[
        {'from': '2026-06-05', 'through': '2026-06-01'},
        {'from': '2024-01-01', 'through': '2025-01-01'},
        {'pastDays': frontLoggedTimeMaxDays + 1},
        {'pastDays': 0},
        {'from': '2026-02-29', 'through': '2026-03-01'},
        {'period': 'today', 'pastDays': 14},
        {'from': '2026-06-01'},
      ]) {
        expect(await asked(args), isEmpty, reason: '$args');
        expect(
          responses().last,
          contains('summarize_logged_time needs exactly one of'),
          reason: '$args',
        );
      }
    });

    test('refuses a missing or unknown period and a second summary, and '
        'reports an unwired summarizer', () async {
      final asked = <FrontTimePeriod?>[];
      final s = strategy(
        timeSummarizer: (query) async {
          asked.add(query.period);
          return logged(query.period);
        },
      );
      await s.processToolCalls(
        toolCalls: [
          _call('summarize_logged_time', const <String, dynamic>{}),
          _call('summarize_logged_time', {'period': 'last_week'}, id: 'call-2'),
          _call('summarize_logged_time', {
            'period': 'past_7_days',
          }, id: 'call-3'),
          _call('summarize_logged_time', {'period': 'today'}, id: 'call-4'),
        ],
        manager: manager,
      );
      expect(asked, [FrontTimePeriod.past7Days]);
      expect(responses(), [
        contains(
          'needs exactly one of: period (one of today, yesterday, '
          'this_week, past_7_days, past_30_days, this_month, last_month), '
          'pastDays (1 to $frontLoggedTimeMaxDays)',
        ),
        contains('needs exactly one of'),
        startsWith('Time logged past 7 days'),
        frontTimeSummaryExhaustedAnswer,
      ]);
      expect(s.lookupCalls, 1);

      await strategy().processToolCalls(
        toolCalls: [
          _call('summarize_logged_time', {'period': 'today'}),
        ],
        manager: manager,
      );
      expect(responses().last, contains('Logged time is unavailable'));
    });
  });

  group('list_closed_tasks', () {
    const roses = FrontIndexRow(
      kind: FrontDestinationKind.task,
      id: 'roses',
      title: 'Prune the roses',
      status: 'DONE',
      categoryId: 'home',
    );
    const shed = FrontIndexRow(
      kind: FrontDestinationKind.task,
      id: 'shed',
      title: 'Paint the shed',
      status: 'REJECTED',
      categoryId: 'home',
    );
    FrontClosedTasks closed(FrontPullRequestQuery window) => FrontClosedTasks(
      period: window.period,
      from: DateTime(2026, 11),
      through: DateTime(2026, 11),
      tasks: [
        (
          row: roses,
          closed: TaskStatus.done(
            id: 's-roses',
            createdAt: DateTime(2026, 11, 1, 10),
            utcOffset: 0,
          ),
        ),
        (
          row: shed,
          closed: TaskStatus.rejected(
            id: 's-shed',
            createdAt: DateTime(2026, 11, 1, 11),
            utcOffset: 0,
          ),
        ),
      ],
      categoryNames: const {'home': 'Home'},
      narrowedTo: const ['Home'],
    );

    test(
      'answers with what was completed and rejected in the period and '
      'category asked; she names them by title and they are linked',
      () async {
        final asked = <(FrontPullRequestQuery, Set<String>)>[];
        final s = strategy(
          routingIndex: FrontRoutingIndex(
            categories: const [FrontCategory(id: 'home', name: 'Home')],
          ),
          closedLister: (window, categoryIds) async {
            asked.add((window, categoryIds));
            return closed(window);
          },
        );
        await s.processToolCalls(
          toolCalls: [
            _call('list_closed_tasks', {
              'period': 'yesterday',
              'categoryIds': ['home'],
            }),
          ],
          manager: manager,
        );
        expect(asked.single.$1, (
          period: FrontTimePeriod.yesterday,
          range: null,
        ));
        expect(asked.single.$2, {'home'});
        expect(
          responses().single,
          'Tasks completed or rejected yesterday (2026-11-01) in Home: 2 '
          '(1 completed, 1 rejected), oldest first:\n'
          '- task:roses | Prune the roses | completed 2026-11-01 | Home\n'
          '- task:shed | Paint the shed | rejected 2026-11-01 | Home',
        );
        // Every task it found rides her reply as a card, each saying how
        // it closed.
        expect(s.closedTaskCards, [
          FrontClosedTaskCard(
            id: 'roses',
            title: 'Prune the roses',
            closedAt: DateTime(2026, 11, 1, 10),
            categoryId: 'home',
          ),
          FrontClosedTaskCard(
            id: 'shed',
            title: 'Paint the shed',
            closedAt: DateTime(2026, 11, 1, 11),
            rejected: true,
            categoryId: 'home',
          ),
        ]);
        expect(s.lookupCalls, 1);
        expect(s.hasTerminalOutput, isFalse);

        final action = await s.processToolCalls(
          toolCalls: [
            _call('reply_to_user', {
              'message':
                  'Yesterday you completed:\n- Prune the roses\n'
                  'and rejected:\n- Paint the shed',
            }, id: 'call-2'),
          ],
          manager: manager,
        );
        expect(action, ConversationAction.complete);
        expect(
          s.replyToUser,
          'Yesterday you completed:\n- [Prune the roses](lotti://task/roses)\n'
          'and rejected:\n- [Paint the shed](lotti://task/shed)',
        );
        expect(s.dispatch, isNull);
      },
    );

    test('a weekend is read as the days the call spelled out', () async {
      final asked = <FrontPullRequestQuery>[];
      final s = strategy(
        closedLister: (window, _) async {
          asked.add(window);
          return closed(window);
        },
      );
      await s.processToolCalls(
        toolCalls: [
          _call('list_closed_tasks', {
            'from': '2026-10-31',
            'through': '2026-11-01',
          }),
        ],
        manager: manager,
      );
      expect(asked.single, (
        period: null,
        range: InsightsRange(
          startDay: epochDay(DateTime(2026, 10, 31)),
          endDayExclusive: epochDay(DateTime(2026, 11, 2)),
        ),
      ));
    });

    test('a list that found nothing leaves her reply without cards', () async {
      final s = strategy(
        closedLister: (window, _) async => FrontClosedTasks(
          period: window.period,
          from: DateTime(2026, 11, 2),
          through: DateTime(2026, 11, 2),
          tasks: const [],
        ),
      );
      await s.processToolCalls(
        toolCalls: [
          _call('list_closed_tasks', {'period': 'today'}),
        ],
        manager: manager,
      );
      expect(responses().single, startsWith('None: no task completed'));
      expect(s.closedTaskCards, isNull);
    });

    test('refuses a missing or unknown period, a category it may not name '
        'and a second list, and reports an unwired lister', () async {
      final asked = <FrontTimePeriod?>[];
      final s = strategy(
        closedLister: (window, _) async {
          asked.add(window.period);
          return closed(window);
        },
      );
      await s.processToolCalls(
        toolCalls: [
          _call('list_closed_tasks', const <String, dynamic>{}),
          _call('list_closed_tasks', {'period': 'last_week'}, id: 'call-2'),
          _call('list_closed_tasks', {
            'period': 'today',
            'categoryIds': ['nope'],
          }, id: 'call-3'),
          _call('list_closed_tasks', {'period': 'past_7_days'}, id: 'call-4'),
          _call('list_closed_tasks', {'period': 'today'}, id: 'call-5'),
        ],
        manager: manager,
      );
      expect(asked, [FrontTimePeriod.past7Days]);
      expect(responses(), [
        contains(
          'list_closed_tasks needs exactly one of: period (one of today, '
          'yesterday, this_week, past_7_days, past_30_days, this_month, '
          'last_month), pastDays',
        ),
        contains('needs exactly one of'),
        contains('nope is not a category id listed under ## Categories'),
        startsWith('Tasks completed or rejected past 7 days'),
        frontClosedListExhaustedAnswer,
      ]);
      expect(s.lookupCalls, 1);

      await strategy().processToolCalls(
        toolCalls: [
          _call('list_closed_tasks', {'period': 'today'}),
        ],
        manager: manager,
      );
      expect(responses().last, contains('Closed tasks are unavailable'));
    });
  });

  group('summarize_pull_requests', () {
    // The turn's day: Monday 2026-11-02.
    final today = epochDay(DateTime(2026, 11, 2));

    FrontPullRequests summary(
      FrontPullRequestQuery query, {
      bool opened = true,
    }) => FrontPullRequests(
      period: query.period,
      chart: FrontPullRequestChart(
        range:
            query.range ??
            InsightsRange(startDay: today - 6, endDayExclusive: today + 1),
        categoryIds: const {},
      ),
      pullRequests: [
        FrontPullRequest(
          key: 'penguin/colony#7',
          title: 'Fish ledger',
          createdAt: opened ? DateTime(2026, 11, 1, 10) : DateTime(2026, 9),
          mergedAt: DateTime(2026, 11, 2, 8),
          additions: 120,
          deletions: 30,
        ),
      ],
    );

    test('reads the past N days and keeps the chart for her reply when '
        'pull requests were opened', () async {
      final asked = <FrontPullRequestQuery>[];
      final s = strategy(
        pullRequestSummarizer: (query) async {
          asked.add(query);
          return summary(query);
        },
      );
      await s.processToolCalls(
        toolCalls: [
          _call('summarize_pull_requests', {'pastDays': 14}),
        ],
        manager: manager,
      );

      final range = InsightsRange(
        startDay: today - 13,
        endDayExclusive: today + 1,
      );
      expect(asked.single, (period: null, range: range));
      final answer = responses().single;
      expect(answer, startsWith('Pull requests 2026-10-20 '));
      expect(answer, contains('- opened: 1, +120 -30 lines'));
      expect(s.pullRequestChart?.range, range);
      expect(s.lookupCalls, 1);
      expect(s.hasTerminalOutput, isFalse);
    });

    test('keeps no chart when nothing was opened in the days', () async {
      final s = strategy(
        pullRequestSummarizer: (query) async => summary(query, opened: false),
      );
      await s.processToolCalls(
        toolCalls: [
          _call('summarize_pull_requests', {'period': 'past_7_days'}),
        ],
        manager: manager,
      );
      expect(responses().single, contains('- merged: 1, +120 -30 lines'));
      expect(s.pullRequestChart, isNull);
    });

    test('refuses an unreadable window and a second summary, and reports an '
        'unwired summarizer', () async {
      final asked = <FrontPullRequestQuery>[];
      final s = strategy(
        pullRequestSummarizer: (query) async {
          asked.add(query);
          return summary(query);
        },
      );
      await s.processToolCalls(
        toolCalls: [
          _call('summarize_pull_requests', const <String, dynamic>{}),
          _call('summarize_pull_requests', {
            'period': 'today',
            'pastDays': 3,
          }, id: 'call-2'),
          _call('summarize_pull_requests', {
            'from': '2026-10-31',
            'through': '2026-11-01',
          }, id: 'call-3'),
          _call('summarize_pull_requests', {'period': 'today'}, id: 'call-4'),
        ],
        manager: manager,
      );
      expect(asked.single.range?.startDay, epochDay(DateTime(2026, 10, 31)));
      expect(responses(), [
        contains(
          'summarize_pull_requests needs exactly one of: period (one of '
          'today, yesterday, this_week, past_7_days, past_30_days, '
          'this_month, last_month), pastDays (1 to 31), or from and through',
        ),
        contains('needs exactly one of'),
        startsWith('Pull requests 2026-10-31 through 2026-11-01'),
        frontPullRequestSummaryExhaustedAnswer,
      ]);
      expect(s.lookupCalls, 1);

      await strategy().processToolCalls(
        toolCalls: [
          _call('summarize_pull_requests', {'period': 'today'}),
        ],
        manager: manager,
      );
      expect(responses().last, contains('Pull requests are unavailable'));
    });
  });

  group('ask_user', () {
    test('her question names a recited task as a link', () async {
      final s = strategy();
      await s.processToolCalls(
        toolCalls: [
          _call('ask_user', {'question': 'Is it task:garden you mean?'}),
        ],
        manager: manager,
      );
      expect(
        s.askUser!.question,
        'Is it [Garden](lotti://task/garden) you mean?',
      );
    });

    test('a question with listed options ends the turn', () async {
      final s = strategy();
      final action = await s.processToolCalls(
        toolCalls: [
          _call('ask_user', {
            'question': 'Which one?',
            'options': [
              {'kind': 'task', 'id': 'garden', 'label': 'Garden'},
              {'kind': 'person', 'id': 'pip', 'label': 'Pip'},
            ],
          }),
        ],
        manager: manager,
      );
      expect(action, ConversationAction.complete);
      expect(s.askUser!.question, 'Which one?');
      expect(s.askUser!.options.map((o) => o.id), ['garden', 'pip']);
    });

    test('may offer a closed task the conversation named, as no '
        'destination it could route to', () async {
      final s = strategy(
        conversationTasks: const [
          FrontIndexRow(
            kind: FrontDestinationKind.task,
            id: 'roses',
            title: 'Prune the roses',
            status: 'DONE',
          ),
        ],
      );
      await s.processToolCalls(
        toolCalls: [
          _call('ask_user', {
            'question': 'A follow-up to which?',
            'options': [
              {'kind': 'task', 'id': 'roses', 'label': 'Prune the roses'},
              {'kind': 'task', 'id': 'garden', 'label': 'Garden'},
            ],
          }),
        ],
        manager: manager,
      );
      expect(s.askUser!.options.map((o) => o.id), ['roses', 'garden']);
    });

    test('a second question in one turn is refused', () async {
      final s = strategy();
      await s.processToolCalls(
        toolCalls: [
          _call('ask_user', {'question': 'Which one?'}),
          _call('ask_user', {'question': 'Or this?'}, id: 'call-2'),
        ],
        manager: manager,
      );
      expect(responses().last, contains('at most once per turn'));
      expect(s.askUser!.question, 'Which one?');
    });

    test(
      'an option must be a listed owner; more than three is refused',
      () async {
        await strategy().processToolCalls(
          toolCalls: [
            _call('ask_user', {
              'question': 'Which?',
              'options': [
                {'kind': 'task', 'id': 'nope', 'label': 'Nope'},
              ],
            }),
            _call('ask_user', {
              'question': 'Which?',
              'options': [
                {'kind': 'day', 'id': 'x', 'label': 'Today'},
              ],
            }, id: 'call-2'),
            _call('ask_user', {
              'question': 'Which?',
              'options': [
                for (var i = 0; i < 4; i++)
                  {'kind': 'task', 'id': 'garden', 'label': 'G'},
              ],
            }, id: 'call-3'),
            _call('ask_user', {'question': ''}, id: 'call-4'),
          ],
          manager: manager,
        );
        expect(responses(), [
          contains('task:nope is not in <routing_index>'),
          contains('needs a kind'),
          contains('at most 3 options'),
          contains('needs a question'),
        ]);
      },
    );

    test('ask_user and dispatch in one turn are mutually exclusive', () async {
      final s = strategy();
      await s.processToolCalls(
        toolCalls: [
          _call('dispatch', fullDispatch()),
          _call('ask_user', {'question': 'Sure?'}, id: 'call-2'),
        ],
        manager: manager,
      );
      expect(responses().last, contains('already ended with dispatch'));
      expect(s.askUser, isNull);

      final t = strategy();
      await t.processToolCalls(
        toolCalls: [
          _call('ask_user', {'question': 'Sure?'}),
          _call('dispatch', fullDispatch(), id: 'call-2'),
        ],
        manager: manager,
      );
      expect(responses().last, contains('already ended with ask_user'));
      expect(t.dispatch, isNull);
    });
  });

  group('terminal calls are exclusive', () {
    test('a reply beside a rejected dispatch is dropped so the turn stays '
        'open for the repair', () async {
      final s = strategy();
      final action = await s.processToolCalls(
        toolCalls: [
          _call('reply_to_user', {'message': 'Filed under Garden.'}),
          _call('dispatch', {
            'segments': [segment(start: 0, end: 13, id: 'nope')],
          }, id: 'call-2'),
        ],
        manager: manager,
      );

      expect(action, ConversationAction.continueConversation);
      expect(s.replyToUser, isNull);
      expect(s.hasTerminalOutput, isFalse);

      // The repair round may still end with a valid reply.
      final repaired = await s.processToolCalls(
        toolCalls: [
          _call('reply_to_user', {'message': 'Nothing fits.'}),
        ],
        manager: manager,
      );
      expect(repaired, ConversationAction.complete);
      expect(s.replyToUser, 'Nothing fits.');
    });

    test('a reply beside a rejected dispatch survives when a question was '
        'accepted in the same batch', () async {
      final s = strategy();
      await s.processToolCalls(
        toolCalls: [
          _call('ask_user', {'question': 'Which?'}),
          _call('dispatch', {
            'segments': [segment(start: 0, end: 13, id: 'nope')],
          }, id: 'call-2'),
        ],
        manager: manager,
      );
      expect(s.askUser, isNotNull);
      expect(s.hasTerminalOutput, isTrue);
    });

    test(
      'ask_user and reply_to_user refuse each other in either order',
      () async {
        final s = strategy();
        await s.processToolCalls(
          toolCalls: [
            _call('ask_user', {'question': 'Which?'}),
            _call('reply_to_user', {'message': 'Hi'}, id: 'call-2'),
          ],
          manager: manager,
        );
        expect(responses().last, contains('already ended with ask_user'));
        expect(s.replyToUser, isNull);

        final t = strategy();
        await t.processToolCalls(
          toolCalls: [
            _call('reply_to_user', {'message': 'Hi'}),
            _call('ask_user', {'question': 'Which?'}, id: 'call-2'),
          ],
          manager: manager,
        );
        expect(responses().last, contains('already ended with reply_to_user'));
        expect(t.askUser, isNull);
        expect(t.replyToUser, 'Hi');
      },
    );
  });

  group('reply_to_user', () {
    test('one reply may accompany a dispatch; a second is refused', () async {
      final s = strategy();
      final action = await s.processToolCalls(
        toolCalls: [
          _call('reply_to_user', {'message': ' Filed both. '}),
          _call('dispatch', fullDispatch(), id: 'call-2'),
          _call('reply_to_user', {'message': 'Again'}, id: 'call-3'),
          _call('reply_to_user', {'message': ''}, id: 'call-4'),
        ],
        manager: manager,
      );
      expect(action, ConversationAction.complete);
      expect(s.replyToUser, 'Filed both.');
      expect(s.dispatch, isNotNull);
      final answers = responses();
      expect(answers[2], contains('at most once per turn'));
      expect(answers[3], contains('non-empty message'));
    });
  });

  test(
    'every call is recorded in the message log, failures included',
    () async {
      await strategy().processToolCalls(
        toolCalls: [
          _call('read_tldr', {'ids': const <String>[]}),
        ],
        manager: manager,
      );
      final kinds = upserts.whereType<AgentMessageEntity>().map((m) => m.kind);
      expect(kinds, [
        AgentMessageKind.thought,
        AgentMessageKind.action,
        AgentMessageKind.toolResult,
      ]);
    },
  );

  test('no continuation prompt: the workflow owns the repair', () {
    expect(strategy().getContinuationPrompt(manager), isNull);
  });
}
