import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/service/front_owner_titles.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

final _stamp = DateTime(2026, 10);

Metadata _meta(String id) => Metadata(
  id: id,
  createdAt: _stamp,
  updatedAt: _stamp,
  dateFrom: _stamp,
  dateTo: _stamp,
);

void main() {
  late MockJournalDb journalDb;
  late MockAgentRepository agentRepository;
  late FrontOwnerTitles titles;

  setUp(() {
    journalDb = MockJournalDb();
    agentRepository = MockAgentRepository();
    titles = FrontOwnerTitles(
      journalDb: journalDb,
      agentRepository: agentRepository,
    );
  });

  test(
    'a task, a project and a person are titled from their journal row',
    () async {
      final status = TaskStatus.open(id: 's', createdAt: _stamp, utcOffset: 0);
      when(() => journalDb.journalEntityById('t')).thenAnswer(
        (_) async => JournalEntity.task(
          meta: _meta('t'),
          data: TaskData(
            status: status,
            statusHistory: [status],
            dateFrom: _stamp,
            dateTo: _stamp,
            title: 'Garden',
          ),
        ),
      );
      when(() => journalDb.journalEntityById('p')).thenAnswer(
        (_) async => JournalEntity.project(
          meta: _meta('p'),
          data: ProjectData(
            title: 'Relocation',
            status: ProjectStatus.open(
              id: 'ps',
              createdAt: _stamp,
              utcOffset: 0,
            ),
            dateFrom: _stamp,
            dateTo: _stamp,
          ),
        ),
      );
      when(() => journalDb.journalEntityById('r')).thenAnswer(
        (_) async => JournalEntity.relationship(
          meta: _meta('r'),
          data: RelationshipData(
            title: 'Pip',
            status: RelationshipStatus.active(
              id: 'rs',
              createdAt: _stamp,
              utcOffset: 0,
            ),
          ),
        ),
      );

      expect(await titles.titleFor(FrontDestinationKind.task, 't'), 'Garden');
      expect(
        await titles.titleFor(FrontDestinationKind.project, 'p'),
        'Relocation',
      );
      expect(await titles.titleFor(FrontDestinationKind.person, 'r'), 'Pip');
    },
  );

  test('a row of the wrong kind, or none, titles nothing', () async {
    when(() => journalDb.journalEntityById('x')).thenAnswer((_) async => null);
    when(() => journalDb.journalEntityById('r')).thenAnswer(
      (_) async => JournalEntity.relationship(
        meta: _meta('r'),
        data: RelationshipData(
          title: 'Pip',
          status: RelationshipStatus.active(
            id: 'rs',
            createdAt: _stamp,
            utcOffset: 0,
          ),
        ),
      ),
    );
    expect(await titles.titleFor(FrontDestinationKind.task, 'x'), isNull);
    // A person row asked for as a task is still a person: no title.
    expect(await titles.titleFor(FrontDestinationKind.task, 'r'), 'Pip');
  });

  test('a goal is titled by its active spec statement', () async {
    when(
      () => agentRepository.getEntity(goalSpecHeadId('goal-a')),
    ).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecHead(
        id: goalSpecHeadId('goal-a'),
        agentId: 'goal-a',
        versionId: 'spec-1',
        updatedAt: _stamp,
        vectorClock: null,
      ),
    );
    when(() => agentRepository.getEntity('spec-1')).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecVersion(
        id: 'spec-1',
        agentId: 'goal-a',
        version: 1,
        status: GoalSpecVersionStatus.active,
        authoredBy: 'user',
        title: 'Swim',
        statement: 'Swim 2 km a day on average.',
        criteria: const GoalCriterion.habit(
          criterionId: 'c',
          habitId: 'h',
          window: GoalWindow.day(),
          targetCount: 1,
        ),
        createdAt: _stamp,
        vectorClock: null,
      ),
    );

    expect(
      await titles.titleFor(FrontDestinationKind.goal, 'goal-a'),
      'Swim 2 km a day on average.',
    );
  });

  test(
    'a goal without a head, or with a deleted one, titles nothing',
    () async {
      when(
        () => agentRepository.getEntity(goalSpecHeadId('gone')),
      ).thenAnswer((_) async => null);
      expect(await titles.titleFor(FrontDestinationKind.goal, 'gone'), isNull);
      verifyNever(() => agentRepository.getEntity('spec-1'));
    },
  );

  test('kinds without an owner title nothing and read nothing', () async {
    for (final kind in [
      FrontDestinationKind.day,
      FrontDestinationKind.newThing,
      FrontDestinationKind.journal,
      FrontDestinationKind.unrouted,
    ]) {
      expect(await titles.titleFor(kind, 'x'), isNull, reason: kind.name);
    }
    verifyNever(() => journalDb.journalEntityById(any()));
    verifyNever(() => agentRepository.getEntity(any()));
  });
}
