// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/filtering/task_filter_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../../test_utils/fake_journal_page_controller.dart';

void main() {
  late FakeJournalPageController fakeController;
  late JournalPageState mockState;
  late MockPagingController mockPagingController;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockJournalDb mockJournalDb;

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

  setUp(() {
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

    getIt.allowReassignment = true;
    getIt
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<JournalDb>(mockJournalDb);
  });

  tearDown(getIt.reset);

  Widget buildSubject() {
    fakeController = FakeJournalPageController(mockState);

    return WidgetTestBench(
      child: ProviderScope(
        overrides: [
          journalPageScopeProvider.overrideWithValue(true),
          journalPageControllerProvider(true).overrideWith(
            () => fakeController,
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
  });
}
