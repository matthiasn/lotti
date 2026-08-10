import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/pages/agents_page.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../../widget_test_utils.dart';

void main() {
  AgentIdentityEntity identity(String id, String name) =>
      AgentDomainEntity.agent(
            id: id,
            agentId: id,
            kind: AgentKinds.goalAgent,
            displayName: name,
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: '$id:state',
            config: const AgentConfig(),
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            vectorClock: null,
          )
          as AgentIdentityEntity;

  GoalAgentHealth health({
    GoalTrackStatus? trackStatus,
    String? reportOneLiner,
    int pendingProposals = 0,
    GoalHealthDirection? direction,
  }) => (
    trackStatus: trackStatus,
    attainment: null,
    reportOneLiner: reportOneLiner,
    pendingProposals: pendingProposals,
    spec: null,
    direction: direction,
  );

  testWidgets('the empty state is the first-run explainer, not a bare line', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const AgentsPage(),
        overrides: [
          activeGoalAgentsProvider.overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('One agent per goal'), findsOneWidget);
    // The cost-honesty line and the CTA are part of the explainer.
    expect(find.textContaining('fractions of a cent'), findsOneWidget);
    expect(find.text('Set an intention'), findsOneWidget);

    // The CTA opens the creation flow.
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);
    await tester.tap(find.text('Set an intention'));
    await tester.pump();
    expect(navigated, ['/agents/create']);
  });

  testWidgets('a row shows the coarse health chip, the executive summary '
      'and the direction arrow — and NO percentage', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const AgentsPage(),
        overrides: [
          activeGoalAgentsProvider.overrideWith(
            (ref) async => [
              identity('goal-fit', 'Expedition fitness'),
              identity('goal-sleep', 'Sleep 8h'),
            ],
          ),
          goalAgentHealthProvider('goal-fit').overrideWith(
            (ref) async => health(
              trackStatus: GoalTrackStatus.offTrack,
              reportOneLiner: 'The gym has been quiet since Tuesday.',
              pendingProposals: 1,
              direction: GoalHealthDirection.down,
            ),
          ),
          goalAgentHealthProvider('goal-sleep').overrideWith(
            (ref) async => health(
              trackStatus: GoalTrackStatus.onTrack,
              reportOneLiner: 'Seven solid nights running.',
              direction: GoalHealthDirection.up,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Coarse health: offTrack → Behind, onTrack → Healthy.
    expect(find.text('Behind'), findsOneWidget);
    expect(find.text('Healthy'), findsOneWidget);
    // The runtime status vocabulary never reaches the chip.
    expect(find.text('Off track'), findsNothing);
    expect(find.text('On track'), findsNothing);

    // Executive summaries render; no percentage anywhere.
    expect(find.text('The gym has been quiet since Tuesday.'), findsOneWidget);
    expect(find.text('Seven solid nights running.'), findsOneWidget);
    expect(find.textContaining('% of target'), findsNothing);

    // Needs-you badge on the goal with a pending proposal — its caption reads
    // in the alert's `ink` foreground, not the raw hue (contrast floor).
    expect(find.text('Proposal awaiting review'), findsOneWidget);
    final tokens = resolveTestTheme().extension<DsTokens>()!;
    expect(
      tester.widget<Text>(find.text('Proposal awaiting review')).style?.color,
      tokens.colors.alert.info.ink,
    );

    // Direction arrows: down for the slipping goal, up for the healthy one.
    expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
    expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);

    // The arrows carry screen-reader labels — otherwise the only trend
    // signal in the row is inaccessible. (The row's InkWell merges child
    // semantics, so assert the Icon's own label rather than a standalone
    // semantics node.)
    expect(
      tester
          .widget<Icon>(find.byIcon(Icons.trending_down_rounded))
          .semanticLabel,
      'Trending down',
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.trending_up_rounded)).semanticLabel,
      'Trending up',
    );
  });

  testWidgets('a report one-liner that leaks a percentage is suppressed — the '
      'row never renders a percentage on this surface', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const AgentsPage(),
        overrides: [
          activeGoalAgentsProvider.overrideWith(
            (ref) async => [
              identity('goal-leak', 'Walk daily'),
              identity('goal-clean', 'Sleep 8h'),
            ],
          ),
          goalAgentHealthProvider('goal-leak').overrideWith(
            (ref) async => health(
              trackStatus: GoalTrackStatus.offTrack,
              // Locale comma decimal — must be caught too, not just `64%`.
              reportOneLiner: 'Progress is 12,5 % of target this week.',
            ),
          ),
          goalAgentHealthProvider('goal-clean').overrideWith(
            (ref) async => health(
              trackStatus: GoalTrackStatus.onTrack,
              reportOneLiner: 'Seven solid nights running.',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    // The leaked-percentage one-liner is withheld entirely — including the
    // comma-decimal locale form...
    expect(find.textContaining('12,5'), findsNothing);
    expect(find.textContaining('% of target'), findsNothing);
    // ...while a clean events-and-time one-liner still renders.
    expect(find.text('Seven solid nights running.'), findsOneWidget);
  });

  testWidgets('the settled-empty first-run screen hides the global create FAB '
      '— the explainer CTA is the sole creation affordance', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const AgentsPage(),
        overrides: [
          activeGoalAgentsProvider.overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    // The explainer's own CTA remains the single way in.
    expect(find.text('Set an intention'), findsOneWidget);
  });

  testWidgets('a row whose health has not resolved yet shows no health chip '
      '(never a false "Not enough data") while the name still renders', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const AgentsPage(),
        overrides: [
          activeGoalAgentsProvider.overrideWith(
            (ref) async => [identity('goal-x', 'Stretch daily')],
          ),
          // A health load that never completes — the row is settled, its
          // health is not.
          goalAgentHealthProvider('goal-x').overrideWith(
            (ref) => Completer<GoalAgentHealth>().future,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Stretch daily'), findsOneWidget);
    for (final label in [
      'Healthy',
      'Behind',
      'Restarting',
      'Not enough data',
    ]) {
      expect(
        find.text(label),
        findsNothing,
        reason: 'an unresolved row must not assert a verdict',
      );
    }
  });

  testWidgets('recovering reads Restarting (never a failure), and a goal '
      'with no register yet reads Not enough data', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const AgentsPage(),
        overrides: [
          activeGoalAgentsProvider.overrideWith(
            (ref) async => [
              identity('goal-a', 'Stretch daily'),
              identity('goal-b', 'Read before bed'),
            ],
          ),
          goalAgentHealthProvider('goal-a').overrideWith(
            (ref) async => health(trackStatus: GoalTrackStatus.recovering),
          ),
          // No trackStatus at all — no register has been written yet.
          goalAgentHealthProvider(
            'goal-b',
          ).overrideWith((ref) async => health()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Restarting'), findsOneWidget);
    expect(find.text('Not enough data'), findsOneWidget);
  });

  testWidgets('a single register yields no direction arrow', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const AgentsPage(),
        overrides: [
          activeGoalAgentsProvider.overrideWith(
            (ref) async => [identity('goal-a', 'Stretch daily')],
          ),
          goalAgentHealthProvider('goal-a').overrideWith(
            (ref) async => health(trackStatus: GoalTrackStatus.onTrack),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.trending_up_rounded), findsNothing);
    expect(find.byIcon(Icons.trending_flat_rounded), findsNothing);
    expect(find.byIcon(Icons.trending_down_rounded), findsNothing);
  });

  testWidgets('a failed first load says so instead of a blank page', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const AgentsPage(),
        overrides: [
          activeGoalAgentsProvider.overrideWith(
            (ref) async => throw StateError('agent db unavailable'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't load your agents right now."),
      findsOneWidget,
    );
    expect(find.text('One agent per goal'), findsNothing);
  });
}
