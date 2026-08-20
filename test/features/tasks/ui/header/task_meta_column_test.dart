import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_column.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_section.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../mocks/mocks.dart';
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
  late MockEntitiesCacheService mockCache;

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
      due: DateTime(2026, 4, 25),
      estimate: const Duration(hours: 2),
    ),
  );

  setUp(() async {
    mockCache = MockEntitiesCacheService();
    when(() => mockCache.showPrivateEntries).thenReturn(true);
    when(() => mockCache.getCategoryById(any())).thenReturn(null);
    when(() => mockCache.getLabelById(any())).thenReturn(null);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<EntitiesCacheService>(mockCache)
          ..registerSingleton<EditorStateService>(MockEditorStateService())
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
          ..registerSingleton<TimeService>(MockTimeService())
          ..registerSingleton<NavService>(MockNavService());
      },
    );
  });

  tearDown(tearDownTestGetIt);

  Widget pumpColumn({bool scaffold = true}) {
    const column = Row(
      children: [
        Expanded(child: SizedBox.expand()),
        TaskMetaColumn(taskId: taskId),
      ],
    );
    return ProviderScope(
      overrides: [
        entryControllerProvider(taskId).overrideWith(
          () => FakeEntryController(task),
        ),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value(const []),
        ),
        projectForTaskProvider(taskId).overrideWith((ref) async => null),
        taskProgressControllerProvider(
          taskId,
        ).overrideWith(_FakeTaskProgressController.new),
        taskConsumptionTotalsProvider(taskId).overrideWith(
          (ref) => Stream.value(makeConsumptionTotals()),
        ),
      ],
      child: makeTestableWidgetNoScroll(
        scaffold ? const Scaffold(body: column) : column,
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('carries its own title above the metadata rows', (tester) async {
    await tester.pumpWidget(pumpColumn());
    await settle(tester);

    expect(find.text('Task details'), findsOneWidget);
    final title = tester.getBottomLeft(find.text('Task details'));
    final firstRow = tester.getTopLeft(find.text('Status'));
    expect(firstRow.dy, greaterThanOrEqualTo(title.dy));
  });

  testWidgets('holds the section at the stacked narrow density', (
    tester,
  ) async {
    await tester.pumpWidget(pumpColumn());
    await settle(tester);

    final section = tester.widget<TaskMetaSection>(
      find.byType(TaskMetaSection),
    );
    expect(section.taskId, taskId);
    expect(section.density, TaskMetaDensity.narrow);
  });

  testWidgets('occupies exactly the column width', (tester) async {
    await tester.pumpWidget(pumpColumn());
    await settle(tester);

    expect(
      tester.getSize(find.byType(TaskMetaColumn)).width,
      kTaskMetaColumnWidth,
    );
  });

  testWidgets('brings its own Material so the rows inherit a text style', (
    tester,
  ) async {
    // Pumped with NO Scaffold above it — the column is a sibling of the task
    // page's Scaffold, not a child of it. Without a Material of its own the
    // rows have no default text style to inherit (Flutter flags that with
    // yellow underlines) and the row ink has nothing to paint on.
    await tester.pumpWidget(pumpColumn(scaffold: false));
    await settle(tester);

    expect(
      find.ancestor(
        of: find.text('Task details'),
        matching: find.byType(Material),
      ),
      findsWidgets,
    );
  });

  testWidgets('scrolls on its own so the task beside it stays put', (
    tester,
  ) async {
    await tester.pumpWidget(pumpColumn());
    await settle(tester);

    expect(
      find.descendant(
        of: find.byType(TaskMetaColumn),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
  });

  testWidgets('every metadata row survives the narrow measure unclipped', (
    tester,
  ) async {
    await tester.pumpWidget(pumpColumn());
    await settle(tester);

    for (final label in [
      'Status',
      'Priority',
      'Category',
      'Due date',
      'Estimate',
      'Labels',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label row missing');
    }
    expect(find.text('Apr 25, 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('TaskMetaColumnScope', () {
    testWidgets('reports the column mounted above the subtree', (
      tester,
    ) async {
      late bool visible;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          TaskMetaColumnScope(
            visible: true,
            child: Builder(
              builder: (context) {
                visible = TaskMetaColumnScope.isVisible(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(visible, isTrue);
    });

    testWidgets('reads false with no scope at all', (tester) async {
      late bool visible;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              visible = TaskMetaColumnScope.isVisible(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(visible, isFalse);
    });
  });
}
