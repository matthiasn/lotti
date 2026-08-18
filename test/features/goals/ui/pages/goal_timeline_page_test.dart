import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_composer.dart';
import 'package:lotti/features/goals/ui/pages/goal_timeline_page.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../../widget_test_utils.dart';

void main() {
  final now = DateTime(2026, 8, 18, 9);

  AgentIdentityEntity identity(AgentLifecycle lifecycle) =>
      AgentDomainEntity.agent(
            id: 'agent-1',
            agentId: 'agent-1',
            kind: AgentKinds.goalAgent,
            displayName: 'Fitness',
            lifecycle: lifecycle,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {'cat-1'},
            currentStateId: 'agent-1:state',
            config: const AgentConfig(),
            createdAt: now,
            updatedAt: now,
            vectorClock: null,
          )
          as AgentIdentityEntity;

  setUp(() => beamToNamedOverride = null);
  tearDown(() => beamToNamedOverride = null);

  Future<void> pump(
    WidgetTester tester, {
    AgentLifecycle lifecycle = AgentLifecycle.active,
    void Function(String)? onBeam,
  }) {
    beamToNamedOverride = onBeam;
    return withClock(
      Clock.fixed(now),
      () => tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const GoalTimelinePage(agentId: 'agent-1'),
          overrides: [
            agentIdentityProvider(
              'agent-1',
            ).overrideWith((ref) async => identity(lifecycle)),
            goalTimelineItemsProvider('agent-1').overrideWithValue(const []),
            goalCaptureTargetProvider(
              'agent-1',
            ).overrideWith((ref) async => 'goal-1'),
          ],
        ),
      ),
    );
  }

  testWidgets('titles itself Check-ins and renders the rail', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Check-ins'), findsWidgets);
    expect(
      find.textContaining('Tell your agent what is actually going on'),
      findsOneWidget,
    );
  });

  testWidgets('an active goal can record without scrolling', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    // The history may be months long; creating must stay in the app bar.
    await tester.tap(
      find.byKey(const ValueKey('goal-timeline-checkin-action')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GoalCheckInComposer), findsOneWidget);
  });

  testWidgets('back returns to the goal, not to the goals list', (
    tester,
  ) async {
    final navigated = <String>[];
    await pump(tester, onBeam: navigated.add);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // The timeline is stacked on the goal; popping past it would drop the
    // user two levels.
    expect(navigated, ['/goals/details/agent-1']);
  });

  testWidgets('a dormant goal is readable but offers no capture', (
    tester,
  ) async {
    await pump(tester, lifecycle: AgentLifecycle.dormant);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('goal-timeline-checkin-action')),
      findsNothing,
    );
  });
}
