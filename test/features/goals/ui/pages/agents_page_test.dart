import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_progress_card.dart';
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
    int? deficit,
    int? buffer,
    GoalSpecVersionEntity? spec,
  }) => (
    trackStatus: trackStatus,
    attainment: null,
    reportOneLiner: reportOneLiner,
    pendingProposals: pendingProposals,
    spec: spec,
    direction: direction,
    deficit: deficit,
    buffer: buffer,
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

    // Trend is a separate visible field beside status, not an icon-only hint.
    expect(find.text('Trending down'), findsOneWidget);
    expect(find.text('Trending up'), findsOneWidget);
  });

  testWidgets(
    'a row uses the goal title while retaining the persona identity',
    (
      tester,
    ) async {
      final spec =
          AgentDomainEntity.goalSpecVersion(
                id: 'goal-fit:spec-v1',
                agentId: 'goal-fit',
                version: 1,
                status: GoalSpecVersionStatus.active,
                authoredBy: 'user',
                title: 'Walk daily',
                statement: 'Walk every day.',
                criteria: const GoalCriterion.habit(
                  criterionId: 'walk',
                  habitId: 'walk',
                  window: GoalWindow.rollingDays(count: 7),
                  targetCount: 5,
                ),
                createdAt: DateTime(2026),
                vectorClock: null,
              )
              as GoalSpecVersionEntity;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentsPage(),
          overrides: [
            activeGoalAgentsProvider.overrideWith(
              (ref) async => [identity('goal-fit', 'Juno')],
            ),
            goalAgentHealthProvider('goal-fit').overrideWith(
              (ref) async => health(
                trackStatus: GoalTrackStatus.onTrack,
                spec: spec,
              ),
            ),
            goalAgentProgressViewProvider(
              'goal-fit',
            ).overrideWith((ref) async => null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Walk daily'), findsOneWidget);
      expect(find.text('Juno'), findsNothing);
    },
  );

  testWidgets('an on-track composite does not badge an unmet leaf', (
    tester,
  ) async {
    final spec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-fit:spec-v1',
              agentId: 'goal-fit',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Health trajectory',
              statement: 'Improve either health signal.',
              criteria: const GoalCriterion.anyOf(
                criterionId: 'health',
                criteria: [
                  GoalCriterion.metric(
                    criterionId: 'weight',
                    dataType: 'HealthDataType.WEIGHT',
                    window: GoalWindow.rollingDays(count: 7),
                    aggregation: GoalAggregation.dailySumThenAverage,
                    target: 80,
                    direction: GoalDirection.atMost,
                  ),
                  GoalCriterion.metric(
                    criterionId: 'steps',
                    dataType: 'steps',
                    window: GoalWindow.day(),
                    aggregation: GoalAggregation.sum,
                    target: 8000,
                  ),
                ],
              ),
              createdAt: DateTime(2026),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;
    final today = DateTime.utc(2026, 8, 11);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const AgentsPage(),
        overrides: [
          activeGoalAgentsProvider.overrideWith(
            (ref) async => [identity('goal-fit', 'Juno')],
          ),
          goalAgentHealthProvider('goal-fit').overrideWith(
            (ref) async => health(
              trackStatus: GoalTrackStatus.onTrack,
              spec: spec,
            ),
          ),
          goalAgentProgressViewProvider('goal-fit').overrideWith(
            (ref) async => GoalProgressView(
              today: today,
              rootOnTrack: true,
              metrics: [
                GoalMetricProgressView(
                  name: 'Weight',
                  target: 80,
                  direction: GoalDirection.atMost,
                  days: [GoalProgressDay(day: today, value: 85)],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Healthy'), findsOneWidget);
    expect(find.text('Weight needs attention'), findsNothing);
  });

  testWidgets('a rolling-window goal shows a deterministic recovery hint when '
      'behind, and a buffer hint when at rate', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const AgentsPage(),
        overrides: [
          activeGoalAgentsProvider.overrideWith(
            (ref) async => [
              identity('goal-behind', 'Stretch daily'),
              identity('goal-rate', 'Walk daily'),
            ],
          ),
          goalAgentHealthProvider('goal-behind').overrideWith(
            (ref) async => health(
              trackStatus: GoalTrackStatus.offTrack,
              deficit: 3,
            ),
          ),
          goalAgentHealthProvider('goal-rate').overrideWith(
            (ref) async => health(
              trackStatus: GoalTrackStatus.onTrack,
              // At rate: deficit 0, one day of buffer before a success ages.
              deficit: 0,
              buffer: 1,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 days to recover'), findsOneWidget);
    expect(find.text('1 day of buffer'), findsOneWidget);
  });

  testWidgets(
    'a resolved goal spec adds the compact seven-day progress strip',
    (
      tester,
    ) async {
      final spec =
          AgentDomainEntity.goalSpecVersion(
                id: 'goal-fit:spec-v1',
                agentId: 'goal-fit',
                version: 1,
                status: GoalSpecVersionStatus.active,
                authoredBy: 'user',
                title: 'Fitness',
                statement: 'Walk most days.',
                criteria: const GoalCriterion.habit(
                  criterionId: 'walk',
                  habitId: 'walk',
                  window: GoalWindow.rollingDays(count: 7),
                  targetCount: 4,
                ),
                createdAt: DateTime(2026),
                vectorClock: null,
              )
              as GoalSpecVersionEntity;
      final today = DateTime.utc(2026, 8, 11);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentsPage(),
          overrides: [
            activeGoalAgentsProvider.overrideWith(
              (ref) async => [identity('goal-fit', 'Expedition fitness')],
            ),
            goalAgentHealthProvider('goal-fit').overrideWith(
              (ref) async => (
                trackStatus: GoalTrackStatus.onTrack,
                attainment: 1.0,
                reportOneLiner: null,
                pendingProposals: 0,
                spec: spec,
                direction: null,
                deficit: null,
                buffer: null,
              ),
            ),
            goalAgentProgressViewProvider('goal-fit').overrideWith(
              (ref) async => GoalProgressView(
                today: today,
                habits: [
                  GoalHabitProgressView(
                    habitId: 'walk',
                    name: 'Walk',
                    targetCount: 4,
                    days: [
                      for (var offset = 7; offset >= 0; offset--)
                        GoalProgressDay(
                          day: today.subtract(Duration(days: offset)),
                          value: offset.isEven ? 1 : 0,
                        ),
                    ],
                    successfulWeeks: 3,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final strip = tester.widget<GoalCompactWindowStrip>(
        find.byType(GoalCompactWindowStrip),
      );
      expect(strip.days, [
        GoalCompactDayState.full,
        GoalCompactDayState.none,
        GoalCompactDayState.full,
        GoalCompactDayState.none,
        GoalCompactDayState.full,
        GoalCompactDayState.none,
        GoalCompactDayState.full,
      ]);

      // On a wide row the strip moves into the right-aligned data block, so
      // the card's width carries information instead of dead surface.
      expect(
        tester.getTopRight(find.byType(GoalCompactWindowStrip)).dx,
        greaterThan(
          tester.getTopRight(find.text('Fitness')).dx,
        ),
        reason: 'strip should sit trailing, past the title block',
      );
      // Resolved data renders REAL cells; the dashed placeholder encoding is
      // reserved for rows whose window has not resolved.
      expect(strip.placeholder, isFalse);
    },
  );

  testWidgets('the create FAB opens the creation flow, and a row opens that '
      "agent's detail page", (tester) async {
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const AgentsPage(),
        overrides: [
          activeGoalAgentsProvider.overrideWith(
            (ref) async => [identity('goal-fit', 'Expedition fitness')],
          ),
          goalAgentHealthProvider('goal-fit').overrideWith(
            (ref) async => health(trackStatus: GoalTrackStatus.onTrack),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DesignSystemFloatingActionButton));
    await tester.pump();
    expect(navigated, ['/agents/create']);

    await tester.tap(find.text('Expedition fitness'));
    await tester.pump();
    expect(navigated, ['/agents/create', '/agents/details/goal-fit']);
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
    expect(find.byType(DesignSystemFloatingActionButton), findsNothing);
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
