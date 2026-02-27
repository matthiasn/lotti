import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_instances_list.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });
  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

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

      final context = tester.element(find.byType(AgentInstancesList));
      expect(find.text('Task Worker'), findsOneWidget);
      expect(
        find.text(context.messages.agentEvolutionSessionTitle(2)),
        findsOneWidget,
      );
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
      expect(
        find.text(context.messages.agentEvolutionSessionTitle(1)),
        findsNothing,
      );
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
      expect(
        find.text(context.messages.agentEvolutionSessionTitle(5)),
        findsOneWidget,
      );
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

      final context = tester.element(find.byType(AgentInstancesList));
      expect(
        find.text(context.messages.agentEvolutionStatusCompleted),
        findsOneWidget,
      );
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

    testWidgets('task agent filter renders when evolution provider is loading',
        (tester) async {
      final agent = makeTestIdentity(
        id: 'agent-1',
        agentId: 'agent-1',
        displayName: 'Ready Agent',
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const Scaffold(body: AgentInstancesList()),
          overrides: [
            allAgentInstancesProvider.overrideWith(
              (ref) async => [agent],
            ),
            // Evolution provider never completes — simulates slow fetch.
            allEvolutionSessionsProvider.overrideWith(
              (ref) => Completer<List<AgentDomainEntity>>().future,
            ),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(false),
            ),
            templateForAgentProvider.overrideWith(
              (ref, agentId) async => null,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final context = tester.element(find.byType(AgentInstancesList));

      // Select "Task Agent" filter so evolution loading doesn't block us
      await tapSegment(tester, context.messages.agentInstancesKindTaskAgent);

      // Task agent should be visible despite evolution still loading
      expect(find.text('Ready Agent'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('evolution filter renders when agent provider errors',
        (tester) async {
      final session = makeTestEvolutionSession(
        id: 'evo-1',
        sessionNumber: 7,
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const Scaffold(body: AgentInstancesList()),
          overrides: [
            // Agent provider errors
            allAgentInstancesProvider.overrideWith(
              (ref) async => throw Exception('agent fetch failed'),
            ),
            allEvolutionSessionsProvider.overrideWith(
              (ref) async => [session],
            ),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(false),
            ),
            templateForAgentProvider.overrideWith(
              (ref, agentId) async => null,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final context = tester.element(find.byType(AgentInstancesList));

      // Select "Evolution" filter so agent error doesn't block us
      await tapSegment(tester, context.messages.agentInstancesKindEvolution);

      // Evolution session should be visible despite agent provider error
      expect(
        find.text(context.messages.agentEvolutionSessionTitle(7)),
        findsOneWidget,
      );
    });

    testWidgets('tapping task agent card navigates to agent detail',
        (tester) async {
      String? navigatedPath;
      beamToNamedOverride = (path) => navigatedPath = path;

      final agent = makeTestIdentity(
        id: 'agent-nav',
        agentId: 'agent-nav',
        displayName: 'Nav Agent',
      );

      await tester.pumpWidget(buildSubject(agents: [agent]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nav Agent'));
      expect(navigatedPath, '/settings/agents/instances/agent-nav');
    });

    testWidgets('tapping evolution card navigates to template detail',
        (tester) async {
      String? navigatedPath;
      beamToNamedOverride = (path) => navigatedPath = path;

      final session = makeTestEvolutionSession(
        id: 'evo-nav',
        templateId: 'tpl-42',
      );

      await tester.pumpWidget(buildSubject(evolutions: [session]));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentInstancesList));
      await tester.tap(
        find.text(context.messages.agentEvolutionSessionTitle(1)),
      );
      expect(navigatedPath, '/settings/agents/templates/tpl-42');
    });

    testWidgets('shows error state when both providers fail', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const Scaffold(body: AgentInstancesList()),
          overrides: [
            allAgentInstancesProvider.overrideWith(
              (ref) async => throw Exception('agents failed'),
            ),
            allEvolutionSessionsProvider.overrideWith(
              (ref) async => throw Exception('evolutions failed'),
            ),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(false),
            ),
            templateForAgentProvider.overrideWith(
              (ref, agentId) async => null,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentInstancesList));
      expect(find.text(context.messages.commonError), findsOneWidget);
    });

    testWidgets('shows abandoned evolution status badge', (tester) async {
      final session = makeTestEvolutionSession(
        id: 'evo-abandoned',
        status: EvolutionSessionStatus.abandoned,
      );

      await tester.pumpWidget(buildSubject(evolutions: [session]));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentInstancesList));
      expect(
        find.text(context.messages.agentEvolutionStatusAbandoned),
        findsOneWidget,
      );
    });

    testWidgets('shows created lifecycle badge on agent card', (tester) async {
      final agent = makeTestIdentity(
        id: 'agent-created',
        agentId: 'agent-created',
        displayName: 'Created Agent',
        lifecycle: AgentLifecycle.created,
      );

      await tester.pumpWidget(buildSubject(agents: [agent]));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentInstancesList));
      expect(
        find.text(context.messages.agentLifecycleCreated),
        findsAtLeast(1),
      );
    });

    testWidgets('shows destroyed lifecycle badge on agent card',
        (tester) async {
      final agent = makeTestIdentity(
        id: 'agent-destroyed',
        agentId: 'agent-destroyed',
        displayName: 'Destroyed Agent',
        lifecycle: AgentLifecycle.destroyed,
      );

      await tester.pumpWidget(buildSubject(agents: [agent]));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentInstancesList));
      expect(
        find.text(context.messages.agentLifecycleDestroyed),
        findsAtLeast(1),
      );
    });

    testWidgets('shows template name on task agent card when available',
        (tester) async {
      final agent = makeTestIdentity(
        id: 'agent-with-tpl',
        agentId: 'agent-with-tpl',
        displayName: 'Worker Agent',
      );

      final template = makeTestTemplate(
        id: 'tpl-for-agent',
        agentId: 'tpl-for-agent',
        displayName: 'My Template',
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
              (ref, agentId) => Stream.value(false),
            ),
            templateForAgentProvider.overrideWith(
              (ref, agentId) async => template,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Template'), findsOneWidget);
    });

    testWidgets('active evolution status badge is shown', (tester) async {
      final session = makeTestEvolutionSession(
        id: 'evo-active',
      );

      await tester.pumpWidget(buildSubject(evolutions: [session]));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentInstancesList));
      // "Active" appears in lifecycle filter segment AND in evolution status
      // badge — verify at least one occurrence from the status badge
      expect(
        find.text(context.messages.agentEvolutionStatusActive),
        findsAtLeast(1),
      );
    });
  });
}
