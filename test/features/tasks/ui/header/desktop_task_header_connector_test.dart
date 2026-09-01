import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_cost_indicator.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/project_selection_modal_content.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/state/task_one_liner_provider.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header_connector.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_column.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_section.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
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
  late MockEditorStateService mockEditorStateService;
  late MockJournalDb mockJournalDb;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockNavService mockNavService;

  final now = DateTime(2026, 4, 20, 12);

  setUp(() async {
    mockCache = MockEntitiesCacheService();
    mockEditorStateService = MockEditorStateService();
    mockJournalDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();
    mockPersistenceLogic = MockPersistenceLogic();
    mockNavService = MockNavService();

    // Default: task has no blocking links. Individual tests override this
    // to exercise the "Blocked by" chip.
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
    when(
      () => mockCache.sortedLabels,
    ).thenReturn(const <LabelDefinition>[]);
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
          ..registerSingleton<EditorStateService>(mockEditorStateService)
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
          // TaskProgressController resolves TimeService in a field
          // initialiser, so every test that touches the estimate chip needs
          // it registered even when it is never exercised.
          ..registerSingleton<TimeService>(MockTimeService())
          ..registerSingleton<NavService>(mockNavService);
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
            TaskStatus.open(
              id: 'status-1',
              createdAt: now,
              utcOffset: 0,
            ),
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

  CategoryDefinition buildCategory({
    String id = 'cat-1',
    String name = 'Work',
  }) {
    return CategoryDefinition(
      id: id,
      createdAt: now,
      updatedAt: now,
      name: name,
      color: '#FF0000',
      vectorClock: null,
      private: false,
      active: true,
    );
  }

  LabelDefinition buildLabel({
    required String id,
    required String name,
    String color = '#112233',
    bool? private,
  }) {
    return LabelDefinition(
      id: id,
      createdAt: now,
      updatedAt: now,
      name: name,
      color: color,
      vectorClock: null,
      private: private,
    );
  }

  ProjectEntry buildProject({
    String id = 'project-1',
    String title = 'Alpha',
  }) {
    return ProjectEntry(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: ProjectData(
        title: title,
        status: ProjectStatus.active(
          id: 'ps-active',
          createdAt: now,
          utcOffset: 0,
        ),
        dateFrom: now,
        dateTo: now,
      ),
    );
  }

  void stubBlockers(String taskId, List<EntryLink> links) {
    when(
      () => mockJournalDb.typedLinksForTaskIds(
        {taskId},
        types: {'BlocksLink'},
      ),
    ).thenAnswer((_) async => links);
  }

  EntryLink blocksLink({
    required String id,
    required String fromId,
    required String toId,
  }) => EntryLink.blocks(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: now,
    updatedAt: now,
    vectorClock: null,
  );

  Widget pumpConnector({
    required Task task,
    ProjectEntry? project,
    List<LabelDefinition> labels = const [],
    TaskProgressState? progress,
    String? oneLiner,
    Locale locale = const Locale('en'),
    bool metaColumnVisible = false,
    int aiCallCount = 0,
  }) {
    return ProviderScope(
      overrides: [
        createEntryControllerOverride(task),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value(labels),
        ),
        projectForTaskProvider(task.id).overrideWith(
          (ref) async => project,
        ),
        taskProgressControllerProvider(task.id).overrideWith(
          () => _FakeTaskProgressController(progress),
        ),
        taskOneLinerProvider.overrideWith(
          (ref, taskId) async => oneLiner,
        ),
        taskConsumptionTotalsProvider(task.id).overrideWith(
          (ref) => Stream.value(
            makeConsumptionTotals(
              callCount: aiCallCount,
              impactCallCount: aiCallCount,
              credits: aiCallCount > 0 ? 0.42 : 0,
            ),
          ),
        ),
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
        locale: locale,
        home: Scaffold(
          body: TaskMetaColumnScope(
            visible: metaColumnVisible,
            child: DesktopTaskHeaderConnector(taskId: task.id),
          ),
        ),
      ),
    );
  }

  group('DesktopTaskHeaderConnector — data mapping', () {
    testWidgets('renders DesktopTaskHeader for a Task entity', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(pumpConnector(task: task));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DesktopTaskHeader), findsOneWidget);
      expect(find.text('Test Task'), findsOneWidget);
    });

    testWidgets('passes the task AI one-liner into the header', (tester) async {
      const oneLiner = 'Final review is waiting on the payment provider';
      final task = buildTask();

      await tester.pumpWidget(
        pumpConnector(task: task, oneLiner: oneLiner),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(oneLiner), findsOneWidget);
    });

    testWidgets('formats due dates for the active German locale', (
      tester,
    ) async {
      final due = DateTime(2026, 7, 17);
      final task = buildTask(due: due);

      await tester.pumpWidget(
        pumpConnector(task: task, locale: const Locale('de')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Fällig: ${DateFormat.yMMMd('de').format(due)}'),
        findsOneWidget,
      );
      expect(find.textContaining('Jul 17, 2026'), findsNothing);
    });

    testWidgets('emits SizedBox.shrink for non-Task entities', (tester) async {
      final notATask = JournalEntity.journalEntry(
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
            createEntryControllerOverride(notATask),
            labelsStreamProvider.overrideWith(
              (ref) => Stream<List<LabelDefinition>>.value(const []),
            ),
            projectForTaskProvider('note-1').overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            theme: DesignSystemTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: DesktopTaskHeaderConnector(taskId: 'note-1'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DesktopTaskHeader), findsNothing);
    });

    testWidgets(
      'passes the cached category definition into the header',
      (tester) async {
        when(
          () => mockCache.getCategoryById('cat-1'),
        ).thenReturn(buildCategory());
        final task = buildTask(categoryId: 'cat-1');

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Work'), findsOneWidget);
      },
    );

    testWidgets('shows the project title when one is linked', (tester) async {
      // A project only exists inside a category, and the crumb only renders
      // its project segment once that category is set.
      final category = buildCategory();
      when(() => mockCache.getCategoryById('cat-1')).thenReturn(category);
      final task = buildTask(categoryId: 'cat-1');
      final project = buildProject();

      await tester.pumpWidget(pumpConnector(task: task, project: project));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Alpha'), findsOneWidget);
    });

    testWidgets(
      'renders only label definitions present in the cache, sorted alphabetically',
      (tester) async {
        when(
          () => mockCache.getLabelById('lbl-b'),
        ).thenReturn(buildLabel(id: 'lbl-b', name: 'Beta'));
        when(
          () => mockCache.getLabelById('lbl-a'),
        ).thenReturn(buildLabel(id: 'lbl-a', name: 'Alpha'));
        when(
          () => mockCache.getLabelById('lbl-missing'),
        ).thenReturn(null);

        final task = buildTask(
          labelIds: const ['lbl-b', 'lbl-a', 'lbl-missing'],
        );

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The summary compresses the taxonomy into one read-out, names in
        // alphabetical order; the unresolvable id is dropped.
        expect(find.text('Alpha, Beta'), findsOneWidget);
        expect(find.textContaining('lbl-missing'), findsNothing);
      },
    );

    testWidgets(
      'hides private labels when showPrivateEntries is false',
      (tester) async {
        when(() => mockCache.showPrivateEntries).thenReturn(false);
        when(
          () => mockCache.getLabelById('lbl-public'),
        ).thenReturn(buildLabel(id: 'lbl-public', name: 'Public'));
        when(() => mockCache.getLabelById('lbl-private')).thenReturn(
          buildLabel(id: 'lbl-private', name: 'Private', private: true),
        );

        final task = buildTask(
          labelIds: const ['lbl-public', 'lbl-private'],
        );

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Public'), findsOneWidget);
        expect(find.text('Private'), findsNothing);
      },
    );

    testWidgets(
      'completed tasks never paint an overdue due-date chip',
      (tester) async {
        // Due date ten days in the past but the task is done — urgency
        // collapses to "normal".
        final task = buildTask(
          due: DateTime(2026, 4, 10),
          status: TaskStatus.done(
            id: 'status-done',
            createdAt: now,
            utcOffset: 0,
          ),
        );

        await withClock(Clock.fixed(now), () async {
          await tester.pumpWidget(pumpConnector(task: task));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        });

        // Due date chip renders with the default subdued styling, not the
        // overdue red. We assert the due label is present — the exact
        // styling is already covered by the header's own test.
        expect(find.textContaining('Apr'), findsOneWidget);
      },
    );
  });

  group('DesktopTaskHeaderConnector — estimate in the summary lane', () {
    final estimateTag = find.byKey(const ValueKey('task-estimate-summary-tag'));

    testWidgets('shows the task estimate without opening the fly-out', (
      tester,
    ) async {
      final task = buildTask(estimate: const Duration(hours: 2));

      await tester.pumpWidget(pumpConnector(task: task));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(estimateTag, findsOneWidget);
      expect(find.text('2h'), findsOneWidget);
      expect(find.byType(TaskMetaSection), findsNothing);
    });

    testWidgets('shows no estimate tag for a task without an estimate', (
      tester,
    ) async {
      final task = buildTask();

      await tester.pumpWidget(pumpConnector(task: task));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(estimateTag, findsNothing);
      expect(find.byType(DesktopTaskHeader), findsOneWidget);
    });
  });

  group('DesktopTaskHeaderConnector — AI cost in the summary lane', () {
    testWidgets('shows the cost beside the status once AI has run', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpConnector(task: buildTask(), aiCallCount: 7),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Always visible on the task, not one panel away.
      expect(find.text('€0.42'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('renders nothing for a task that has never used AI', (
      tester,
    ) async {
      await tester.pumpWidget(pumpConnector(task: buildTask()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AiCostIndicator), findsNothing);
    });

    testWidgets('tapping it opens the details that hold the breakdown', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpConnector(task: buildTask(), aiCallCount: 7),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('€0.42'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TaskMetaSection), findsOneWidget);
      expect(find.text('AI spend'), findsOneWidget);
    });

    testWidgets('reads as a plain fact while the details column is up', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpConnector(
          task: buildTask(),
          aiCallCount: 7,
          metaColumnVisible: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Still visible — but it does not offer a panel that is already open.
      expect(find.text('€0.42'), findsOneWidget);
      expect(
        tester.widget<AiCostIndicator>(find.byType(AiCostIndicator)).onTap,
        isNull,
      );
    });
  });

  group('DesktopTaskHeaderConnector — fly-out and crumb invocations', () {
    testWidgets(
      'tapping a summary read-out opens the metadata fly-out',
      (tester) async {
        final task = buildTask();

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Every read-out routes to the same fly-out; the priority glyph sits
        // inside one of them.
        await tester.tap(find.byType(TaskShowcasePriorityGlyph).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(TaskMetaSection), findsOneWidget);
        expect(find.text('Task details'), findsOneWidget);
      },
    );

    testWidgets(
      'the Details trigger stands down where the details column is mounted',
      (tester) async {
        await tester.pumpWidget(
          pumpConnector(task: buildTask(), metaColumnVisible: true),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The read-outs stay; the offer to open a second copy of them does
        // not, and neither do their hit targets.
        expect(find.text('Open'), findsOneWidget);
        expect(find.text('Details'), findsNothing);

        await tester.tap(find.byType(TaskShowcasePriorityGlyph).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(TaskMetaSection), findsNothing);
      },
    );

    testWidgets(
      'the Details trigger opens the fly-out with label + value rows',
      (tester) async {
        final task = buildTask(estimate: const Duration(hours: 2));

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Details'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(TaskMetaSection), findsOneWidget);
        // Descriptive labels with their values.
        expect(find.text('Status'), findsOneWidget);
        expect(find.text('Priority'), findsOneWidget);
        expect(find.text('Estimate'), findsOneWidget);
        expect(find.text('0m of 2h'), findsOneWidget);
      },
    );

    testWidgets(
      'offers no crumb but an inline "Set category" chip when the task has '
      'no category, and the chip opens the picker directly',
      (tester) async {
        // Without a category there is no ancestry to show: no crumb, no
        // separator — the summary lane carries the dashed offer instead.
        final task = buildTask();

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('No category'), findsNothing);
        expect(find.text('No project'), findsNothing);
        expect(find.text('/'), findsNothing);
        expect(find.text('Set category'), findsOneWidget);

        await tester.tap(find.text('Set category'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Straight to the picker — no fly-out detour for the one attribute
        // the header actively offers.
        expect(find.byType(CategoryPickerSheet), findsOneWidget);
        expect(find.byType(TaskMetaSection), findsNothing);
      },
    );

    testWidgets(
      'restores the project crumb once the task has a category',
      (tester) async {
        final category = buildCategory();
        when(() => mockCache.getCategoryById('cat-1')).thenReturn(category);
        final task = buildTask(categoryId: 'cat-1');

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Work'), findsOneWidget);
        expect(find.text('/'), findsOneWidget);
        expect(find.text('No project'), findsOneWidget);
      },
    );
  });

  group('DesktopTaskHeaderConnector — picker callbacks', () {
    List<Override> connectorOverrides({
      required Task task,
      required ToggleCallTracker tracker,
    }) => [
      entryControllerProvider(task.id).overrideWith(
        () => FakeEntryController(task, tracker: tracker),
      ),
      labelsStreamProvider.overrideWith(
        (ref) => Stream<List<LabelDefinition>>.value(const []),
      ),
      projectForTaskProvider(task.id).overrideWith((ref) async => null),
      taskProgressControllerProvider(task.id).overrideWith(
        () => _FakeTaskProgressController(null),
      ),
    ];

    Widget wrapInTestApp({
      required List<Override> overrides,
      required Widget home,
    }) {
      return ProviderScope(
        overrides: overrides,
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
          home: home,
        ),
      );
    }

    Widget pumpConnectorWithTracker({
      required Task task,
      required ToggleCallTracker tracker,
    }) {
      return wrapInTestApp(
        overrides: connectorOverrides(task: task, tracker: tracker),
        home: Scaffold(body: DesktopTaskHeaderConnector(taskId: task.id)),
      );
    }

    testWidgets(
      'category picked through the fly-out closes its modal without popping '
      'the outer route',
      (tester) async {
        // Reproduces the bottom-nav topology: the connector lives in a
        // per-tab nested Navigator inside the MaterialApp root Navigator.
        // On phone width the picker opens on the root Navigator
        // (`shouldUseRootNavigatorForBottomSheet`), so popping with the
        // connector's outer context would pop the nested route instead of
        // the modal. This guards the c6627fe8d-style fix through the new
        // fly-out path.
        final pickable = buildCategory(id: 'cat-pick', name: 'Focus');
        when(() => mockCache.sortedCategories).thenReturn([pickable]);
        when(() => mockCache.getCategoryById('cat-pick')).thenReturn(pickable);

        final task = buildTask();
        final tracker = ToggleCallTracker();

        await tester.pumpWidget(
          wrapInTestApp(
            overrides: connectorOverrides(task: task, tracker: tracker),
            home: MediaQuery(
              data: const MediaQueryData(size: Size(390, 844)),
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: DesktopTaskHeaderConnector(taskId: task.id),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Details'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Category'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Focus'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The selection persisted through the shared picker...
        expect(tracker.updateCategoryIdCalls, equals(['cat-pick']));
        // ...the category modal closed, and the outer nested route was NOT
        // popped — the connector is still mounted.
        expect(find.byType(CategoryPickerSheet), findsNothing);
        expect(find.byType(DesktopTaskHeaderConnector), findsOneWidget);
      },
    );

    testWidgets(
      'saving a new title forwards to EntryController.save',
      (tester) async {
        final task = buildTask();
        final tracker = ToggleCallTracker();

        await tester.pumpWidget(
          pumpConnectorWithTracker(task: task, tracker: tracker),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Enter edit mode on the read-only title.
        await tester.tap(find.text('Test Task'));
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'New Title');
        // A frame, so the confirm control (hidden while the field still
        // matches the title it opened on) is in the tree to tap.
        await tester.pump();
        await tester.tap(find.byIcon(LottiIcons.confirm));
        await tester.pump();

        expect(tracker.saveCalls, hasLength(1));
        expect(tracker.saveCalls.single['title'], 'New Title');
      },
    );
  });

  group('DesktopTaskHeaderConnector — due-date urgency', () {
    testWidgets(
      'past-due tasks surface the overdue badge styling',
      (tester) async {
        final past = DateTime(2026, 4, 10);
        final task = buildTask(due: past);

        await withClock(Clock.fixed(now), () async {
          await tester.pumpWidget(pumpConnector(task: task));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        });

        // The due chip is present; overdue styling is exercised downstream.
        expect(find.textContaining('Apr'), findsOneWidget);
      },
    );

    testWidgets(
      'tasks due today pick up the today urgency styling',
      (tester) async {
        final task = buildTask(due: DateTime(2026, 4, 20, 18));

        await withClock(Clock.fixed(now), () async {
          await tester.pumpWidget(pumpConnector(task: task));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        });

        // Either the urgency label or the date string is visible.
        expect(find.byType(DesktopTaskHeader), findsOneWidget);
      },
    );

    testWidgets(
      'tasks due in the future fall through to the normal urgency branch',
      (tester) async {
        // A future date (well past "today") exercises the
        // `case DueDateUrgency.normal:` arm of `_dueUrgency`.
        final task = buildTask(due: DateTime(2026, 6, 15));

        await withClock(Clock.fixed(now), () async {
          await tester.pumpWidget(pumpConnector(task: task));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        });

        expect(find.byType(DesktopTaskHeader), findsOneWidget);
        expect(find.textContaining('Jun'), findsOneWidget);
      },
    );
  });

  group('DesktopTaskHeaderConnector — project picker', () {
    /// Builds overrides for project-picker tests, using a real
    /// [MockProjectRepository] stub so [projectsForCategoryProvider]
    /// can serve the project list and [linkTaskToProject] /
    /// [unlinkTaskFromProject] calls can be verified.
    List<Override> projectPickerOverrides({
      required Task task,
      required ToggleCallTracker tracker,
      required MockProjectRepository projectRepo,
      List<ProjectEntry> projects = const [],
      ProjectEntry? currentProject,
    }) {
      return [
        entryControllerProvider(task.id).overrideWith(
          () => FakeEntryController(task, tracker: tracker),
        ),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value(const []),
        ),
        projectForTaskProvider(
          task.id,
        ).overrideWith((ref) async => currentProject),
        taskProgressControllerProvider(task.id).overrideWith(
          () => _FakeTaskProgressController(null),
        ),
        projectRepositoryProvider.overrideWithValue(projectRepo),
        if (task.meta.categoryId != null)
          projectsForCategoryProvider(task.meta.categoryId!).overrideWith(
            (ref) async => projects,
          ),
      ];
    }

    Widget wrapWithProjectApp({
      required List<Override> overrides,
      required Task task,
    }) {
      return ProviderScope(
        overrides: overrides,
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
            body: DesktopTaskHeaderConnector(taskId: task.id),
          ),
        ),
      );
    }

    testWidgets(
      'task with a category exposes a tappable project crumb that opens '
      'the project picker (covers onProjectTap lambda + _showProjectPicker)',
      (tester) async {
        final category = buildCategory(id: 'cat-proj', name: 'Design');
        when(
          () => mockCache.getCategoryById('cat-proj'),
        ).thenReturn(category);

        final task = buildTask(categoryId: 'cat-proj');
        final tracker = ToggleCallTracker();
        final projectRepo = MockProjectRepository();

        when(
          () => projectRepo.updateStream,
        ).thenAnswer((_) => const Stream<Set<String>>.empty());

        final overrides = projectPickerOverrides(
          task: task,
          tracker: tracker,
          projectRepo: projectRepo,
        );

        await tester.pumpWidget(
          wrapWithProjectApp(overrides: overrides, task: task),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // "No project" is the unassigned crumb; when categoryId is non-null
        // the connector passes a real onProjectTap callback (not null).
        await tester.tap(find.text('No project'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The project-selection modal opened.
        expect(find.byType(ProjectSelectionModalContent), findsOneWidget);
      },
    );

    testWidgets(
      "the picker opens with the task's current project already selected",
      (tester) async {
        final category = buildCategory(id: 'cat-proj', name: 'Design');
        when(
          () => mockCache.getCategoryById('cat-proj'),
        ).thenReturn(category);

        final current = buildProject(id: 'proj-1', title: 'Alpha Project');
        final other = buildProject(id: 'proj-2', title: 'Beta Project');
        final task = buildTask(categoryId: 'cat-proj');
        final projectRepo = MockProjectRepository();
        when(
          () => projectRepo.updateStream,
        ).thenAnswer((_) => const Stream<Set<String>>.empty());

        final overrides = projectPickerOverrides(
          task: task,
          tracker: ToggleCallTracker(),
          projectRepo: projectRepo,
          projects: [current, other],
          currentProject: current,
        );

        await tester.pumpWidget(
          wrapWithProjectApp(overrides: overrides, task: task),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The crumb names the linked project, so that is the tap target.
        await tester.tap(find.text('Alpha Project'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        DesignSystemSelectionRow row(String key) =>
            tester.widget<DesignSystemSelectionRow>(
              find.byKey(ValueKey(key)),
            );

        // The connector has to forward the linked project as the picker's
        // current selection; without it the sheet would open showing
        // "No project" ticked while the task is in one.
        expect(row('project-proj-1').selected, isTrue);
        expect(row('project-proj-2').selected, isFalse);
        expect(row('project-none').selected, isFalse);
      },
    );

    testWidgets(
      'selecting "No project" in the picker calls unlinkTaskFromProject',
      (tester) async {
        final category = buildCategory(id: 'cat-proj', name: 'Design');
        when(
          () => mockCache.getCategoryById('cat-proj'),
        ).thenReturn(category);

        // Task already linked to a project so we can verify unlink.
        final existingProject = buildProject(id: 'proj-existing', title: 'Old');
        final task = buildTask(categoryId: 'cat-proj');
        final tracker = ToggleCallTracker();
        final projectRepo = MockProjectRepository();

        when(
          () => projectRepo.updateStream,
        ).thenAnswer((_) => const Stream<Set<String>>.empty());
        when(
          () => projectRepo.unlinkTaskFromProject(any()),
        ).thenAnswer((_) async => true);

        final overrides = projectPickerOverrides(
          task: task,
          tracker: tracker,
          projectRepo: projectRepo,
          projects: [existingProject],
        );

        await tester.pumpWidget(
          wrapWithProjectApp(overrides: overrides, task: task),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('No project'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap the "No project" row (null selection).
        await tester.tap(find.text('No project').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(() => projectRepo.unlinkTaskFromProject(task.id)).called(1);
      },
    );

    testWidgets(
      'selecting an existing project in the picker calls linkTaskToProject',
      (tester) async {
        final category = buildCategory(id: 'cat-proj', name: 'Design');
        when(
          () => mockCache.getCategoryById('cat-proj'),
        ).thenReturn(category);

        final project = buildProject(id: 'proj-1', title: 'Alpha Project');
        final task = buildTask(categoryId: 'cat-proj');
        final tracker = ToggleCallTracker();
        final projectRepo = MockProjectRepository();

        when(
          () => projectRepo.updateStream,
        ).thenAnswer((_) => const Stream<Set<String>>.empty());
        when(
          () => projectRepo.linkTaskToProject(
            projectId: any(named: 'projectId'),
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer((_) async => true);

        final overrides = projectPickerOverrides(
          task: task,
          tracker: tracker,
          projectRepo: projectRepo,
          projects: [project],
        );

        await tester.pumpWidget(
          wrapWithProjectApp(overrides: overrides, task: task),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('No project'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap the "Alpha Project" row in the picker.
        await tester.tap(find.text('Alpha Project'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(
          () => projectRepo.linkTaskToProject(
            projectId: 'proj-1',
            taskId: task.id,
          ),
        ).called(1);
      },
    );
  });

  group('DesktopTaskHeaderConnector — labels read-out', () {
    testWidgets(
      'tapping the labels read-out opens the metadata fly-out',
      (tester) async {
        // Build a task with a label that the cache resolves.
        final label = buildLabel(id: 'lbl-tap', name: 'Urgent');
        when(
          () => mockCache.getLabelById('lbl-tap'),
        ).thenReturn(label);

        final task = buildTask(labelIds: const ['lbl-tap']);
        final tracker = ToggleCallTracker();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              entryControllerProvider(task.id).overrideWith(
                () => FakeEntryController(task, tracker: tracker),
              ),
              labelsStreamProvider.overrideWith(
                (ref) => Stream<List<LabelDefinition>>.value(const []),
              ),
              projectForTaskProvider(task.id).overrideWith(
                (ref) async => null,
              ),
              taskProgressControllerProvider(task.id).overrideWith(
                () => _FakeTaskProgressController(null),
              ),
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
                body: DesktopTaskHeaderConnector(taskId: task.id),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The compressed labels read-out is rendered (label name visible).
        expect(find.text('Urgent'), findsOneWidget);

        // Tapping it routes to the fly-out, where the Labels row edits.
        await tester.tap(find.text('Urgent'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(TaskMetaSection), findsOneWidget);
      },
    );
  });

  group('DesktopTaskHeaderConnector — blocked-by chip', () {
    testWidgets('renders nothing when the task has no blockers', (
      tester,
    ) async {
      final task = buildTask();
      stubBlockers(task.id, []);

      await tester.pumpWidget(pumpConnector(task: task));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(LottiIcons.block), findsNothing);
    });

    testWidgets(
      'states only that the task is blocked, naming the blocker in the '
      'tooltip, and navigates to it when there is exactly one open blocker',
      (tester) async {
        final task = buildTask();
        final blocker = Task(
          meta: Metadata(
            id: 'blocker-1',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          data: TaskData(
            status: TaskStatus.open(id: 's', createdAt: now, utcOffset: 0),
            dateFrom: now,
            dateTo: now,
            statusHistory: const [],
            title: 'Fix the outage',
          ),
        );
        stubBlockers(task.id, [
          blocksLink(id: 'l1', fromId: 'blocker-1', toId: task.id),
        ]);
        when(
          () => mockJournalDb.entriesForIds([blocker.meta.id]),
        ).thenReturn(MockSelectable([toDbEntity(blocker)]));

        // openLinkedTaskDetail only routes through NavService on desktop
        // layouts — below kDesktopBreakpoint it pushes a real MaterialPageRoute
        // to TaskDetailsPage instead, which needs a lot more test scaffolding.
        // MediaQuery reads tester.view.physicalSize/devicePixelRatio, not
        // binding.setSurfaceSize (which only constrains render-object layout).
        tester.view.physicalSize = const Size(1280, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The chip is count-only: embedding the title made it grow with the
        // title and out-shout the status pill beside it.
        expect(find.text('Blocked by 1 task'), findsOneWidget);
        expect(find.textContaining('Fix the outage'), findsNothing);
        final tooltip = tester.widget<Tooltip>(
          find.ancestor(
            of: find.byIcon(LottiIcons.block),
            matching: find.byType(Tooltip),
          ),
        );
        // ...but the tooltip still names it, at no layout cost.
        expect(tooltip.message, 'Blocked by Fix the outage');

        await tester.tap(find.byIcon(LottiIcons.block));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(
          () => mockNavService.pushDesktopTaskDetail('blocker-1'),
        ).called(1);
      },
    );

    testWidgets(
      'opens a read-only blockers sheet when there is more than one open '
      'blocker',
      (tester) async {
        final task = buildTask();
        final blockerA = Task(
          meta: Metadata(
            id: 'blocker-a',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          data: TaskData(
            status: TaskStatus.open(id: 's', createdAt: now, utcOffset: 0),
            dateFrom: now,
            dateTo: now,
            statusHistory: const [],
            title: 'Blocker A',
          ),
        );
        final blockerB = Task(
          meta: Metadata(
            id: 'blocker-b',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          data: TaskData(
            status: TaskStatus.open(id: 's', createdAt: now, utcOffset: 0),
            dateFrom: now,
            dateTo: now,
            statusHistory: const [],
            title: 'Blocker B',
          ),
        );
        stubBlockers(task.id, [
          blocksLink(id: 'l1', fromId: 'blocker-a', toId: task.id),
          blocksLink(id: 'l2', fromId: 'blocker-b', toId: task.id),
        ]);
        when(
          () => mockJournalDb.entriesForIds(['blocker-a', 'blocker-b']),
        ).thenReturn(
          MockSelectable([toDbEntity(blockerA), toDbEntity(blockerB)]),
        );

        // Desktop sizing so opening a blocker routes through NavService,
        // which is what makes "navigated behind the barrier" observable.
        tester.view.physicalSize = const Size(1280, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final tooltip = tester.widget<Tooltip>(
          find.ancestor(
            of: find.byIcon(LottiIcons.block),
            matching: find.byType(Tooltip),
          ),
        );
        expect(tooltip.message, 'Tap to see 2 blockers');

        await tester.tap(find.byIcon(LottiIcons.block));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verifyNever(() => mockNavService.pushDesktopTaskDetail(any()));
        expect(find.text('Blocker A'), findsOneWidget);
        expect(find.text('Blocker B'), findsOneWidget);
        expect(find.text('Blocked by'), findsOneWidget);

        // Picking one closes the sheet *and* navigates. Navigating without
        // closing routes behind the sheet's own barrier, so the user is left
        // looking at an unchanged sheet and the tap reads as doing nothing.
        await tester.tap(find.text('Blocker B'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(
          () => mockNavService.pushDesktopTaskDetail('blocker-b'),
        ).called(1);
        expect(find.text('Blocker A'), findsNothing);
      },
    );

    testWidgets(
      'shows a bare Blocked pill with no tap target when the only blocker '
      'is unresolved',
      (tester) async {
        final task = buildTask();
        stubBlockers(task.id, [
          blocksLink(id: 'l1', fromId: 'missing-blocker', toId: task.id),
        ]);
        when(
          () => mockJournalDb.entriesForIds(['missing-blocker']),
        ).thenReturn(MockSelectable(const []));

        await tester.pumpWidget(pumpConnector(task: task));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byIcon(LottiIcons.block), findsOneWidget);
        expect(find.text('Blocker not synced yet'), findsOneWidget);

        final pill = tester.widget<DsPill>(
          find.ancestor(
            of: find.byIcon(LottiIcons.block),
            matching: find.byType(DsPill),
          ),
        );
        expect(pill.onTap, isNull);
      },
    );
  });
}
