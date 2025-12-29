import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/ui/filtering/task_date_display_toggle.dart';
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
    bool showCreationDate = false,
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
      showCreationDate: showCreationDate,
    );
  }

  Widget buildSubject() {
    return WidgetTestBench(
      child: BlocProvider<JournalPageCubit>.value(
        value: mockCubit,
        child: const TaskDateDisplayToggle(),
      ),
    );
  }

  group('TaskDateDisplayToggle', () {
    testWidgets('renders correctly with Switch and label', (tester) async {
      when(() => mockCubit.state).thenReturn(createState());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify the widget is rendered
      expect(find.byType(TaskDateDisplayToggle), findsOneWidget);

      // Verify Switch is present
      expect(find.byType(Switch), findsOneWidget);

      // Verify label text is present
      expect(find.text('Show creation date on cards'), findsOneWidget);
    });

    testWidgets('Switch is off when showCreationDate is false', (tester) async {
      when(() => mockCubit.state).thenReturn(createState());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);
    });

    testWidgets('Switch is on when showCreationDate is true', (tester) async {
      when(() => mockCubit.state)
          .thenReturn(createState(showCreationDate: true));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);
    });

    testWidgets(
        'calls setShowCreationDate(show: true) when Switch is turned on',
        (tester) async {
      when(() => mockCubit.state).thenReturn(createState());
      when(() => mockCubit.setShowCreationDate(show: true))
          .thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Tap on the Switch to turn it on
      await tester.tap(find.byType(Switch));
      await tester.pump();

      verify(() => mockCubit.setShowCreationDate(show: true)).called(1);
    });

    testWidgets(
        'calls setShowCreationDate(show: false) when Switch is turned off',
        (tester) async {
      when(() => mockCubit.state)
          .thenReturn(createState(showCreationDate: true));
      when(() => mockCubit.setShowCreationDate(show: false))
          .thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Tap on the Switch to turn it off
      await tester.tap(find.byType(Switch));
      await tester.pump();

      verify(() => mockCubit.setShowCreationDate(show: false)).called(1);
    });

    testWidgets('label and switch are in a Row', (tester) async {
      when(() => mockCubit.state).thenReturn(createState());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify Row contains both label and switch
      final rowFinder = find.byType(Row);
      expect(rowFinder, findsOneWidget);

      expect(
        find.descendant(of: rowFinder, matching: find.byType(Switch)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: rowFinder,
          matching: find.text('Show creation date on cards'),
        ),
        findsOneWidget,
      );
    });
  });
}
