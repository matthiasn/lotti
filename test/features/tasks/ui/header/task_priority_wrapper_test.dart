import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_priority_wrapper.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/widgets/cards/modern_status_chip.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPersistenceLogic mockPersistenceLogic;
  late MockEditorStateService mockEditorStateService;
  late MockJournalDb mockJournalDb;
  late MockUpdateNotifications mockUpdateNotifications;

  setUpAll(() {
    registerFallbackValue(fallbackJournalEntity);
    registerFallbackValue(FakeTaskData());
    mockPersistenceLogic = MockPersistenceLogic();
    mockEditorStateService = MockEditorStateService();
    mockJournalDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => const Stream<Set<String>>.empty());

    getIt
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<EditorStateService>(mockEditorStateService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  tearDownAll(() async {
    await getIt.reset();
  });

  testWidgets('opens picker and updates priority', (tester) async {
    final task = testTask.copyWith(
      data: testTask.data.copyWith(priority: TaskPriority.p2Medium),
    );

    when(() => mockPersistenceLogic.updateTask(
          journalEntityId: any(named: 'journalEntityId'),
          taskData: any(named: 'taskData'),
          categoryId: any(named: 'categoryId'),
          entryText: any(named: 'entryText'),
        )).thenAnswer((_) async => true);

    final overrides = <Override>[
      entryControllerProvider(id: task.meta.id).overrideWith(
        () => _TestEntryController(task),
      ),
    ];

    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: overrides,
        child: TaskPriorityWrapper(taskId: task.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    // Button shows current short code
    expect(find.text('P2'), findsOneWidget);

    // Open the picker by tapping the label on the button
    await tester.tap(find.text('P2'));
    await tester.pumpAndSettle();

    // Tap P0 row
    await tester.tap(find.textContaining('P0'));
    await tester.pumpAndSettle();

    final captured = verify(() => mockPersistenceLogic.updateTask(
          journalEntityId: task.meta.id,
          taskData: captureAny(named: 'taskData'),
          categoryId: any(named: 'categoryId'),
          entryText: any(named: 'entryText'),
        )).captured;

    final updated = captured.single as TaskData;
    expect(updated.priority, TaskPriority.p0Urgent);
  });

  testWidgets('renders Priority: label and chip in header', (tester) async {
    final task = testTask;

    final overrides = <Override>[
      entryControllerProvider(id: task.meta.id).overrideWith(
        () => _TestEntryController(task),
      ),
    ];

    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: overrides,
        child: TaskPriorityWrapper(taskId: task.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Priority:'), findsOneWidget);
    expect(find.byType(ModernStatusChip), findsOneWidget);
  });

  testWidgets('modal shows chips and no exclamation icon', (tester) async {
    final task = testTask;

    final overrides = <Override>[
      entryControllerProvider(id: task.meta.id).overrideWith(
        () => _TestEntryController(task),
      ),
    ];

    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: overrides,
        child: TaskPriorityWrapper(taskId: task.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    // Open modal by tapping header label
    await tester.tap(find.text('Priority:'));
    await tester.pumpAndSettle();

    // Expect chip options (P0..P3) and no old exclamation icon
    expect(find.text('P0'), findsOneWidget);
    expect(find.text('P1'), findsOneWidget);
    // 'P2' appears in header chip and in the modal; allow multiple.
    expect(find.text('P2'), findsWidgets);
    expect(find.text('P3'), findsOneWidget);
    expect(find.byIcon(Icons.priority_high_rounded), findsNothing);
  });

  testWidgets('priority selection persists after rebuild', (tester) async {
    final initial = testTask.copyWith(
      data: testTask.data.copyWith(priority: TaskPriority.p2Medium),
    );

    var currentPriority = TaskPriority.p2Medium;

    when(() => mockPersistenceLogic.updateTask(
          journalEntityId: any(named: 'journalEntityId'),
          taskData: any(named: 'taskData'),
          categoryId: any(named: 'categoryId'),
          entryText: any(named: 'entryText'),
        )).thenAnswer((invocation) async {
      final td = invocation.namedArguments[#taskData] as TaskData;
      currentPriority = td.priority;
      return true;
    });

    List<Override> buildOverrides() => <Override>[
          entryControllerProvider(id: initial.meta.id).overrideWith(
            () => _TestEntryController(initial.copyWith(
              data: initial.data.copyWith(priority: currentPriority),
            )),
          ),
        ];

    // Initial build
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: buildOverrides(),
        child: TaskPriorityWrapper(taskId: initial.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('P2'), findsOneWidget);

    // Change to P0 via UI
    await tester.tap(find.text('P2'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('P0'));
    await tester.pumpAndSettle();

    // Rebuild the widget tree simulating a rebuild
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: buildOverrides(),
        child: TaskPriorityWrapper(taskId: initial.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    // Verify persistence in UI and captured state
    expect(find.text('P0'), findsOneWidget);
    expect(currentPriority, TaskPriority.p0Urgent);
  });
}
