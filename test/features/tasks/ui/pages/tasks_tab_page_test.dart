// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/projects/ui/widgets/project_health_header.dart';
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
    bool enableVectorSearch = false,
    bool enableProjects = false,
  }) {
    return JournalPageState(
      match: '',
      showTasks: true,
      pagingController: pagingController,
      taskStatuses: const ['OPEN', 'IN PROGRESS'],
      selectedTaskStatuses: const {'OPEN'},
      selectedCategoryIds: selectedCategoryIds,
      selectedLabelIds: selectedLabelIds,
      selectedEntryTypes: const ['Task'],
      fullTextMatches: const <String>{},
      enableVectorSearch: enableVectorSearch,
      enableProjects: enableProjects,
    );
  }

  Widget buildSubject({
    required JournalPageState state,
    TasksTabCreateTaskCallback? onCreateTaskPressed,
    TasksTabProjectHeaderBuilder? projectHeaderBuilder,
    MediaQueryData? mediaQueryData,
  }) {
    fakeController = FakeJournalPageController(state);

    return makeTestableWidgetNoScroll(
      TasksTabPage(
        onCreateTaskPressed: onCreateTaskPressed,
        projectHeaderBuilder: projectHeaderBuilder,
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

    await tester.tap(find.byIcon(Icons.tune_rounded));
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
    'shows quick labels, vector mode in filters, project header, and FAB hook',
    (
      tester,
    ) async {
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
          projectHeaderBuilder:
              ({
                required categoryId,
                required selectedProjectIds,
                required onToggleProject,
                required onClearStale,
              }) {
                return Text('project-header:$categoryId');
              },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Active label filters'), findsOneWidget);
      expect(find.text('Focus'), findsOneWidget);
      expect(find.text('project-header:cat-1'), findsOneWidget);

      expect(find.text('Vector'), findsNothing);

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Search mode'), findsOneWidget);

      await tester.tap(find.text('Vector'));
      await tester.pumpAndSettle();
      expect(fakeController.searchModeCalls, contains(SearchMode.vector));

      Navigator.of(tester.element(find.text('Search mode'))).pop();
      await tester.pumpAndSettle();

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

  testWidgets('default project header renders ProjectHealthHeader', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        state: state(enableProjects: true),
        // Do NOT provide projectHeaderBuilder — exercises default path
      ),
    );
    await tester.pump();

    expect(find.byType(ProjectHealthHeader), findsOneWidget);
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
}
