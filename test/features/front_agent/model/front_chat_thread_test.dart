import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';

void main() {
  FrontDoorEntry door(String id, FrontDoorOutcome? outcome) => FrontDoorEntry(
    doorId: id,
    record: FrontDoorRecord(
      segmentIndex: 0,
      text: 'x',
      kind: FrontDestinationKind.task,
      status: FrontDoorStatus.done,
      claimedAt: DateTime.utc(2026, 10, 26),
      outcome: outcome,
    ),
  );

  test('an option reads from the record, and nothing from a shape this '
      'build does not know', () {
    final option = FrontAskOption.fromJson(const {
      'kind': 'goal',
      'id': 'g',
      'label': 'Swim',
    })!;
    expect(option.kind, FrontDestinationKind.goal);
    expect(option.id, 'g');
    expect(option.label, 'Swim');
    expect(FrontAskOption.fromJson(const {'kind': 'goal', 'id': 'g'}), isNull);
    expect(FrontAskOption.fromJson('nope'), isNull);
  });

  test('the inbox is every turn with a door still waiting on the user, and '
      'the count is the doors', () {
    final thread = FrontChatThread(
      messages: [
        AgentChatMessage(
          id: 'u1',
          role: AgentChatRole.user,
          text: 'a',
          createdAt: DateTime(2026),
        ),
      ],
      doorsByMessageId: {
        'u1': [
          door('a', const FrontDoorProposal(ownerId: 't')),
          door('b', const FrontDoorInbox()),
          door('c', const FrontDoorFiled(entryId: 'e')),
        ],
        'u2': [door('d', const FrontDoorDeclined())],
        'u3': [
          door('e', null),
          door('f', const FrontDoorTaskCreated(taskId: 't')),
        ],
        'u4': [door('g', const FrontDoorInbox(newKind: FrontNewKind.task))],
      },
    );

    expect(thread.inboxMessageIds, {'u1', 'u4'});
    expect(thread.inboxCount, 3);
    expect(door('a', const FrontDoorProposal(ownerId: 't')).awaitsUser, isTrue);
    expect(door('c', const FrontDoorFiled(entryId: 'e')).awaitsUser, isFalse);
    expect(FrontChatThread.empty.inboxCount, 0);
    expect(FrontChatThread.empty.inboxMessageIds, isEmpty);
  });

  test("a turn's doors are carried by her reply right after it, else by "
      'the turn itself, and the inbox names both', () {
    AgentChatMessage m(String id, AgentChatRole role) => AgentChatMessage(
      id: id,
      role: role,
      text: id,
      createdAt: DateTime(2026),
    );
    final thread = FrontChatThread(
      messages: [
        m('u1', AgentChatRole.user),
        m('r1', AgentChatRole.agent),
        m('u2', AgentChatRole.user),
        m('u3', AgentChatRole.user),
        m('ask3', AgentChatRole.agent),
        m('u4', AgentChatRole.user),
      ],
      doorsByMessageId: {
        'u1': [door('a', const FrontDoorProposal(ownerId: 't'))],
        'u2': [door('b', const FrontDoorFiled(entryId: 'e'))],
        'u3': [door('c', const FrontDoorInbox())],
        'u4': [door('d', null)],
      },
    );

    // Her reply follows: the doors are her answer.
    expect(thread.carrierOf('u1'), 'r1');
    expect(thread.doorsCarriedBy('r1')!.single.doorId, 'a');
    expect(thread.doorsCarriedBy('u1'), isNull);
    // Another user turn follows, or nothing yet: the turn keeps its doors.
    expect(thread.carrierOf('u2'), 'u2');
    expect(thread.doorsCarriedBy('u2')!.single.doorId, 'b');
    expect(thread.carrierOf('u3'), 'ask3');
    expect(thread.carrierOf('u4'), 'u4');
    expect(thread.doorsCarriedBy('u4')!.single.doorId, 'd');
    expect(thread.carrierOf('unknown'), 'unknown');
    expect(thread.doorsCarriedBy('ask3')!.single.doorId, 'c');
    // The inbox filter keeps the words and the carrier together.
    expect(thread.inboxMessageIds, {'u1', 'r1', 'u3', 'ask3'});
  });
}
