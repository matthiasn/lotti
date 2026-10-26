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
}
