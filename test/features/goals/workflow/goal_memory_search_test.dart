import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/memory/memory_search.dart';
import 'package:lotti/features/agents/model/observation_record.dart';
import 'package:lotti/features/agents/workflow/agent_observations.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';
import 'package:lotti/features/goals/model/goal_checkin_source.dart';
import 'package:lotti/features/goals/service/goal_chat_history_service.dart';
import 'package:lotti/features/goals/workflow/goal_memory_search.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/agent_test_device.dart';

void main() {
  const agentId = 'goal-agent-1';

  setUpAll(registerAllFallbackValues);

  late AgentTestDevice device;
  late MockDomainLogger logger;
  late List<GoalCheckInSource> checkIns;
  Error? checkInFailure;

  GoalMemorySearch searcher() => GoalMemorySearch(
    syncService: device.sync,
    chatHistory: GoalChatHistoryService(device.repository),
    logger: logger,
    checkInSourceReader: (id) async {
      expect(id, agentId);
      if (checkInFailure case final failure?) throw failure;
      return checkIns;
    },
  );

  /// One visible chat turn — the user's, or the agent's reply — with words.
  Future<void> chat(
    String id,
    String text, {
    required DateTime at,
    bool fromUser = true,
  }) async {
    await device.sync.upsertEntity(
      AgentDomainEntity.agentMessagePayload(
        id: '$id:payload',
        agentId: agentId,
        createdAt: at,
        vectorClock: null,
        content: {'text': text},
      ),
    );
    await device.sync.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: id,
        agentId: agentId,
        threadId: 'thread',
        kind: fromUser ? AgentMessageKind.user : AgentMessageKind.action,
        createdAt: at,
        vectorClock: null,
        contentEntryId: '$id:payload',
        metadata: fromUser
            ? const AgentMessageMetadata()
            : const AgentMessageMetadata(
                runKey: 'run-1',
                toolName: AgentConversationToolNames.replyToUser,
              ),
      ),
    );
  }

  setUp(() async {
    device = AgentTestDevice('host-a', background: false);
    logger = MockDomainLogger();
    checkInFailure = null;
    checkIns = [
      GoalCheckInSource(
        entryId: 'checkin-spring',
        recordedAt: DateTime(2026, 4, 2, 21),
        text:
            'Walked down to the ice shelf with the colony. The fog made the '
            'walk calm.',
      ),
      GoalCheckInSource(
        entryId: 'checkin-summer',
        recordedAt: DateTime(2026, 7, 9, 21),
        text: 'Skipped the walk; the colony was restless all day.',
      ),
    ];
    await chat(
      'chat-user',
      'Can we keep the evening walk even when the colony is restless?',
      at: DateTime(2026, 7, 10, 8),
    );
    await chat(
      'chat-reply',
      'Yes — a short walk counts. Try the shelf path.',
      at: DateTime(2026, 7, 10, 8, 1),
      fromUser: false,
    );
    await persistAgentObservations(
      device.sync,
      agentId: agentId,
      threadId: 'thread',
      runKey: 'run-0',
      now: DateTime(2026, 5),
      observations: const [
        ObservationRecord(text: 'Fog days are the calm walk days.'),
      ],
    );
  });

  tearDown(() => device.db.close());

  test(
    "recalls a check-in in the user's own words, by every keyword",
    () async {
      final recall = await searcher().search(agentId, {
        'query': 'ice shelf fog',
      });

      expect(recall.ok, isTrue);
      expect(
        recall.text,
        contains('Found 1 memory match(es) for "ice shelf fog"'),
      );
      expect(recall.text, contains('(checkIn) (id: checkin-spring)'));
      expect(recall.text, contains('The fog made the walk calm.'));
    },
  );

  test("spans check-ins, both sides of the chat and the agent's own "
      'observations, newest first', () async {
    final recall = await searcher().search(agentId, {'query': 'walk'});

    final ids = RegExp(
      r'\(id: ([^)]+)\)',
    ).allMatches(recall.text).map((m) => m.group(1)).toList();
    expect(ids, [
      'chat-reply',
      'chat-user',
      'checkin-summer',
      isNotNull, // the observation's message id
      'checkin-spring',
    ]);
    expect(recall.text, contains('(agentReply)'));
    expect(recall.text, contains('(userMessage)'));
    expect(recall.text, contains('(observation)'));
  });

  test('pulls an entry up by id', () async {
    final recall = await searcher().search(agentId, {
      'ids': ['checkin-summer'],
    });

    expect(recall.text, contains('for ids checkin-summer'));
    expect(recall.text, contains('restless all day'));
    expect(recall.text, isNot(contains('ice shelf')));
  });

  test('a long check-in is cut to its share; the whole stays in the '
      'journal', () async {
    checkIns = [
      GoalCheckInSource(
        entryId: 'checkin-long',
        recordedAt: DateTime(2026, 8),
        text: 'krill ${List.filled(800, 'colony').join(' ')}',
      ),
    ];

    final recall = await searcher().search(agentId, {'query': 'krill'});

    final line = recall.text
        .split('\n')
        .firstWhere((l) => l.contains('checkin-long'));
    expect(line, endsWith('…'));
    expect(line.split(' ').length, lessThan(300));
  });

  test('a check-in cut in a keyword hit reads whole when pulled up by id — '
      'up to the recall budget', () async {
    final long = 'krill ${List.filled(400, 'colony').join(' ')}';
    checkIns = [
      GoalCheckInSource(
        entryId: 'checkin-long',
        recordedAt: DateTime(2026, 8),
        text: long,
      ),
    ];

    final byKeyword = await searcher().search(agentId, {'query': 'krill'});
    expect(byKeyword.text, isNot(contains(long)));

    final byId = await searcher().search(agentId, {
      'ids': ['checkin-long'],
    });
    expect(byId.text, contains(long));
  });

  test('a huge entry pulled up by id still keeps the whole response — text, '
      'details and links — within the recall budget', () async {
    final links = [for (var i = 0; i < 12; i++) '[[relates:note-$i]]'];
    checkIns = [
      GoalCheckInSource(
        entryId: 'checkin-huge',
        recordedAt: DateTime(2026, 8),
        text: '${links.join(' ')} ${List.filled(3000, 'colony').join(' ')}',
      ),
    ];

    final byId = await searcher().search(agentId, {
      'ids': ['checkin-huge'],
    });

    expect(byId.text, contains('(id: checkin-huge)'));
    expect(byId.text, contains('links: '));
    expect(
      TextChunker.estimateTokens(byId.text),
      lessThanOrEqualTo(goalMemoryResultTokenBudget),
    );
  });

  test('asks for keywords or ids when given neither', () async {
    final recall = await searcher().search(agentId, {});

    expect(recall.ok, isFalse);
    expect(recall.text, memorySearchMissingTermsError);
  });

  test(
    'a source that cannot be read costs only itself, and is logged',
    () async {
      checkInFailure = StateError('journal gone');

      final recall = await searcher().search(agentId, {'query': 'walk'});

      expect(recall.ok, isTrue);
      expect(recall.text, isNot(contains('checkIn')));
      expect(recall.text, contains('(userMessage)'));
      verify(
        () => logger.error(
          LogDomain.agentWorkflow,
          any(that: isA<StateError>()),
          stackTrace: any(named: 'stackTrace', that: isNotNull),
          subDomain: 'GoalMemorySearch',
          message: 'goal memory search could not read its check-ins',
        ),
      ).called(1);
    },
  );

  test('a search that fails answers so, and is logged', () async {
    final sync = MockAgentSyncService();
    when(() => sync.repository).thenThrow(StateError('agent db gone'));
    final broken = GoalMemorySearch(
      syncService: sync,
      chatHistory: GoalChatHistoryService(device.repository),
      logger: logger,
    );

    final recall = await broken.search(agentId, {'query': 'walk'});

    expect(recall.ok, isFalse);
    expect(recall.text, memorySearchFailedError);
    verify(
      () => logger.error(
        LogDomain.agentWorkflow,
        any(that: isA<StateError>()),
        stackTrace: any(named: 'stackTrace', that: isNotNull),
        subDomain: 'GoalMemorySearch',
        message: 'goal memory search failed',
      ),
    ).called(1);
  });

  test('forAgent binds the searcher to one goal', () async {
    final recall = await searcher().forAgent(agentId)({'query': 'shelf path'});

    expect(recall.text, contains('(id: chat-reply)'));
  });
}
