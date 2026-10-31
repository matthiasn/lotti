import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/workflow/task_project_options.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../projects/test_utils.dart';
import '../test_data/entity_factories.dart';

void main() {
  const categoryId = 'category-penguins';
  final task = testTask.copyWith(
    meta: testTask.meta.copyWith(categoryId: categoryId),
  );
  final taskId = task.meta.id;

  late MockJournalDb journalDb;
  late MockProjectRepository projectRepository;
  late MockAgentRepository agentRepository;

  final colony = makeTestProject(
    id: 'project-colony',
    title: 'colony census',
    categoryId: categoryId,
    status: ProjectStatus.active(
      id: 'status-active',
      createdAt: DateTime(2024, 3, 15),
      utcOffset: 0,
    ),
  );
  final iceShelf = makeTestProject(
    id: 'project-ice',
    title: 'Ice shelf survey',
    categoryId: categoryId,
  );

  Future<List<TaskProjectOption>> load() => loadTaskProjectOptions(
    taskId: taskId,
    journalDb: journalDb,
    projectRepository: projectRepository,
    agentRepository: agentRepository,
  );

  setUp(() {
    journalDb = MockJournalDb();
    projectRepository = MockProjectRepository();
    agentRepository = MockAgentRepository();
    when(
      () => journalDb.journalEntityById(taskId),
    ).thenAnswer((_) async => task);
    when(
      () => projectRepository.getProjectsForCategory(categoryId),
    ).thenAnswer((_) async => [iceShelf, colony]);
    when(
      () => projectRepository.getProjectForTask(taskId),
    ).thenAnswer((_) async => iceShelf);
    when(
      () => agentRepository.getLatestProjectReportForProjectId(colony.meta.id),
    ).thenAnswer(
      (_) async => makeTestReport(
        oneLiner: 'Counting the colony before winter.',
        tldr: '  Census of the north colony; tally due in March.  ',
      ),
    );
    when(
      () =>
          agentRepository.getLatestProjectReportForProjectId(iceShelf.meta.id),
    ).thenAnswer((_) async => null);
  });

  group('loadTaskProjectOptions', () {
    test(
      "lists the category's projects by title, with report summaries",
      () async {
        final options = await load();

        expect(options.map((o) => o.id), ['project-colony', 'project-ice']);
        final colonyOption = options.first;
        expect(colonyOption.title, 'colony census');
        expect(colonyOption.status, 'ACTIVE');
        expect(colonyOption.oneLiner, 'Counting the colony before winter.');
        // Report text is trimmed so the model reads no stray whitespace.
        expect(
          colonyOption.tldr,
          'Census of the north colony; tally due in March.',
        );
        expect(colonyOption.isCurrent, isFalse);

        // A project without a report still lists, without summaries.
        final iceOption = options.last;
        expect(iceOption.status, 'OPEN');
        expect(iceOption.oneLiner, isNull);
        expect(iceOption.tldr, isNull);
        expect(iceOption.isCurrent, isTrue);
      },
    );

    test('is empty for a task without a category, reading nothing', () async {
      when(
        () => journalDb.journalEntityById(taskId),
      ).thenAnswer((_) async => testTask);

      expect(await load(), isEmpty);
      verifyNever(() => projectRepository.getProjectsForCategory(any()));
    });

    test('is empty when the id is not a task', () async {
      when(
        () => journalDb.journalEntityById(taskId),
      ).thenAnswer((_) async => colony);

      expect(await load(), isEmpty);
      verifyNever(() => projectRepository.getProjectsForCategory(any()));
    });
  });

  group('matchTaskProjectOption', () {
    const options = [
      TaskProjectOption(
        id: 'p1',
        title: 'Colony census',
        status: 'ACTIVE',
        isCurrent: false,
      ),
      TaskProjectOption(
        id: 'p2',
        title: 'Fish stocks',
        status: 'OPEN',
        isCurrent: false,
      ),
      TaskProjectOption(
        id: 'p3',
        title: 'fish stocks ',
        status: 'OPEN',
        isCurrent: false,
      ),
    ];

    test('matches an id, trimmed', () {
      expect(matchTaskProjectOption(options, ' p2 ')?.id, 'p2');
    });

    test('matches a unique title regardless of case', () {
      expect(matchTaskProjectOption(options, 'COLONY CENSUS')?.id, 'p1');
    });

    test('matches nothing for a shared title or an unknown reference', () {
      expect(matchTaskProjectOption(options, 'Fish stocks'), isNull);
      expect(matchTaskProjectOption(options, 'invented-id'), isNull);
    });
  });

  group('renderTaskProjectOptions', () {
    test('renders each project as JSON the model can parse', () {
      final rendered = renderTaskProjectOptions(const [
        TaskProjectOption(
          id: 'p1',
          title: 'Colony census',
          status: 'ACTIVE',
          oneLiner: 'Counting the colony.',
          tldr: 'Census due in March.',
          isCurrent: true,
        ),
      ]);

      expect(jsonDecode(rendered), {
        'projects': [
          {
            'id': 'p1',
            'title': 'Colony census',
            'status': 'ACTIVE',
            'oneLiner': 'Counting the colony.',
            'tldr': 'Census due in March.',
            'isCurrentProject': true,
          },
        ],
      });
    });

    test('tells the model not to propose when there are no projects', () {
      expect(
        renderTaskProjectOptions(const []),
        "No projects exist in this task's category. Do not call "
        'set_task_project.',
      );
    });
  });
}
