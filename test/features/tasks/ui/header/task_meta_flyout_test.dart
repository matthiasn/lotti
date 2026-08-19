import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/project_selection_modal_content.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_flyout.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/picker/entity_picker_sheet.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../ai_consumption/test_utils.dart';

class _FakeTaskProgressController extends TaskProgressController {
  _FakeTaskProgressController(this._state);

  final TaskProgressState? _state;

  @override
  Future<TaskProgressState?> build() async => _state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockEntitiesCacheService mockCache;
  late MockJournalDb mockJournalDb;
  late MockUpdateNotifications mockUpdateNotifications;

  final now = DateTime(2026, 4, 20, 12);

  setUp(() async {
    mockCache = MockEntitiesCacheService();
    mockJournalDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();

    when(
      () => mockJournalDb.typedLinksForTaskIds(
        any(),
        types: any(named: 'types'),
      ),
    ).thenAnswer((_) async => <EntryLink>[]);
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());
    when(() => mockCache.showPrivateEntries).thenReturn(true);
    when(() => mockCache.getCategoryById(any())).thenReturn(null);
    when(() => mockCache.getLabelById(any())).thenReturn(null);
    when(
      () => mockCache.sortedCategories,
    ).thenReturn(const <CategoryDefinition>[]);
    when(() => mockCache.sortedLabels).thenReturn(const <LabelDefinition>[]);
    when(
      () => mockCache.filterLabelsForCategory(any(), any()),
    ).thenAnswer(
      (invocation) =>
          invocation.positionalArguments.first as List<LabelDefinition>,
    );

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockJournalDb)
          ..unregister<UpdateNotifications>()
          ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
          ..registerSingleton<EntitiesCacheService>(mockCache)
          ..registerSingleton<EditorStateService>(MockEditorStateService())
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
          // TaskProgressController resolves TimeService in a field
          // initialiser, so the estimate-adjacent rows need it registered
          // even when it is never exercised.
          ..registerSingleton<TimeService>(MockTimeService())
          ..registerSingleton<NavService>(MockNavService());
      },
    );
  });

  tearDown(tearDownTestGetIt);

  Task buildTask({
    String id = 'task-1',
    String? categoryId,
    DateTime? due,
    TaskStatus? status,
    Duration? estimate,
    List<String>? labelIds,
    TaskPriority priority = TaskPriority.p2Medium,
  }) {
    return Task(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
        categoryId: categoryId,
        labelIds: labelIds,
      ),
      data: TaskData(
        status:
            status ??
            TaskStatus.open(id: 'status-1', createdAt: now, utcOffset: 0),
        dateFrom: now,
        dateTo: now,
        statusHistory: const [],
        title: 'Test Task',
        due: due,
        estimate: estimate,
        priority: priority,
      ),
    );
  }

  LabelDefinition buildLabel({required String id, required String name}) {
    return LabelDefinition(
      id: id,
      createdAt: now,
      updatedAt: now,
      name: name,
      color: '#112233',
      vectorClock: null,
    );
  }

  Widget pumpFlyout({
    required Task task,
    ToggleCallTracker? tracker,
    ProjectEntry? project,
    TaskProgressState? progress,
    int aiCallCount = 0,
    List<Override> extraOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        entryControllerProvider(task.id).overrideWith(
          () => FakeEntryController(task, tracker: tracker),
        ),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value(const []),
        ),
        projectForTaskProvider(task.id).overrideWith((ref) async => project),
        taskProgressControllerProvider(task.id).overrideWith(
          () => _FakeTaskProgressController(progress),
        ),
        taskConsumptionTotalsProvider(task.id).overrideWith(
          (ref) => Stream.value(
            makeConsumptionTotals(
              callCount: aiCallCount,
              impactCallCount: aiCallCount,
              credits: aiCallCount > 0 ? 0.35 : 0,
              energyKwh: aiCallCount > 0 ? 0.078 : 0,
              carbonGCo2: aiCallCount > 0 ? 15 : 0,
            ),
          ),
        ),
        ...extraOverrides,
      ],
      child: MaterialApp(
        theme: DesignSystemTheme.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          FormBuilderLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TaskMetaFlyoutContent(taskId: task.id),
          ),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('TaskMetaFlyoutContent — rows and values', () {
    testWidgets('renders every field as a descriptive label + value pair', (
      tester,
    ) async {
      final task = buildTask(
        due: DateTime(2026, 4, 25),
        estimate: const Duration(hours: 2),
      );

      await tester.pumpWidget(pumpFlyout(task: task));
      await settle(tester);

      // Descriptive labels.
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Priority'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Due date'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('Labels'), findsOneWidget);
      // Values.
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Apr 25, 2026'), findsOneWidget);
      expect(find.text('0m of 2h'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('unset fields read "Not set" at low emphasis', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(pumpFlyout(task: task));
      await settle(tester);

      // Category, due date, time and labels are all unset.
      expect(find.text('Not set'), findsNWidgets(4));
      final context = tester.element(find.text('Not set').first);
      final text = tester.widget<Text>(find.text('Not set').first);
      expect(text.style?.color, TaskShowcasePalette.lowText(context));
      // No estimate → no progress bar.
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('renders the category name with its colour dot', (
      tester,
    ) async {
      when(() => mockCache.getCategoryById('cat-1')).thenReturn(
        CategoryDefinition(
          id: 'cat-1',
          createdAt: now,
          updatedAt: now,
          name: 'Work',
          color: '#FF0000',
          vectorClock: null,
          private: false,
          active: true,
        ),
      );
      final task = buildTask(categoryId: 'cat-1');

      await tester.pumpWidget(pumpFlyout(task: task));
      await settle(tester);

      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('shows no project row while the task has no category', (
      tester,
    ) async {
      await tester.pumpWidget(pumpFlyout(task: buildTask()));
      await settle(tester);
      expect(find.text('Project'), findsNothing);
    });

    testWidgets(
      'shows the project row once a category is set, naming the linked '
      'project',
      (tester) async {
        when(() => mockCache.getCategoryById('cat-1')).thenReturn(
          CategoryDefinition(
            id: 'cat-1',
            createdAt: now,
            updatedAt: now,
            name: 'Work',
            color: '#FF0000',
            vectorClock: null,
            private: false,
            active: true,
          ),
        );
        final project = ProjectEntry(
          meta: Metadata(
            id: 'project-1',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          data: ProjectData(
            title: 'Alpha',
            status: ProjectStatus.active(
              id: 'ps',
              createdAt: now,
              utcOffset: 0,
            ),
            dateFrom: now,
            dateTo: now,
          ),
        );
        await tester.pumpWidget(
          pumpFlyout(
            task: buildTask(id: 'task-2', categoryId: 'cat-1'),
            project: project,
          ),
        );
        await settle(tester);
        expect(find.text('Project'), findsOneWidget);
        expect(find.text('Alpha'), findsOneWidget);
      },
    );

    testWidgets('joins label names, compressing the tail into "+N"', (
      tester,
    ) async {
      for (final entry in {
        'lbl-a': 'Alpha',
        'lbl-b': 'Beta',
        'lbl-c': 'Gamma',
        'lbl-d': 'Delta',
      }.entries) {
        when(
          () => mockCache.getLabelById(entry.key),
        ).thenReturn(buildLabel(id: entry.key, name: entry.value));
      }
      final task = buildTask(
        labelIds: const ['lbl-a', 'lbl-b', 'lbl-c', 'lbl-d'],
      );

      await tester.pumpWidget(pumpFlyout(task: task));
      await settle(tester);

      // Alphabetical, three named, one compressed.
      expect(find.text('Alpha, Beta, Delta +1'), findsOneWidget);
    });

    testWidgets('hides private labels when showPrivateEntries is false', (
      tester,
    ) async {
      when(() => mockCache.showPrivateEntries).thenReturn(false);
      when(
        () => mockCache.getLabelById('lbl-public'),
      ).thenReturn(buildLabel(id: 'lbl-public', name: 'Public'));
      when(() => mockCache.getLabelById('lbl-private')).thenReturn(
        LabelDefinition(
          id: 'lbl-private',
          createdAt: now,
          updatedAt: now,
          name: 'Private',
          color: '#112233',
          vectorClock: null,
          private: true,
        ),
      );
      final task = buildTask(labelIds: const ['lbl-public', 'lbl-private']);

      await tester.pumpWidget(pumpFlyout(task: task));
      await settle(tester);

      expect(find.text('Public'), findsOneWidget);
      expect(find.textContaining('Private'), findsNothing);
    });

    testWidgets(
      'time row shows tracked-of-estimated in error ink when overtime',
      (tester) async {
        final task = buildTask(estimate: const Duration(hours: 1));

        await tester.pumpWidget(
          pumpFlyout(
            task: task,
            progress: const TaskProgressState(
              progress: Duration(hours: 2),
              estimate: Duration(hours: 1),
            ),
          ),
        );
        await settle(tester);

        expect(find.text('2h of 1h'), findsOneWidget);
        final context = tester.element(find.text('2h of 1h'));
        final text = tester.widget<Text>(find.text('2h of 1h'));
        expect(text.style?.color, TaskShowcasePalette.error(context));
      },
    );

    testWidgets('overdue due dates read in the error colour', (tester) async {
      final task = buildTask(due: DateTime(2026, 4, 10));

      await tester.pumpWidget(pumpFlyout(task: task));
      await settle(tester);

      final finder = find.text('Apr 10, 2026');
      expect(finder, findsOneWidget);
      final context = tester.element(finder);
      final text = tester.widget<Text>(finder);
      expect(text.style?.color, TaskShowcasePalette.error(context));
    });

    testWidgets(
      'a done task never paints its past due date as overdue',
      (tester) async {
        final task = buildTask(
          due: DateTime(2026, 4, 10),
          status: TaskStatus.done(id: 'sd', createdAt: now, utcOffset: 0),
        );

        await tester.pumpWidget(pumpFlyout(task: task));
        await settle(tester);

        final text = tester.widget<Text>(find.text('Apr 10, 2026'));
        final context = tester.element(find.text('Apr 10, 2026'));
        expect(text.style?.color, TaskShowcasePalette.highText(context));
      },
    );
  });

  group('TaskMetaFlyoutContent — AI spend row', () {
    testWidgets('hidden entirely for tasks without recorded AI calls', (
      tester,
    ) async {
      await tester.pumpWidget(pumpFlyout(task: buildTask()));
      await settle(tester);

      expect(find.text('AI spend'), findsNothing);
    });

    testWidgets(
      'renders the consumption read-out with no edit chevron when calls '
      'are recorded',
      (tester) async {
        await tester.pumpWidget(
          pumpFlyout(task: buildTask(), aiCallCount: 3),
        );
        await settle(tester);

        expect(find.text('AI spend'), findsOneWidget);
        // A fact, not a setting: the row is not tappable.
        final row = tester.widget<TaskMetaFieldRow>(
          find.ancestor(
            of: find.text('AI spend'),
            matching: find.byType(TaskMetaFieldRow),
          ),
        );
        expect(row.onTap, isNull);
      },
    );
  });

  group('TaskMetaFlyoutContent — editing through the rows', () {
    testWidgets('the status row opens the status picker and persists', (
      tester,
    ) async {
      final tracker = ToggleCallTracker();
      await tester.pumpWidget(
        pumpFlyout(task: buildTask(), tracker: tracker),
      );
      await settle(tester);

      await tester.tap(find.text('Status'));
      await settle(tester);
      await tester.tap(find.text('In Progress'));
      await settle(tester);

      expect(tracker.updateTaskStatusCalls, hasLength(1));
    });

    testWidgets('the priority row opens the picker and persists', (
      tester,
    ) async {
      final tracker = ToggleCallTracker();
      await tester.pumpWidget(
        pumpFlyout(task: buildTask(), tracker: tracker),
      );
      await settle(tester);

      await tester.tap(find.text('Priority'));
      await settle(tester);
      expect(find.text('Select priority'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('task-priority-P0')));
      await settle(tester);

      expect(tracker.updateTaskPriorityCalls, equals(['P0']));
    });

    testWidgets('the due date row opens the picker; Done saves a date', (
      tester,
    ) async {
      final tracker = ToggleCallTracker();
      await tester.pumpWidget(
        pumpFlyout(task: buildTask(), tracker: tracker),
      );
      await settle(tester);

      await tester.tap(find.text('Due date'));
      await settle(tester);
      await tester.tap(find.text('Done'));
      await settle(tester);

      expect(tracker.saveCalls, hasLength(1));
      expect(tracker.saveCalls.single['dueDate'], isA<DateTime>());
    });

    testWidgets('the time row opens the estimate picker', (tester) async {
      final tracker = ToggleCallTracker();
      await tester.pumpWidget(
        pumpFlyout(task: buildTask(), tracker: tracker),
      );
      await settle(tester);

      await tester.tap(find.text('Time'));
      await settle(tester);

      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('the project row opens the project picker', (tester) async {
      when(() => mockCache.getCategoryById('cat-1')).thenReturn(
        CategoryDefinition(
          id: 'cat-1',
          createdAt: now,
          updatedAt: now,
          name: 'Work',
          color: '#FF0000',
          vectorClock: null,
          private: false,
          active: true,
        ),
      );
      final projectRepo = MockProjectRepository();
      when(
        () => projectRepo.updateStream,
      ).thenAnswer((_) => const Stream<Set<String>>.empty());

      final task = buildTask(categoryId: 'cat-1');
      await tester.pumpWidget(
        pumpFlyout(
          task: task,
          extraOverrides: [
            projectRepositoryProvider.overrideWithValue(projectRepo),
            projectsForCategoryProvider(
              'cat-1',
            ).overrideWith((ref) async => const []),
          ],
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Project'));
      await settle(tester);

      expect(find.byType(ProjectSelectionModalContent), findsOneWidget);
    });

    testWidgets('the labels row opens the label selector', (tester) async {
      await tester.pumpWidget(pumpFlyout(task: buildTask()));
      await settle(tester);

      await tester.tap(find.text('Labels'));
      await settle(tester);

      expect(find.byType(EntityPickerSheet), findsOneWidget);
    });
  });

  group('TaskMetaFlyoutContent — guards', () {
    testWidgets('renders nothing for a non-task entry', (tester) async {
      final note = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'note-1',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryControllerProvider('note-1').overrideWith(
              () => FakeEntryController(note),
            ),
            labelsStreamProvider.overrideWith(
              (ref) => Stream<List<LabelDefinition>>.value(const []),
            ),
          ],
          child: MaterialApp(
            theme: DesignSystemTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: TaskMetaFlyoutContent(taskId: 'note-1'),
            ),
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Status'), findsNothing);
    });
  });
}
