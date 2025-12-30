// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/filtering/task_status_filter.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class FakeJournalPageController extends JournalPageController {
  FakeJournalPageController(this._testState);

  final JournalPageState _testState;
  final List<String> toggledStatuses = [];
  final List<String> singleSelectedStatuses = [];
  int clearSelectedTaskStatusesCalled = 0;
  int selectAllTaskStatusesCalled = 0;

  @override
  JournalPageState build(bool showTasks) => _testState;

  @override
  JournalPageState get state => _testState;

  @override
  Future<void> toggleSelectedTaskStatus(String status) async {
    toggledStatuses.add(status);
  }

  @override
  Future<void> selectSingleTaskStatus(String status) async {
    singleSelectedStatuses.add(status);
  }

  @override
  Future<void> clearSelectedTaskStatuses() async {
    clearSelectedTaskStatusesCalled++;
  }

  @override
  Future<void> selectAllTaskStatuses() async {
    selectAllTaskStatusesCalled++;
  }
}

class MockPagingController extends Mock
    implements PagingController<int, JournalEntity> {}

void main() {
  late FakeJournalPageController fakeController;
  late JournalPageState mockState;
  late MockPagingController mockPagingController;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Register a mock for the HapticFeedback service
    // tester. binding. defaultBinaryMessenger.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform,
            (MethodCall methodCall) async {
      return null;
    });

    mockPagingController = MockPagingController();
    mockState = JournalPageState(
      match: '',
      tagIds: <String>{},
      filters: {},
      showPrivateEntries: false,
      selectedEntryTypes: const [],
      fullTextMatches: {},
      showTasks: true,
      pagingController: mockPagingController,
      taskStatuses: const ['OPEN', 'GROOMED', 'IN PROGRESS'],
      selectedTaskStatuses: {'OPEN'},
      selectedCategoryIds: {},
      selectedLabelIds: const {},
    );
  });

  Widget buildWithState(JournalPageState state) {
    fakeController = FakeJournalPageController(state);

    return WidgetTestBench(
      child: ProviderScope(
        overrides: [
          journalPageScopeProvider.overrideWithValue(true),
          journalPageControllerProvider(true)
              .overrideWith(() => fakeController),
        ],
        child: const TaskStatusFilter(),
      ),
    );
  }

  Widget buildChipWithState(JournalPageState state, Widget child) {
    fakeController = FakeJournalPageController(state);

    return WidgetTestBench(
      child: ProviderScope(
        overrides: [
          journalPageScopeProvider.overrideWithValue(true),
          journalPageControllerProvider(true)
              .overrideWith(() => fakeController),
        ],
        child: child,
      ),
    );
  }

  group('TaskStatusFilter', () {
    testWidgets('renders correctly with all statuses', (tester) async {
      await tester.pumpWidget(buildWithState(mockState));
      await tester.pumpAndSettle();

      // Verify the widget is rendered
      expect(find.byType(TaskStatusFilter), findsOneWidget);

      // Verify the title is displayed
      expect(find.byType(Text), findsWidgets);

      // Verify all task status chips are rendered (3 statuses + All chip)
      expect(find.byType(FilterChoiceChip), findsNWidgets(4));

      // Verify each status chip is rendered - using a more general approach
      // Instead of checking for specific text, just make sure we have the right number
      // of FilterChoiceChips that are not the "All" chip
      final statusChips = tester.widgetList<FilterChoiceChip>(
        find.byWidgetPredicate(
          (widget) =>
              widget is FilterChoiceChip &&
              !widget.label.toLowerCase().contains('all'),
        ),
      );
      expect(statusChips.length, mockState.taskStatuses.length);

      // Verify the "All" chip is rendered
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is FilterChoiceChip &&
              widget.label.toLowerCase().contains('all'),
        ),
        findsOneWidget,
      );
    });
  });

  group('TaskStatusChip', () {
    testWidgets('renders correctly when status is selected', (tester) async {
      // Set up a selected status
      const selectedStatus = 'OPEN';

      await tester.pumpWidget(
        buildChipWithState(
          mockState,
          const TaskStatusChip(
            selectedStatus,
            onlySelected: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the chip is rendered
      expect(find.byType(FilterChoiceChip), findsOneWidget);

      // Verify the chip is selected
      final chipWidget =
          tester.widget<FilterChoiceChip>(find.byType(FilterChoiceChip));
      expect(chipWidget.isSelected, isTrue);
    });

    testWidgets('renders correctly when status is not selected',
        (tester) async {
      // Set up a non-selected status
      const nonSelectedStatus = 'GROOMED';

      await tester.pumpWidget(
        buildChipWithState(
          mockState,
          const TaskStatusChip(
            nonSelectedStatus,
            onlySelected: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the chip is rendered
      expect(find.byType(FilterChoiceChip), findsOneWidget);

      // Verify the chip is not selected
      final chipWidget =
          tester.widget<FilterChoiceChip>(find.byType(FilterChoiceChip));
      expect(chipWidget.isSelected, isFalse);
    });

    testWidgets(
        'does not render when onlySelected is true and status is not selected',
        (tester) async {
      // Set up a non-selected status
      const nonSelectedStatus = 'GROOMED';

      await tester.pumpWidget(
        buildChipWithState(
          mockState,
          const TaskStatusChip(
            nonSelectedStatus,
            onlySelected: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the chip is not rendered
      expect(find.byType(FilterChoiceChip), findsNothing);
    });

    testWidgets('calls toggleSelectedTaskStatus when tapped', (tester) async {
      // Set up a status
      const status = 'GROOMED';

      await tester.pumpWidget(
        buildChipWithState(
          mockState,
          const TaskStatusChip(
            status,
            onlySelected: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the chip
      await tester.tap(find.byType(FilterChoiceChip));
      await tester.pump();

      // Verify that toggleSelectedTaskStatus was called
      expect(fakeController.toggledStatuses, contains(status));
    });

    testWidgets('calls selectSingleTaskStatus when long pressed',
        (tester) async {
      // Set up a status
      const status = 'GROOMED';

      await tester.pumpWidget(
        buildChipWithState(
          mockState,
          const TaskStatusChip(
            status,
            onlySelected: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long press on the chip
      await tester.longPress(find.byType(FilterChoiceChip));
      await tester.pump();

      // Verify that selectSingleTaskStatus was called
      expect(fakeController.singleSelectedStatuses, contains(status));
    });
  });

  group('TaskStatusAllChip', () {
    testWidgets('renders correctly when all statuses are selected',
        (tester) async {
      // Set all statuses to be selected
      final allSelectedState = JournalPageState(
        match: '',
        tagIds: <String>{},
        filters: {},
        showPrivateEntries: false,
        selectedEntryTypes: const [],
        fullTextMatches: {},
        showTasks: true,
        pagingController: mockPagingController,
        taskStatuses: const ['OPEN', 'GROOMED', 'IN PROGRESS'],
        selectedTaskStatuses: {'OPEN', 'GROOMED', 'IN PROGRESS'},
        selectedCategoryIds: {},
        selectedLabelIds: const {},
      );

      await tester.pumpWidget(
        buildChipWithState(allSelectedState, const TaskStatusAllChip()),
      );
      await tester.pumpAndSettle();

      // Verify the chip is rendered
      expect(find.byType(FilterChoiceChip), findsOneWidget);

      // Verify the chip is selected
      final chipWidget =
          tester.widget<FilterChoiceChip>(find.byType(FilterChoiceChip));
      expect(chipWidget.isSelected, isTrue);
    });

    testWidgets('renders correctly when not all statuses are selected',
        (tester) async {
      // Only some statuses are selected (default in setUp)

      await tester.pumpWidget(
        buildChipWithState(mockState, const TaskStatusAllChip()),
      );
      await tester.pumpAndSettle();

      // Verify the chip is rendered
      expect(find.byType(FilterChoiceChip), findsOneWidget);

      // Verify the chip is not selected
      final chipWidget =
          tester.widget<FilterChoiceChip>(find.byType(FilterChoiceChip));
      expect(chipWidget.isSelected, isFalse);
    });

    testWidgets(
        'calls clearSelectedTaskStatuses when tapped and all are selected',
        (tester) async {
      // Set all statuses to be selected
      final allSelectedState = JournalPageState(
        match: '',
        tagIds: <String>{},
        filters: {},
        showPrivateEntries: false,
        selectedEntryTypes: const [],
        fullTextMatches: {},
        showTasks: true,
        pagingController: mockPagingController,
        taskStatuses: const ['OPEN', 'GROOMED', 'IN PROGRESS'],
        selectedTaskStatuses: {'OPEN', 'GROOMED', 'IN PROGRESS'},
        selectedCategoryIds: {},
        selectedLabelIds: const {},
      );

      await tester.pumpWidget(
        buildChipWithState(allSelectedState, const TaskStatusAllChip()),
      );
      await tester.pumpAndSettle();

      // Tap on the chip
      await tester.tap(find.byType(FilterChoiceChip));
      await tester.pump();

      // Verify that clearSelectedTaskStatuses was called
      expect(fakeController.clearSelectedTaskStatusesCalled, 1);
    });

    testWidgets(
        'calls selectAllTaskStatuses when tapped and not all are selected',
        (tester) async {
      // Only some statuses are selected (default in setUp)

      await tester.pumpWidget(
        buildChipWithState(mockState, const TaskStatusAllChip()),
      );
      await tester.pumpAndSettle();

      // Tap on the chip
      await tester.tap(find.byType(FilterChoiceChip));
      await tester.pump();

      // Verify that selectAllTaskStatuses was called
      expect(fakeController.selectAllTaskStatusesCalled, 1);
    });
  });
}
