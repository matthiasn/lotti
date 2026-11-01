import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/tasks/state/task_project_suggestion_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_entry_controller.dart';
import '../../../helpers/service_overrides.dart';
import '../../../helpers/test_get_it.dart';
import '../../../mocks/mocks.dart';
import '../../projects/test_utils.dart';

const _categoryId = 'cat-1';
const _taskId = 'task-1';

final _created = DateTime(2024, 3, 15);

Task _task({
  String title = 'Prepare work presentation',
  String? categoryId = _categoryId,
  bool private = false,
  String body = '',
  List<String>? labelIds,
}) {
  final task = makeTestTask(id: _taskId, title: title, createdAt: _created);
  return task.copyWith(
    meta: task.meta.copyWith(
      categoryId: categoryId,
      private: private,
      labelIds: labelIds,
    ),
    entryText: body.isEmpty ? null : EntryText(plainText: body),
  );
}

ProjectEntry _project(
  String id,
  String title, {
  ProjectStatus? status,
  bool private = false,
}) {
  final project = makeTestProject(
    id: id,
    title: title,
    categoryId: _categoryId,
    status: status,
    createdAt: _created,
  );
  return project.copyWith(meta: project.meta.copyWith(private: private));
}

void main() {
  late MockProjectRepository repository;
  late MockEntitiesCacheService cache;
  late StreamController<Set<String>> updates;
  late SettingsDb settingsDb;

  final work = _project('work', 'Work');
  final home = _project('home', 'Home');

  setUp(() async {
    repository = MockProjectRepository();
    cache = MockEntitiesCacheService();
    updates = StreamController<Set<String>>.broadcast();
    settingsDb = SettingsDb(inMemoryDatabase: true);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<SettingsDb>()
          ..registerSingleton<SettingsDb>(settingsDb)
          // The fake entry controller's base class resolves it on creation.
          ..registerSingleton<EditorStateService>(MockEditorStateService());
      },
    );

    when(() => repository.updateStream).thenAnswer((_) => updates.stream);
    when(
      () => repository.getProjectsForCategory(_categoryId),
    ).thenAnswer((_) async => [work, home]);
    when(
      () => repository.getRecentTaskTitlesForProjects(
        any(),
        limitPerProject: any(named: 'limitPerProject'),
      ),
    ).thenAnswer((_) async => const {});
    when(
      () => repository.getProjectForTask(_taskId),
    ).thenAnswer((_) async => null);
    when(
      () => repository.getLinkedProjectForTask(_taskId),
    ).thenAnswer((_) async => null);
    when(() => cache.showPrivateEntries).thenReturn(true);
    when(() => cache.getLabelById(any())).thenReturn(null);
  });

  tearDown(() async {
    await updates.close();
    await tearDownTestGetIt();
    await settingsDb.close();
  });

  ProviderContainer makeContainer({Task? task, Override? entryOverride}) {
    final container = ProviderContainer(
      overrides: withServiceOverrides([
        projectRepositoryProvider.overrideWithValue(repository),
        entitiesCacheServiceProvider.overrideWithValue(cache),
        entryOverride ?? createEntryControllerOverride(task ?? _task()),
      ]),
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Reads the suggestion with a live subscription held, so the autoDispose
  /// chain it awaits is not torn down mid-load.
  Future<TaskProjectSuggestion?> readSuggestion(
    ProviderContainer container,
  ) {
    final subscription = container.listen(
      taskProjectSuggestionProvider(_taskId),
      (_, _) {},
    );
    addTearDown(subscription.close);
    return container.read(taskProjectSuggestionProvider(_taskId).future);
  }

  group('taskProjectSuggestionProvider', () {
    test("suggests the project an unassigned task's title is about", () async {
      final container = makeContainer();

      expect(
        await readSuggestion(container),
        const TaskProjectSuggestion(projectId: 'work', projectTitle: 'Work'),
      );
    });

    test('suggests nothing for a task that already has a project', () async {
      when(
        () => repository.getProjectForTask(_taskId),
      ).thenAnswer((_) async => home);
      final container = makeContainer();

      expect(await readSuggestion(container), isNull);
    });

    test('suggests nothing for a task linked to a project the private gate '
        'hides', () async {
      when(
        () => repository.getLinkedProjectForTask(_taskId),
      ).thenAnswer((_) async => _project('secret', 'Work', private: true));
      final container = makeContainer();

      expect(await readSuggestion(container), isNull);
    });

    test('suggests nothing and reads no projects for a task without a '
        'category', () async {
      final container = makeContainer(task: _task(categoryId: null));

      expect(await readSuggestion(container), isNull);
      verifyNever(() => repository.getProjectsForCategory(any()));
    });

    test('never suggests a completed or archived project', () async {
      final now = DateTime(2024, 3, 15);
      when(() => repository.getProjectsForCategory(_categoryId)).thenAnswer(
        (_) async => [
          _project(
            'done',
            'Work',
            status: ProjectStatus.completed(
              id: 's1',
              createdAt: now,
              utcOffset: 0,
            ),
          ),
          _project(
            'old',
            'Work archive',
            status: ProjectStatus.archived(
              id: 's2',
              createdAt: now,
              utcOffset: 0,
            ),
          ),
          home,
        ],
      );
      final container = makeContainer();

      expect(await readSuggestion(container), isNull);
    });

    test('never suggests a project of the other privacy — the repository '
        'would refuse the link', () async {
      when(() => repository.getProjectsForCategory(_categoryId)).thenAnswer(
        (_) async => [_project('work', 'Work', private: true), home],
      );

      expect(await readSuggestion(makeContainer()), isNull);
      expect(
        await readSuggestion(makeContainer(task: _task(private: true))),
        const TaskProjectSuggestion(projectId: 'work', projectTitle: 'Work'),
      );
    });

    test(
      'learns a project from the titles of the tasks already in it',
      () async {
        when(
          () => repository.getRecentTaskTitlesForProjects(
            {'work', 'home'},
            limitPerProject: maxHistoryTitlesPerProject,
          ),
        ).thenAnswer(
          (_) async => {
            'home': [
              'Order mulch',
              'Prune roses',
              'Water roses',
              'Order seeds',
            ],
          },
        );
        final container = makeContainer(
          task: _task(title: 'Order roses fertilizer'),
        );

        expect((await readSuggestion(container))?.projectId, 'home');
      },
    );

    test(
      "reads the task's body and visible labels, not hidden ones",
      () async {
        when(() => cache.getLabelById('lbl-home')).thenReturn(
          LabelDefinition(
            id: 'lbl-home',
            name: 'Home',
            color: '#000000',
            createdAt: _created,
            updatedAt: _created,
            vectorClock: null,
            private: true,
          ),
        );

        final fromBody = makeContainer(
          task: _task(title: 'Call the plumber', body: 'about the home boiler'),
        );
        expect((await readSuggestion(fromBody))?.projectId, 'home');

        final fromLabel = makeContainer(
          task: _task(title: 'Call the plumber', labelIds: const ['lbl-home']),
        );
        expect((await readSuggestion(fromLabel))?.projectId, 'home');

        when(() => cache.showPrivateEntries).thenReturn(false);
        final hiddenLabel = makeContainer(
          task: _task(title: 'Call the plumber', labelIds: const ['lbl-home']),
        );
        expect(await readSuggestion(hiddenLabel), isNull);
      },
    );

    test('a title edit re-ranks the task — the suggestion appears once the '
        'title names its topic', () async {
      final container = makeContainer(
        entryOverride: entryControllerProvider(_taskId).overrideWith(
          () => TitleSavingFakeEntryController(_task(title: '')),
        ),
      );
      expect(await readSuggestion(container), isNull);

      await container
          .read(entryControllerProvider(_taskId).notifier)
          .save(title: 'Prepare work presentation');

      expect(
        await container.read(taskProjectSuggestionProvider(_taskId).future),
        const TaskProjectSuggestion(projectId: 'work', projectTitle: 'Work'),
      );
    });

    test('disappears once the task is linked — the link notification '
        're-reads its project', () async {
      final container = makeContainer();
      expect((await readSuggestion(container))?.projectId, 'work');

      when(
        () => repository.getProjectForTask(_taskId),
      ).thenAnswer((_) async => work);
      updates.add({_taskId, projectNotification});
      await pumpEventQueue();

      expect(
        await container.read(taskProjectSuggestionProvider(_taskId).future),
        isNull,
      );
    });

    test('a dismissed project is not suggested again for that task, and the '
        'runner-up does not step in', () async {
      // "Presentation skills" clears the threshold on its own; only the
      // stronger "Work presentation" keeps it from being the suggestion.
      when(() => repository.getProjectsForCategory(_categoryId)).thenAnswer(
        (_) async => [
          _project('slides', 'Work presentation'),
          _project('skills', 'Presentation skills'),
          home,
        ],
      );
      final container = makeContainer();
      expect((await readSuggestion(container))?.projectId, 'slides');

      await container
          .read(taskProjectSuggestionDismissalsProvider(_taskId).notifier)
          .dismiss('slides');

      expect(
        await container.read(taskProjectSuggestionProvider(_taskId).future),
        isNull,
      );
    });

    test('a different title earns a suggestion for a different project after '
        'a dismissal', () async {
      final container = makeContainer(
        entryOverride: entryControllerProvider(_taskId).overrideWith(
          () => TitleSavingFakeEntryController(_task()),
        ),
      );
      expect((await readSuggestion(container))?.projectId, 'work');
      await container
          .read(taskProjectSuggestionDismissalsProvider(_taskId).notifier)
          .dismiss('work');

      await container
          .read(entryControllerProvider(_taskId).notifier)
          .save(title: 'Fix the home heating');

      expect(
        (await container.read(
          taskProjectSuggestionProvider(_taskId).future,
        ))?.projectId,
        'home',
      );
    });
  });

  group('TaskProjectSuggestionDismissals', () {
    test('a dismissal survives a restart, and only for its own task', () async {
      final first = makeContainer();
      await first
          .read(taskProjectSuggestionDismissalsProvider(_taskId).notifier)
          .dismiss('work');
      first.dispose();

      expect(
        await settingsDb.itemByKey(taskProjectSuggestionDismissedKey(_taskId)),
        '["work"]',
      );

      final second = makeContainer();
      expect(await readSuggestion(second), isNull);
      expect(
        await second.read(
          taskProjectSuggestionDismissalsProvider('other-task').future,
        ),
        isEmpty,
      );
    });

    test('a write that fails after its provider was disposed is still '
        'logged — the page that dismissed may close mid-write', () async {
      final gatedDb = MockSettingsDb();
      final write = Completer<int>();
      when(() => gatedDb.itemByKey(any())).thenAnswer((_) async => null);
      when(
        () => gatedDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) => write.future);
      final logger = MockDomainLogger();
      final container = ProviderContainer(
        overrides: [
          settingsDbProvider.overrideWithValue(gatedDb),
          domainLoggerProvider.overrideWithValue(logger),
        ],
      );
      addTearDown(container.dispose);
      final provider = taskProjectSuggestionDismissalsProvider(_taskId);
      final subscription = container.listen(provider, (_, _) {});
      await container.read(provider.future);

      final dismissal = container.read(provider.notifier).dismiss('work');
      subscription.close();
      await container.pump();
      expect(container.exists(provider), isFalse);

      write.completeError(StateError('disk full'));
      await dismissal;

      verify(
        () => gatedDb.saveSettingsItem(
          taskProjectSuggestionDismissedKey(_taskId),
          '["work"]',
        ),
      ).called(1);
      verify(
        () => logger.error(
          LogDomain.settings,
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'taskProjectSuggestionDismissals.persist',
        ),
      ).called(1);
    });

    test('dismissing the same project twice writes one entry', () async {
      final container = makeContainer();
      final notifier = container.read(
        taskProjectSuggestionDismissalsProvider(_taskId).notifier,
      );
      await notifier.dismiss('work');
      await notifier.dismiss('home');
      await notifier.dismiss('work');

      expect(
        await settingsDb.itemByKey(taskProjectSuggestionDismissedKey(_taskId)),
        '["home","work"]',
      );
    });

    test('a corrupt record reads as nothing dismissed', () async {
      await settingsDb.saveSettingsItem(
        taskProjectSuggestionDismissedKey(_taskId),
        '{not json',
      );
      final container = makeContainer();

      expect(
        await container.read(
          taskProjectSuggestionDismissalsProvider(_taskId).future,
        ),
        isEmpty,
      );
      expect((await readSuggestion(container))?.projectId, 'work');
    });

    test('a failed read or write is logged and leaves the in-memory state '
        'working', () async {
      final failing = MockSettingsDb();
      when(
        () => failing.itemByKey(any()),
      ).thenAnswer((_) => Future.error(StateError('read failed')));
      when(
        () => failing.saveSettingsItem(any(), any()),
      ).thenAnswer((_) => Future.error(StateError('write failed')));
      final logger = MockDomainLogger();
      final container = ProviderContainer(
        overrides: [
          settingsDbProvider.overrideWithValue(failing),
          domainLoggerProvider.overrideWithValue(logger),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        taskProjectSuggestionDismissalsProvider(_taskId),
        (_, _) {},
      );
      addTearDown(subscription.close);

      expect(
        await container.read(
          taskProjectSuggestionDismissalsProvider(_taskId).future,
        ),
        isEmpty,
      );
      await container
          .read(taskProjectSuggestionDismissalsProvider(_taskId).notifier)
          .dismiss('work');

      expect(
        container.read(taskProjectSuggestionDismissalsProvider(_taskId)).value,
        {'work'},
      );
      final logged = verify(
        () => logger.error(
          any(),
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: captureAny(named: 'subDomain'),
        ),
      ).captured;
      expect(logged, [
        'taskProjectSuggestionDismissals.load',
        'taskProjectSuggestionDismissals.persist',
      ]);
    });
  });

  group('isSuggestibleProject', () {
    test('only open, active, monitoring and on-hold projects qualify', () {
      final now = DateTime(2024, 3, 15);
      ProjectEntry withStatus(ProjectStatus status) =>
          _project('p', 'P', status: status);

      expect(
        isSuggestibleProject(
          withStatus(ProjectStatus.open(id: 's', createdAt: now, utcOffset: 0)),
        ),
        isTrue,
      );
      expect(
        isSuggestibleProject(
          withStatus(
            ProjectStatus.onHold(
              id: 's',
              createdAt: now,
              utcOffset: 0,
              reason: 'waiting',
            ),
          ),
        ),
        isTrue,
      );
      expect(
        isSuggestibleProject(
          withStatus(
            ProjectStatus.completed(id: 's', createdAt: now, utcOffset: 0),
          ),
        ),
        isFalse,
      );
    });
  });
}
