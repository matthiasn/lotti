import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_instances_list.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    List<AgentDomainEntity> agents = const [],
    List<AgentDomainEntity> evolutions = const [],
  }) {
    return makeTestableWidgetNoScroll(
      const Scaffold(body: AgentInstancesList()),
      overrides: [
        allAgentInstancesProvider.overrideWith(
          (ref) async => agents,
        ),
        allEvolutionSessionsProvider.overrideWith(
          (ref) async => evolutions,
        ),
        agentIsRunningProvider.overrideWith(
          (ref, agentId) => Stream.value(false),
        ),
        templateForAgentProvider.overrideWith(
          (ref, agentId) async => null,
        ),
      ],
    );
  }

  /// Taps a [SegmentedButton] segment by finding the text within it.
  Future<void> tapSegment(WidgetTester tester, String label) async {
    // SegmentedButton segments render text; when the same label appears
    // both in the filter and in a badge, we pick the first occurrence
    // which is always the filter row (rendered above the list).
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  group('AgentInstancesList', () {
    testWidgets('shows task agents by default', (tester) async {
      final agent = makeTestIdentity(
        id: 'agent-1',
        agentId: 'agent-1',
        displayName: 'Alpha Agent',
      );

      await tester.pumpWidget(buildSubject(agents: [agent]));
      await tester.pumpAndSettle();

      expect(find.text('Alpha Agent'), findsOneWidget);
    });

    testWidgets('shows both agents and evolutions in All mode', (tester) async {
      final agent = makeTestIdentity(
        id: 'agent-1',
        agentId: 'agent-1',
        displayName: 'Task Worker',
      );
      final session = makeTestEvolutionSession(
        id: 'evo-1',
        sessionNumber: 2,
      );

      await tester.pumpWidget(
        buildSubject(agents: [agent], evolutions: [session]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Task Worker'), findsOneWidget);
      expect(find.text('Evolution #2'), findsOneWidget);
    });

    testWidgets('filters to only task agents', (tester) async {
      final agent = makeTestIdentity(
        id: 'agent-1',
        agentId: 'agent-1',
        displayName: 'Task Worker',
      );
      final session = makeTestEvolutionSession(
        id: 'evo-1',
      );

      await tester.pumpWidget(
        buildSubject(agents: [agent], evolutions: [session]),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentInstancesList));
      await tapSegment(tester, context.messages.agentInstancesKindTaskAgent);

      expect(find.text('Task Worker'), findsOneWidget);
      expect(find.text('Evolution #1'), findsNothing);
    });

    testWidgets('filters to only evolution sessions', (tester) async {
      final agent = makeTestIdentity(
        id: 'agent-1',
        agentId: 'agent-1',
        displayName: 'Task Worker',
      );
      final session = makeTestEvolutionSession(
        id: 'evo-1',
        sessionNumber: 5,
      );

      await tester.pumpWidget(
        buildSubject(agents: [agent], evolutions: [session]),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentInstancesList));
      await tapSegment(tester, context.messages.agentInstancesKindEvolution);

      expect(find.text('Task Worker'), findsNothing);
      expect(find.text('Evolution #5'), findsOneWidget);
    });

    testWidgets('lifecycle filter narrows task agents', (tester) async {
      final activeAgent = makeTestIdentity(
        id: 'agent-active',
        agentId: 'agent-active',
        displayName: 'Active Agent',
      );
      final dormantAgent = makeTestIdentity(
        id: 'agent-dormant',
        agentId: 'agent-dormant',
        displayName: 'Dormant Agent',
        lifecycle: AgentLifecycle.dormant,
      );

      await tester.pumpWidget(
        buildSubject(agents: [activeAgent, dormantAgent]),
      );
      await tester.pumpAndSettle();

      // Both visible initially
      expect(find.text('Active Agent'), findsOneWidget);
      expect(find.text('Dormant Agent'), findsOneWidget);

      // Tap "Active" lifecycle filter (first occurrence is the filter segment)
      final context = tester.element(find.byType(AgentInstancesList));
      await tapSegment(tester, context.messages.agentInstancesFilterActive);

      expect(find.text('Active Agent'), findsOneWidget);
      expect(find.text('Dormant Agent'), findsNothing);
    });

    testWidgets('shows empty state when no instances match', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    });

    testWidgets('lifecycle badge is shown on agent card', (tester) async {
      final activeAgent = makeTestIdentity(
        id: 'agent-1',
        agentId: 'agent-1',
        displayName: 'Agent 1',
      );

      await tester.pumpWidget(buildSubject(agents: [activeAgent]));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentInstancesList));
      // "Active" appears both in the lifecycle filter segment and in the
      // lifecycle badge on the card — expect at least 2.
      expect(
        find.text(context.messages.agentLifecycleActive),
        findsAtLeast(2),
      );
    });

    testWidgets('evolution session card shows status badge', (tester) async {
      final session = makeTestEvolutionSession(
        id: 'evo-1',
        status: EvolutionSessionStatus.completed,
      );

      await tester.pumpWidget(buildSubject(evolutions: [session]));
      await tester.pumpAndSettle();

      expect(find.text('completed'), findsOneWidget);
    });

    testWidgets('running agent shows progress indicator', (tester) async {
      final agent = makeTestIdentity(
        id: 'agent-running',
        agentId: 'agent-running',
        displayName: 'Running Agent',
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const Scaffold(body: AgentInstancesList()),
          overrides: [
            allAgentInstancesProvider.overrideWith(
              (ref) async => [agent],
            ),
            allEvolutionSessionsProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(true),
            ),
            templateForAgentProvider.overrideWith(
              (ref, agentId) async => null,
            ),
          ],
        ),
      );
      // Use pump instead of pumpAndSettle since CircularProgressIndicator
      // animates continuously and never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Running Agent'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('hides lifecycle filter in evolution-only mode',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          evolutions: [makeTestEvolutionSession()],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentInstancesList));

      // Switch to Evolution filter
      await tapSegment(tester, context.messages.agentInstancesKindEvolution);

      // Lifecycle filter should not be visible
      expect(
        find.text(context.messages.agentInstancesFilterDormant),
        findsNothing,
      );
      expect(
        find.text(context.messages.agentInstancesFilterDestroyed),
        findsNothing,
      );
    });
  });
}
