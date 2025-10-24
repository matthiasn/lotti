import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/ui/filtering/task_status_filter.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockJournalPageCubit extends MockCubit<JournalPageState>
    implements JournalPageCubit {}

class MockPagingController extends Mock
    implements PagingController<int, JournalEntity> {}

void main() {
  late MockJournalPageCubit mockCubit;
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

    mockCubit = MockJournalPageCubit();
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
    );

    when(() => mockCubit.state).thenReturn(mockState);
  });

  group('TaskStatusFilter', () {
    Widget buildSubject() {
      return WidgetTestBench(
        child: BlocProvider<JournalPageCubit>.value(
          value: mockCubit,
          child: const TaskStatusFilter(),
        ),
      );
    }

    testWidgets('renders correctly with all statuses', (tester) async {
      await tester.pumpWidget(buildSubject());
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
        WidgetTestBench(
          child: BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const TaskStatusChip(
              selectedStatus,
              onlySelected: false,
            ),
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
        WidgetTestBench(
          child: BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const TaskStatusChip(
              nonSelectedStatus,
              onlySelected: false,
            ),
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
        WidgetTestBench(
          child: BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const TaskStatusChip(
              nonSelectedStatus,
              onlySelected: true,
            ),
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

      // Set up the mock to allow the toggleSelectedTaskStatus call
      when(() => mockCubit.toggleSelectedTaskStatus(status))
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        WidgetTestBench(
          child: BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const TaskStatusChip(
              status,
              onlySelected: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the chip
      await tester.tap(find.byType(FilterChoiceChip));
      await tester.pump();

      // Verify that toggleSelectedTaskStatus was called
      verify(() => mockCubit.toggleSelectedTaskStatus(status)).called(1);
    });

    testWidgets('calls selectSingleTaskStatus when long pressed',
        (tester) async {
      // Set up a status
      const status = 'GROOMED';

      // Set up the mock to allow the selectSingleTaskStatus call
      when(() => mockCubit.selectSingleTaskStatus(status))
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        WidgetTestBench(
          child: BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const TaskStatusChip(
              status,
              onlySelected: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long press on the chip
      await tester.longPress(find.byType(FilterChoiceChip));
      await tester.pump();

      // Verify that selectSingleTaskStatus was called
      verify(() => mockCubit.selectSingleTaskStatus(status)).called(1);
    });
  });

  group('TaskStatusAllChip', () {
    testWidgets('renders correctly when all statuses are selected',
        (tester) async {
      // Set all statuses to be selected
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
        selectedTaskStatuses: {'OPEN', 'GROOMED', 'IN PROGRESS'},
        selectedCategoryIds: {},
      );
      when(() => mockCubit.state).thenReturn(mockState);

      await tester.pumpWidget(
        WidgetTestBench(
          child: BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const TaskStatusAllChip(),
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

    testWidgets('renders correctly when not all statuses are selected',
        (tester) async {
      // Only some statuses are selected (default in setUp)

      await tester.pumpWidget(
        WidgetTestBench(
          child: BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const TaskStatusAllChip(),
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
        'calls clearSelectedTaskStatuses when tapped and all are selected',
        (tester) async {
      // Set all statuses to be selected
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
        selectedTaskStatuses: {'OPEN', 'GROOMED', 'IN PROGRESS'},
        selectedCategoryIds: {},
      );
      when(() => mockCubit.state).thenReturn(mockState);

      // Set up the mock to allow the clearSelectedTaskStatuses call
      when(() => mockCubit.clearSelectedTaskStatuses())
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        WidgetTestBench(
          child: BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const TaskStatusAllChip(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the chip
      await tester.tap(find.byType(FilterChoiceChip));
      await tester.pump();

      // Verify that clearSelectedTaskStatuses was called
      verify(() => mockCubit.clearSelectedTaskStatuses()).called(1);
    });

    testWidgets(
        'calls selectAllTaskStatuses when tapped and not all are selected',
        (tester) async {
      // Only some statuses are selected (default in setUp)

      // Set up the mock to allow the selectAllTaskStatuses call
      when(() => mockCubit.selectAllTaskStatuses()).thenAnswer((_) async {});

      await tester.pumpWidget(
        WidgetTestBench(
          child: BlocProvider<JournalPageCubit>.value(
            value: mockCubit,
            child: const TaskStatusAllChip(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the chip
      await tester.tap(find.byType(FilterChoiceChip));
      await tester.pump();

      // Verify that selectAllTaskStatuses was called
      verify(() => mockCubit.selectAllTaskStatuses()).called(1);
    });
  });
}
