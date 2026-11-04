import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/classes/task_progress_state.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/agent_maintenance_section.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_cost_indicator.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/tasks/ui/widgets/task_ai_cost_indicator.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/project_lookup_providers.dart';
import 'package:lotti/providers/task_progress_controller.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../helpers/service_overrides.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/entity_factories.dart';
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

  final agent = makeTestIdentity(
    agentId: 'task-agent-1',
    displayName: 'Planning Agent',
  );

  Widget pump({
    required int callCount,
    Widget? indicator,
    AgentDomainEntity? taskAgent,
    Future<AgentDomainEntity?>? taskAgentLookup,
    // One lookup per fetch, in order — for refetch scenarios.
    List<Future<AgentDomainEntity?>>? taskAgentLookups,
  }) {
    return ProviderScope(
      overrides: withServiceOverrides([
        taskAgentProvider(taskId).overrideWith(
          (ref) =>
              taskAgentLookups?.removeAt(0) ??
              taskAgentLookup ??
              Future.value(taskAgent),
        ),
        // The internals panel resolves the identity; keeping it in flight
        // renders the panel shell without the tab bodies' providers.
        agentIdentityProvider.overrideWith(
          (ref, agentId) => Completer<AgentDomainEntity?>().future,
        ),
        agentStateProvider.overrideWith((ref, agentId) async => null),
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
      ]),
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

  Future<void> tapCost(WidgetTester tester) async {
    await tester.tap(find.text('€0.35'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  void expectInternalsOpened(WidgetTester tester) {
    final panel = tester.widget<AgentInternalsPanel>(
      find.byType(AgentInternalsPanel),
    );
    expect(panel.agentId, 'task-agent-1');
    expect(panel.agentName, 'Planning Agent');
    // The task's maintenance band rides along, as from the summary card.
    expect(panel.maintenance?.kind, AgentMaintenanceKind.task);
    expect(panel.maintenance?.entityId, taskId);
    expect(find.text('Agent internals'), findsOneWidget);
    expect(find.text('Task details'), findsNothing);
  }

  testWidgets(
    'tapping opens the task agent internals, not the task details',
    (tester) async {
      await tester.pumpWidget(pump(callCount: 4, taskAgent: agent));
      await settle(tester);

      await tapCost(tester);

      expectInternalsOpened(tester);
    },
  );

  testWidgets('a tap during the agent lookup waits for it, then opens the '
      'internals', (tester) async {
    final lookup = Completer<AgentDomainEntity?>();
    await tester.pumpWidget(
      pump(callCount: 4, taskAgentLookup: lookup.future),
    );
    await settle(tester);

    await tester.tap(find.text('€0.35'));
    await tester.pump();
    // Nothing opens while the lookup is unresolved, least of all the
    // details a task with an agent should not land on.
    expect(find.text('Task details'), findsNothing);
    expect(find.byType(AgentInternalsPanel), findsNothing);

    lookup.complete(agent);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expectInternalsOpened(tester);
  });

  testWidgets('taps repeated during the lookup open the internals once', (
    tester,
  ) async {
    final lookup = Completer<AgentDomainEntity?>();
    await tester.pumpWidget(
      pump(callCount: 4, taskAgentLookup: lookup.future),
    );
    await settle(tester);

    // No route is up while the lookup is pending, so nothing blocks the
    // second tap — the indicator must coalesce it.
    await tester.tap(find.text('€0.35'));
    await tester.pump();
    await tester.tap(find.text('€0.35'));
    await tester.pump();
    lookup.complete(agent);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(AgentInternalsPanel), findsOneWidget);
  });

  testWidgets('a refetch after "no agent" is waited for, not routed to the '
      'details', (tester) async {
    final refetch = Completer<AgentDomainEntity?>();
    await tester.pumpWidget(
      pump(
        callCount: 4,
        taskAgentLookups: [Future<AgentDomainEntity?>.value(), refetch.future],
      ),
    );
    await settle(tester);

    // An agent gets linked: the lookup refetches while still holding the
    // earlier "none".
    ProviderScope.containerOf(
      tester.element(find.byType(AiCostIndicator)),
    ).invalidate(taskAgentProvider(taskId));
    await tester.pump();

    await tester.tap(find.text('€0.35'));
    await tester.pump();
    expect(find.text('Task details'), findsNothing);

    refetch.complete(agent);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expectInternalsOpened(tester);
  });

  testWidgets('a tap during a lookup that finds no agent opens the details', (
    tester,
  ) async {
    final lookup = Completer<AgentDomainEntity?>();
    await tester.pumpWidget(
      pump(callCount: 4, taskAgentLookup: lookup.future),
    );
    await settle(tester);

    await tester.tap(find.text('€0.35'));
    await tester.pump();
    lookup.complete(null);
    await tester.pumpAndSettle();

    expect(find.text('Task details'), findsOneWidget);
    expect(find.byType(AgentInternalsPanel), findsNothing);
  });

  testWidgets('a tap during a lookup that fails opens the details', (
    tester,
  ) async {
    final lookup = Completer<AgentDomainEntity?>();
    await tester.pumpWidget(
      pump(callCount: 4, taskAgentLookup: lookup.future),
    );
    await settle(tester);

    await tester.tap(find.text('€0.35'));
    await tester.pump();
    lookup.completeError(StateError('agent repository unavailable'));
    await tester.pumpAndSettle();

    expect(find.text('Task details'), findsOneWidget);
    expect(find.byType(AgentInternalsPanel), findsNothing);
  });

  testWidgets('without an agent, tapping falls back to the task details', (
    tester,
  ) async {
    await tester.pumpWidget(pump(callCount: 4));
    await settle(tester);

    await tester.tap(find.text('€0.35'));
    await tester.pumpAndSettle();

    // The metadata fly-out, with the rows the compact indicator summarizes.
    expect(find.text('Task details'), findsOneWidget);
    expect(find.text('AI spend'), findsOneWidget);
    expect(find.byType(AgentInternalsPanel), findsNothing);
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

  testWidgets('inside the details, a task without an agent carries no tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      pump(
        callCount: 4,
        indicator: const TaskAiCostIndicator.inDetails(taskId: taskId),
      ),
    );
    await settle(tester);

    expect(
      tester.widget<AiCostIndicator>(find.byType(AiCostIndicator)).onTap,
      isNull,
    );
  });

  testWidgets('inside the details, tapping still opens the agent internals', (
    tester,
  ) async {
    await tester.pumpWidget(
      pump(
        callCount: 4,
        taskAgent: agent,
        indicator: const TaskAiCostIndicator.inDetails(taskId: taskId),
      ),
    );
    await settle(tester);

    await tapCost(tester);

    expectInternalsOpened(tester);
  });
}
