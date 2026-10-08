import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_link.dart' as agent_model;
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/repository/recording_context_resolver.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../projects/test_utils.dart';

final _at = DateTime(2026, 10, 8);

Metadata _meta(String id, {DateTime? deletedAt}) => Metadata(
  id: id,
  createdAt: _at,
  updatedAt: _at,
  dateFrom: _at,
  dateTo: _at,
  deletedAt: deletedAt,
);

Task _task(String id) =>
    JournalEntity.task(
          meta: _meta(id),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-$id',
              createdAt: _at,
              utcOffset: 0,
            ),
            title: 'Feed the colony',
            statusHistory: const [],
            dateFrom: _at,
            dateTo: _at,
            languageCode: 'de',
          ),
        )
        as Task;

RelationshipEntry _person(String id, {DateTime? deletedAt}) =>
    JournalEntity.relationship(
          meta: _meta(id, deletedAt: deletedAt),
          data: RelationshipData(
            title: 'Commander Pip Frostbeak',
            nickname: 'Pip',
            languageCode: 'en',
            status: RelationshipStatus.active(
              id: 'status-$id',
              createdAt: _at,
              utcOffset: 0,
            ),
          ),
        )
        as RelationshipEntry;

CheckInEntry _checkIn(String id, {required String relationshipId}) =>
    JournalEntity.checkIn(
          meta: _meta(id),
          data: CheckInData(
            relationshipId: relationshipId,
            interactionType: CheckInInteractionType.other,
          ),
        )
        as CheckInEntry;

GoalEntry _goal(String id) =>
    JournalEntity.goal(
          meta: _meta(id),
          data: const GoalData(
            title: 'Waddle daily',
            statement: 'Waddle 2 km every day.',
            criteria: GoalCriterion.allOf(
              criterionId: 'all',
              criteria: <GoalCriterion>[],
            ),
            specVersion: 2,
            specVersionId: 'spec-2',
          ),
        )
        as GoalEntry;

JournalEvent _event(String id) =>
    JournalEntity.event(
          meta: _meta(id),
          data: const EventData(
            title: 'Ice floe survey',
            stars: 0,
            status: EventStatus.planned,
          ),
        )
        as JournalEvent;

AgentReportEntity _report({
  String content = '',
  String? tldr,
  Map<String, Object?> provenance = const {},
}) =>
    AgentDomainEntity.agentReport(
          id: 'report',
          agentId: 'agent-1',
          scope: AgentReportScopes.current,
          createdAt: _at,
          vectorClock: null,
          content: content,
          tldr: tldr,
          provenance: provenance,
        )
        as AgentReportEntity;

agent_model.AgentLink _link(String fromId, DateTime createdAt) =>
    agent_model.AgentLink.basic(
      id: 'link-$fromId',
      fromId: fromId,
      toId: 'subject',
      createdAt: createdAt,
      updatedAt: createdAt,
      vectorClock: null,
    );

void main() {
  late MockJournalRepository journal;
  late MockAiInputRepository aiInput;
  late MockTaskSummaryResolver taskSummaries;
  late MockAgentRepository agents;
  late MockDomainLogger logger;
  late RecordingContextResolver resolver;

  setUp(() {
    journal = MockJournalRepository();
    aiInput = MockAiInputRepository();
    taskSummaries = MockTaskSummaryResolver();
    agents = MockAgentRepository();
    logger = MockDomainLogger();
    resolver = RecordingContextResolver(
      journalRepository: journal,
      aiInputRepository: aiInput,
      taskSummaryResolver: taskSummaries,
      agentRepository: agents,
      domainLogger: logger,
    );
  });

  void parentsAre(List<JournalEntity> parents) => when(
    () => journal.getLinkedToEntities(linkedTo: 'audio-1'),
  ).thenAnswer((_) async => parents);

  void entityIs(JournalEntity entity) => when(
    () => aiInput.getEntity(entity.meta.id),
  ).thenAnswer((_) async => entity);

  Map<String, Object?> header(RecordingContext context) =>
      jsonDecode(context.headerJson!) as Map<String, Object?>;

  group('subjectOf', () {
    test('the linked task wins without looking anything up', () async {
      final subject = await resolver.subjectOf(
        'audio-1',
        linkedTaskId: 'task-1',
      );

      expect(subject, isA<TaskRecordingSubject>());
      expect(subject!.id, 'task-1');
      verifyNever(
        () => journal.getLinkedToEntities(linkedTo: any(named: 'linkedTo')),
      );
    });

    test(
      'picks the parent by kind — task, then person (directly or through a '
      'check-in), goal, project, event — whatever order the links come in',
      () async {
        final project = makeTestProject(id: 'project-1');
        parentsAre([_event('event-1'), project, _goal('goal-1')]);
        expect(
          await resolver.subjectOf('audio-1'),
          isA<GoalRecordingSubject>(),
        );

        parentsAre([
          _event('event-1'),
          _checkIn('check-in-1', relationshipId: 'person-1'),
          _goal('goal-1'),
        ]);
        final viaCheckIn = await resolver.subjectOf('audio-1');
        expect(viaCheckIn, isA<RelationshipRecordingSubject>());
        expect(viaCheckIn!.id, 'person-1', reason: 'the person, not the entry');

        parentsAre([_person('person-2'), _task('task-9')]);
        expect(
          (await resolver.subjectOf('audio-1'))!.id,
          'task-9',
          reason: 'a task the caller did not pass still frames its recording',
        );

        parentsAre([_event('event-1'), project]);
        expect(
          await resolver.subjectOf('audio-1'),
          isA<ProjectRecordingSubject>(),
        );

        parentsAre([_event('event-1')]);
        expect(
          await resolver.subjectOf('audio-1'),
          isA<EventRecordingSubject>(),
        );
      },
    );

    test(
      'skips a deleted parent, and resolves nothing with no parent',
      () async {
        parentsAre([
          _person('person-1', deletedAt: _at),
          _event('event-1'),
        ]);
        expect(
          await resolver.subjectOf('audio-1'),
          isA<EventRecordingSubject>(),
        );

        parentsAre([]);
        expect(await resolver.subjectOf('audio-1'), isNull);
      },
    );

    test('a failed lookup is logged and frames nothing', () async {
      when(
        () => journal.getLinkedToEntities(linkedTo: 'audio-1'),
      ).thenThrow(StateError('db closed'));

      expect(await resolver.subjectOf('audio-1'), isNull);
      verify(
        () => logger.error(
          any(),
          any<Object>(that: isA<StateError>()),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'RecordingContextResolver',
          message: any(named: 'message'),
        ),
      ).called(1);
    });
  });

  group('contextFor', () {
    void linkedAgents(String subjectId, String type, List<String> agentIds) {
      when(() => agents.getLinksTo(subjectId, type: type)).thenAnswer(
        (_) async => [
          for (final (i, id) in agentIds.indexed)
            _link(id, _at.add(Duration(minutes: i))),
        ],
      );
    }

    test('a task: its title and language, and its full report', () async {
      entityIs(_task('task-1'));
      when(
        () => taskSummaries.resolve('task-1', fullReport: true),
      ).thenAnswer((_) async => 'The colony is fed twice a day.');

      final context = await resolver.contextFor(
        const TaskRecordingSubject('task-1'),
      );

      expect(context!.label, 'Task');
      expect(context.reportHeading, 'Task Report');
      expect(header(context), {
        'title': 'Feed the colony',
        'languageCode': 'de',
      });
      expect(context.report, 'The colony is fed twice a day.');
    });

    test(
      'a person: name, nickname and language, and the briefing of the newest '
      'agent linked to them',
      () async {
        entityIs(_person('person-1'));
        linkedAgents('person-1', AgentLinkTypes.agentRelationship, [
          'agent-old',
          'agent-new',
        ]);
        when(
          () => agents.getLatestReport('agent-new', AgentReportScopes.current),
        ).thenAnswer((_) async => _report(content: '  Pip is recovering.  '));

        final context = await resolver.contextFor(
          const RelationshipRecordingSubject('person-1'),
        );

        expect(context!.label, 'Person');
        expect(context.reportHeading, 'Relationship Briefing');
        expect(header(context), {
          'name': 'Commander Pip Frostbeak',
          'nickname': 'Pip',
          'languageCode': 'en',
        });
        expect(context.report, 'Pip is recovering.');
      },
    );

    for (final (provenance, framed) in [
      ({'specVersionId': 'spec-2'}, true),
      ({'specVersionId': 'spec-1'}, false),
      (<String, Object?>{}, false),
    ]) {
      test(
        "a goal's report frames it only when written for its active spec "
        '(${provenance['specVersionId'] ?? 'no spec'})',
        () async {
          entityIs(_goal('goal-1'));
          linkedAgents('goal-1', AgentLinkTypes.agentGoal, ['agent-goal']);
          when(
            () =>
                agents.getLatestReport('agent-goal', AgentReportScopes.current),
          ).thenAnswer(
            (_) async => _report(content: 'On track.', provenance: provenance),
          );

          final context = await resolver.contextFor(
            const GoalRecordingSubject('goal-1'),
          );

          expect(context!.label, 'Goal');
          expect(header(context), {
            'title': 'Waddle daily',
            'statement': 'Waddle 2 km every day.',
          });
          expect(context.report, framed ? 'On track.' : isNull);
        },
      );
    }

    test(
      'a project uses its newest report, falling back to the TLDR when the '
      'body is empty',
      () async {
        final project = makeTestProject(id: 'project-1', title: 'New burrow');
        entityIs(project);
        when(
          () => agents.getLatestProjectReportForProjectId('project-1'),
        ).thenAnswer((_) async => _report(tldr: ' Digging starts Monday. '));

        final context = await resolver.contextFor(
          const ProjectRecordingSubject('project-1'),
        );

        expect(context!.reportHeading, 'Project Report');
        expect(header(context), {'title': 'New burrow'});
        expect(context.report, 'Digging starts Monday.');
      },
    );

    test('an event with no agent has its header and no report', () async {
      entityIs(_event('event-1'));
      linkedAgents('event-1', AgentLinkTypes.agentEvent, []);

      final context = await resolver.contextFor(
        const EventRecordingSubject('event-1'),
      );

      expect(context!.label, 'Event');
      expect(header(context), {'title': 'Ice floe survey'});
      expect(context.report, isNull);
    });

    test('an empty report frames nothing', () async {
      entityIs(_event('event-1'));
      linkedAgents('event-1', AgentLinkTypes.agentEvent, ['agent-1']);
      when(
        () => agents.getLatestReport('agent-1', AgentReportScopes.current),
      ).thenAnswer((_) async => _report(tldr: '  '));

      final context = await resolver.contextFor(
        const EventRecordingSubject('event-1'),
      );

      expect(context!.report, isNull);
    });

    test(
      'a failing report lookup is logged and leaves the header standing',
      () async {
        entityIs(_event('event-1'));
        when(
          () => agents.getLinksTo('event-1', type: AgentLinkTypes.agentEvent),
        ).thenThrow(StateError('agents closed'));

        final context = await resolver.contextFor(
          const EventRecordingSubject('event-1'),
        );

        expect(header(context!), {'title': 'Ice floe survey'});
        expect(context.report, isNull);
        verify(
          () => logger.error(
            any(),
            any<Object>(that: isA<StateError>()),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'RecordingContextResolver',
            message: any(named: 'message'),
          ),
        ).called(1);
      },
    );

    test('without the agent system every subject keeps its header', () async {
      final bare = RecordingContextResolver(
        journalRepository: journal,
        aiInputRepository: aiInput,
        taskSummaryResolver: taskSummaries,
        agentRepository: null,
        domainLogger: logger,
      );
      entityIs(_person('person-1'));

      final context = await bare.contextFor(
        const RelationshipRecordingSubject('person-1'),
      );

      expect(header(context!)['name'], 'Commander Pip Frostbeak');
      expect(context.report, isNull);
      verifyZeroInteractions(agents);
    });

    test(
      'a subject that is gone, deleted, or of another kind frames nothing',
      () async {
        when(() => aiInput.getEntity('missing')).thenAnswer((_) async => null);
        expect(
          await resolver.contextFor(const GoalRecordingSubject('missing')),
          isNull,
        );

        entityIs(_person('person-1', deletedAt: _at));
        expect(
          await resolver.contextFor(
            const RelationshipRecordingSubject('person-1'),
          ),
          isNull,
        );

        entityIs(_event('event-1'));
        expect(
          await resolver.contextFor(const GoalRecordingSubject('event-1')),
          isNull,
        );
      },
    );
  });
}
