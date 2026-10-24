import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_strategy.dart';
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

  FrontAgentStrategy strategy({FrontCorpusMatcher? matcher}) =>
      FrontAgentStrategy(
        syncService: syncService,
        domainLogger: domainLogger,
        agentId: 'front_agent',
        threadId: 'thread-1',
        runKey: 'run-1',
        input: input,
        index: index,
        corpusMatcher: matcher,
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

  group('ask_user', () {
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
