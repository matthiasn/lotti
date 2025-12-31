import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_creation_date_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../test_helper.dart';

class _TestEntryController extends EntryController {
  _TestEntryController(this._task);

  final Task _task;

  @override
  Future<EntryState?> build({required String id}) async {
    return EntryState.saved(
      entryId: id,
      entry: _task,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

class _NonTaskEntryController extends EntryController {
  @override
  Future<EntryState?> build({required String id}) async {
    // Return a non-Task entry (JournalEntry)
    return EntryState.saved(
      entryId: id,
      entry: testTextEntry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockEditorStateService mockEditorStateService;
  late MockJournalDb mockJournalDb;
  late MockUpdateNotifications mockUpdateNotifications;

  setUpAll(() {
    mockEditorStateService = MockEditorStateService();
    mockJournalDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => const Stream<Set<String>>.empty());

    getIt
      ..registerSingleton<EditorStateService>(mockEditorStateService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  tearDownAll(() async {
    await getIt.reset();
  });

  group('TaskCreationDateWidget', () {
    testWidgets('displays formatted date without time', (tester) async {
      final creationDate = DateTime(2025, 12, 24, 14, 30);
      final task = testTask.copyWith(
        meta: testTask.meta.copyWith(dateFrom: creationDate),
      );

      final overrides = <Override>[
        entryControllerProvider(id: task.meta.id).overrideWith(
          () => _TestEntryController(task),
        ),
      ];

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: overrides,
          child: TaskCreationDateWidget(taskId: task.meta.id),
        ),
      );
      await tester.pumpAndSettle();

      // Verify date is displayed in yMMMd format (without time)
      expect(
          find.text(DateFormat.yMMMd().format(creationDate)), findsOneWidget);

      // Verify time is NOT displayed (using same format used by the widget)
      final timeStr = DateFormat.Hm().format(creationDate);
      expect(find.textContaining(timeStr), findsNothing);
    });

    testWidgets('renders for Task entries', (tester) async {
      final task = testTask;

      final overrides = <Override>[
        entryControllerProvider(id: task.meta.id).overrideWith(
          () => _TestEntryController(task),
        ),
      ];

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: overrides,
          child: TaskCreationDateWidget(taskId: task.meta.id),
        ),
      );
      await tester.pumpAndSettle();

      // Widget should render for Task entries
      expect(find.byType(TaskCreationDateWidget), findsOneWidget);
    });

    testWidgets('is tappable to open date picker modal', (tester) async {
      final task = testTask;

      final overrides = <Override>[
        entryControllerProvider(id: task.meta.id).overrideWith(
          () => _TestEntryController(task),
        ),
      ];

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: overrides,
          child: TaskCreationDateWidget(taskId: task.meta.id),
        ),
      );
      await tester.pumpAndSettle();

      // Verify widget is wrapped in GestureDetector
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('returns empty widget for non-Task entries', (tester) async {
      final overrides = <Override>[
        entryControllerProvider(id: 'non-task').overrideWith(
          _NonTaskEntryController.new,
        ),
      ];

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: overrides,
          child: const TaskCreationDateWidget(taskId: 'non-task'),
        ),
      );
      await tester.pumpAndSettle();

      // Should return empty widget (SizedBox.shrink) for non-Task
      expect(find.byType(TaskCreationDateWidget), findsOneWidget);
      // The widget should not contain any text or icons
      expect(find.byIcon(Icons.calendar_today_rounded), findsNothing);
    });

    testWidgets('opens modal when tapped', (tester) async {
      final task = testTask;

      final overrides = <Override>[
        entryControllerProvider(id: task.meta.id).overrideWith(
          () => _TestEntryController(task),
        ),
      ];

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: overrides,
          child: TaskCreationDateWidget(taskId: task.meta.id),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the widget to open the date picker modal
      await tester.tap(find.byIcon(Icons.calendar_today_rounded));
      await tester.pumpAndSettle();

      // Verify modal is opened by checking for "Date & Time Range" title
      expect(find.text('Date & Time Range'), findsOneWidget);
    });
  });
}
