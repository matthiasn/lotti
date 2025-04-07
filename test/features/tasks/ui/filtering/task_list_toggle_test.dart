import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/ui/filtering/task_list_toggle.dart';
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
      taskAsListView: true,
      pagingController: mockPagingController,
      taskStatuses: const ['OPEN', 'GROOMED', 'IN PROGRESS'],
      selectedTaskStatuses: {'OPEN'},
      selectedCategoryIds: {},
    );

    when(() => mockCubit.state).thenReturn(mockState);
  });

  Widget buildSubject() {
    return createTestApp(
      BlocProvider<JournalPageCubit>.value(
        value: mockCubit,
        child: const TaskListToggle(),
      ),
    );
  }

  group('TaskListToggle', () {
    testWidgets('renders correctly when taskAsListView is true',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify that the widget is rendered
      expect(find.byType(TaskListToggle), findsOneWidget);

      // Verify that SegmentedButton is rendered
      expect(find.byType(SegmentedButton<bool>), findsOneWidget);

      // Verify that the correct icons are displayed
      expect(find.byIcon(Icons.density_small_rounded), findsOneWidget);
      expect(find.byIcon(Icons.density_medium_rounded), findsOneWidget);
    });

    testWidgets('renders correctly when taskAsListView is false',
        (tester) async {
      // Change the state to return false for taskAsListView
      mockState = JournalPageState(
        match: '',
        tagIds: <String>{},
        filters: {},
        showPrivateEntries: false,
        selectedEntryTypes: const [],
        fullTextMatches: {},
        showTasks: true,
        taskAsListView: false,
        pagingController: mockPagingController,
        taskStatuses: const ['OPEN', 'GROOMED', 'IN PROGRESS'],
        selectedTaskStatuses: {'OPEN'},
        selectedCategoryIds: {},
      );
      when(() => mockCubit.state).thenReturn(mockState);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify that the widget is rendered
      expect(find.byType(TaskListToggle), findsOneWidget);

      // Verify that SegmentedButton is rendered
      expect(find.byType(SegmentedButton<bool>), findsOneWidget);

      // Verify that the correct icons are displayed
      expect(find.byIcon(Icons.density_small_rounded), findsOneWidget);
      expect(find.byIcon(Icons.density_medium_rounded), findsOneWidget);
    });

    testWidgets('calls toggleTaskAsListView when tapped', (tester) async {
      // Set up the mock to allow the toggleTaskAsListView call
      when(() => mockCubit.toggleTaskAsListView()).thenAnswer((_) {});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Tap on the second segment (false)
      await tester.tap(find.byIcon(Icons.density_medium_rounded));
      await tester.pump();

      // Verify that toggleTaskAsListView was called
      verify(() => mockCubit.toggleTaskAsListView()).called(1);
    });
  });
}
