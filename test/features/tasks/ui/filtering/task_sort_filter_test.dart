import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/ui/filtering/task_sort_filter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockJournalPageCubit extends MockCubit<JournalPageState>
    implements JournalPageCubit {}

class MockPagingController extends Mock
    implements PagingController<int, JournalEntity> {}

void main() {
  late MockJournalPageCubit mockCubit;
  late MockPagingController mockPagingController;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Register a mock for the HapticFeedback service
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform,
            (MethodCall methodCall) async {
      return null;
    });

    mockCubit = MockJournalPageCubit();
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

  Widget buildSubject() {
    return WidgetTestBench(
      child: BlocProvider<JournalPageCubit>.value(
        value: mockCubit,
        child: const TaskSortFilter(),
      ),
    );
  }

  group('TaskSortFilter', () {
    testWidgets('renders correctly with SegmentedButton', (tester) async {
      when(() => mockCubit.state).thenReturn(createState());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify the widget is rendered
      expect(find.byType(TaskSortFilter), findsOneWidget);

      // Verify SegmentedButton is present
      expect(find.byType(SegmentedButton<TaskSortOption>), findsOneWidget);

      // Verify both segment labels are present
      expect(find.text('Priority'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
    });

    testWidgets('shows Priority selected when sortOption is byPriority',
        (tester) async {
      when(() => mockCubit.state).thenReturn(createState());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final segmentedButton = tester.widget<SegmentedButton<TaskSortOption>>(
        find.byType(SegmentedButton<TaskSortOption>),
      );

      expect(segmentedButton.selected, {TaskSortOption.byPriority});
    });

    testWidgets('shows Date selected when sortOption is byDate',
        (tester) async {
      when(() => mockCubit.state)
          .thenReturn(createState(sortOption: TaskSortOption.byDate));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final segmentedButton = tester.widget<SegmentedButton<TaskSortOption>>(
        find.byType(SegmentedButton<TaskSortOption>),
      );

      expect(segmentedButton.selected, {TaskSortOption.byDate});
    });

    testWidgets('calls setSortOption when Priority segment is tapped',
        (tester) async {
      when(() => mockCubit.state)
          .thenReturn(createState(sortOption: TaskSortOption.byDate));
      when(() => mockCubit.setSortOption(TaskSortOption.byPriority))
          .thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Tap on Priority segment
      await tester.tap(find.text('Priority'));
      await tester.pump();

      verify(() => mockCubit.setSortOption(TaskSortOption.byPriority))
          .called(1);
    });

    testWidgets('calls setSortOption when Date segment is tapped',
        (tester) async {
      when(() => mockCubit.state).thenReturn(createState());
      when(() => mockCubit.setSortOption(TaskSortOption.byDate))
          .thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Tap on Date segment
      await tester.tap(find.text('Date'));
      await tester.pump();

      verify(() => mockCubit.setSortOption(TaskSortOption.byDate)).called(1);
    });

    testWidgets('displays sort by label', (tester) async {
      when(() => mockCubit.state).thenReturn(createState());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify label is shown
      expect(find.text('Sort by'), findsOneWidget);
    });

    testWidgets('SegmentedButton has two segments', (tester) async {
      when(() => mockCubit.state).thenReturn(createState());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify SegmentedButton has exactly 2 segments
      final segmentedButton = tester.widget<SegmentedButton<TaskSortOption>>(
        find.byType(SegmentedButton<TaskSortOption>),
      );
      expect(segmentedButton.segments.length, 2);
      expect(segmentedButton.segments[0].value, TaskSortOption.byPriority);
      expect(segmentedButton.segments[1].value, TaskSortOption.byDate);
    });
  });
}
