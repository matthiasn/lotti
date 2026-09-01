// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/chips/active_filter_chip.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/design_system/components/headers/tab_section_header.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/ui/app_command_controller.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/state/task_list_density_controller.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filter_rail.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsing_task_list_header.dart';
import 'package:lotti/features/tasks/ui/widgets/task_browse_list_item_rows.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:mocktail/mocktail.dart';

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

  setUp(() async {
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

    final mockUserActivityService = MockUserActivityService();
    when(mockUserActivityService.updateActivity).thenReturn(null);

    getItMocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
          ..registerSingleton<NavService>(mockNavService)
          ..registerSingleton<TimeService>(mockTimeService)
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
          ..registerSingleton<UserActivityService>(mockUserActivityService);
      },
    );
    when(
      () => getItMocks.journalDb.getProjectsForCategory(any()),
    ).thenAnswer((_) async => <ProjectEntry>[]);
    when(
      () => getItMocks.journalDb.getVisibleProjects(),
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
    AgentAssignmentFilter agentAssignmentFilter = AgentAssignmentFilter.all,
    String match = '',
  }) {
    return JournalPageState(
      match: match,
      agentAssignmentFilter: agentAssignmentFilter,
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
    TasksTabPageController? controller,
    MediaQueryData? mediaQueryData,
  }) {
    fakeController = FakeJournalPageController(state);

    return makeTestableWidgetNoScroll(
      AppCommandHost(
        handlers: const {},
        platform: TargetPlatform.windows,
        child: TasksTabPage(
          onCreateTaskPressed: onCreateTaskPressed,
          controller: controller,
        ),
      ),
      mediaQueryData: mediaQueryData,
      overrides: [
        journalPageScopeProvider.overrideWithValue(true),
        journalPageControllerProvider(true).overrideWith(() => fakeController),
        taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
      ],
    );
  }

  testWidgets('FAB inherits every unambiguous active task filter', (
    tester,
  ) async {
    TaskCreationFilterContext? receivedContext;
    var calls = 0;
    await tester.pumpWidget(
      buildSubject(
        state: state(
          selectedCategoryIds: const {'cat-1'},
          selectedProjectIds: const {'project-1'},
          selectedLabelIds: const {'label-1', 'label-2'},
          selectedTaskStatuses: const {'IN PROGRESS'},
          enableProjects: true,
        ),
        onCreateTaskPressed: (ref, filterContext) async {
          calls++;
          receivedContext = filterContext;
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byType(DesignSystemFloatingActionButton));
    await tester.pump();

    expect(calls, 1);
    expect(receivedContext?.categoryId, 'cat-1');
    expect(receivedContext?.projectId, 'project-1');
    expect(receivedContext?.labelIds, {'label-1', 'label-2'});
    expect(receivedContext?.status, 'IN PROGRESS');
  });

  testWidgets('FAB leaves ambiguous single-value filters at their defaults', (
    tester,
  ) async {
    TaskCreationFilterContext? receivedContext;
    await tester.pumpWidget(
      buildSubject(
        state: state(
          selectedCategoryIds: const {'cat-1', 'cat-2'},
          selectedProjectIds: const {'project-1', 'project-2'},
          selectedLabelIds: const <String>{},
          selectedTaskStatuses: const {'OPEN', 'IN PROGRESS'},
          enableProjects: true,
        ),
        onCreateTaskPressed: (ref, filterContext) async {
          receivedContext = filterContext;
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byType(DesignSystemFloatingActionButton));
    await tester.pump();

    expect(receivedContext?.categoryId, isNull);
    expect(receivedContext?.projectId, isNull);
    expect(receivedContext?.labelIds, isEmpty);
    expect(receivedContext?.status, isNull);
  });

  testWidgets('commands refresh, create, and focus task search', (
    tester,
  ) async {
    TaskCreationFilterContext? createdFilterContext;
    await tester.pumpWidget(
      buildSubject(
        state: state(),
        onCreateTaskPressed: (ref, filterContext) async {
          createdFilterContext = filterContext;
        },
      ),
    );
    await tester.pump();

    final commandContext = tester.element(find.byType(Scaffold).first);
    final commandController = AppCommandControllerProvider.of(commandContext);
    expect(
      await commandController.invoke(commandContext, AppCommandId.refresh),
      isTrue,
    );
    expect(fakeController.refreshQueryPreserveFlags, contains(true));

    expect(
      await commandController.invoke(
        commandContext,
        AppCommandId.createInContext,
      ),
      isTrue,
    );
    expect(createdFilterContext?.categoryId, 'cat-1');
    expect(createdFilterContext?.status, 'OPEN');

    expect(
      await commandController.invoke(commandContext, AppCommandId.focusSearch),
      isTrue,
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
  });

  testWidgets('external search bridge follows the attached tab controller', (
    tester,
  ) async {
    final firstController = TasksTabPageController();
    final secondController = TasksTabPageController();
    addTearDown(firstController.dispose);
    addTearDown(secondController.dispose);

    await tester.pumpWidget(
      buildSubject(state: state(), controller: firstController),
    );
    await tester.pump();

    firstController.focusSearch();
    await tester.pump();
    await tester.pump();

    TextField searchField() => tester.widget<TextField>(find.byType(TextField));
    expect(searchField().focusNode?.hasFocus, isTrue);

    searchField().focusNode?.unfocus();
    await tester.pumpWidget(
      buildSubject(state: state(), controller: secondController),
    );
    await tester.pump();

    firstController.focusSearch();
    await tester.pump();
    await tester.pump();
    expect(searchField().focusNode?.hasFocus, isFalse);

    secondController.focusSearch();
    await tester.pump();
    await tester.pump();
    expect(searchField().focusNode?.hasFocus, isTrue);
  });

  test('filter inheritance ignores empty and Unassigned selections', () {
    for (final pageState in [
      const JournalPageState(),
      const JournalPageState(
        selectedCategoryIds: {''},
        selectedProjectIds: {''},
        selectedLabelIds: {''},
        selectedTaskStatuses: {''},
      ),
    ]) {
      final filterContext = TaskCreationFilterContext.fromPageState(pageState);

      expect(filterContext.categoryId, isNull);
      expect(filterContext.projectId, isNull);
      expect(filterContext.labelIds, isEmpty);
      expect(filterContext.status, isNull);
    }
  });

  testWidgets('search updates, filter modal opens, and row taps navigate', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(state: state()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField), 'agentic');
    await tester.pump();
    expect(fakeController.searchStringCalls, contains('agentic'));

    // The compact bar keeps an (offstage) filter icon of its own, so scope
    // the tap to the expanded header's button.
    await tester.tap(
      find.descendant(
        of: find.byType(TabSectionHeader),
        matching: find.byIcon(LottiIcons.filter),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Filter tasks'), findsOneWidget);

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
    'shows the active label chip and FAB hook with custom create callback',
    (tester) async {
      String? createdCategoryId;

      await tester.pumpWidget(
        buildSubject(
          state: state(
            selectedLabelIds: const {'label-1'},
            enableVectorSearch: true,
            enableProjects: true,
          ),
          onCreateTaskPressed: (ref, filterContext) async {
            createdCategoryId = filterContext.categoryId;
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Active label filters'), findsNothing);
      expect(find.text('Focus'), findsOneWidget);

      await tester.tap(find.byIcon(LottiIcons.add));
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Header should still render at compact width (the collapsed bar keeps
    // an offstage 'Tasks' title of its own, so scope to the visible header).
    expect(
      find.descendant(
        of: find.byType(TabSectionHeader),
        matching: find.text('Tasks'),
      ),
      findsOneWidget,
    );
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
        labelIds: any(named: 'labelIds'),
      ),
    ).thenAnswer((_) async => createdTask);

    await tester.pumpWidget(
      buildSubject(
        state: state(selectedLabelIds: const {'label-1'}),
        // Do NOT provide onCreateTaskPressed — exercises default path
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(LottiIcons.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    verify(
      () => mockNavService.beamToNamed('/tasks/new-task', data: null),
    ).called(1);
    final capturedLabelIds = verify(
      () => mockPersistenceLogic.createTaskEntry(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
        labelIds: captureAny(named: 'labelIds'),
      ),
    ).captured.single;
    expect(capturedLabelIds, ['label-1']);
  });

  testWidgets(
    "the default FAB waits for the category's agent assignment before it "
    'navigates, so the new task opens on the layout it will keep',
    (tester) async {
      final createdTask = TestTaskFactory.create(
        id: 'agent-task',
        title: '',
        categoryId: 'cat-1',
        dateFrom: DateTime(2026, 4, 8, 9),
        dateTo: DateTime(2026, 4, 8, 10),
      );
      when(
        () => mockPersistenceLogic.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
          labelIds: any(named: 'labelIds'),
        ),
      ).thenAnswer((_) async => createdTask);

      // A category that auto-assigns an agent — the case where navigating
      // first meant the page painted first-run and then reflowed into the
      // established layout as the agent landed.
      when(() => mockEntitiesCacheService.getCategoryById('cat-1')).thenReturn(
        CategoryDefinition(
          id: 'cat-1',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          name: 'Work',
          vectorClock: null,
          private: false,
          active: true,
          favorite: false,
          color: '#3355FF',
          defaultTemplateId: 'template-1',
        ),
      );

      final assignment = Completer<AgentIdentityEntity>();
      addTearDown(() {
        if (!assignment.isCompleted) assignment.completeError(Exception('x'));
      });
      final agentService = MockTaskAgentService();
      when(
        () => agentService.createTaskAgent(
          taskId: any(named: 'taskId'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
          templateId: any(named: 'templateId'),
          profileId: any(named: 'profileId'),
          setupOrigin: any(named: 'setupOrigin'),
          setupOriginEntityId: any(named: 'setupOriginEntityId'),
          awaitContent: any(named: 'awaitContent'),
          automaticUpdatesEnabled: any(named: 'automaticUpdatesEnabled'),
        ),
      ).thenAnswer((_) => assignment.future);

      fakeController = FakeJournalPageController(state());
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AppCommandHost(
            handlers: {},
            platform: TargetPlatform.windows,
            child: TasksTabPage(),
          ),
          overrides: [
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(
              true,
            ).overrideWith(() => fakeController),
            taskAgentServiceProvider.overrideWithValue(agentService),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(LottiIcons.add));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verifyNever(
        () => mockNavService.beamToNamed('/tasks/agent-task', data: null),
      );

      assignment.completeError(Exception('assignment finished'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Even a failed assignment releases the navigation — the task exists,
      // and stranding the user on the list would be the worse outcome.
      verify(
        () => mockNavService.beamToNamed('/tasks/agent-task', data: null),
      ).called(1);
    },
  );

  testWidgets('uses the design-system FAB with bottom-nav padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        state: state(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(DesignSystemBottomNavigationFabPadding), findsOneWidget);
    expect(find.byType(DesignSystemFloatingActionButton), findsOneWidget);
  });

  testWidgets(
    'the worded FAB matches the task action bar: 48 high, one step4 above '
    'the content edge',
    (tester) async {
      await tester.pumpWidget(
        buildSubject(
          state: state(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final tokens = tester
          .element(find.byType(DesignSystemFloatingActionButton))
          .designTokens;
      final fab = tester.getRect(
        find.byType(DesignSystemFloatingActionButton),
      );
      // Same height as the Track time pill in the detail pane's action bar,
      // which is the control it sits beside on a desktop split.
      expect(fab.height, TapTargets.minimum);

      // ...and the same distance off the bottom edge as that bar's own
      // padding, so the two pills share a centreline rather than the FAB
      // riding four pixels high on the framework's fixed 16.
      final scaffold = tester.getRect(find.byType(Scaffold).first);
      final padded = tester.getRect(
        find.byType(DesignSystemBottomNavigationFabPadding),
      );
      expect(
        scaffold.bottom - padded.bottom,
        closeTo(tokens.spacing.step4, 0.01),
      );
    },
  );

  testWidgets(
    'rebuilding the page does not restart the FAB move transition',
    (tester) async {
      await tester.pumpWidget(
        buildSubject(
          state: state(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason: 'baseline: the page must be settled before the rebuild',
      );

      // Rebuild the page with an equivalent tree — the Scaffold element is
      // reused, so `didUpdateWidget` compares the old and new FAB locations.
      await tester.pumpWidget(
        buildSubject(
          state: state(),
        ),
      );
      await tester.pump();

      // The FAB location is rebuilt from tokens on every build. Without value
      // equality Scaffold reads each fresh instance as a move to a new spot
      // and restarts the transition — a setState and an animation per journal
      // query result, for a FAB that never actually moves.
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Trigger pull-to-refresh by dragging the scroll view down enough
      // for RefreshIndicator to fire.
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 300),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      'the agent clause is a removable chip, so the funnel and the chip row '
      'agree about what is narrowing the list',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            state: state(
              selectedTaskStatuses: const <String>{},
              selectedCategoryIds: const <String>{},
              agentAssignmentFilter: AgentAssignmentFilter.hasAgent,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(ActiveFilterChip), findsOneWidget);
        final chip = tester.widget<ActiveFilterChip>(
          find.byType(ActiveFilterChip),
        );
        expect(chip.leadingIcon, LottiIcons.aiModel);
        expect(chip.label, 'Has Agent');

        await tester.tap(find.byType(ActiveFilterChip));
        await tester.pump();

        expect(fakeController.applyBatchFilterUpdateCalled, 1);
        expect(
          fakeController.agentAssignmentFilterCalls.last,
          AgentAssignmentFilter.all,
        );
      },
    );

    testWidgets('the noAgent clause names itself too, not just hasAgent', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          state: state(
            selectedTaskStatuses: const <String>{},
            selectedCategoryIds: const <String>{},
            agentAssignmentFilter: AgentAssignmentFilter.noAgent,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester.widget<ActiveFilterChip>(find.byType(ActiveFilterChip)).label,
        'No Agent',
      );
    });

    testWidgets(
      'Clear all clears the search query it sits beside, not just the '
      'clauses — and appears once a query plus one clause are narrowing',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            state: state(
              selectedTaskStatuses: const <String>{},
              selectedCategoryIds: const <String>{'cat-1'},
              match: 'roof',
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // One clause chip only, yet the batch reset is offered: the query is
        // the second narrowing.
        expect(find.byType(ActiveFilterChip), findsOneWidget);
        final clearAll = find.widgetWithText(DesignSystemChip, 'Clear all');
        expect(clearAll, findsOneWidget);

        await tester.tap(clearAll);
        await tester.pump();

        expect(fakeController.setSelectedCategoryIdsCalls.last, isEmpty);
        expect(fakeController.searchStringCalls.last, isEmpty);
        // Back to the RESTING view, not to "every status". An empty status
        // set means "no status filter" to the query builder, so clearing
        // filters through the rail's reset would silently ADD done, rejected
        // and parked tasks — more than the user has ever seen on this page.
        expect(
          fakeController.setSelectedTaskStatusesCalls.last,
          defaultSelectedTaskStatuses,
        );
      },
    );

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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The only ActiveFilterChip rendered is the OPEN status chip.
        expect(find.byType(ActiveFilterChip), findsOneWidget);
        final chip = tester.widget<ActiveFilterChip>(
          find.byType(ActiveFilterChip),
        );
        expect(chip.label, isNotEmpty);
        expect(chip.leadingIcon, LottiIcons.radioUnselected);

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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

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
      'renders one chip for each selected label and removes it on tap',
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

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

    for (final selection in [
      (
        name: 'category',
        categoryIds: const <String>{''},
        labelIds: const <String>{},
      ),
      (
        name: 'label',
        categoryIds: const <String>{},
        labelIds: const <String>{''},
      ),
    ]) {
      testWidgets(
        'renders and removes the Unassigned ${selection.name} chip',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              state: state(
                selectedTaskStatuses: const <String>{},
                selectedCategoryIds: selection.categoryIds,
                selectedLabelIds: selection.labelIds,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(ActiveFilterChip), findsOneWidget);
          expect(
            tester
                .widget<ActiveFilterChip>(find.byType(ActiveFilterChip))
                .label,
            'Unassigned',
          );

          await tester.tap(find.byType(ActiveFilterChip));
          await tester.pump();

          expect(fakeController.applyBatchFilterUpdateCalled, 1);
          if (selection.name == 'category') {
            expect(fakeController.setSelectedCategoryIdsCalls.last, isEmpty);
            expect(fakeController.setSelectedProjectIdsCalls.last, isEmpty);
          } else {
            expect(fakeController.setSelectedLabelIdsCalls.last, isEmpty);
          }
        },
      );
    }

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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 2 statuses + 2 priorities + 1 category + 1 label = 6 chips.
        expect(find.byType(ActiveFilterChip), findsNWidgets(6));
      },
    );
  });

  group('Tasks saved-filter controls', () {
    // The header no longer carries a "· {name}" suffix; task-local controls
    // surface the active saved filter instead. These tests exercise page-level
    // responsive wiring, collapse behavior, and the active view name.
    Widget buildSubjectWithSavedFilter({
      required String? activeId,
      required List<SavedTaskFilter> seed,
      JournalPageState? pageState,
      bool hasUnsaved = false,
      MediaQueryData? mediaQueryData,
    }) {
      fakeController = FakeJournalPageController(pageState ?? state());

      return makeTestableWidgetNoScroll(
        const TasksTabPage(),
        mediaQueryData: mediaQueryData,
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
          tasksFilterHasUnsavedClausesProvider.overrideWith(
            (ref) => hasUnsaved,
          ),
          // Keep counts off the GetIt-backed repository in this page-level test.
          savedTaskFilterCountsProvider.overrideWith(
            (ref) async => const {'sv-1': 3},
          ),
          allTasksTotalCountProvider.overrideWith((ref) async => 50),
        ],
      );
    }

    testWidgets('omits the rail entirely when no saved filters exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubjectWithSavedFilter(
          activeId: null,
          seed: const [],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The mobile rail collapses to nothing — no Filters button — and the old
      // "· {name}" header suffix is gone for good.
      expect(find.byKey(SavedTaskFilterRailKeys.savedButton), findsNothing);
      // No "· {name}" suffix in the expanded header title (the collapsed
      // compact bar legitimately uses a middot for its context run).
      expect(
        find.descendant(
          of: find.byType(TabSectionHeader),
          matching: find.textContaining('· '),
        ),
        findsNothing,
      );
    });

    testWidgets('surfaces the active saved filter name in the rail', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubjectWithSavedFilter(
          activeId: 'sv-1',
          seed: const [
            SavedTaskFilter(
              id: 'sv-1',
              name: 'In Progress P0',
              filter: TasksFilter(),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(SavedTaskFilterRailKeys.savedButton), findsOneWidget);
      // The Filters button keeps a plain label (its saved-count rides a
      // separate slot, not a parenthetical).
      expect(find.text('Views'), findsOneWidget);
      // The active pill shows the saved filter's name. Scoped to the rail:
      // the (offstage) collapsed compact bar now carries the name too, as
      // its context label.
      expect(
        find.descendant(
          of: find.byKey(SavedTaskFilterRailKeys.root),
          matching: find.text('In Progress P0'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('does not duplicate saved filters in the desktop task pane', (
      tester,
    ) async {
      final selectedTaskId = ValueNotifier<String?>(null);
      addTearDown(selectedTaskId.dispose);
      when(
        () => mockNavService.desktopSelectedTaskId,
      ).thenReturn(selectedTaskId);

      // The collapse gate reads the real pane width via LayoutBuilder, so the
      // desktop scenario needs a desktop-sized VIEW, not just a MediaQuery.
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        buildSubjectWithSavedFilter(
          activeId: 'sv-1',
          seed: const [
            SavedTaskFilter(
              id: 'sv-1',
              name: 'Desktop focus',
              filter: TasksFilter(),
            ),
          ],
          mediaQueryData: const MediaQueryData(size: Size(1400, 900)),
        ),
      );
      await tester.pump();

      expect(find.text('Desktop focus'), findsNothing);
      expect(find.byKey(SavedTaskFilterRailKeys.root), findsNothing);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets(
      'matched saved filter replaces rather than duplicates its filter chips',
      (tester) async {
        final selectedTaskId = ValueNotifier<String?>(null);
        addTearDown(selectedTaskId.dispose);
        when(
          () => mockNavService.desktopSelectedTaskId,
        ).thenReturn(selectedTaskId);

        // Desktop-sized VIEW so the pane-width collapse gate stays static.
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          buildSubjectWithSavedFilter(
            activeId: 'sv-1',
            seed: const [
              SavedTaskFilter(
                id: 'sv-1',
                name: 'Urgent in progress',
                filter: TasksFilter(
                  selectedTaskStatuses: {'IN PROGRESS'},
                  selectedPriorities: {'P0'},
                ),
              ),
            ],
            pageState: state(
              selectedTaskStatuses: const {'IN PROGRESS'},
              selectedCategoryIds: const {},
              selectedPriorities: const {'P0'},
            ),
            mediaQueryData: const MediaQueryData(size: Size(1400, 900)),
          ),
        );
        await tester.pump();

        expect(find.text('Urgent in progress'), findsNothing);
        expect(find.byType(ActiveFilterChip), findsNothing);
      },
    );

    testWidgets(
      'custom desktop filter keeps removable chips in the task pane',
      (
        tester,
      ) async {
        final selectedTaskId = ValueNotifier<String?>(null);
        addTearDown(selectedTaskId.dispose);
        when(
          () => mockNavService.desktopSelectedTaskId,
        ).thenReturn(selectedTaskId);

        await tester.pumpWidget(
          buildSubjectWithSavedFilter(
            activeId: null,
            hasUnsaved: true,
            seed: const [
              SavedTaskFilter(
                id: 'sv-1',
                name: 'Saved baseline',
                filter: TasksFilter(),
              ),
            ],
            pageState: state(
              selectedTaskStatuses: const {'OPEN'},
              selectedCategoryIds: const {},
            ),
            mediaQueryData: const MediaQueryData(size: Size(1400, 900)),
          ),
        );
        await tester.pump();

        expect(find.byType(ActiveFilterChip), findsOneWidget);
        expect(find.text('Saved baseline'), findsNothing);
        expect(find.text('Custom'), findsNothing);
      },
    );

    testWidgets(
      'rail collapses when activeId does not resolve to any saved filter',
      (tester) async {
        // Stale-id case: provider says sv-1 is active, but the list is empty
        // (e.g. concurrent delete). The rail must collapse rather than throw.
        await tester.pumpWidget(
          buildSubjectWithSavedFilter(
            activeId: 'sv-1',
            seed: const [],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(SavedTaskFilterRailKeys.savedButton), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('stale active id keeps custom filter chips removable', (
      tester,
    ) async {
      final selectedTaskId = ValueNotifier<String?>(null);
      addTearDown(selectedTaskId.dispose);
      when(
        () => mockNavService.desktopSelectedTaskId,
      ).thenReturn(selectedTaskId);

      await tester.pumpWidget(
        buildSubjectWithSavedFilter(
          activeId: 'deleted',
          seed: const [
            SavedTaskFilter(
              id: 'still-saved',
              name: 'Still saved',
              filter: TasksFilter(),
            ),
          ],
          pageState: state(
            selectedPriorities: const {'P0'},
            selectedCategoryIds: const {},
          ),
          mediaQueryData: const MediaQueryData(size: Size(1400, 900)),
        ),
      );
      await tester.pump();

      expect(find.byType(ActiveFilterChip), findsNWidgets(2));
      expect(find.text('Custom'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('no-results empty state', () {
    const message = 'No tasks match your search.';

    setUp(() {
      pagingController.value = PagingState<int, JournalEntity>(
        pages: const [<JournalEntity>[]],
        keys: const [0],
        hasNextPage: false,
      );
    });

    Future<void> pumpEmpty(
      WidgetTester tester, {
      MediaQueryData? mediaQueryData,
    }) async {
      await tester.pumpWidget(
        buildSubject(state: state(), mediaQueryData: mediaQueryData),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets(
      'composes the design-system empty state with the tasks glyph',
      (tester) async {
        await pumpEmpty(tester);

        final emptyState = find.byType(DesignSystemEmptyState);
        expect(emptyState, findsOneWidget);
        expect(
          tester.widget<DesignSystemEmptyState>(emptyState).icon,
          LottiIcons.list,
        );
        expect(
          find.descendant(of: emptyState, matching: find.text(message)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the message is never laid out edge to edge on a phone-width pane',
      (tester) async {
        tester.view
          ..physicalSize = const Size(390, 844)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpEmpty(
          tester,
          mediaQueryData: const MediaQueryData(size: Size(390, 844)),
        );

        final messageFinder = find.text(message);
        final inset = tester.element(messageFinder).designTokens.spacing.step6;
        final paragraph = tester.renderObject<RenderParagraph>(messageFinder);

        // The layout contract, not the painted position: whatever width the
        // rendered lines happen to take, the paragraph must never be OFFERED
        // the full pane width — that is exactly the state in which a wrapping
        // message painted flush against the screen edge.
        expect(
          paragraph.constraints.maxWidth,
          lessThanOrEqualTo(390 - 2 * inset + 0.01),
        );
      },
    );

    testWidgets(
      'a message wrapped by a large text scale keeps clear of both edges',
      (tester) async {
        tester.view
          ..physicalSize = const Size(390, 844)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpEmpty(
          tester,
          mediaQueryData: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(2),
          ),
        );

        final messageFinder = find.text(message);
        final inset = tester.element(messageFinder).designTokens.spacing.step6;
        final paragraph = tester.renderObject<RenderParagraph>(messageFinder);

        // Measure per word, not over the whole string: a wrapped line's
        // trailing space glyph legitimately extends past the visual line
        // edge, so its selection box would fail an edge assertion without
        // any ink being rendered there.
        final wordBoxes = <TextBox>[];
        var searchStart = 0;
        for (final word in message.split(' ')) {
          final start = message.indexOf(word, searchStart);
          searchStart = start + word.length;
          wordBoxes.addAll(
            paragraph.getBoxesForSelection(
              TextSelection(baseOffset: start, extentOffset: searchStart),
            ),
          );
        }

        // Guard against a vacuous pass: the accessibility scale must
        // actually wrap the message, since a single centered line kept
        // clear of the edges even before the empty state carried an inset.
        final lineTops = wordBoxes.map((box) => box.top).toSet();
        expect(
          lineTops.length,
          greaterThan(1),
          reason: 'the scaled message must wrap for this test to bite',
        );

        for (final box in wordBoxes) {
          final left = paragraph.localToGlobal(Offset(box.left, box.top)).dx;
          final right = paragraph.localToGlobal(Offset(box.right, box.top)).dx;
          expect(
            left,
            greaterThanOrEqualTo(inset - 0.01),
            reason: 'no rendered word may reach the left screen edge',
          );
          expect(
            right,
            lessThanOrEqualTo(390 - inset + 0.01),
            reason: 'no rendered word may reach the right screen edge',
          );
        }
      },
    );
  });

  testWidgets(
    'header filter is inactive for the default status set and no other facets',
    (tester) async {
      await tester.pumpWidget(
        buildSubject(
          state: state(
            selectedCategoryIds: const <String>{},
            selectedTaskStatuses: defaultSelectedTaskStatuses,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester
            .widget<TabSectionHeader>(find.byType(TabSectionHeader))
            .filtersActive,
        isFalse,
      );
    },
  );

  testWidgets(
    'header filter is active when the status selection differs from default',
    (tester) async {
      // Narrowed to a single non-default status, no other facets → the
      // affordance still flips active on the status dimension alone.
      await tester.pumpWidget(
        buildSubject(
          state: state(
            selectedCategoryIds: const <String>{},
            selectedTaskStatuses: const <String>{'DONE'},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester
            .widget<TabSectionHeader>(find.byType(TabSectionHeader))
            .filtersActive,
        isTrue,
      );
    },
  );

  testWidgets(
    'clear and submit on the search header route through setSearchString',
    (tester) async {
      await tester.pumpWidget(buildSubject(state: state()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Pull the wired callbacks straight off the header to avoid
      // flakiness from the search bar's internal show-clear-when-non-empty
      // state. Each callback should land in setSearchString.
      tester.widget<TabSectionHeader>(find.byType(TabSectionHeader))
        ..onSearchPressed('agentic')
        ..onSearchCleared();
      await tester.pump();

      expect(
        fakeController.searchStringCalls,
        containsAll(<String>['agentic', '']),
      );
    },
  );

  testWidgets(
    'looks up vectorSearchDistances when showDistances is true',
    (tester) async {
      // The first task in `tasks` is task-1; rows are keyed by task id,
      // so a distance entry under that key is what the row would
      // forward into TaskBrowseListItem.vectorDistance.
      final stateWithDistances = state().copyWith(
        showDistances: true,
        vectorSearchDistances: const {'task-1': 0.31},
      );

      await tester.pumpWidget(buildSubject(state: stateWithDistances));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Layout-time success here means itemBuilder ran and the
      // showDistances branch was taken without throwing — the same
      // pre-existing 'search updates...' test verifies the row content
      // for the same fixture. Sanity-check both tasks rendered.
      expect(find.text('Write migration'), findsOneWidget);
      expect(find.text('Validate grouping'), findsOneWidget);
    },
  );

  testWidgets(
    'renders a project chip and removes the id via applyBatchFilterUpdate',
    (tester) async {
      final project = TestProjectFactory.create(
        id: 'proj-1',
        title: 'Migration',
        categoryId: 'cat-1',
      );
      when(
        () => getItMocks.journalDb.getVisibleProjects(),
      ).thenAnswer((_) async => [project]);

      await tester.pumpWidget(
        buildSubject(
          state: state(
            selectedTaskStatuses: const <String>{},
            selectedCategoryIds: const <String>{},
            selectedProjectIds: const <String>{'proj-1'},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ActiveFilterChip), findsOneWidget);
      final chip = tester.widget<ActiveFilterChip>(
        find.byType(ActiveFilterChip),
      );
      expect(chip.label, 'Migration');
      expect(chip.leadingIcon, LottiIcons.folder);

      await tester.tap(find.byType(ActiveFilterChip));
      await tester.pump();

      expect(fakeController.applyBatchFilterUpdateCalled, 1);
      expect(fakeController.setSelectedProjectIdsCalls.last, isEmpty);
    },
  );

  testWidgets(
    'renders a P3 priority chip with the matching avatar glyph',
    (tester) async {
      // Covers the P3 arms of _priorityFromInternalId / _priorityAccent.
      // The earlier "P0 priority chip" test already exercises P0; this
      // hits the bottom rung of the priority palette.
      await tester.pumpWidget(
        buildSubject(
          state: state(
            selectedTaskStatuses: const <String>{},
            selectedCategoryIds: const <String>{},
            selectedPriorities: const <String>{'P3'},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ActiveFilterChip), findsOneWidget);
      final chip = tester.widget<ActiveFilterChip>(
        find.byType(ActiveFilterChip),
      );
      expect(chip.label, 'P3');
      expect(chip.avatar, isNotNull);
    },
  );

  testWidgets(
    'first-page and new-page progress indicators delegate to '
    'CircularProgressIndicator.adaptive',
    (tester) async {
      // The two builders never fire on their own without a real paging
      // lifecycle, but coverage just needs the closures invoked once.
      // Pull the delegate off the rendered PagedSliverList and call the
      // builders against a live BuildContext, then inspect the returned
      // widget tree to confirm both wire a Padding > Center > spinner.
      await tester.pumpWidget(buildSubject(state: state()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final pagedList = tester.widget<PagedSliverList<int, JournalEntity>>(
        find.byType(PagedSliverList<int, JournalEntity>),
      );
      final delegate = pagedList.builderDelegate;
      final ctx = tester.element(
        find.byType(PagedSliverList<int, JournalEntity>),
      );

      final firstPageWidget = delegate.firstPageProgressIndicatorBuilder!(
        ctx,
      );
      final newPageWidget = delegate.newPageProgressIndicatorBuilder!(ctx);

      Widget unwrapToCenter(Widget w) {
        expect(w, isA<Padding>());
        final padding = w as Padding;
        expect(padding.child, isA<Center>());
        return (padding.child! as Center).child!;
      }

      expect(unwrapToCenter(firstPageWidget), isA<CircularProgressIndicator>());
      expect(unwrapToCenter(newPageWidget), isA<CircularProgressIndicator>());
    },
  );

  group('collapsing header', () {
    late PagingController<int, JournalEntity> longListController;

    setUp(() {
      final manyTasks = [
        for (var i = 0; i < 20; i++)
          TestTaskFactory.create(
            id: 'scroll-task-$i',
            title: 'Scrollable task $i',
            categoryId: 'cat-1',
            dateFrom: DateTime(2026, 4, 8, 9),
            dateTo: DateTime(2026, 4, 8, 10),
          ),
      ];
      longListController =
          PagingController<int, JournalEntity>(
              getNextPageKey: (_) => null,
              fetchPage: (_) async => const <JournalEntity>[],
            )
            ..value = PagingState<int, JournalEntity>(
              pages: [manyTasks],
              keys: const [0],
              hasNextPage: false,
            );
    });

    tearDown(() => longListController.dispose());

    JournalPageState longListState() {
      return JournalPageState(
        match: '',
        showTasks: true,
        pagingController: longListController,
        taskStatuses: const ['OPEN', 'IN PROGRESS'],
        selectedTaskStatuses: const {'OPEN'},
        selectedCategoryIds: const {'cat-1'},
        selectedEntryTypes: const ['Task'],
        fullTextMatches: const <String>{},
      );
    }

    CrossFadeState crossFadeState(WidgetTester tester) => tester
        .widget<AnimatedCrossFade>(
          find.byKey(CollapsingTaskListHeaderKeys.root),
        )
        .crossFadeState;

    Future<void> pumpCollapsed(WidgetTester tester) async {
      await tester.pumpWidget(buildSubject(state: longListState()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      // One pump to start the cross-fade, one to run it to completion.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('scrolling down collapses the header to the compact bar', (
      tester,
    ) async {
      await pumpCollapsed(tester);

      expect(crossFadeState(tester), CrossFadeState.showSecond);
      // The compact bar is a fraction of the expanded header's height, so
      // the collapse reclaims real list space.
      final compactHeight = tester
          .getSize(find.byKey(CollapsingTaskListHeaderKeys.root))
          .height;
      expect(compactHeight, lessThan(64));
    });

    testWidgets(
      'mouse-wheel scrolling (PointerScrollEvent) collapses and restores '
      'the header — the desktop input path, not just touch drags',
      (tester) async {
        await tester.pumpWidget(buildSubject(state: longListState()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final center = tester.getCenter(find.byType(CustomScrollView));
        final testPointer = TestPointer(1, PointerDeviceKind.mouse)
          ..hover(center);
        // Three wheel notches down.
        for (var i = 0; i < 3; i++) {
          await tester.sendEventToBinding(
            testPointer.scroll(const Offset(0, 120)),
          );
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 300));
        expect(crossFadeState(tester), CrossFadeState.showSecond);

        // One deliberate notch up restores.
        await tester.sendEventToBinding(
          testPointer.scroll(const Offset(0, -120)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(crossFadeState(tester), CrossFadeState.showFirst);
      },
    );

    testWidgets('scrolling back up restores the full header', (tester) async {
      await pumpCollapsed(tester);

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, 100),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(crossFadeState(tester), CrossFadeState.showFirst);
      expect(find.byType(TabSectionHeader), findsOneWidget);
    });

    testWidgets('typed search input survives a collapse/expand round trip', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(state: longListState()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.byType(TextField), 'migration');
      // Drop focus so the focus pin doesn't (correctly) block the collapse.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(crossFadeState(tester), CrossFadeState.showSecond);

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, 100),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(crossFadeState(tester), CrossFadeState.showFirst);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'migration',
      );
    });

    testWidgets('compact search affordance re-expands and focuses the field', (
      tester,
    ) async {
      await pumpCollapsed(tester);

      await tester.tap(
        find.byKey(CollapsingTaskListHeaderKeys.compactSearchButton),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(crossFadeState(tester), CrossFadeState.showFirst);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'tasks-search',
      );
    });

    testWidgets(
      'an ad-hoc filtered collapsed header NAMES its narrowing — one '
      'localized clause count in the title context, and nothing numeric on '
      'the funnel to double-encode or collide with it',
      (tester) async {
        final filteredState = JournalPageState(
          match: '',
          showTasks: true,
          pagingController: longListController,
          taskStatuses: const ['OPEN', 'IN PROGRESS'],
          selectedTaskStatuses: const {'OPEN'},
          selectedCategoryIds: const {'cat-1'},
          selectedPriorities: const {'P0'},
          selectedEntryTypes: const ['Task'],
          fullTextMatches: const <String>{},
        );
        await tester.pumpWidget(buildSubject(state: filteredState));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -400),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(crossFadeState(tester), CrossFadeState.showSecond);

        // 1 status (deviating) + 1 category + 1 priority = 3 clauses.
        expect(
          find.descendant(
            of: find.byKey(CollapsingTaskListHeaderKeys.compactBar),
            matching: find.textContaining('3 filters', findRichText: true),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(CollapsingTaskListHeaderKeys.compactFilterButton),
            matching: find.text('3'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('compact title tap re-expands the header', (tester) async {
      await pumpCollapsed(tester);

      await tester.tap(
        find.byKey(CollapsingTaskListHeaderKeys.compactTitle),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(crossFadeState(tester), CrossFadeState.showFirst);
    });

    testWidgets('compact filter affordance opens the filter modal directly', (
      tester,
    ) async {
      await pumpCollapsed(tester);

      await tester.tap(
        find.byKey(CollapsingTaskListHeaderKeys.compactFilterButton),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Filter tasks'), findsOneWidget);
      // Opening filters does not expand the header behind the sheet.
      expect(crossFadeState(tester), CrossFadeState.showSecond);
    });

    testWidgets(
      'dismissing the compact filter modal without changing the filter shape '
      'leaves the header collapsed — the scroll position keeps its context',
      (tester) async {
        await pumpCollapsed(tester);

        await tester.tap(
          find.byKey(CollapsingTaskListHeaderKeys.compactFilterButton),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Filter tasks'), findsOneWidget);

        // Close it the way a back gesture would, with nothing changed.
        tester.state<NavigatorState>(find.byType(Navigator).last).pop();
        await tester.pumpAndSettle();

        expect(find.text('Filter tasks'), findsNothing);
        expect(crossFadeState(tester), CrossFadeState.showSecond);
      },
    );

    testWidgets(
      'a collapse releases the search field: a focused field scrolled off '
      'screen would keep an invisible caret and swallow typing',
      (tester) async {
        await tester.pumpWidget(buildSubject(state: longListState()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byType(TextField).first);
        await tester.pump();
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .focusNode
              ?.hasFocus,
          isTrue,
        );

        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -400),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(crossFadeState(tester), CrossFadeState.showSecond);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .focusNode
              ?.hasFocus,
          isFalse,
        );
      },
    );

    testWidgets('a short list keeps the header expanded', (tester) async {
      await tester.pumpWidget(buildSubject(state: state()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(crossFadeState(tester), CrossFadeState.showFirst);
    });

    testWidgets('desktop layout keeps the static header (no collapse)', (
      tester,
    ) async {
      final selectedNotifier = ValueNotifier<String?>(null);
      addTearDown(selectedNotifier.dispose);
      when(
        () => mockNavService.desktopSelectedTaskId,
      ).thenReturn(selectedNotifier);

      // The gate reads the real pane width via LayoutBuilder, so the
      // desktop scenario needs a desktop-sized VIEW, not just a MediaQuery.
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        buildSubject(
          state: longListState(),
          mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(CollapsingTaskListHeaderKeys.root),
        findsNothing,
      );
      expect(find.byType(TabSectionHeader), findsOneWidget);

      // Scrolling a static-header pane must not accumulate collapse state
      // behind it: the search field is still on screen (so unfocusing it
      // would be inexplicable), and a later narrowing would otherwise snap
      // the header shut with no gesture from the user.
      final searchField = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      searchField.focusNode?.requestFocus();
      await tester.pump();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(searchField.focusNode?.hasFocus, isTrue);
      expect(find.byType(TabSectionHeader), findsOneWidget);
    });

    testWidgets(
      'a narrow desktop split-view list pane collapses like a phone: the '
      'gate is the pane width, not the window width',
      (tester) async {
        final selectedNotifier = ValueNotifier<String?>(null);
        addTearDown(selectedNotifier.dispose);
        when(
          () => mockNavService.desktopSelectedTaskId,
        ).thenReturn(selectedNotifier);

        fakeController = FakeJournalPageController(longListState());
        // A desktop-sized window (1280) hosting the page in a ~400px pane,
        // exactly the split-view shape TasksRootPage produces.
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const AppCommandHost(
              handlers: {},
              platform: TargetPlatform.windows,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 400,
                  child: TasksTabPage(),
                ),
              ),
            ),
            mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
            overrides: [
              journalPageScopeProvider.overrideWithValue(true),
              journalPageControllerProvider(
                true,
              ).overrideWith(() => fakeController),
              taskAgentServiceProvider.overrideWithValue(
                MockTaskAgentService(),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(CollapsingTaskListHeaderKeys.root),
          findsOneWidget,
        );

        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -400),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(crossFadeState(tester), CrossFadeState.showSecond);
      },
    );

    testWidgets(
      'an active saved view collapses to its NAME, not a clause-count '
      "badge, matching the expanded header's suppressed chip row",
      (tester) async {
        fakeController = FakeJournalPageController(longListState());
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const AppCommandHost(
              handlers: {},
              platform: TargetPlatform.windows,
              child: TasksTabPage(),
            ),
            overrides: [
              journalPageScopeProvider.overrideWithValue(true),
              journalPageControllerProvider(
                true,
              ).overrideWith(() => fakeController),
              taskAgentServiceProvider.overrideWithValue(
                MockTaskAgentService(),
              ),
              savedTaskFiltersControllerProvider.overrideWith(
                () => _StubSavedTaskFiltersController(const [
                  SavedTaskFilter(
                    id: 'sv-1',
                    name: 'Deep Work',
                    filter: TasksFilter(),
                  ),
                ]),
              ),
              currentSavedTaskFilterIdProvider.overrideWith((ref) => 'sv-1'),
              tasksFilterHasUnsavedClausesProvider.overrideWith(
                (ref) => false,
              ),
              savedTaskFilterCountsProvider.overrideWith(
                (ref) async => const {'sv-1': 3},
              ),
              allTasksTotalCountProvider.overrideWith((ref) async => 50),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -400),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(crossFadeState(tester), CrossFadeState.showSecond);

        // The saved view's name is the collapsed representation…
        expect(
          find.descendant(
            of: find.byKey(CollapsingTaskListHeaderKeys.compactBar),
            matching: find.textContaining('Deep Work', findRichText: true),
          ),
          findsOneWidget,
        );
        // …and nothing numeric competes with it on the funnel.
        expect(
          find.descendant(
            of: find.byKey(CollapsingTaskListHeaderKeys.compactFilterButton),
            matching: find.byType(Badge),
          ),
          findsNothing,
        );
      },
    );
  });

  group('tasks list density toggle', () {
    const toggleKey = Key('tasks_list_density_toggle');

    testWidgets(
      'rides the first section-header line, below the filter row',
      (tester) async {
        await tester.pumpWidget(buildSubject(state: state()));
        await tester.pump();

        final toggle = find.byKey(toggleKey);
        expect(toggle, findsOneWidget);

        // Below the filter row: the toggle starts under the search field
        // that anchors it…
        final searchTop = tester.getTopLeft(find.byType(TextField).first).dy;
        expect(tester.getTopLeft(toggle).dy, greaterThan(searchTop));

        // …and shares the section-header line with the task count instead
        // of costing the header a row of its own.
        final context = tester.element(toggle);
        final countText = find.text(
          context.messages.taskShowcaseTaskCount(2),
        );
        expect(countText, findsOneWidget);
        expect(
          tester.getCenter(toggle).dy,
          closeTo(tester.getCenter(countText).dy, 1),
        );

        // Glyph-only control: dense visual, but the hit area keeps the
        // full design-system tap-target floor.
        final size = tester.getSize(find.byKey(toggleKey));
        expect(size.width, greaterThanOrEqualTo(TapTargets.minimum));
        expect(size.height, greaterThanOrEqualTo(TapTargets.minimum));
      },
    );

    testWidgets(
      'tapping switches the rows to title-only compact mode and persists it',
      (tester) async {
        await tester.pumpWidget(buildSubject(state: state()));
        await tester.pump();

        // Expanded by default: full cards with their duration labels.
        expect(find.byType(TaskRowContent), findsNWidgets(2));
        expect(find.byType(TaskCompactRowContent), findsNothing);

        await tester.tap(find.byKey(toggleKey));
        await tester.pump();

        // Compact: every row is title-only, the titles stay visible.
        expect(find.byType(TaskCompactRowContent), findsNWidgets(2));
        expect(find.byType(TaskRowContent), findsNothing);
        expect(find.text('Write migration'), findsOneWidget);
        expect(find.text('Validate grouping'), findsOneWidget);

        verify(
          () => getItMocks.settingsDb.saveSettingsItem(
            taskListCompactModeSettingsKey,
            'true',
          ),
        ).called(1);

        // Tapping again restores the full cards.
        await tester.tap(find.byKey(toggleKey));
        await tester.pump();
        expect(find.byType(TaskRowContent), findsNWidgets(2));
        verify(
          () => getItMocks.settingsDb.saveSettingsItem(
            taskListCompactModeSettingsKey,
            'false',
          ),
        ).called(1);
      },
    );

    testWidgets('a persisted compact preference applies on first build', (
      tester,
    ) async {
      when(
        () => getItMocks.settingsDb.itemByKey(taskListCompactModeSettingsKey),
      ).thenAnswer((_) async => 'true');

      await tester.pumpWidget(buildSubject(state: state()));
      await tester.pump();
      await tester.pump();

      expect(find.byType(TaskCompactRowContent), findsNWidgets(2));
      expect(find.byType(TaskRowContent), findsNothing);
    });
  });
}

class _StubSavedTaskFiltersController extends SavedTaskFiltersController {
  _StubSavedTaskFiltersController(this._seed);
  final List<SavedTaskFilter> _seed;

  @override
  Future<List<SavedTaskFilter>> build() async => _seed;
}
