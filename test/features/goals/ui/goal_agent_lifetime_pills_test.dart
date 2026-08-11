import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/goals/ui/goal_agent_lifetime_pills.dart';

import '../../../widget_test_utils.dart';
import '../../ai_consumption/test_utils.dart';

void main() {
  testWidgets('shows lifetime Melious impact and compute pills', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: GoalAgentLifetimePills(agentId: 'goal-1')),
        overrides: [
          agentConsumptionTotalsProvider.overrideWith(
            (ref, agentId) => Stream.value(
              makeConsumptionTotals(
                callCount: 3,
                impactCallCount: 2,
                inputTokens: 1200,
                outputTokens: 800,
                totalTokens: 2000,
                credits: 0.42,
                energyKwh: 0.012,
                carbonGCo2: 3.4,
                waterLiters: 0.012,
                durationMs: 3660000,
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('€0.42 · 12 Wh · 3.4 g'), findsOneWidget);
    expect(find.text('1h 1m AI time'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('goal-agent-lifetime-pills')),
      findsOneWidget,
    );
  });

  testWidgets('uses the localized sub-minute duration in the lifetime pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: GoalAgentLifetimePills(agentId: 'goal-1')),
        locale: const Locale('de'),
        overrides: [
          agentConsumptionTotalsProvider.overrideWith(
            (ref, agentId) => Stream.value(
              makeConsumptionTotals(callCount: 1, durationMs: 1200),
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Unter 1 Min. KI-Zeit'), findsOneWidget);
  });

  testWidgets('hides governance pills when the agent has no calls', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: GoalAgentLifetimePills(agentId: 'goal-1')),
        overrides: [
          agentConsumptionTotalsProvider.overrideWith(
            (ref, agentId) => Stream.value(makeConsumptionTotals()),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('goal-agent-lifetime-pills')),
      findsNothing,
    );
  });

  testWidgets('withholds AI time when legacy calls have no duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: GoalAgentLifetimePills(agentId: 'goal-1')),
        overrides: [
          agentConsumptionTotalsProvider.overrideWith(
            (ref, agentId) => Stream.value(
              makeConsumptionTotals(
                callCount: 2,
                inputTokens: 100,
                outputTokens: 50,
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('goal-agent-lifetime-pills')),
      findsOneWidget,
    );
    expect(find.textContaining('AI time'), findsNothing);
  });
}
