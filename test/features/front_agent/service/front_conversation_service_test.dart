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

  test('nothing said yet is no conversation', () async {
    final index = await service.load();

    expect(index.conversations, isEmpty);
    expect(index.latest, isNull);
  });
}
