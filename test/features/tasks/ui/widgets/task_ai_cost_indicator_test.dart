import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_cost_indicator.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/widgets/task_ai_cost_indicator.dart';
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

  Widget pump({required int callCount, Widget? indicator}) {
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
          (ref) => Stream.value(
            makeConsumptionTotals(
              callCount: callCount,
              impactCallCount: callCount,
              credits: callCount > 0 ? 0.35 : 0,
            ),
          ),
        ),
      ],
      child: makeTestableWidgetNoScroll(
        Scaffold(
          body: Center(
            child: indicator ?? const TaskAiCostIndicator(taskId: taskId),
          ),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('renders the task cost once calls are recorded', (tester) async {
    await tester.pumpWidget(pump(callCount: 4));
    await settle(tester);

    expect(find.text('€0.35'), findsOneWidget);
  });

  testWidgets('renders nothing for a task that never used AI', (tester) async {
    await tester.pumpWidget(pump(callCount: 0));
    await settle(tester);

    expect(find.byType(AiCostIndicator), findsNothing);
  });

  testWidgets('tapping opens the task details', (tester) async {
    await tester.pumpWidget(pump(callCount: 4));
    await settle(tester);

    await tester.tap(find.text('€0.35'));
    await tester.pumpAndSettle();

    // The metadata fly-out, with the rows the compact indicator summarizes.
    expect(find.text('Task details'), findsOneWidget);
    expect(find.text('AI spend'), findsOneWidget);
  });

  testWidgets('an explicit callback replaces the default drill-down', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      pump(
        callCount: 4,
        indicator: TaskAiCostIndicator(
          taskId: taskId,
          onTap: () => taps++,
        ),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('€0.35'));
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(find.text('Task details'), findsNothing);
  });

  testWidgets('the read-only form carries no tap at all', (tester) async {
    await tester.pumpWidget(
      pump(
        callCount: 4,
        indicator: const TaskAiCostIndicator.readOnly(taskId: taskId),
      ),
    );
    await settle(tester);

    expect(
      tester.widget<AiCostIndicator>(find.byType(AiCostIndicator)).onTap,
      isNull,
    );
  });
}
