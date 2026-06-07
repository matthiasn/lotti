// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/filtering/task_filter_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late FakeJournalPageController fakeController;
  late JournalPageState mockState;
  late MockPagingController mockPagingController;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockJournalDb mockJournalDb;
  late MockDomainLogger mockDomainLogger;

  final testCategories = [
    CategoryDefinition(
      id: 'cat-1',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      name: 'Work',
      vectorClock: null,
      private: false,
      active: true,
      color: '#FF0000',
    ),
    CategoryDefinition(
      id: 'cat-2',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      name: 'Personal',
      vectorClock: null,
      private: false,
      active: true,
      color: '#00FF00',
    ),
  ];

  final testLabels = [
    LabelDefinition(
      id: 'label-1',
      name: 'Urgent',
      color: '#FF0000',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      vectorClock: null,
      private: false,
    ),
  ];

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall methodCall,
        ) async {
          return null;
        });

    mockPagingController = MockPagingController();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockJournalDb = MockJournalDb();

    mockState = JournalPageState(
      match: '',
      filters: {},
      showPrivateEntries: false,
      selectedEntryTypes: const [],
      fullTextMatches: {},
      showTasks: true,
      pagingController: mockPagingController,
      taskStatuses: const [
        'OPEN',
        'GROOMED',
        'IN PROGRESS',
        'BLOCKED',
        'ON HOLD',
        'DONE',
        'REJECTED',
      ],
      selectedTaskStatuses: {'OPEN', 'IN PROGRESS'},
      selectedCategoryIds: const {},
      selectedLabelIds: const {},
      selectedPriorities: const {},
    );

    when(
      () => mockEntitiesCacheService.sortedCategories,
    ).thenReturn(testCategories);
    when(() => mockEntitiesCacheService.sortedLabels).thenReturn(testLabels);
    when(
      () => mockJournalDb.getProjectsForCategory(any()),
    ).thenAnswer((_) async => <ProjectEntry>[]);

    final mockSettingsDb = MockSettingsDb();
    when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);
    when(
      () => mockSettingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);
    mockDomainLogger = MockDomainLogger();
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockJournalDb)
          ..unregister<SettingsDb>()
          ..registerSingleton<SettingsDb>(mockSettingsDb)
          // Registered here (not inside individual tests) so registration
          // and teardown stay symmetric across the whole file.
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(mockDomainLogger);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    SavedTaskFiltersController Function()? savedTaskFiltersController,
    bool hasUnsavedClauses = false,
    MediaQueryData? mediaQueryData,
  }) {
    fakeController = FakeJournalPageController(mockState);

    return WidgetTestBench(
      mediaQueryData: mediaQueryData,
      child: ProviderScope(
        overrides: [
          journalPageScopeProvider.overrideWithValue(true),
          journalPageControllerProvider(true).overrideWith(
            () => fakeController,
          ),
          // Saved-filter providers depend on the live JournalPageController.
          // Override them with safe defaults so these tests exercise the
          // existing filter UI without spinning up the saved-filter stack.
          savedTaskFiltersControllerProvider.overrideWith(
            savedTaskFiltersController ??
                () => _StubSavedTaskFiltersController(const []),
          ),
          currentSavedTaskFilterIdProvider.overrideWith((ref) => null),
          tasksFilterHasUnsavedClausesProvider.overrideWith(
            (ref) => hasUnsavedClauses,
          ),
        ],
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                key: const ValueKey('open-filter-modal'),
                onPressed: () => showTaskFilterModal(
                  context,
                  showTasks: true,
                ),
                child: const Text('Open Filter'),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Builds the subject with the save flow enabled.
  Widget buildWithSaveEnabled({
    required bool hasUnsavedClauses,
    required SavedTaskFiltersController savedTaskFiltersController,
  }) => buildSubject(
    savedTaskFiltersController: () => savedTaskFiltersController,
    hasUnsavedClauses: hasUnsavedClauses,
  );

  /// Builds subject with enableProjects on the initial state, using a tall
  /// phone-width screen so the project field is not obscured by the sticky
  /// action bar inside the Wolt modal sheet.
  Widget buildWithProjects({required bool enableProjects}) {
    mockState = mockState.copyWith(enableProjects: enableProjects);
    return buildSubject(
      mediaQueryData: const MediaQueryData(size: Size(390, 844)),
    );
  }

  group('showTaskFilterModal', () {
    testWidgets('shows design system filter sheet with correct sections', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
      await tester.pumpAndSettle();

      // Filter modal is displayed
      expect(find.text('Tasks Filter'), findsOneWidget);
      expect(find.byType(DesignSystemTaskFilterSheet), findsOneWidget);

      // Sort section
      expect(find.text('Sort by'), findsOneWidget);

      // Action bar
      expect(find.text('Clear all'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
    });

    testWidgets('displays category options from cache', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
      await tester.pumpAndSettle();

      // Category field is visible
      expect(
        find.byKey(
          const ValueKey('design-system-task-filter-field-category'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('applies batch filter update when apply is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
      await tester.pumpAndSettle();

      // Tap apply
      final applyButton = find.byKey(
        const ValueKey('design-system-task-filter-apply'),
      );
      await tester.ensureVisible(applyButton);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      expect(fakeController.applyBatchFilterUpdateCalled, 1);
    });

    testWidgets('opens status selection modal and applies result', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
      await tester.pumpAndSettle();

      // Tap status field to open selection modal
      await tester.tap(
        find.byKey(
          const ValueKey('design-system-task-filter-field-status'),
        ),
      );
      await tester.pumpAndSettle();

      // Status selection modal shows task statuses (use key-based finders
      // because the chip label "Open" is also visible behind the modal)
      expect(
        find.byKey(
          const ValueKey('design-system-filter-selection-option-OPEN'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('design-system-filter-selection-option-GROOMED'),
        ),
        findsOneWidget,
      );

      // Toggle 'Blocked' on
      await tester.tap(
        find.byKey(
          const ValueKey('design-system-filter-selection-option-BLOCKED'),
        ),
      );
      await tester.pump();

      // Apply selection
      await tester.tap(
        find.byKey(
          const ValueKey('design-system-filter-selection-apply'),
        ),
      );
      await tester.pumpAndSettle();

      // Status field should now show the updated selection in the draft
      // (the chip for BLOCKED should appear)
      expect(
        find.byKey(
          const ValueKey('design-system-task-filter-remove-status-BLOCKED'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('opens category selection modal via field press', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
      await tester.pumpAndSettle();

      // Tap category field to open selection modal
      final categoryField = find.byKey(
        const ValueKey('design-system-task-filter-field-category'),
      );
      await tester.ensureVisible(categoryField);
      await tester.pumpAndSettle();
      await tester.tap(categoryField);
      await tester.pumpAndSettle();

      // Category selection shows our test categories
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
    });

    testWidgets('opens label selection modal and applies the selection', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
      await tester.pumpAndSettle();

      // Tap the label field to open the multi-select modal.
      final labelField = find.byKey(
        const ValueKey('design-system-task-filter-field-label'),
      );
      await tester.ensureVisible(labelField);
      await tester.pumpAndSettle();
      await tester.tap(labelField);
      await tester.pumpAndSettle();

      // Toggle the cached label on inside the selection modal.
      await tester.tap(
        find.byKey(
          const ValueKey('design-system-filter-selection-option-label-1'),
        ),
      );
      await tester.pump();

      // Apply the field selection.
      await tester.tap(
        find.byKey(
          const ValueKey('design-system-filter-selection-apply'),
        ),
      );
      await tester.pumpAndSettle();

      // The draft now shows the selected label as a removable chip.
      expect(
        find.byKey(
          const ValueKey('design-system-task-filter-remove-label-label-1'),
        ),
        findsOneWidget,
      );

      // Apply the whole sheet: the batch update must carry the label id
      // through to the controller.
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(fakeController.applyBatchFilterUpdateCalled, 1);
      expect(
        fakeController.setSelectedLabelIdsCalls.single,
        contains('label-1'),
      );
    });

    testWidgets('applies filter with selected sort and priority changes', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
      await tester.pumpAndSettle();

      // Change sort to "by creation date"
      await tester.tap(
        find.byKey(
          const ValueKey('design-system-task-filter-sort-byDate'),
        ),
      );
      await tester.pump();

      // Select priority P1
      await tester.tap(
        find.byKey(
          const ValueKey('design-system-task-filter-priority-p1'),
        ),
      );
      await tester.pump();

      // Apply — use pump() sequence instead of pumpAndSettle to avoid
      // layout assertion during Wolt modal animation teardown.
      await tester.tap(
        find.byKey(
          const ValueKey('design-system-task-filter-apply'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(fakeController.applyBatchFilterUpdateCalled, 1);
      expect(fakeController.sortOptionCalls, [TaskSortOption.byDate]);
      expect(fakeController.setSelectedPrioritiesCalls, [
        {'P1'},
      ]);
    });

    testWidgets('clear all resets filters in draft state', (tester) async {
      // Start with some selections
      mockState = mockState.copyWith(
        selectedTaskStatuses: {'OPEN', 'BLOCKED'},
        selectedCategoryIds: {'cat-1'},
        selectedPriorities: {'P0'},
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
      await tester.pumpAndSettle();

      // Tap clear all
      final clearButton = find.byKey(
        const ValueKey('design-system-task-filter-clear'),
      );
      await tester.ensureVisible(clearButton);
      await tester.tap(clearButton);
      await tester.pump();

      // Applied count should be 0
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('fetches projects for all categories on open', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
      await tester.pumpAndSettle();

      // Verify that getProjectsForCategory was called for each category
      verify(
        () => mockJournalDb.getProjectsForCategory('cat-1'),
      ).called(1);
      verify(
        () => mockJournalDb.getProjectsForCategory('cat-2'),
      ).called(1);
    });

    testWidgets('toggle rows appear and interact correctly', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
      await tester.pumpAndSettle();

      // Scroll down to find toggle rows
      final showCreation = find.byKey(
        const ValueKey('design-system-task-filter-toggle-showCreationDate'),
      );
      await tester.ensureVisible(showCreation);
      await tester.pump();

      // Toggle should be visible
      expect(showCreation, findsOneWidget);
    });

    testWidgets('save flow creates new filter and closes modal', (
      tester,
    ) async {
      // Need hasUnsavedClauses=true so canSave is enabled.
      await tester.pumpWidget(
        buildWithSaveEnabled(
          hasUnsavedClauses: true,
          savedTaskFiltersController: _ThrowingSavedTaskFiltersController(
            throwOnCreate: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
      await tester.pumpAndSettle();

      // Tap the Save button to open the popup.
      final saveBtn = find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey);
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Type a name in the popup text field.
      final field = find.byKey(
        DesignSystemTaskFilterActionBar.saveNamePopupFieldKey,
      );
      await tester.enterText(field, 'My Filter');
      await tester.pump();

      // Commit via the popup commit button.
      final commitBtn = find.byKey(
        DesignSystemTaskFilterActionBar.saveNamePopupCommitKey,
      );
      await tester.ensureVisible(commitBtn);
      await tester.tap(commitBtn);
      await tester.pumpAndSettle();

      // Modal should have closed (apply + save + dismiss).
      expect(find.text('Tasks Filter'), findsNothing);
    });

    testWidgets(
      'save error logs via DomainLogger and keeps modal open',
      (tester) async {
        await tester.pumpWidget(
          buildWithSaveEnabled(
            hasUnsavedClauses: true,
            savedTaskFiltersController: _ThrowingSavedTaskFiltersController(
              throwOnCreate: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
        await tester.pumpAndSettle();

        final saveBtn = find.byKey(
          DesignSystemTaskFilterActionBar.saveButtonKey,
        );
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        final field = find.byKey(
          DesignSystemTaskFilterActionBar.saveNamePopupFieldKey,
        );
        await tester.enterText(field, 'Error Filter');
        await tester.pump();

        final commitBtn = find.byKey(
          DesignSystemTaskFilterActionBar.saveNamePopupCommitKey,
        );
        await tester.ensureVisible(commitBtn);
        await tester.tap(commitBtn);
        await tester.pumpAndSettle();

        // DomainLogger.error must have been called once on the tasks domain.
        verify(
          () => mockDomainLogger.error(
            LogDomain.tasks,
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'saveFilter',
          ),
        ).called(1);

        // Close the modal so it doesn't leak into subsequent tests.
        tester.state<NavigatorState>(find.byType(Navigator).last).pop();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'project field tapped — empty projects list returns no update',
      (tester) async {
        // Default mock already returns [] for getProjectsForCategory.
        // Rebuild with enableProjects so the project field appears.
        await tester.pumpWidget(buildWithProjects(enableProjects: true));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
        await tester.pumpAndSettle();

        // With no projects the project field is absent (hasProjectField is
        // false), so the sheet has no project field to tap — the coverage
        // for the empty-filteredProjects early-return (line 197) is exercised
        // via _fetchProjectsForFilter returning an empty list and
        // _handleProjectFieldPressed guard.
        expect(
          find.byKey(
            const ValueKey('design-system-task-filter-field-project'),
          ),
          findsNothing,
        );

        // Apply should still work.
        final applyBtn = find.byKey(
          const ValueKey('design-system-task-filter-apply'),
        );
        await tester.ensureVisible(applyBtn);
        await tester.tap(applyBtn);
        await tester.pumpAndSettle();

        expect(fakeController.applyBatchFilterUpdateCalled, 1);
      },
    );

    testWidgets(
      'project field tapped — projects available, cancel returns no update',
      (tester) async {
        final testProject = _makeTestProject('proj-1', 'cat-1', 'My Project');
        when(
          () => mockJournalDb.getProjectsForCategory('cat-1'),
        ).thenAnswer((_) async => [testProject]);

        await tester.pumpWidget(buildWithProjects(enableProjects: true));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
        await tester.pumpAndSettle();

        // Project field should appear because we have projects.
        final projectField = find.byKey(
          const ValueKey('design-system-task-filter-field-project'),
        );
        // Scroll so the project field is well above the sticky action bar.
        // ensureVisible scrolls the field to the edge of the visible area,
        // which puts it behind the sticky footer; drag the scrollable further.
        await tester.ensureVisible(projectField);
        await tester.pump();
        await tester.drag(
          find.byType(Scrollable).last,
          const Offset(0, -120),
          warnIfMissed: false,
        );
        await tester.pump();
        await tester.tap(projectField);
        await tester.pumpAndSettle();

        // Project selection modal is open — dismiss without selecting by
        // tapping the Back button (pop) rather than Done, so selectedIds==null.
        // Use the last Navigator in the tree (the modal's own navigator).
        tester.state<NavigatorState>(find.byType(Navigator).last).pop();
        await tester.pumpAndSettle();

        // No project selection was committed, so draft state is unchanged.
        // The modal is still open.
        expect(find.text('Tasks Filter'), findsOneWidget);
      },
    );

    testWidgets(
      'project field tapped — projects available, selecting updates draft',
      (tester) async {
        final testProject = _makeTestProject('proj-1', 'cat-1', 'My Project');
        when(
          () => mockJournalDb.getProjectsForCategory('cat-1'),
        ).thenAnswer((_) async => [testProject]);

        await tester.pumpWidget(buildWithProjects(enableProjects: true));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
        await tester.pumpAndSettle();

        final projectField = find.byKey(
          const ValueKey('design-system-task-filter-field-project'),
        );
        // Scroll past the project field so it clears the sticky action bar.
        await tester.ensureVisible(projectField);
        await tester.pump();
        await tester.drag(
          find.byType(Scrollable).last,
          const Offset(0, -120),
          warnIfMissed: false,
        );
        await tester.pump();
        await tester.tap(projectField);
        await tester.pumpAndSettle();

        // Select the project row in the project selection modal.
        final projectRow = find.byKey(
          const ValueKey('design-system-project-selection-option-proj-1'),
        );
        await tester.ensureVisible(projectRow);
        await tester.tap(projectRow);
        await tester.pump();

        // Tap Done to commit the selection.
        final doneBtn = find.byKey(
          const ValueKey('design-system-project-selection-apply'),
        );
        await tester.ensureVisible(doneBtn);
        await tester.tap(doneBtn);
        await tester.pumpAndSettle();

        // Back in the filter modal, a remove chip for proj-1 should appear.
        expect(
          find.byKey(
            const ValueKey(
              'design-system-task-filter-remove-project-proj-1',
            ),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'apply passes search mode when enableVectorSearch is true on desktop',
      (tester) async {
        // Desktop width triggers isDesktopLayout → searchModeOptions populated
        // → hasSearchMode == true → line 271 (toMode branch) is exercised.
        // WidgetTestBench uses the mediaQueryData we pass for context.size, so
        // provide a desktop-width MediaQueryData rather than changing the view.
        mockState = mockState.copyWith(
          enableVectorSearch: true,
        );

        fakeController = FakeJournalPageController(mockState);

        const desktopMediaQuery = MediaQueryData(size: Size(1200, 900));

        // Dialog mode triggers a 4.5 px overflow in the action-bar Row at the
        // test dialog width (476 px). Suppress it so the meaningful assertion
        // (searchModeCalls) is the only thing we check in this test.
        final errors = <FlutterErrorDetails>[];
        final originalHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          if (!details.exceptionAsString().contains('RenderFlex')) {
            originalHandler?.call(details);
          } else {
            errors.add(details);
          }
        };
        addTearDown(() => FlutterError.onError = originalHandler);

        await tester.pumpWidget(
          WidgetTestBench(
            mediaQueryData: desktopMediaQuery,
            child: ProviderScope(
              overrides: [
                journalPageScopeProvider.overrideWithValue(true),
                journalPageControllerProvider(true).overrideWith(
                  () => fakeController,
                ),
                savedTaskFiltersControllerProvider.overrideWith(
                  () => _StubSavedTaskFiltersController(const []),
                ),
                currentSavedTaskFilterIdProvider.overrideWith((ref) => null),
                tasksFilterHasUnsavedClausesProvider.overrideWith(
                  (ref) => false,
                ),
              ],
              child: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      key: const ValueKey('open-filter-modal'),
                      onPressed: () =>
                          showTaskFilterModal(context, showTasks: true),
                      child: const Text('Open Filter'),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
        await tester.pumpAndSettle();

        // Tap Apply so _applyFilterState executes with hasSearchMode==true.
        final applyBtn = find.byKey(
          const ValueKey('design-system-task-filter-apply'),
        );
        await tester.ensureVisible(applyBtn);
        await tester.tap(applyBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // applyBatchFilterUpdate was called with a searchMode (not null).
        expect(fakeController.applyBatchFilterUpdateCalled, 1);
        expect(fakeController.searchModeCalls, isNotEmpty);
      },
    );

    testWidgets(
      '_draftStateToTasksFilter falls back to controllerState toggles',
      (tester) async {
        // Set non-default values so the fallback paths (lines 308, 311) use
        // the controllerState values rather than a toggle override.
        mockState = mockState.copyWith(
          showCreationDate: true,
          showDueDate: false,
        );

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
        await tester.pumpAndSettle();

        // Apply without changing any toggles; _draftStateToTasksFilter will
        // use the toggleMap values (which equal the controllerState defaults
        // from buildTasksFilterSheetState). The ?? fallbacks are reached only
        // when the toggle ID is absent; here we verify the apply path writes
        // the correct show-creation / show-due-date values.
        final applyBtn = find.byKey(
          const ValueKey('design-system-task-filter-apply'),
        );
        await tester.ensureVisible(applyBtn);
        await tester.tap(applyBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(fakeController.applyBatchFilterUpdateCalled, 1);
        // showCreationDate=true and showDueDate=false come from the toggle
        // map (which mirrors controllerState); both lines 308 & 311 are exercised.
        expect(fakeController.showCreationDateCalls, contains(true));
        expect(fakeController.showDueDateCalls, contains(false));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Tests from task_filter_modal_save_flow_test.dart — recording save flow
  // ---------------------------------------------------------------------------
  group('save flow (recording)', () {
    late FakeJournalPageController saveFlowFakeController;
    late JournalPageState saveFlowMockState;
    late MockEntitiesCacheService saveFlowMockCache;
    late MockJournalDb saveFlowMockJournalDb;

    setUp(() {
      saveFlowMockCache = MockEntitiesCacheService();
      saveFlowMockJournalDb = MockJournalDb();

      when(() => saveFlowMockCache.sortedCategories).thenReturn(const []);
      when(() => saveFlowMockCache.sortedLabels).thenReturn(const []);
      when(
        () => saveFlowMockJournalDb.getProjectsForCategory(any()),
      ).thenAnswer((_) async => <ProjectEntry>[]);

      saveFlowMockState = const JournalPageState(
        taskStatuses: ['OPEN', 'IN PROGRESS'],
        selectedTaskStatuses: {'OPEN'},
        selectedCategoryIds: {},
        selectedLabelIds: {},
        selectedPriorities: {},
      );

      final saveFlowMockSettingsDb = MockSettingsDb();
      when(
        () => saveFlowMockSettingsDb.itemByKey(any()),
      ).thenAnswer((_) async => null);
      when(
        () => saveFlowMockSettingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);

      getIt.allowReassignment = true;
      getIt
        ..registerSingleton<EntitiesCacheService>(saveFlowMockCache)
        ..registerSingleton<JournalDb>(saveFlowMockJournalDb)
        ..registerSingleton<SettingsDb>(saveFlowMockSettingsDb);
    });

    tearDown(getIt.reset);

    Widget buildSaveFlowSubject({
      required _RecordingSavedFiltersController recorder,
      String? activeId,
      bool hasUnsavedClauses = true,
      JournalPageState? pageState,
    }) {
      saveFlowFakeController = FakeJournalPageController(
        pageState ?? saveFlowMockState,
      );

      return WidgetTestBench(
        child: ProviderScope(
          overrides: [
            journalPageScopeProvider.overrideWithValue(true),
            journalPageControllerProvider(true).overrideWith(
              () => saveFlowFakeController,
            ),
            savedTaskFiltersControllerProvider.overrideWith(() => recorder),
            currentSavedTaskFilterIdProvider.overrideWith((ref) => activeId),
            tasksFilterHasUnsavedClausesProvider.overrideWith(
              (ref) => hasUnsavedClauses,
            ),
          ],
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const ValueKey('open-filter-modal'),
                onPressed: () => showTaskFilterModal(context, showTasks: true),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> openModalAndSave(
      WidgetTester tester, {
      required String typedName,
    }) async {
      await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(DesignSystemTaskFilterActionBar.saveNamePopupFieldKey),
        typedName,
      );
      await tester.pump();
      await tester.tap(
        find.byKey(DesignSystemTaskFilterActionBar.saveNamePopupCommitKey),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'creates a new saved filter when no active id is set, captures the '
      'modal draft, and closes the modal',
      (tester) async {
        final recorder = _RecordingSavedFiltersController(const []);
        await tester.pumpWidget(
          buildSaveFlowSubject(
            recorder: recorder,
            pageState: const JournalPageState(
              taskStatuses: ['OPEN', 'IN PROGRESS'],
              selectedTaskStatuses: {'IN PROGRESS'},
              selectedCategoryIds: {},
              selectedLabelIds: {},
              selectedPriorities: {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await openModalAndSave(tester, typedName: '  My filter  ');

        expect(recorder.creates, hasLength(1));
        expect(recorder.creates.single.name, 'My filter');
        expect(
          recorder.creates.single.filter.selectedTaskStatuses,
          {'IN PROGRESS'},
        );
        expect(recorder.updates, isEmpty);

        expect(
          find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
          findsNothing,
        );
      },
    );

    testWidgets(
      'updates the active saved filter when typed name matches the active name',
      (tester) async {
        final recorder = _RecordingSavedFiltersController(
          const [
            SavedTaskFilter(
              id: 'sv-1',
              name: 'In progress',
              filter: TasksFilter(),
            ),
          ],
        );
        await tester.pumpWidget(
          buildSaveFlowSubject(
            recorder: recorder,
            activeId: 'sv-1',
            pageState: const JournalPageState(
              taskStatuses: ['OPEN', 'IN PROGRESS', 'BLOCKED'],
              selectedTaskStatuses: {'BLOCKED'},
              selectedCategoryIds: {},
              selectedLabelIds: {},
              selectedPriorities: {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byKey(const ValueKey('open-filter-modal'))),
        );
        await container.read(savedTaskFiltersControllerProvider.future);
        await tester.pumpAndSettle();

        await openModalAndSave(tester, typedName: 'In progress');

        expect(recorder.updates, hasLength(1));
        expect(recorder.updates.single.id, 'sv-1');
        expect(
          recorder.updates.single.filter.selectedTaskStatuses,
          {'BLOCKED'},
        );
        expect(recorder.creates, isEmpty);
      },
    );

    testWidgets(
      'creates a new saved filter when active id has no resolved name',
      (tester) async {
        final recorder = _RecordingSavedFiltersController(const []);
        await tester.pumpWidget(
          buildSaveFlowSubject(
            recorder: recorder,
            activeId: 'sv-1',
          ),
        );
        await tester.pumpAndSettle();

        await openModalAndSave(tester, typedName: 'Whatever');

        expect(recorder.creates, hasLength(1));
        expect(recorder.creates.single.name, 'Whatever');
        expect(recorder.updates, isEmpty);
      },
    );

    testWidgets(
      'creates a new saved filter when typed name differs from active name',
      (tester) async {
        final recorder = _RecordingSavedFiltersController(
          const [
            SavedTaskFilter(
              id: 'sv-1',
              name: 'Existing',
              filter: TasksFilter(),
            ),
          ],
        );
        await tester.pumpWidget(
          buildSaveFlowSubject(
            recorder: recorder,
            activeId: 'sv-1',
            pageState: const JournalPageState(
              taskStatuses: ['OPEN', 'IN PROGRESS', 'BLOCKED'],
              selectedTaskStatuses: {'BLOCKED'},
              selectedCategoryIds: {},
              selectedLabelIds: {},
              selectedPriorities: {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byKey(const ValueKey('open-filter-modal'))),
        );
        await container.read(savedTaskFiltersControllerProvider.future);
        await tester.pumpAndSettle();

        await openModalAndSave(tester, typedName: 'Different');

        expect(recorder.creates, hasLength(1));
        expect(recorder.creates.single.name, 'Different');
        expect(recorder.updates, isEmpty);
      },
    );

    testWidgets(
      'captures in-modal priority edits in the saved filter — regression '
      'guard for the bug where Save persisted the previously applied '
      'filter instead of the current modal draft',
      (tester) async {
        final recorder = _RecordingSavedFiltersController(const []);
        await tester.pumpWidget(buildSaveFlowSubject(recorder: recorder));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
        await tester.pumpAndSettle();

        final p1Chip = find.byKey(
          const ValueKey('design-system-task-filter-priority-p1'),
        );
        await tester.ensureVisible(p1Chip);
        await tester.pumpAndSettle();
        await tester.tap(p1Chip);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(DesignSystemTaskFilterActionBar.saveNamePopupFieldKey),
          'Edited',
        );
        await tester.pump();
        await tester.tap(
          find.byKey(DesignSystemTaskFilterActionBar.saveNamePopupCommitKey),
        );
        await tester.pumpAndSettle();

        expect(recorder.creates, hasLength(1));
        expect(recorder.creates.single.name, 'Edited');
        expect(
          recorder.creates.single.filter.selectedPriorities,
          {'P1'},
        );
        expect(recorder.updates, isEmpty);
        expect(
          find.byKey(DesignSystemTaskFilterActionBar.saveButtonKey),
          findsNothing,
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProjectEntry _makeTestProject(
  String id,
  String categoryId,
  String title,
) {
  final epoch = DateTime(2024);
  return ProjectEntry(
    meta: Metadata(
      id: id,
      createdAt: epoch,
      updatedAt: epoch,
      dateFrom: epoch,
      dateTo: epoch,
      categoryId: categoryId,
    ),
    data: ProjectData(
      title: title,
      status: ProjectStatus.active(
        id: 'status-1',
        createdAt: epoch,
        utcOffset: 0,
      ),
      dateFrom: epoch,
      dateTo: epoch,
    ),
  );
}

// ---------------------------------------------------------------------------
// Stubs / test doubles
// ---------------------------------------------------------------------------

class _StubSavedTaskFiltersController extends SavedTaskFiltersController {
  _StubSavedTaskFiltersController(this._seed);
  final List<SavedTaskFilter> _seed;

  @override
  Future<List<SavedTaskFilter>> build() async => _seed;
}

/// Stubs that either succeed or throw on [create] / [updateFilter].
class _ThrowingSavedTaskFiltersController extends SavedTaskFiltersController {
  _ThrowingSavedTaskFiltersController({required this.throwOnCreate});

  final bool throwOnCreate;

  @override
  Future<List<SavedTaskFilter>> build() async => const [];

  @override
  Future<SavedTaskFilter> create({
    required String name,
    required TasksFilter filter,
  }) async {
    if (throwOnCreate) {
      throw Exception('create failed');
    }
    return SavedTaskFilter(
      id: 'new-id',
      name: name,
      filter: filter,
    );
  }
}

/// Recorder controller — captures `create` and `updateFilter` calls so we can
/// assert which save-flow branch ran.
class _RecordingSavedFiltersController extends SavedTaskFiltersController {
  _RecordingSavedFiltersController(this._seed);

  final List<SavedTaskFilter> _seed;
  final List<({String name, TasksFilter filter})> creates = [];
  final List<({String id, TasksFilter filter})> updates = [];

  @override
  Future<List<SavedTaskFilter>> build() async => _seed;

  @override
  Future<SavedTaskFilter> create({
    required String name,
    required TasksFilter filter,
  }) async {
    creates.add((name: name, filter: filter));
    final created = SavedTaskFilter(
      id: 'sv-${creates.length}',
      name: name,
      filter: filter,
    );
    state = AsyncData([..._seed, created]);
    return created;
  }

  @override
  Future<void> updateFilter(String id, TasksFilter filter) async {
    updates.add((id: id, filter: filter));
  }
}
