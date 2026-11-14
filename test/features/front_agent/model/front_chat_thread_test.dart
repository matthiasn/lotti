import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_cited_answer.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';

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

  test("the thread's surfaces are its replies' and one per journal answer "
      'with points, under its own id; an answer of an owner gets none', () {
    final evidence = QueryEvidence(
      source: const QuerySourceRef(
        id: 'e1',
        private: false,
        categoryPrivate: false,
        categoryId: 'c',
      ),
      kind: QuerySourceKind.text,
      label: 'Colony chores',
      sourceDate: DateTime.utc(2026, 10, 27),
      textVersion: 'entryText',
      fingerprint: 'f',
      sourceText: 'Fix the hinge.',
      start: 0,
      end: 14,
      summary: '',
    );
    final reply = FrontReplySurface.compose(
      surfaceId: 'a1',
      components: const [
        {
          'component': FrontReplyComponents.quickReplies,
          'options': ['Ok'],
        },
      ],
    );
    final thread = FrontChatThread(
      messages: const [],
      surfacesByMessageId: {'a1': reply},
      doorsByMessageId: {
        'u1': [
          door(
            'd:door:0',
            FrontDoorAnswer(
              text: 'Promised [1].',
              summaryBased: false,
              incomplete: false,
              fromJournal: true,
              evidence: [evidence],
            ),
          ),
          door(
            'd:door:1',
            const FrontDoorAnswer(
              text: 'On track.',
              summaryBased: true,
              incomplete: false,
            ),
          ),
          door('d:door:2', null),
        ],
      },
    );

    final surfaces = thread.surfaces;

    expect(surfaces.keys, ['a1', frontDoorAnswerSurfaceId('d:door:0')]);
    expect(surfaces['a1'], same(reply));
    final create =
        surfaces[frontDoorAnswerSurfaceId('d:door:0')]!
                .message['createSurface']!
            as Map;
    final points = FrontCitedPoint.listFromJson(
      (create['dataModel']! as Map)[FrontReplyData.answer],
    );
    expect(points.single.text, 'Promised.');
    expect(points.single.sources.single.id, 'e1');
  });
}
