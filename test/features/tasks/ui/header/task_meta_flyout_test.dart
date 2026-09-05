import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_flyout.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_section.dart';
import 'package:lotti/features/tasks/ui/header/task_status_modal_content.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_utils/material_ui_finders.dart';
import '../../../../widget_test_utils.dart';
import '../../../ai_consumption/test_utils.dart';

class _FakeTaskProgressController extends TaskProgressController {
  @override
  Future<TaskProgressState?> build() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 4, 20, 12);
  const taskId = 'task-1';

  final task = Task(
    meta: Metadata(
      id: taskId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
    data: TaskData(
      status: TaskStatus.open(id: 'status-1', createdAt: now, utcOffset: 0),
      dateFrom: now,
      dateTo: now,
      statusHistory: const [],
      title: 'Test Task',
    ),
  );

  late MockJournalDb mockJournalDb;

  setUp(() async {
    final mockCache = MockEntitiesCacheService();
    when(() => mockCache.showPrivateEntries).thenReturn(true);
    when(() => mockCache.getCategoryById(any())).thenReturn(null);
    when(() => mockCache.getLabelById(any())).thenReturn(null);

    final mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<EntitiesCacheService>(mockCache)
          ..registerSingleton<EditorStateService>(MockEditorStateService())
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
          ..registerSingleton<TimeService>(MockTimeService())
          ..registerSingleton<NavService>(MockNavService());
      },
    );
    mockJournalDb = mocks.journalDb;
    when(
      () => mockJournalDb.typedLinksForTaskIds(
        any(),
        types: any(named: 'types'),
      ),
    ).thenAnswer((_) async => <EntryLink>[]);
  });

  tearDown(tearDownTestGetIt);

  Future<void> pumpOpener(
    WidgetTester tester, {
    ToggleCallTracker? tracker,
    Completer<void>? writeGate,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryControllerProvider(taskId).overrideWith(
            () => ScriptedEntryController(
              task,
              tracker: tracker,
              gate: writeGate,
            ),
          ),
          labelsStreamProvider.overrideWith(
            (ref) => Stream<List<LabelDefinition>>.value(const []),
          ),
          projectForTaskProvider(taskId).overrideWith((ref) async => null),
          taskProgressControllerProvider(
            taskId,
          ).overrideWith(_FakeTaskProgressController.new),
          taskConsumptionTotalsProvider(
            taskId,
          ).overrideWith((ref) => Stream.value(makeConsumptionTotals())),
        ],
        child: makeTestableWidgetNoScroll(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => TaskMetaFlyout.show(context, taskId: taskId),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Opens the status picker from the fly-out's Status row, and asserts it is
  /// actually up — every test below turns on which of the two stacked modals
  /// a later tap lands in.
  Future<void> openStatusPicker(WidgetTester tester) async {
    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskStatusModalContent), findsOneWidget);
  }

  testWidgets('opens the metadata section in a titled modal', (tester) async {
    await pumpOpener(tester);

    expect(find.text('Task details'), findsOneWidget);
    final section = tester.widget<TaskMetaSection>(
      find.byType(TaskMetaSection),
    );
    expect(section.taskId, taskId);
    // The modal host keeps the two-column measure; only the persistent
    // column stacks its rows.
    expect(section.density, TaskMetaDensity.wide);
  });

  testWidgets('closes itself when a status is picked', (tester) async {
    // The header's completion celebration plays directly behind this panel,
    // so the panel gets out of the way rather than dimming the moment it
    // exists to mark.
    final tracker = ToggleCallTracker();
    await pumpOpener(tester, tracker: tracker);
    await openStatusPicker(tester);

    await tester.tap(find.byKey(const ValueKey('task-status-DONE')));
    await tester.pumpAndSettle();

    expect(find.text('Task details'), findsNothing);
    expect(find.byType(TaskMetaSection), findsNothing);
    // Closing the panel is not instead of the write — it precedes it.
    expect(tracker.updateTaskStatusCalls, equals(['DONE']));
  });

  testWidgets('stays open when the status picker closes with no choice', (
    tester,
  ) async {
    final tracker = ToggleCallTracker();
    await pumpOpener(tester, tracker: tracker);
    await openStatusPicker(tester);

    // The picker is the later of the two modal routes, so its close button is
    // the later of the two in the tree.
    await tester.tap(findMaterialTooltip('Close').last);
    await tester.pumpAndSettle();

    // The picker really closed — without this the whole test would also pass
    // on a tap that landed nowhere.
    expect(find.byType(TaskStatusModalContent), findsNothing);
    expect(find.text('Task details'), findsOneWidget);
    expect(tracker.updateTaskStatusCalls, isEmpty);
  });

  testWidgets('closes on Blocked and still prompts for the blocker', (
    tester,
  ) async {
    // The composition the two halves of this change meet in: the fly-out pops
    // itself, taking the picker's `context` and `ref` with it, and the
    // follow-up prompt still has to arrive. The gate holds the write past the
    // panel's exit animation, so the section really is disposed by the time
    // the prompt is decided — un-gated, the route's subtree outlives the write
    // and the test would pass without the durable container/overlay context.
    final mockFts5Db = MockFts5Db();
    when(
      () => mockJournalDb.getTasks(
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => <JournalEntity>[]);
    when(
      () => mockFts5Db.watchFullTextMatches(any()),
    ).thenAnswer((_) => Stream.value(<String>[]));
    getIt.registerSingleton<Fts5Db>(mockFts5Db);

    final tracker = ToggleCallTracker();
    final writeGate = Completer<void>();
    await pumpOpener(tester, tracker: tracker, writeGate: writeGate);
    await openStatusPicker(tester);

    await tester.tap(find.byKey(const ValueKey('task-status-BLOCKED')));
    await tester.pumpAndSettle();

    // The panel is gone before the write has even landed.
    expect(find.text('Task details'), findsNothing);
    expect(find.byType(TaskMetaSection), findsNothing);
    expect(tracker.updateTaskStatusCalls, isEmpty);

    writeGate.complete();
    await tester.pumpAndSettle();

    expect(tracker.updateTaskStatusCalls, equals(['BLOCKED']));
    expect(find.text("What's blocking this?"), findsOneWidget);
  });
}
