import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/knowledge/agent_knowledge_providers.dart';
import 'package:lotti/features/agents/ui/knowledge/agent_knowledge_panel.dart';
import 'package:lotti/features/goals/ui/knowledge/goal_knowledge_section.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  final proposed =
      AgentDomainEntity.plannerKnowledge(
            id: 'fact-1',
            agentId: 'goal-agent',
            key: 'walks-after-dinner',
            hook: 'Walks after dinner',
            statementText: 'I walk after dinner, never before.',
            source: KnowledgeSource.agentInferred,
            status: KnowledgeStatus.proposed,
            createdAt: DateTime(2026, 10),
            updatedAt: DateTime(2026, 10),
            vectorClock: null,
          )
          as PlannerKnowledgeEntity;

  Future<void> pump(
    WidgetTester tester,
    Future<AgentKnowledgeView> Function() view,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const GoalKnowledgeSection(agentId: 'goal-agent'),
        overrides: [
          agentKnowledgeProvider('goal-agent').overrideWith((ref) => view()),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('a goal whose agent has learned nothing gains no card', (
    tester,
  ) async {
    await pump(
      tester,
      () async => const AgentKnowledgeView(confirmed: [], proposed: []),
    );

    expect(find.byKey(const ValueKey('goal-knowledge-section')), findsNothing);
    expect(find.byType(AgentKnowledgePanel), findsNothing);
  });

  testWidgets('nothing renders until the knowledge has loaded', (
    tester,
  ) async {
    final pending = Completer<AgentKnowledgeView>();
    await pump(tester, () => pending.future);

    expect(find.byType(AgentKnowledgePanel), findsNothing);
    pending.complete(const AgentKnowledgeView(confirmed: [], proposed: []));
  });

  testWidgets("a fact awaiting the user shows this goal's panel", (
    tester,
  ) async {
    await pump(
      tester,
      () async => AgentKnowledgeView(confirmed: const [], proposed: [proposed]),
    );

    final panel = tester.widget<AgentKnowledgePanel>(
      find.byType(AgentKnowledgePanel),
    );
    expect(panel.agentId, 'goal-agent');
    expect(find.text('I walk after dinner, never before.'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
  });

  testWidgets('a failed first read shows why, with a retry that reloads', (
    tester,
  ) async {
    var reads = 0;
    await pump(tester, () async {
      reads++;
      if (reads == 1) throw Exception('store unavailable');
      return AgentKnowledgeView(confirmed: const [], proposed: [proposed]);
    });

    // The facts are not silently out of reach: the panel says so.
    expect(find.byKey(const ValueKey('goal-knowledge-section')), findsOne);
    expect(find.text("Couldn't load what I've learned."), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-knowledge-retry')));
    await tester.pump();
    await tester.pump();

    expect(reads, 2);
    expect(find.text('I walk after dinner, never before.'), findsOneWidget);
  });
}
