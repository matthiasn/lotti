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
import 'package:lotti/features/tasks/ui/filtering/task_date_display_toggle.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class FakeJournalPageController extends JournalPageController {
  FakeJournalPageController(this._testState);

  final JournalPageState _testState;
  final List<bool> showCreationDateCalls = [];

  @override
  JournalPageState build(bool showTasks) => _testState;

  @override
  JournalPageState get state => _testState;

  @override
  Future<void> setShowCreationDate({required bool show}) async {
    showCreationDateCalls.add(show);
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

  Widget buildSubject(JournalPageState state) {
    fakeController = FakeJournalPageController(state);

    return WidgetTestBench(
      child: ProviderScope(
        overrides: [
          journalPageScopeProvider.overrideWithValue(true),
          journalPageControllerProvider(true)
              .overrideWith(() => fakeController),
        ],
        child: const TaskDateDisplayToggle(),
      ),
    );
  }

  group('TaskDateDisplayToggle', () {
    testWidgets('renders correctly with SwitchListTile and label',
        (tester) async {
      await tester.pumpWidget(buildSubject(createState()));
      await tester.pumpAndSettle();

      // Verify the widget is rendered
      expect(find.byType(TaskDateDisplayToggle), findsOneWidget);

      // Verify SwitchListTile is present (which contains Switch internally)
      expect(find.byType(SwitchListTile), findsOneWidget);

      // Verify label text is present
      expect(find.text('Show creation date on cards'), findsOneWidget);
    });

    testWidgets('Switch is off when showCreationDate is false', (tester) async {
      await tester.pumpWidget(buildSubject(createState()));
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);
    });

    testWidgets('Switch is on when showCreationDate is true', (tester) async {
      await tester
          .pumpWidget(buildSubject(createState(showCreationDate: true)));
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);
    });

    testWidgets(
        'calls setShowCreationDate(show: true) when Switch is turned on',
        (tester) async {
      await tester.pumpWidget(buildSubject(createState()));
      await tester.pumpAndSettle();

      // Tap on the Switch to turn it on
      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(fakeController.showCreationDateCalls, contains(true));
    });

    testWidgets(
        'calls setShowCreationDate(show: false) when Switch is turned off',
        (tester) async {
      await tester
          .pumpWidget(buildSubject(createState(showCreationDate: true)));
      await tester.pumpAndSettle();

      // Tap on the Switch to turn it off
      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(fakeController.showCreationDateCalls, contains(false));
    });

    testWidgets('SwitchListTile contains label and switch', (tester) async {
      await tester.pumpWidget(buildSubject(createState()));
      await tester.pumpAndSettle();

      // Verify SwitchListTile contains both label and switch
      final listTileFinder = find.byType(SwitchListTile);
      expect(listTileFinder, findsOneWidget);

      // Verify Switch is within SwitchListTile
      expect(
        find.descendant(of: listTileFinder, matching: find.byType(Switch)),
        findsOneWidget,
      );

      // Verify label text is within SwitchListTile
      expect(
        find.descendant(
          of: listTileFinder,
          matching: find.text('Show creation date on cards'),
        ),
        findsOneWidget,
      );
    });
  });
}
