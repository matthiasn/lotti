import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/change_set.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/event_people_directory.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../relationships/helpers/test_people.dart';
import '../test_utils.dart';

void main() {
  const eventId = 'event-1';
  const agentId = 'agent-1';
  final at = DateTime(2026, 7, 16, 20);

  EntryLink relationshipLink(
    String personId, {
    String toId = eventId,
    bool hidden = false,
    DateTime? deletedAt,
  }) => EntryLink.relationship(
    id: 'link-$personId-$toId',
    fromId: personId,
    toId: toId,
    createdAt: at,
    updatedAt: at,
    vectorClock: null,
    hidden: hidden,
    deletedAt: deletedAt,
  );

  group('load', () {
    late MockJournalRepository journal;
    late MockAgentRepository agents;

    setUp(() {
      journal = MockJournalRepository();
      agents = MockAgentRepository();
      when(journal.getRelationships).thenAnswer(
        (_) async => [
          makeTestPerson(id: 'rocko', title: 'Rocko'),
          makeTestPerson(id: 'pip', title: 'Pip Penguin', nickname: ' Pip '),
          makeTestPerson(id: 'oona', title: 'oona'),
          makeTestPerson(id: 'kai', title: 'Kai'),
          makeTestPerson(id: 'gone', title: 'Gone', deletedAt: at),
        ],
      );
      when(
        () => journal.getTypedLinksForTaskIds(
          {eventId},
          linkTypes: {'RelationshipLink'},
        ),
      ).thenAnswer(
        (_) async => [
          relationshipLink('rocko'),
          relationshipLink('tombstoned', deletedAt: at),
          relationshipLink('hidden', hidden: true),
          relationshipLink('pip', toId: 'other-event'),
        ],
      );
      when(
        () => agents.getPendingChangeSets(agentId, taskId: eventId),
      ).thenAnswer(
        (_) async => [
          makeTestChangeSet(
            agentId: agentId,
            taskId: eventId,
            items: const [
              ChangeItem(
                toolName: EventAgentToolNames.suggestPerson,
                args: {'personId': 'oona', 'personName': 'oona'},
                humanSummary: 'Add oona to the event',
              ),
              // Already decided items of a pending set are not pending.
              ChangeItem(
                toolName: EventAgentToolNames.suggestPerson,
                args: {'personId': 'pip'},
                humanSummary: 'Add Pip Penguin to the event',
                status: ChangeItemStatus.rejected,
              ),
              ChangeItem(
                toolName: EventAgentToolNames.suggestFollowUpTask,
                args: {'personId': 'rocko', 'title': 'x'},
                humanSummary: 'Follow-up task: x',
              ),
            ],
          ),
        ],
      );
      when(
        () => agents.getChangeDecisions(agentId, taskId: eventId),
      ).thenAnswer(
        (_) async => [
          makeTestChangeDecision(
            agentId: agentId,
            taskId: eventId,
            toolName: EventAgentToolNames.suggestPerson,
            verdict: ChangeDecisionVerdict.rejected,
            args: const {'personId': 'kai'},
          ),
          // A confirmed one is a link by now, not a dismissal.
          makeTestChangeDecision(
            id: 'cd-2',
            agentId: agentId,
            taskId: eventId,
            toolName: EventAgentToolNames.suggestPerson,
            args: const {'personId': 'oona'},
          ),
        ],
      );
    });

    test('reads everyone, by name, with where each stands', () async {
      final directory = await EventPeopleDirectory.load(
        journalRepository: journal,
        agentRepository: agents,
        agentId: agentId,
        eventId: eventId,
      );

      expect(directory.people.map((p) => p.id), [
        'kai',
        'oona',
        'pip',
        'rocko',
      ]);
      expect(directory.byId('pip')?.nickname, 'Pip');
      expect(directory.byId('gone'), isNull);
      expect(directory.standingOf('rocko'), EventPersonStanding.withEvent);
      expect(directory.standingOf('oona'), EventPersonStanding.suggested);
      expect(directory.standingOf('kai'), EventPersonStanding.dismissed);
      expect(directory.standingOf('pip'), EventPersonStanding.open);
    });
  });

  group('standing', () {
    test('being with the event outranks a dismissal, which outranks a '
        'pending suggestion', () {
      final directory = EventPeopleDirectory(
        people: const [EventKnownPerson(id: 'a', name: 'A')],
        withEventIds: {'a'},
        suggestedIds: {'a', 'b'},
        dismissedIds: {'a', 'b'},
      );

      expect(directory.standingOf('a'), EventPersonStanding.withEvent);
      expect(directory.standingOf('b'), EventPersonStanding.dismissed);
    });
  });

  group('render', () {
    final directory = EventPeopleDirectory(
      people: const [
        EventKnownPerson(id: 'kai', name: 'Kai'),
        EventKnownPerson(id: 'oona', name: 'Oona', nickname: 'Oona'),
        EventKnownPerson(id: 'pip', name: 'Pip Penguin', nickname: 'Pip'),
        EventKnownPerson(id: 'rocko', name: 'Rocko'),
      ],
      withEventIds: {'rocko'},
      suggestedIds: {'oona'},
      dismissedIds: {'kai'},
    );

    test('one line per person: id, name, a differing nickname, standing', () {
      expect(
        directory.render(),
        '- kai: Kai — dismissed by the user for this event\n'
        '- oona: Oona — already suggested, awaiting the user\n'
        '- pip: Pip Penguin (called "Pip")\n'
        '- rocko: Rocko — already with this event',
      );
    });

    test('a query narrows by name or nickname, ignoring case', () {
      expect(
        directory.render(query: ' PIP '),
        '- pip: Pip Penguin (called "Pip")',
      );
      expect(directory.render(query: 'rock'), contains('- rocko: Rocko'));
    });

    test('says so when nothing matches, or nobody is kept', () {
      expect(directory.render(query: 'zed'), 'No person matches "zed".');
      expect(
        EventPeopleDirectory(people: const []).render(),
        'The user keeps no people yet.',
      );
    });
  });
}
