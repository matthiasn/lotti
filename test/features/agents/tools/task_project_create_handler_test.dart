import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/change_effect.dart';
import 'package:lotti/features/agents/tools/task_project_create_handler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../projects/test_utils.dart' show makeTestProject;

void main() {
  final now = DateTime(2026, 11, 2, 9, 30);

  late MockPersistenceLogic persistence;
  late MockJournalDb journalDb;
  late MockProjectRepository projects;
  late TaskProjectCreateHandler handler;

  Task makeTask({String? categoryId = 'cat-penguins', bool? private}) => Task(
    meta: Metadata(
      id: 'task-igloo',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      categoryId: categoryId,
      private: private,
    ),
    data: TaskData(
      status: TaskStatus.open(id: 'status-1', createdAt: now, utcOffset: 0),
      dateFrom: now,
      dateTo: now,
      statusHistory: const [],
      title: 'Patch the igloo roof',
    ),
  );

  ProjectEntry project(
    String id,
    String title, {
    bool private = false,
    DateTime? deletedAt,
  }) {
    final base = makeTestProject(
      id: id,
      title: title,
      categoryId: 'cat-penguins',
    );
    return base.copyWith(
      meta: base.meta.copyWith(private: private, deletedAt: deletedAt),
    );
  }

  /// Answers `createMetadata` as the real service does: the id derived from
  /// the `uuidV5Input` when one is given.
  void stubMetadata() {
    when(
      () => persistence.createMetadata(
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
        categoryId: any(named: 'categoryId'),
        private: any(named: 'private'),
        uuidV5Input: any(named: 'uuidV5Input'),
      ),
    ).thenAnswer((invocation) async {
      final input = invocation.namedArguments[#uuidV5Input] as String?;
      return Metadata(
        id: input == null ? 'random-id' : 'derived:$input',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
        categoryId: invocation.namedArguments[#categoryId] as String?,
        private: invocation.namedArguments[#private] as bool?,
      );
    });
  }

  ProjectEntry capturedProject() =>
      verify(
            () => projects.createProject(project: captureAny(named: 'project')),
          ).captured.single
          as ProjectEntry;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    persistence = MockPersistenceLogic();
    journalDb = MockJournalDb();
    projects = MockProjectRepository();
    handler = TaskProjectCreateHandler(
      persistenceLogic: persistence,
      journalDb: journalDb,
      projectRepository: projects,
    );

    stubMetadata();
    when(
      () => projects.getProjectsForCategory(any()),
    ).thenAnswer((_) async => const []);
    when(
      () => projects.createProject(project: any(named: 'project')),
    ).thenAnswer(
      (invocation) async => invocation.namedArguments[#project] as ProjectEntry,
    );
    when(
      () => projects.linkTaskToProject(
        projectId: any(named: 'projectId'),
        taskId: any(named: 'taskId'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => journalDb.journalEntityMapForIdsIncludingDeleted(any()),
    ).thenAnswer((_) async => const {});
    when(
      () => journalDb.journalEntityById(any()),
    ).thenAnswer((_) async => null);
  });

  group('normalizeProjectTitle', () {
    test('trims, collapses inner whitespace and keeps the spelling', () {
      expect(normalizeProjectTitle('  Igloo \t  Repairs\n'), 'Igloo Repairs');
      expect(normalizeProjectTitle('iPhone App'), 'iPhone App');
    });

    test('is null for nothing a project could be named', () {
      expect(normalizeProjectTitle(null), isNull);
      expect(normalizeProjectTitle(42), isNull);
      expect(normalizeProjectTitle(' \n '), isNull);
    });

    test('projectTitleKey ignores case and whitespace, nothing else', () {
      expect(
        projectTitleKey(' Igloo   REPAIRS'),
        projectTitleKey('igloo repairs'),
      );
      expect(
        projectTitleKey('Igloo Repairs'),
        isNot(projectTitleKey('Igloo Repair')),
      );
    });
  });

  group('handle', () {
    test(
      "creates the project active, in the task's category, named as given, "
      'and moves the task into it',
      () async {
        final result = await withClock(
          Clock.fixed(now),
          () => handler.handle(makeTask(), {'title': ' Igloo  Repairs '}),
        );

        expect(result.success, isTrue, reason: result.output);
        final created = capturedProject();
        expect(created.data.title, 'Igloo Repairs');
        expect(created.meta.categoryId, 'cat-penguins');
        expect(created.data.status, isA<ProjectActive>());
        expect(created.data.status.createdAt, now);
        expect(created.data.dateFrom, now);
        expect(result.mutatedEntityId, created.meta.id);
        expect(result.output, startsWith('Created active project'));
        verify(
          () => projects.linkTaskToProject(
            projectId: created.meta.id,
            taskId: 'task-igloo',
          ),
        ).called(1);
      },
    );

    test(
      "gives a private task's project the private flag, or the link would be "
      'refused',
      () async {
        await handler.handle(makeTask(private: true), {'title': 'Den Watch'});

        expect(capturedProject().meta.private, isTrue);
      },
    );

    test('derives the id from a confirmed change item', () async {
      const effect = ChangeEffect(key: 'set-1:0:confirmed');

      final result = await handler.handle(
        makeTask(),
        {'title': 'Igloo Repairs'},
        effect: effect,
      );

      expect(
        result.mutatedEntityId,
        'derived:${effect.entityInput(TaskProjectCreateHandler.projectRole)}',
      );
    });

    test(
      'joins a same-titled project of the category instead of creating one',
      () async {
        when(() => projects.getProjectsForCategory('cat-penguins')).thenAnswer(
          (_) async => [project('project-igloo', 'igloo  repairs')],
        );

        final result = await handler.handle(makeTask(), {
          'title': 'Igloo Repairs',
        });

        expect(result.success, isTrue);
        expect(result.mutatedEntityId, 'project-igloo');
        expect(result.output, contains('already exists'));
        verifyNever(
          () => projects.createProject(project: any(named: 'project')),
        );
        verify(
          () => projects.linkTaskToProject(
            projectId: 'project-igloo',
            taskId: 'task-igloo',
          ),
        ).called(1);
      },
    );

    test(
      'does not join a same-titled project of the other privacy, which the '
      'task could not be linked to',
      () async {
        when(() => projects.getProjectsForCategory('cat-penguins')).thenAnswer(
          (_) async => [
            project('project-hidden', 'Igloo Repairs', private: true),
          ],
        );

        final result = await handler.handle(makeTask(), {
          'title': 'Igloo Repairs',
        });

        expect(result.success, isTrue);
        expect(result.mutatedEntityId, isNot('project-hidden'));
        expect(capturedProject().meta.private, isFalse);
      },
    );

    group('an item applied before', () {
      const effect = ChangeEffect(key: 'set-1:0:confirmed');
      final projectId = effect.entityId(TaskProjectCreateHandler.projectRole);

      void stubEarlier(ProjectEntry earlier) {
        when(
          () => journalDb.journalEntityMapForIdsIncludingDeleted([projectId]),
        ).thenAnswer((_) async => {projectId: earlier});
        when(
          () => journalDb.journalEntityById(projectId),
        ).thenAnswer((_) async => earlier);
      }

      test('only completes the move into the project it created', () async {
        stubEarlier(project(projectId, 'Igloo Repairs'));

        final result = await handler.handle(
          makeTask(),
          {'title': 'Igloo Repairs'},
          effect: effect,
        );

        expect(result.success, isTrue);
        expect(result.mutatedEntityId, projectId);
        verifyNever(
          () => projects.createProject(project: any(named: 'project')),
        );
        verify(
          () => projects.linkTaskToProject(
            projectId: projectId,
            taskId: 'task-igloo',
          ),
        ).called(1);
      });

      test('leaves a project deleted since deleted, writing nothing', () async {
        stubEarlier(
          project(projectId, 'Igloo Repairs', deletedAt: DateTime(2026, 11)),
        );

        final result = await handler.handle(
          makeTask(),
          {'title': 'Igloo Repairs'},
          effect: effect,
        );

        expect(result.success, isTrue);
        expect(result.output, startsWith('Nothing applied'));
        verifyNever(
          () => projects.createProject(project: any(named: 'project')),
        );
        verifyNever(
          () => projects.linkTaskToProject(
            projectId: any(named: 'projectId'),
            taskId: any(named: 'taskId'),
          ),
        );
      });
    });

    test(
      "moves the task into the other device's project when it arrives "
      'between the check and the insert',
      () async {
        const effect = ChangeEffect(key: 'set-1:0:confirmed');
        final projectId = effect.entityId(TaskProjectCreateHandler.projectRole);
        when(
          () => projects.createProject(project: any(named: 'project')),
        ).thenAnswer((_) async => null);
        when(
          () => journalDb.journalEntityById(projectId),
        ).thenAnswer((_) async => project(projectId, 'Igloo Repairs'));

        final result = await handler.handle(
          makeTask(),
          {'title': 'Igloo Repairs'},
          effect: effect,
        );

        expect(result.success, isTrue);
        expect(result.mutatedEntityId, projectId);
      },
    );

    test('reports a failed insert with nothing to fall back on', () async {
      when(
        () => projects.createProject(project: any(named: 'project')),
      ).thenAnswer((_) async => null);

      final result = await handler.handle(makeTask(), {
        'title': 'Igloo Repairs',
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Project creation failed');
      verifyNever(
        () => projects.linkTaskToProject(
          projectId: any(named: 'projectId'),
          taskId: any(named: 'taskId'),
        ),
      );
    });

    test(
      'fails a refused move, so the item stays pending and a retry only '
      'moves the task',
      () async {
        when(
          () => projects.linkTaskToProject(
            projectId: any(named: 'projectId'),
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer((_) async => false);

        final result = await handler.handle(makeTask(), {
          'title': 'Igloo Repairs',
        });

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Project link rejected');
        expect(result.output, contains('could not be moved'));
      },
    );

    test('rejects a blank title before touching anything', () async {
      final result = await handler.handle(makeTask(), {'title': '  '});

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Missing or empty title');
      verifyZeroInteractions(projects);
    });

    test('rejects a task with no category', () async {
      final result = await handler.handle(makeTask(categoryId: null), {
        'title': 'Igloo Repairs',
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Task has no category');
      verifyZeroInteractions(projects);
    });
  });
}
