// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/chips/active_filter_chip.dart';
import 'package:lotti/features/design_system/components/headers/tab_section_header.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAllFallbackValues);

  late FakeJournalPageController fakeController;
  late TestGetItMocks getItMocks;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockNavService mockNavService;
  late MockTimeService mockTimeService;
  late MockPersistenceLogic mockPersistenceLogic;
  late List<JournalEntity> tasks;
  late PagingController<int, JournalEntity> pagingController;
  late Duration previousVisibilityUpdateInterval;

  setUp(() async {
    previousVisibilityUpdateInterval =
        VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockNavService = MockNavService();
    mockTimeService = MockTimeService();
    mockPersistenceLogic = MockPersistenceLogic();

    when(
      () => mockNavService.beamToNamed(any(), data: any(named: 'data')),
    ).thenReturn(null);
    when(
      () => mockTimeService.getStream(),
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockTimeService.linkedFrom).thenReturn(null);

    final workCategory = CategoryDefinition(
      id: 'cat-1',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      name: 'Work',
      vectorClock: null,
      private: false,
      active: true,
      favorite: false,
      color: '#3355FF',
    );
    final focusLabel = LabelDefinition(
      id: 'label-1',
      name: 'Focus',
      color: '#FFAA00',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      vectorClock: null,
      private: false,
    );

    when(
      () => mockEntitiesCacheService.getCategoryById('cat-1'),
    ).thenReturn(workCategory);
    when(
      () => mockEntitiesCacheService.getLabelById('label-1'),
    ).thenReturn(focusLabel);
    when(
      () => mockEntitiesCacheService.sortedCategories,
    ).thenReturn([workCategory]);
    when(() => mockEntitiesCacheService.sortedLabels).thenReturn([focusLabel]);
    when(() => mockEntitiesCacheService.showPrivateEntries).thenReturn(true);

    getItMocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
          ..registerSingleton<NavService>(mockNavService)
          ..registerSingleton<TimeService>(mockTimeService)
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
          ..registerSingleton<UserActivityService>(UserActivityService());
      },
    );
    when(
      () => getItMocks.journalDb.getProjectsForCategory(any()),
    ).thenAnswer((_) async => <ProjectEntry>[]);
    when(
      () => getItMocks.journalDb.getTaskEstimatesByIds(any()),
    ).thenAnswer((invocation) async {
      final ids = invocation.positionalArguments.first as Set<String>;
      return {for (final id in ids) id: null};
    });
    when(
      () => getItMocks.journalDb.getBulkLinkedTimeSpans(any()),
    ).thenAnswer((_) async => <String, List<LinkedEntityTimeSpan>>{});

    tasks = [
      TestTaskFactory.create(
        id: 'task-1',
        title: 'Write migration',
        categoryId: 'cat-1',
        dateFrom: DateTime(2026, 4, 8, 9),
        dateTo: DateTime(2026, 4, 8, 10),
      ),
      TestTaskFactory.create(
        id: 'task-2',
        title: 'Validate grouping',
        categoryId: 'cat-1',
        dateFrom: DateTime(2026, 4, 8, 11),
        dateTo: DateTime(2026, 4, 8, 12),
      ),
    ];

    pagingController =
        PagingController<int, JournalEntity>(
            getNextPageKey: (_) => null,
            fetchPage: (_) async => const <JournalEntity>[],
          )
          ..value = PagingState<int, JournalEntity>(
            pages: [tasks],
            keys: const [0],
            hasNextPage: false,
          );
  });

  tearDown(() async {
    VisibilityDetectorController.instance.updateInterval =
        previousVisibilityUpdateInterval;
    pagingController.dispose();
    await tearDownTestGetIt();
  });

  JournalPageState state({
    Set<String> selectedLabelIds = const <String>{},
    Set<String> selectedCategoryIds = const <String>{'cat-1'},
    Set<String> selectedTaskStatuses = const <String>{'OPEN'},
    Set<String> selectedPriorities = const <String>{},
    Set<String> selectedProjectIds = const <String>{},
    bool enableVectorSearch = false,
    bool enableProjects = false,
  }) {
    return JournalPageState(
      match: '',
      showTasks: true,
      pagingController: pagingController,
      taskStatuses: const ['OPEN', 'IN PROGRESS'],
      selectedTaskStatuses: selectedTaskStatuses,
      selectedCategoryIds: selectedCategoryIds,
      selectedLabelIds: selectedLabelIds,
      selectedPriorities: selectedPriorities,
      selectedProjectIds: selectedProjectIds,
      selectedEntryTypes: const ['Task'],
      fullTextMatches: const <String>{},
      enableVectorSearch: enableVectorSearch,
      enableProjects: enableProjects,
    );
  }

  Widget buildSubject({
    required JournalPageState state,
    TasksTabCreateTaskCallback? onCreateTaskPressed,
    MediaQueryData? mediaQueryData,
  }) {
    fakeController = FakeJournalPageController(state);

    return makeTestableWidgetNoScroll(
      TasksTabPage(
        onCreateTaskPressed: onCreateTaskPressed,
      ),
      mediaQueryData: mediaQueryData,
      overrides: [
        journalPageScopeProvider.overrideWithValue(true),
        journalPageControllerProvider(true).overrideWith(() => fakeController),
        taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
      ],
    );
  }

  testWidgets('search updates, filter modal opens, and row taps navigate', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(state: state()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'agentic');
    await tester.pump();
    expect(fakeController.searchStringCalls, contains('agentic'));

    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Tasks Filter'), findsOneWidget);

    final rowTapTarget = find.ancestor(
      of: find.text('Write migration'),
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(rowTapTarget.first).onTap?.call();
    await tester.pump();
    verify(
      () => mockNavService.beamToNamed('/tasks/task-1', data: null),
    ).called(1);
  });

  testWidgets(
    'renders the correct tasks when paging items include non-task entities',
    (tester) async {
      final mixedItems = <JournalEntity>[
        JournalEntity.journalEntry(
          meta: TestMetadataFactory.create(
            id: 'entry-1',
            dateFrom: DateTime(2026, 4, 8, 8),
            dateTo: DateTime(2026, 4, 8, 8, 30),
            categoryId: 'cat-1',
          ),
        ),
        ...tasks,
      ];
      pagingController.value = PagingState<int, JournalEntity>(
        pages: [mixedItems],
        keys: const [0],
        hasNextPage: false,
      );

      await tester.pumpWidget(buildSubject(state: state()));
      await tester.pumpAndSettle();

      expect(find.text('Write migration'), findsOneWidget);
      expect(find.text('Validate grouping'), findsOneWidget);

      final secondRowTapTarget = find.ancestor(
        of: find.text('Validate grouping'),
        matching: find.byType(InkWell),
      );
      tester.widget<InkWell>(secondRowTapTarget.first).onTap?.call();
      await tester.pump();

      verify(
        () => mockNavService.beamToNamed('/tasks/task-2', data: null),
      ).called(1);
    },
  );

  testWidgets(
    'shows quick labels and FAB hook with custom create callback',
    (tester) async {
      String? createdCategoryId;

      await tester.pumpWidget(
        buildSubject(
          state: state(
            selectedLabelIds: const {'label-1'},
            enableVectorSearch: true,
            enableProjects: true,
          ),
          onCreateTaskPressed: (ref, categoryId) async {
            createdCategoryId = categoryId;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Active label filters'), findsOneWidget);
      // "Focus" label appears both in the active-filters chip row above the
      // list and in the TaskLabelQuickFilter inside the list.
      expect(find.text('Focus'), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(createdCategoryId, 'cat-1');
    },
  );

  testWidgets('shows loading indicator when pagingController is null', (
    tester,
  ) async {
    const nullPagingState = JournalPageState(
      match: '',
      showTasks: true,
      taskStatuses: ['OPEN', 'IN PROGRESS'],
      selectedTaskStatuses: {'OPEN'},
      selectedCategoryIds: {'cat-1'},
      selectedEntryTypes: ['Task'],
      fullTextMatches: <String>{},
    );

    await tester.pumpWidget(buildSubject(state: nullPagingState));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders compact header padding at narrow width', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        state: state(),
        mediaQueryData: const MediaQueryData(size: Size(400, 844)),
      ),
    );
    await tester.pumpAndSettle();

    // Header should still render at compact width
    expect(find.text('Tasks'), findsOneWidget);
  });

  testWidgets('default FAB creates task and navigates', (tester) async {
    final createdTask = TestTaskFactory.create(
      id: 'new-task',
      title: 'New Task',
      categoryId: 'cat-1',
      dateFrom: DateTime(2026, 4, 8, 9),
      dateTo: DateTime(2026, 4, 8, 10),
    );
    when(
      () => mockPersistenceLogic.createTaskEntry(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => createdTask);

    await tester.pumpWidget(
      buildSubject(
        state: state(),
        // Do NOT provide onCreateTaskPressed — exercises default path
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    verify(
      () => mockNavService.beamToNamed('/tasks/new-task', data: null),
    ).called(1);
  });

  testWidgets('uses the design-system FAB with bottom-nav padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        state: state(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DesignSystemBottomNavigationFabPadding), findsOneWidget);
    expect(find.byType(DesignSystemFloatingActionButton), findsOneWidget);
  });

  testWidgets('desktop mode listens to desktopSelectedTaskId', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final selectedNotifier = ValueNotifier<String?>('task-1');
    when(
      () => mockNavService.desktopSelectedTaskId,
    ).thenReturn(selectedNotifier);

    await tester.pumpWidget(
      buildSubject(
        state: state(),
        mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
      ),
    );
    await tester.pumpAndSettle();

    // The selected task row should receive the selectedTaskId prop,
    // which triggers visual highlighting in desktop mode.
    expect(find.text('Write migration'), findsOneWidget);
    expect(find.text('Validate grouping'), findsOneWidget);
  });

  testWidgets('desktop mode passes activeTaskId to list items', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final selectedNotifier = ValueNotifier<String?>('task-1');
    when(
      () => mockNavService.desktopSelectedTaskId,
    ).thenReturn(selectedNotifier);

    await tester.pumpWidget(
      buildSubject(
        state: state(),
        mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
      ),
    );
    await tester.pumpAndSettle();

    // Change selected task and verify the notifier drives a rebuild
    selectedNotifier.value = 'task-2';
    await tester.pump();

    // Both tasks should still be visible
    expect(find.text('Write migration'), findsOneWidget);
    expect(find.text('Validate grouping'), findsOneWidget);
  });

  testWidgets(
    'pull-to-refresh calls refreshQuery with preserveVisibleItems: true '
    'so the list is swapped atomically without a visible blank flash',
    (tester) async {
      await tester.pumpWidget(buildSubject(state: state()));
      await tester.pumpAndSettle();

      // Trigger pull-to-refresh by dragging the scroll view down enough
      // for RefreshIndicator to fire.
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(fakeController.refreshQueryCalled, greaterThanOrEqualTo(1));
      expect(
        fakeController.refreshQueryPreserveFlags,
        everyElement(isTrue),
        reason:
            'pull-to-refresh must use preserveVisibleItems to avoid the '
            'empty-then-repopulate flicker users reported.',
      );
    },
  );

  testWidgets(
    'tasks header sits outside the RefreshIndicator so pull-to-refresh '
    'only drags the list below it',
    (tester) async {
      await tester.pumpWidget(buildSubject(state: state()));
      await tester.pumpAndSettle();

      final headerFinder = find.byType(TabSectionHeader);
      final refreshFinder = find.byType(RefreshIndicator);
      final scrollFinder = find.byType(CustomScrollView);

      expect(headerFinder, findsOneWidget);
      expect(refreshFinder, findsOneWidget);
      expect(scrollFinder, findsOneWidget);

      // Header must not be a descendant of either RefreshIndicator or the
      // scroll view — otherwise the title would drag with pull-to-refresh.
      expect(
        find.descendant(of: refreshFinder, matching: headerFinder),
        findsNothing,
      );
      expect(
        find.descendant(of: scrollFinder, matching: headerFinder),
        findsNothing,
      );
    },
  );

  group('active-filter chip row', () {
    testWidgets(
      'is hidden entirely when no status/priority/category/label/project '
      'filters are selected',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            state: state(
              selectedTaskStatuses: const <String>{},
              selectedCategoryIds: const <String>{},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ActiveFilterChip), findsNothing);
      },
    );

    testWidgets(
      'renders a status chip with the localised label and removes it via '
      'applyBatchFilterUpdate when ✕ is tapped',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            state: state(
              selectedTaskStatuses: const <String>{'OPEN'},
              selectedCategoryIds: const <String>{},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The only ActiveFilterChip rendered is the OPEN status chip.
        expect(find.byType(ActiveFilterChip), findsOneWidget);
        final chip = tester.widget<ActiveFilterChip>(
          find.byType(ActiveFilterChip),
        );
        expect(chip.label, isNotEmpty);
        expect(chip.leadingIcon, Icons.radio_button_unchecked);

        // Tapping the chip's InkWell fires onRemove, which the widget wires
        // to applyBatchFilterUpdate(statuses: {}).
        await tester.tap(find.byType(ActiveFilterChip));
        await tester.pump();

        expect(fakeController.applyBatchFilterUpdateCalled, 1);
        expect(fakeController.setSelectedTaskStatusesCalls.last, isEmpty);
      },
    );

    testWidgets(
      'renders a category chip for each selected category using the '
      'EntitiesCacheService name and removes it on tap',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            state: state(
              selectedTaskStatuses: const <String>{},
              selectedCategoryIds: const <String>{'cat-1'},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Category chip uses the category's name from EntitiesCacheService.
        expect(find.byType(ActiveFilterChip), findsOneWidget);
        final chip = tester.widget<ActiveFilterChip>(
          find.byType(ActiveFilterChip),
        );
        expect(chip.label, 'Work');

        await tester.tap(find.byType(ActiveFilterChip));
        await tester.pump();

        // Removing a category chip clears that category *and* any project
        // selection, since category change invalidates the project set.
        expect(fakeController.applyBatchFilterUpdateCalled, 1);
        expect(fakeController.setSelectedCategoryIdsCalls.last, isEmpty);
        expect(fakeController.setSelectedProjectIdsCalls.last, isEmpty);
      },
    );

    testWidgets(
      'renders a priority chip with the P-label avatar and calls '
      'applyBatchFilterUpdate on remove',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            state: state(
              selectedTaskStatuses: const <String>{},
              selectedCategoryIds: const <String>{},
              selectedPriorities: const <String>{'P0'},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ActiveFilterChip), findsOneWidget);
        final chip = tester.widget<ActiveFilterChip>(
          find.byType(ActiveFilterChip),
        );
        expect(chip.label, 'P0');
        // Priority chips use the shared TaskShowcasePriorityGlyph via the
        // [avatar] slot — no leadingIcon set.
        expect(chip.avatar, isNotNull);
        expect(chip.leadingIcon, isNull);

        await tester.tap(find.byType(ActiveFilterChip));
        await tester.pump();

        expect(fakeController.applyBatchFilterUpdateCalled, 1);
        expect(fakeController.setSelectedPrioritiesCalls.last, isEmpty);
      },
    );

    testWidgets(
      'renders a label chip for each selected label (in addition to the '
      'quick-label filter inside the list) and removes it on tap',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            state: state(
              selectedTaskStatuses: const <String>{},
              selectedCategoryIds: const <String>{},
              selectedLabelIds: const <String>{'label-1'},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Exactly one ActiveFilterChip for the label (the TaskLabelQuickFilter
        // below the chip row renders its own non-ActiveFilterChip control).
        expect(find.byType(ActiveFilterChip), findsOneWidget);
        final chip = tester.widget<ActiveFilterChip>(
          find.byType(ActiveFilterChip),
        );
        expect(chip.label, 'Focus');

        await tester.tap(find.byType(ActiveFilterChip));
        await tester.pump();

        expect(fakeController.applyBatchFilterUpdateCalled, 1);
        expect(fakeController.setSelectedLabelIdsCalls.last, isEmpty);
      },
    );

    testWidgets(
      'renders one chip per active filter when several are selected at once',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            state: state(
              selectedTaskStatuses: const <String>{'OPEN', 'IN PROGRESS'},
              selectedCategoryIds: const <String>{'cat-1'},
              selectedLabelIds: const <String>{'label-1'},
              selectedPriorities: const <String>{'P0', 'P2'},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 2 statuses + 2 priorities + 1 category + 1 label = 6 chips.
        expect(find.byType(ActiveFilterChip), findsNWidgets(6));
      },
    );
  });

  group('Tasks header saved-filter suffix', () {
    Widget buildSubjectWithSavedFilter({
      required String? activeId,
      required List<SavedTaskFilter> seed,
    }) {
      fakeController = FakeJournalPageController(state());

      return makeTestableWidgetNoScroll(
        const TasksTabPage(),
        overrides: [
          journalPageScopeProvider.overrideWithValue(true),
          journalPageControllerProvider(
            true,
          ).overrideWith(() => fakeController),
          taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
          savedTaskFiltersControllerProvider.overrideWith(
            () => _StubSavedTaskFiltersController(seed),
          ),
          currentSavedTaskFilterIdProvider.overrideWith((ref) => activeId),
          tasksFilterHasUnsavedClausesProvider.overrideWith((ref) => false),
          liveTasksFilterProvider.overrideWith((ref) => const TasksFilter()),
        ],
      );
    }

    testWidgets('renders no suffix when no saved filter is active', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubjectWithSavedFilter(
          activeId: null,
          seed: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('· '), findsNothing);
    });

    testWidgets(
      'renders the "· {name}" suffix when activeId resolves to a saved view',
      (tester) async {
        await tester.pumpWidget(
          buildSubjectWithSavedFilter(
            activeId: 'sv-1',
            seed: const [
              SavedTaskFilter(
                id: 'sv-1',
                name: 'In progress · P0',
                filter: TasksFilter(),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('· In progress · P0'), findsOneWidget);
      },
    );

    testWidgets(
      'renders no suffix when activeId does not resolve to any saved view',
      (tester) async {
        // Stale-id case: provider says sv-1 is active, but the list does not
        // contain it (e.g. concurrent delete). The suffix must degrade to
        // empty rather than throwing.
        await tester.pumpWidget(
          buildSubjectWithSavedFilter(
            activeId: 'sv-1',
            seed: const [],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('· '), findsNothing);
      },
    );
  });
}

class _StubSavedTaskFiltersController extends SavedTaskFiltersController {
  _StubSavedTaskFiltersController(this._seed);
  final List<SavedTaskFilter> _seed;

  @override
  Future<List<SavedTaskFilter>> build() async => _seed;
}
