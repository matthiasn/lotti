import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/model/front_task_draft.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/features/front_agent/workflow/front_conversation_tasks.dart';

import '../../agents/test_data/entity_factories.dart';

void main() {
  (AgentMessageEntity, AgentMessagePayloadEntity) turn(
    Map<String, Object?> content, {
    String? toolName,
    DateTime? at,
  }) => (
    makeTestMessage(
      createdAt: at,
      kind: toolName == null ? AgentMessageKind.user : AgentMessageKind.action,
      toolName: toolName,
    ),
    makeTestMessagePayload(content: content),
  );

  (AgentMessageEntity, AgentMessagePayloadEntity) reply(
    String text, {
    DateTime? at,
  }) => turn({'text': text}, toolName: FrontAgentToolNames.replyToUser, at: at);

  final now = DateTime(2026, 11, 8, 14, 30);

  test('"that one" is the task named last: newest turn first, each task '
      'once', () {
    // Oldest first, as the conversation went; the scanner reads newest first.
    final conversation = [
      reply('Due today: [Prune the roses](lotti://task/roses)'),
      turn({'text': 'and the budget?'}),
      reply(
        '[Draft the budget](lotti://task/budget) and '
        '[Prune the roses](lotti://task/roses).',
      ),
    ];

    expect(frontConversationTaskIds(conversation.reversed), [
      'budget',
      'roses',
    ]);
  });

  test('the tasks a closed-task answer showed as cards are named, the one '
      'closed last first, after any her words linked', () {
    final conversation = [
      reply('Due today: [Prune the roses](lotti://task/roses)'),
      turn({
        'text':
            'You completed 2 and rejected 1, with [Paint](lotti://task/paint).',
        'closedTasks': [
          {'id': 'shed', 'title': 'Shed', 'closedAt': '2026-11-07T10:00:00Z'},
          {'id': 'eggs', 'title': 'Eggs', 'closedAt': '2026-11-08T09:00:00Z'},
          {'id': 'broken'},
        ],
      }, toolName: FrontAgentToolNames.replyToUser),
    ];

    expect(frontConversationTaskIds(conversation.reversed), [
      'paint',
      'eggs',
      'shed',
      'roses',
    ]);
  });

  test('a task the tap made counts as named at the tap, ahead of what '
      'was said after its inbox item was walked', () {
    Map<String, Object?> door({DateTime? tappedAt}) =>
        FrontDoorRecord(
              segmentIndex: 0,
              text: 'make a task to order seeds',
              kind: FrontDestinationKind.newThing,
              status: FrontDoorStatus.claimed,
              claimedAt: now,
              task: const FrontTaskDraft(title: 'Order seeds'),
            )
            .done(
              FrontDoorTaskCreated(
                taskId: 'seeds',
                newKind: FrontNewKind.task,
                at: tappedAt,
              ),
            )
            .toJson();
    List<String> named({DateTime? tappedAt}) => frontConversationTaskIds([
      turn(
        door(tappedAt: tappedAt),
        toolName: frontDoorToolName,
        at: DateTime(2026, 11, 8, 9),
      ),
      reply(
        '[Prune the roses](lotti://task/roses)',
        at: DateTime(2026, 11, 8, 9, 10),
      ),
    ]);

    expect(named(tappedAt: DateTime(2026, 11, 8, 9, 20)), ['seeds', 'roses']);
    expect(
      named(),
      ['roses', 'seeds'],
      reason: 'a record from before the tap time was kept dates by the door',
    );
  });

  test('a routed dispatch, a follow-up it proposed, a question offering a '
      'task and a door into one all name their tasks; owners of other '
      'kinds do not', () {
    const dispatch = FrontDispatch(
      segments: [
        FrontDispatchSegment(
          start: 0,
          end: 5,
          text: 'hose.',
          intent: FrontSegmentIntent.instruction,
          kind: FrontDestinationKind.task,
          confidence: 0.9,
          destinationId: 'garden',
        ),
        FrontDispatchSegment(
          start: 5,
          end: 10,
          text: 'again',
          intent: FrontSegmentIntent.instruction,
          kind: FrontDestinationKind.newThing,
          confidence: 0.9,
          newKind: FrontNewKind.task,
          task: FrontTaskDraft(title: 'Mulch', followsUpTaskId: 'roses'),
        ),
        FrontDispatchSegment(
          start: 10,
          end: 15,
          text: 'Pip',
          intent: FrontSegmentIntent.question,
          kind: FrontDestinationKind.person,
          confidence: 0.9,
          destinationId: 'pip',
        ),
      ],
    );
    final door = FrontDoorRecord(
      segmentIndex: 0,
      text: 'hose.',
      kind: FrontDestinationKind.task,
      destinationId: 'shed',
      status: FrontDoorStatus.claimed,
      claimedAt: now,
    );

    expect(
      frontConversationTaskIds([
        turn(dispatch.toJson(), toolName: FrontAgentToolNames.dispatch),
        turn({
          'question': 'This one?',
          'options': [
            {'kind': 'person', 'id': 'pip', 'label': 'Pip'},
            {'kind': 'task', 'id': 'budget', 'label': 'Draft the budget'},
          ],
        }, toolName: FrontAgentToolNames.askUser),
        turn(door.toJson(), toolName: frontDoorToolName),
        turn({'text': 'see lotti://project/p1'}),
      ]),
      ['garden', 'roses', 'budget', 'shed'],
    );
  });

  test('stops at the cap, keeping the most recently named', () {
    final conversation = [
      for (var i = 0; i < frontConversationTasksMax + 3; i++)
        reply('[Task $i](lotti://task/t$i)'),
    ];

    final ids = frontConversationTaskIds(conversation.reversed);

    expect(ids, hasLength(frontConversationTasksMax));
    expect(ids.first, 't${frontConversationTasksMax + 2}');
  });

  test('a payload of another shape names nothing', () {
    expect(
      frontConversationTaskIds([
        turn({'text': 42}),
        turn({'segments': 'nope'}, toolName: FrontAgentToolNames.dispatch),
        turn({
          'question': 'Which?',
          'options': 'nope',
        }, toolName: FrontAgentToolNames.askUser),
        turn({'segmentIndex': 'x'}, toolName: frontDoorToolName),
        turn({'text': '[x](lotti://task/x)'}, toolName: 'read_tldr'),
      ]),
      isEmpty,
    );
  });
}
