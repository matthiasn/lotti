import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/service/front_conversation_service.dart';

import '../../../helpers/fallbacks.dart';
import '../../agents/agent_test_device.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late AgentTestDevice device;
  late FrontConversationService service;
  final start = DateTime(2026, 10, 31, 9);

  setUp(() {
    device = AgentTestDevice('a', background: false);
    service = FrontConversationService(
      repository: device.repository,
      syncService: device.sync,
    );
  });
  tearDown(() => device.close());

  /// Writes a user turn as the chat service does: its payload, naming
  /// [conversation] unless null, then the message.
  Future<void> turn(
    String id,
    String text, {
    String? conversation,
    int minute = 0,
  }) async {
    final at = start.add(Duration(minutes: minute));
    await device.sync.upsertEntity(
      AgentDomainEntity.agentMessagePayload(
        id: '$id-payload',
        agentId: frontAgentId,
        createdAt: at,
        vectorClock: null,
        content: {
          'text': text,
          'conversationId': ?conversation,
        },
      ),
    );
    await device.sync.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: id,
        agentId: frontAgentId,
        threadId: id,
        kind: AgentMessageKind.user,
        createdAt: at,
        vectorClock: null,
        contentEntryId: '$id-payload',
        metadata: const AgentMessageMetadata(),
      ),
    );
  }

  /// Writes her answer to [turnId] as the front run does: a payload under
  /// [key], then the action row naming the turn as its operation.
  Future<void> answer(
    String id,
    String turnId,
    String text, {
    String tool = 'reply_to_user',
    String key = 'text',
    int minute = 0,
  }) async {
    final at = start.add(Duration(minutes: minute));
    await device.sync.upsertEntity(
      AgentDomainEntity.agentMessagePayload(
        id: '$id-payload',
        agentId: frontAgentId,
        createdAt: at,
        vectorClock: null,
        content: {key: text},
      ),
    );
    await device.sync.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: id,
        agentId: frontAgentId,
        threadId: 'run-$id',
        kind: AgentMessageKind.action,
        createdAt: at,
        vectorClock: null,
        contentEntryId: '$id-payload',
        metadata: AgentMessageMetadata(
          runKey: 'run-$id',
          toolName: tool,
          operationId: turnId,
        ),
      ),
    );
  }

  List<(String, String, bool)> summary(FrontConversationIndex index) => [
    for (final c in index.conversations) (c.id, c.title, c.archived),
  ];

  test('turns from before conversations form one fixed conversation; each '
      'other is titled by its first question, newest first', () async {
    await turn('u1', 'How is the garden?\nAnd the pond?');
    await turn('u2', 'And the pond?', minute: 1);
    await turn('u3', 'Plan the census', conversation: 'c-1', minute: 2);
    await turn('u4', 'Count the hatchlings', conversation: 'c-2', minute: 3);
    await turn('u5', 'Add the north cave', conversation: 'c-1', minute: 4);

    final index = await service.load();

    expect(summary(index), [
      ('c-1', 'Plan the census', false),
      ('c-2', 'Count the hatchlings', false),
      (earlierConversationId, 'How is the garden?', false),
    ]);
    expect(
      index.byId('c-1')!.lastActivity,
      start.add(const Duration(minutes: 4)),
    );
    expect(index.latest!.id, 'c-1');
    expect(index.deletedIds, isEmpty);
  });

  test("a turn synced in UTC is dated in the user's own time, so the list "
      'sorts it by their calendar', () async {
    await device.sync.upsertEntity(
      AgentDomainEntity.agentMessagePayload(
        id: 'utc-payload',
        agentId: frontAgentId,
        createdAt: DateTime.utc(2026, 10, 31, 23, 30),
        vectorClock: null,
        content: const {'text': 'Late count', 'conversationId': 'c-utc'},
      ),
    );
    await device.sync.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: 'utc',
        agentId: frontAgentId,
        threadId: 'utc',
        kind: AgentMessageKind.user,
        createdAt: DateTime.utc(2026, 10, 31, 23, 30),
        vectorClock: null,
        contentEntryId: 'utc-payload',
        metadata: const AgentMessageMetadata(),
      ),
    );

    final at = (await service.load()).byId('c-utc')!.lastActivity;

    expect(at.isUtc, isFalse);
    expect(at, DateTime.utc(2026, 10, 31, 23, 30).toLocal());
  });

  test('renaming, archiving and deleting fold in the order they were '
      'made; a deleted conversation leaves the list', () async {
    await turn('u1', 'Plan the census', conversation: 'c-1');
    await turn('u2', 'Count the hatchlings', conversation: 'c-2', minute: 1);
    await turn('u3', 'Feeding rota', conversation: 'c-3', minute: 2);

    await withClock(Clock.fixed(start), () async {
      await service.rename('c-1', '  Census  ');
      await service.rename('c-1', 'Colony census');
      await service.archive('c-3', archived: true);
      await service.archive('c-3', archived: false);
      await service.archive('c-3', archived: true);
      await service.delete('c-2');
    });

    final index = await service.load();

    expect(summary(index), [
      ('c-3', 'Feeding rota', true),
      ('c-1', 'Colony census', false),
    ]);
    expect(index.deletedIds, {'c-2'});
    expect(index.latest!.id, 'c-1', reason: 'an archived one is not opened');
  });

  test('another device derives the same conversations from the synced '
      'turns and events', () async {
    await turn('u1', 'How is the garden?');
    await turn('u2', 'Plan the census', conversation: 'c-1', minute: 1);
    await service.rename(earlierConversationId, 'Before chats');
    await service.archive('c-1', archived: true);

    final other = AgentTestDevice('b', background: false);
    addTearDown(other.close);
    for (final entity in device.sentEntities) {
      await other.receiveEntity(entity);
    }
    final remote = await FrontConversationService(
      repository: other.repository,
      syncService: other.sync,
    ).load();

    expect(summary(remote), summary(await service.load()));
    expect(summary(remote), [
      ('c-1', 'Plan the census', true),
      (earlierConversationId, 'Before chats', false),
    ]);
  });

  test(
    'a title is the first line, bounded; a blank rename is refused',
    () async {
      await turn('u1', 'penguin ' * 40, conversation: 'c-1');

      final title = (await service.load()).byId('c-1')!.title;

      expect(title.length, FrontConversationService.maxTitleLength);
      expect(title, endsWith('…'));
      expect(() => service.rename('c-1', '   '), throwsArgumentError);
    },
  );

  test('her headless journal questions and lifecycle events without turns '
      'are not conversations', () async {
    await turn('u1', 'Plan the census', conversation: 'c-1');
    // What the door walker writes for a journal question.
    await device.sync.upsertEntity(
      AgentDomainEntity.queryChatEvent(
        id: 'q-1',
        agentId: frontAgentId,
        chatId: 'u1',
        data: const QueryChatEventData.question(text: 'Plan the census'),
        createdAt: start,
        vectorClock: null,
      ),
    );
    await service.rename('c-unsynced', 'Not here yet');

    expect(summary(await service.load()), [
      ('c-1', 'Plan the census', false),
    ]);
  });

  test("a conversation's preview is the first line of her latest turn in "
      'it — a reply or the question she asked back', () async {
    await turn('u1', 'Plan the census', conversation: 'c-1');
    await answer(
      'r1',
      'u1',
      'Saturday works.\nLow tide is at 7:40.',
      minute: 1,
    );
    await turn('u2', 'Who counts?', conversation: 'c-1', minute: 2);
    await answer(
      'a2',
      'u2',
      'Pip or Juno?',
      tool: 'ask_user',
      key: 'question',
      minute: 3,
    );
    await turn('u3', 'Count the hatchlings', conversation: 'c-2', minute: 4);
    await answer('r3', 'u3', 'Forty-two.', minute: 5);
    await turn('u4', 'Feeding rota', conversation: 'c-3', minute: 6);

    final index = await service.load();

    expect(index.byId('c-1')!.preview, 'Pip or Juno?');
    expect(index.byId('c-2')!.preview, 'Forty-two.');
    expect(index.byId('c-3')!.preview, isNull, reason: 'not answered yet');
  });

  test('nothing said yet is no conversation', () async {
    final index = await service.load();

    expect(index.conversations, isEmpty);
    expect(index.latest, isNull);
  });
}
