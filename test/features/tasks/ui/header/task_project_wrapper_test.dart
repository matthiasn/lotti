import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/tasks/ui/header/task_project_widget.dart';
import 'package:lotti/features/tasks/ui/header/task_project_wrapper.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';

class _TestEntryController extends EntryController {
  _TestEntryController(this._entry);

  final JournalEntity _entry;

  @override
  Future<EntryState?> build({required String id}) async {
    return EntryState.saved(
      entryId: id,
      entry: _entry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2024, 3, 15);
  const taskId = 'task-wrapper-1';
  const categoryId = 'cat-wrapper-1';

  late MockProjectRepository mockProjectRepo;

  Task makeTask({String? catId}) {
    return JournalEntity.task(
          meta: Metadata(
            id: taskId,
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
            // ignore: avoid_redundant_argument_values
            vectorClock: null,
            categoryId: catId ?? categoryId,
          ),
          data: TaskData(
            title: 'Test Task',
            statusHistory: const [],
            status: TaskStatus.open(
              id: uuid.v1(),
              createdAt: now,
              utcOffset: 0,
            ),
            dateFrom: now,
            dateTo: now,
          ),
        )
        as Task;
  }

  ProjectEntry makeProject({required String id, required String title}) {
    return JournalEntity.project(
          meta: Metadata(
            id: id,
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
            // ignore: avoid_redundant_argument_values
            vectorClock: null,
            categoryId: categoryId,
          ),
          data: ProjectData(
            title: title,
            status: ProjectStatus.active(
              id: uuid.v1(),
              createdAt: now,
              utcOffset: 0,
            ),
            dateFrom: now,
            dateTo: now,
          ),
        )
        as ProjectEntry;
  }

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mockProjectRepo = MockProjectRepository();
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
          ..registerSingleton<EditorStateService>(MockEditorStateService());
      },
    );
  });

  tearDown(tearDownTestGetIt);

  group('TaskProjectWrapper', () {
    testWidgets('renders SizedBox.shrink when entry is not a Task', (
      tester,
    ) async {
      // Use a non-Task entry (text entry)
      final textEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: taskId,
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
          // ignore: avoid_redundant_argument_values
          vectorClock: null,
        ),
      );

      final overrides = <Override>[
        entryControllerProvider(id: taskId).overrideWith(
          () => _TestEntryController(textEntry),
        ),
      ];

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: overrides,
          child: const TaskProjectWrapper(taskId: taskId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should not render TaskProjectWidget when entry is not a Task
      expect(find.byType(TaskProjectWidget), findsNothing);
    });

    testWidgets('renders TaskProjectWidget when entry is a Task', (
      tester,
    ) async {
      final task = makeTask();
      final project = makeProject(id: 'proj-1', title: 'My Project');

      when(
        () => mockProjectRepo.linkTaskToProject(
          projectId: any(named: 'projectId'),
          taskId: any(named: 'taskId'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => mockProjectRepo.unlinkTaskFromProject(any()),
      ).thenAnswer((_) async => true);

      final overrides = <Override>[
        entryControllerProvider(id: taskId).overrideWith(
          () => _TestEntryController(task),
        ),
        projectForTaskProvider(taskId).overrideWith(
          (ref) async => project,
        ),
        projectRepositoryProvider.overrideWithValue(mockProjectRepo),
      ];

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: overrides,
          child: const TaskProjectWrapper(taskId: taskId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // TaskProjectWidget should show the project title
      expect(find.text('My Project'), findsOneWidget);
    });

    testWidgets('renders SizedBox.shrink during loading', (tester) async {
      final task = makeTask();
      final completer = Completer<ProjectEntry?>();

      final overrides = <Override>[
        entryControllerProvider(id: taskId).overrideWith(
          () => _TestEntryController(task),
        ),
        projectForTaskProvider(taskId).overrideWith(
          (ref) => completer.future,
        ),
        projectRepositoryProvider.overrideWithValue(mockProjectRepo),
      ];

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: overrides,
          child: const TaskProjectWrapper(taskId: taskId),
        ),
      );
      // Only pump once — the future is still loading
      await tester.pump();

      // During loading, projectAsync.when returns SizedBox.shrink
      expect(find.byType(TaskProjectWidget), findsNothing);

      // Complete the future to avoid timer assertions
      completer.complete(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('renders SizedBox.shrink on error', (tester) async {
      final task = makeTask();

      final overrides = <Override>[
        entryControllerProvider(id: taskId).overrideWith(
          () => _TestEntryController(task),
        ),
        projectForTaskProvider(taskId).overrideWith(
          (ref) => Future<ProjectEntry?>.error(Exception('DB error')),
        ),
        projectRepositoryProvider.overrideWithValue(mockProjectRepo),
      ];

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: overrides,
          child: const TaskProjectWrapper(taskId: taskId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // On error, projectAsync.when returns SizedBox.shrink
      expect(find.byType(TaskProjectWidget), findsNothing);
    });

    testWidgets('onSave calls linkTaskToProject when projectId is provided', (
      tester,
    ) async {
      final task = makeTask();
      final project = makeProject(id: 'proj-1', title: 'Link Project');

      when(
        () => mockProjectRepo.linkTaskToProject(
          projectId: any(named: 'projectId'),
          taskId: any(named: 'taskId'),
        ),
      ).thenAnswer((_) async => true);

      final overrides = <Override>[
        entryControllerProvider(id: taskId).overrideWith(
          () => _TestEntryController(task),
        ),
        projectForTaskProvider(taskId).overrideWith(
          (ref) async => project,
        ),
        projectsForCategoryProvider(categoryId).overrideWith(
          (ref) async => [project],
        ),
        projectRepositoryProvider.overrideWithValue(mockProjectRepo),
      ];

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: overrides,
          child: const TaskProjectWrapper(taskId: taskId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the project chip to open the modal
      await tester.tap(find.text('Link Project'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the project in the modal to select it (triggers onSave)
      final projectTiles = find.text('Link Project');
      // There may be multiple — tap the one in the modal list
      await tester.tap(projectTiles.last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(
        () => mockProjectRepo.linkTaskToProject(
          projectId: 'proj-1',
          taskId: taskId,
        ),
      ).called(1);
    });

    testWidgets('onSave calls unlinkTaskFromProject when null', (
      tester,
    ) async {
      final task = makeTask();
      final project = makeProject(id: 'proj-1', title: 'Unlink Project');

      when(
        () => mockProjectRepo.unlinkTaskFromProject(any()),
      ).thenAnswer((_) async => true);

      final overrides = <Override>[
        entryControllerProvider(id: taskId).overrideWith(
          () => _TestEntryController(task),
        ),
        projectForTaskProvider(taskId).overrideWith(
          (ref) async => project,
        ),
        projectsForCategoryProvider(categoryId).overrideWith(
          (ref) async => [project],
        ),
        projectRepositoryProvider.overrideWithValue(mockProjectRepo),
      ];

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: overrides,
          child: const TaskProjectWrapper(taskId: taskId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the project chip to open the modal
      await tester.tap(find.text('Unlink Project'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap "No project" to unlink
      await tester.tap(find.text('No project'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(
        () => mockProjectRepo.unlinkTaskFromProject(taskId),
      ).called(1);
    });

    testWidgets('renders TaskProjectWidget with no project assigned', (
      tester,
    ) async {
      final task = makeTask();

      final overrides = <Override>[
        entryControllerProvider(id: taskId).overrideWith(
          () => _TestEntryController(task),
        ),
        projectForTaskProvider(taskId).overrideWith(
          (ref) async => null,
        ),
        projectRepositoryProvider.overrideWithValue(mockProjectRepo),
      ];

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: overrides,
          child: const TaskProjectWrapper(taskId: taskId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should show "No project" unassigned label from TaskProjectWidget
      expect(find.byType(TaskProjectWrapper), findsOneWidget);
      expect(find.text('No project'), findsOneWidget);
    });
  });
}
