import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/service/front_chat_thread_builder.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  late MockAgentRepository repository;
  late FrontChatThreadBuilder builder;
  late Map<String, AgentDomainEntity> entities;
  late Map<String, List<AgentMessageEntity>> threads;

  setUp(() {
    repository = MockAgentRepository();
    builder = FrontChatThreadBuilder(repository: repository);
    entities = {};
    threads = {frontAgentId: []};
    when(() => repository.getAgentMessages(any())).thenAnswer(
      (invocation) async =>
          threads[invocation.positionalArguments.first as String] ?? [],
    );
    when(() => repository.getEntity(any())).thenAnswer(
      (invocation) async =>
          entities[invocation.positionalArguments.first as String],
    );
  });

  /// A row of [agentId]'s thread with its payload.
  AgentMessageEntity row({
    required String id,
    required AgentMessageKind kind,
    required Map<String, Object?> content,
    String agentId = frontAgentId,
    String? toolName,
    String? operationId,
    String? runKey = 'run-1',
    DateTime? createdAt,
  }) {
    final payload = makeTestMessagePayload(
      id: '$id-payload',
      agentId: agentId,
      content: content,
    );
    entities[payload.id] = payload;
    final message = makeTestMessage(
      id: id,
      agentId: agentId,
      kind: kind,
      metadata: AgentMessageMetadata(
        runKey: runKey,
        toolName: toolName,
        operationId: operationId,
      ),
      contentEntryId: payload.id,
      createdAt: createdAt,
    );
    threads.putIfAbsent(agentId, () => []).add(message);
    return message;
  }

  AgentMessageEntity userTurn(String id, String text, {DateTime? at}) => row(
    id: id,
    kind: AgentMessageKind.user,
    runKey: null,
    content: {'text': text},
    createdAt: at,
  );

  test('an empty thread projects to nothing', () async {
    final thread = await builder.build();
    expect(thread.messages, isEmpty);
    expect(thread.doorsByMessageId, isEmpty);
    expect(thread.optionsByMessageId, isEmpty);
    expect(thread.specialistAgentIds, isEmpty);
  });

  test('user turns, replies and questions are the visible messages, in '
      "order; dispatches, doors and the strategy's own log are not", () async {
    userTurn('u1', 'How is the garden?', at: DateTime(2026, 10, 24, 9));
    row(
      id: 'reply-1',
      kind: AgentMessageKind.action,
      toolName: FrontAgentToolNames.replyToUser,
      operationId: 'u1',
      content: {'text': ' I asked the garden agent. '},
      createdAt: DateTime(2026, 10, 24, 9, 1),
    );
    row(
      id: 'dispatch-1',
      kind: AgentMessageKind.action,
      toolName: FrontAgentToolNames.dispatch,
      operationId: 'u1',
      content: {'input': 'How is the garden?', 'segments': []},
      createdAt: DateTime(2026, 10, 24, 9, 1),
    );
    // The strategy's tool-call log shares the tool name, with no
    // operationId: not an answer row.
    row(
      id: 'log-1',
      kind: AgentMessageKind.action,
      toolName: FrontAgentToolNames.replyToUser,
      content: {'text': 'not shown'},
      createdAt: DateTime(2026, 10, 24, 9, 1),
    );
    userTurn('u2', 'Swim?', at: DateTime(2026, 10, 25, 8));
    row(
      id: 'ask-1',
      kind: AgentMessageKind.action,
      toolName: FrontAgentToolNames.askUser,
      operationId: 'u2',
      content: {
        'question': 'Which one?',
        'options': [
          {'kind': 'goal', 'id': 'goal-a', 'label': 'Swim 2 km'},
          {'kind': 'hologram', 'id': 'x', 'label': 'Nope'},
          'junk',
        ],
      },
      createdAt: DateTime(2026, 10, 25, 8, 1),
    );

    final thread = await builder.build();

    expect(
      [for (final m in thread.messages) (m.id, m.role, m.text)],
      [
        ('u1', AgentChatRole.user, 'How is the garden?'),
        ('reply-1', AgentChatRole.agent, 'I asked the garden agent.'),
        ('u2', AgentChatRole.user, 'Swim?'),
        ('ask-1', AgentChatRole.agent, 'Which one?'),
      ],
    );
    expect(thread.messages[1].runKey, 'run-1');
    expect(thread.messages[0].runKey, isNull);
    final options = thread.optionsByMessageId['ask-1']!;
    expect(options, hasLength(1));
    expect(options.single.kind, FrontDestinationKind.goal);
    expect(options.single.id, 'goal-a');
    expect(options.single.label, 'Swim 2 km');
    expect(thread.optionsByMessageId.containsKey('u2'), isFalse);
  });

  test('a row without a payload, or with an empty text, is left out', () async {
    threads[frontAgentId]!.add(
      makeTestMessage(
        id: 'orphan',
        agentId: frontAgentId,
        kind: AgentMessageKind.user,
        metadata: const AgentMessageMetadata(),
        contentEntryId: 'missing',
      ),
    );
    userTurn('blank', '   ');
    row(
      id: 'ask-blank',
      kind: AgentMessageKind.action,
      toolName: FrontAgentToolNames.askUser,
      operationId: 'blank',
      content: {'question': ''},
    );

    expect((await builder.build()).messages, isEmpty);
  });

  test('the newest fifty messages are kept, and the doors and options of '
      'the dropped ones go with them', () async {
    for (var i = 0; i < 60; i++) {
      userTurn(
        'u$i'.padLeft(4, '0'),
        'turn $i',
        at: DateTime(2026, 10).add(Duration(minutes: i)),
      );
    }
    row(
      id: 'u000-dispatch:door:0',
      kind: AgentMessageKind.action,
      toolName: frontDoorToolName,
      operationId: 'u000'.padLeft(4, '0'),
      content: FrontDoorRecord(
        segmentIndex: 0,
        text: 'turn 0',
        kind: FrontDestinationKind.unrouted,
        status: FrontDoorStatus.done,
        claimedAt: DateTime.utc(2026, 10),
        outcome: const FrontDoorSkipped(FrontDoorSkipReason.noDoor),
      ).toJson(),
    );

    final thread = await builder.build();

    expect(thread.messages, hasLength(50));
    expect(thread.messages.first.text, 'turn 10');
    expect(thread.messages.last.text, 'turn 59');
    expect(thread.doorsByMessageId, isEmpty);
  });

  group('doors', () {
    final claimedAt = DateTime.utc(2026, 10, 24, 9);

    FrontDoorRecord door(
      int index,
      FrontDoorOutcome? outcome, {
      FrontDestinationKind kind = FrontDestinationKind.task,
      String? destinationId = 'garden',
    }) => FrontDoorRecord(
      segmentIndex: index,
      text: 'segment $index',
      kind: kind,
      destinationId: destinationId,
      ownerTitle: 'Owner $index',
      status: outcome == null ? FrontDoorStatus.claimed : FrontDoorStatus.done,
      claimedAt: claimedAt,
      outcome: outcome,
    );

    void doorRow(String id, String turnId, FrontDoorRecord record) => row(
      id: id,
      kind: AgentMessageKind.action,
      toolName: frontDoorToolName,
      operationId: turnId,
      content: record.toJson(),
    );

    test('hang off the user turn they answer, in segment order, with a '
        "specialist's reply mirrored from its own thread by the message "
        'id the door recorded', () async {
      userTurn('u1', 'Garden? Swim? Pip?');
      doorRow(
        'd:door:2',
        'u1',
        door(
          2,
          const FrontDoorChatTurn(
            specialistAgentId: relationshipAgent,
            specialistMessageId: 'pm-1',
          ),
          kind: FrontDestinationKind.person,
          destinationId: 'pip',
        ),
      );
      doorRow(
        'd:door:0',
        'u1',
        door(
          0,
          const FrontDoorAnswer(
            text: 'The seam is next.',
            summaryBased: true,
            incomplete: false,
          ),
        ),
      );
      doorRow(
        'd:door:1',
        'u1',
        door(
          1,
          const FrontDoorChatTurn(
            specialistAgentId: 'goal-swim',
            specialistMessageId: 'gm-1',
          ),
          kind: FrontDestinationKind.goal,
          destinationId: 'goal-swim',
        ),
      );
      // The goal agent has replied to that turn; another reply of its —
      // to someone else's turn — is not the one.
      row(
        id: 'g-other',
        agentId: 'goal-swim',
        kind: AgentMessageKind.action,
        toolName: AgentConversationToolNames.replyToUser,
        operationId: 'gm-0',
        content: {'text': 'An earlier reply.'},
      );
      row(
        id: 'g-reply',
        agentId: 'goal-swim',
        kind: AgentMessageKind.action,
        toolName: AgentConversationToolNames.replyToUser,
        operationId: 'gm-1',
        content: {'text': 'Two of three swims done.'},
      );
      // The person agent is still replying.
      threads[relationshipAgent] = [];

      final thread = await builder.build();

      final doors = thread.doorsByMessageId['u1']!;
      expect([for (final d in doors) d.record.segmentIndex], [0, 1, 2]);
      expect(
        [for (final d in doors) d.doorId],
        ['d:door:0', 'd:door:1', 'd:door:2'],
      );
      expect(doors[0].specialistReply, isNull);
      expect(doors[1].specialistReply, 'Two of three swims done.');
      expect(doors[2].specialistReply, isNull);
      expect(thread.specialistAgentIds, {'goal-swim', relationshipAgent});
      expect(thread.doorsByMessageId.keys, ['u1']);
    });

    test(
      'a door record this build cannot read is skipped, not fatal',
      () async {
        userTurn('u1', 'Garden?');
        row(
          id: 'd:door:0',
          kind: AgentMessageKind.action,
          toolName: frontDoorToolName,
          operationId: 'u1',
          content: {'kind': 'hologram'},
        );
        doorRow('d:door:1', 'u1', door(1, null));

        final thread = await builder.build();

        final doors = thread.doorsByMessageId['u1']!;
        expect(doors, hasLength(1));
        expect(doors.single.record.status, FrontDoorStatus.claimed);
        expect(doors.single.specialistReply, isNull);
        expect(thread.specialistAgentIds, isEmpty);
      },
    );
  });
}

const relationshipAgent = 'relationship_agent:pip';
