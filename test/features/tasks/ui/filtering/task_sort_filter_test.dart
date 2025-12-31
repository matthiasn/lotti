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
import 'package:lotti/features/tasks/ui/filtering/task_sort_filter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class FakeJournalPageController extends JournalPageController {
  FakeJournalPageController(this._testState);

  final JournalPageState _testState;
  final List<TaskSortOption> sortOptionCalls = [];

  @override
  JournalPageState build(bool showTasks) => _testState;

  @override
  JournalPageState get state => _testState;

  @override
  Future<void> setSortOption(TaskSortOption sortOption) async {
    sortOptionCalls.add(sortOption);
  }
}

class MockPagingController extends Mock
    implements PagingController<int, JournalEntity> {}

void main() {
  late MockPagingController mockPagingController;
  late FakeJournalPageController fakeController;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Register a mock for the HapticFeedback service
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform,
            (MethodCall methodCall) async {
      return null;
    });

    mockPagingController = MockPagingController();
  });

  JournalPageState createState({
    TaskSortOption sortOption = TaskSortOption.byPriority,
  }) {
    return JournalPageState(
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
      sortOption: sortOption,
    );
  }

  Widget buildSubject(JournalPageState state) {
    fakeController = FakeJournalPageController(state);

    return WidgetTestBench(
      child: ProviderScope(
        overrides: [
          journalPageScopeProvider.overrideWithValue(true),
          journalPageControllerProvider(true)
              .overrideWith(() => fakeController),
        ],
        child: const TaskSortFilter(),
      ),
    );
  }

  group('TaskSortFilter', () {
    testWidgets('renders correctly with SegmentedButton', (tester) async {
      await tester.pumpWidget(buildSubject(createState()));
      await tester.pumpAndSettle();

      // Verify the widget is rendered
      expect(find.byType(TaskSortFilter), findsOneWidget);

      // Verify SegmentedButton is present
      expect(find.byType(SegmentedButton<TaskSortOption>), findsOneWidget);

      // Verify all segment labels are present
      expect(find.text('Due Date'), findsOneWidget);
      expect(find.text('Created'), findsOneWidget);
      expect(find.text('Priority'), findsOneWidget);
    });

    testWidgets('shows Priority selected when sortOption is byPriority',
        (tester) async {
      await tester.pumpWidget(buildSubject(createState()));
      await tester.pumpAndSettle();

      final segmentedButton = tester.widget<SegmentedButton<TaskSortOption>>(
        find.byType(SegmentedButton<TaskSortOption>),
      );

      expect(segmentedButton.selected, {TaskSortOption.byPriority});
    });

    testWidgets('shows Date selected when sortOption is byDate',
        (tester) async {
      await tester.pumpWidget(
          buildSubject(createState(sortOption: TaskSortOption.byDate)));
      await tester.pumpAndSettle();

      final segmentedButton = tester.widget<SegmentedButton<TaskSortOption>>(
        find.byType(SegmentedButton<TaskSortOption>),
      );

      expect(segmentedButton.selected, {TaskSortOption.byDate});
    });

    testWidgets('calls setSortOption when Priority segment is tapped',
        (tester) async {
      await tester.pumpWidget(
          buildSubject(createState(sortOption: TaskSortOption.byDate)));
      await tester.pumpAndSettle();

      // Tap on Priority segment
      await tester.tap(find.text('Priority'));
      await tester.pump();

      expect(
        fakeController.sortOptionCalls,
        contains(TaskSortOption.byPriority),
      );
    });

    testWidgets('calls setSortOption when Created segment is tapped',
        (tester) async {
      await tester.pumpWidget(buildSubject(createState()));
      await tester.pumpAndSettle();

      // Tap on Created segment
      await tester.tap(find.text('Created'));
      await tester.pump();

      expect(fakeController.sortOptionCalls, contains(TaskSortOption.byDate));
    });

    testWidgets('calls setSortOption when Due Date segment is tapped',
        (tester) async {
      await tester.pumpWidget(buildSubject(createState()));
      await tester.pumpAndSettle();

      // Tap on Due Date segment
      await tester.tap(find.text('Due Date'));
      await tester.pump();

      expect(
        fakeController.sortOptionCalls,
        contains(TaskSortOption.byDueDate),
      );
    });

    testWidgets('displays sort by label', (tester) async {
      await tester.pumpWidget(buildSubject(createState()));
      await tester.pumpAndSettle();

      // Verify label is shown
      expect(find.text('Sort by'), findsOneWidget);
    });

    testWidgets('SegmentedButton has three segments', (tester) async {
      await tester.pumpWidget(buildSubject(createState()));
      await tester.pumpAndSettle();

      // Verify SegmentedButton has exactly 3 segments
      final segmentedButton = tester.widget<SegmentedButton<TaskSortOption>>(
        find.byType(SegmentedButton<TaskSortOption>),
      );
      expect(segmentedButton.segments.length, 3);
      // Order: Due Date, Created, Priority
      expect(segmentedButton.segments[0].value, TaskSortOption.byDueDate);
      expect(segmentedButton.segments[1].value, TaskSortOption.byDate);
      expect(segmentedButton.segments[2].value, TaskSortOption.byPriority);
    });

    testWidgets('shows Due Date selected when sortOption is byDueDate',
        (tester) async {
      await tester.pumpWidget(
          buildSubject(createState(sortOption: TaskSortOption.byDueDate)));
      await tester.pumpAndSettle();

      final segmentedButton = tester.widget<SegmentedButton<TaskSortOption>>(
        find.byType(SegmentedButton<TaskSortOption>),
      );

      expect(segmentedButton.selected, {TaskSortOption.byDueDate});
    });
  });
}
