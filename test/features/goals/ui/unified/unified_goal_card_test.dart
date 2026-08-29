import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_health_direction.dart';
import 'package:lotti/features/goals/ui/unified/unified_goal_card.dart';
import 'package:lotti/features/habits/ui/widgets/habit_action_row.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/day_indicators/day_mark_strip.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockEntitiesCacheService = MockEntitiesCacheService();

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

  GoalSpecVersionEntity spec(String agentId) =>
      AgentDomainEntity.goalSpecVersion(
            id: '$agentId:spec-v1',
            agentId: agentId,
            version: 1,
            status: GoalSpecVersionStatus.active,
            authoredBy: 'user',
            title: 'Fitness',
            statement: 'Stay in motion.',
            criteria: GoalCriterion.allOf(
              criterionId: 'root',
              criteria: [
                GoalCriterion.habit(
                  criterionId: 'c1',
                  habitId: habitFlossing.id,
                  window: const GoalWindow.rollingDays(count: 7),
                  targetCount: 4,
                ),
                GoalCriterion.habit(
                  criterionId: 'c2',
                  habitId: habitFlossingDueLater.id,
                  window: const GoalWindow.rollingDays(count: 7),
                  targetCount: 4,
                ),
              ],
            ),
            createdAt: DateTime(2026),
            vectorClock: null,
          )
          as GoalSpecVersionEntity;

  GoalAgentHealth health({
    required String agentId,
    GoalTrackStatus? trackStatus,
    String? reportOneLiner,
    int? deficit,
    GoalHealthDirection? direction,
    bool withSpec = true,
    int pendingProposals = 0,
  }) => (
    trackStatus: trackStatus,
    attainment: null,
    reportOneLiner: reportOneLiner,
    pendingProposals: pendingProposals,
    spec: withSpec ? spec(agentId) : null,
    direction: direction,
    deficit: deficit,
    buffer: null,
  );

  GoalProgressView progress() => GoalProgressView(
    today: DateTime.utc(2026, 8, 15),
    habits: [
      GoalHabitProgressView(
        habitId: habitFlossing.id,
        name: habitFlossing.name,
        targetCount: 4,
        days: const [],
        successfulWeeks: 1,
        evaluatedSuccesses: 4,
      ),
      GoalHabitProgressView(
        habitId: habitFlossingDueLater.id,
        name: habitFlossingDueLater.name,
        targetCount: 4,
        days: const [],
        successfulWeeks: 0,
        evaluatedSuccesses: 2,
      ),
    ],
  );

  setUp(() {
    when(
      () => mockEntitiesCacheService.getHabitById(habitFlossing.id),
    ).thenAnswer((_) => habitFlossing);
    when(
      () => mockEntitiesCacheService.getHabitById(habitFlossingDueLater.id),
    ).thenAnswer((_) => habitFlossingDueLater);
    getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
  });

  tearDown(getIt.reset);

  Future<void> pump(
    WidgetTester tester, {
    required GoalAgentHealth agentHealth,
    GoalProgressView? progressView,
    bool progressFails = false,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        UnifiedGoalCard(identity: identity('goal-1', 'Fitness')),
        overrides: [
          goalAgentHealthProvider(
            'goal-1',
          ).overrideWith((ref) async => agentHealth),
          if (progressFails)
            goalAgentProgressViewProvider('goal-1').overrideWith(
              (ref) async => throw StateError('progress read failed'),
            )
          else
            goalAgentProgressViewProvider(
              'goal-1',
            ).overrideWith((ref) async => progressView),
          goalAssessmentHistoryProvider(
            'goal-1',
          ).overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the pill with the folded recovery hint and the '
      'templated summary — and no habit rows', (tester) async {
    await pump(
      tester,
      agentHealth: health(
        agentId: 'goal-1',
        trackStatus: GoalTrackStatus.offTrack,
        reportOneLiner: 'The gym has been quiet.',
        deficit: 2,
      ),
      progressView: progress(),
    );

    expect(find.text('Fitness'), findsOneWidget);
    // Behind pill with the deterministic recovery door folded in.
    expect(
      find.text('Behind · 2 successful days needed to recover'),
      findsOneWidget,
    );
    // The summary is TEMPLATED from live state — the agent's one-liner does
    // not reach the list level for habit goals.
    expect(find.text('1 of 2 habits on track'), findsOneWidget);
    expect(find.text('The gym has been quiet.'), findsNothing);

    // The card is its header. Embedding every linked habit as a full row —
    // glyph, streak chain, flame count, window fraction, check circle — cost
    // several rows of a LIST card to restate what the pill above already
    // says in two words. A habit's own record is read on the detail page.
    expect(find.byType(HabitActionRow), findsNothing);
    expect(find.text(habitFlossing.name), findsNothing);
    expect(find.text(habitFlossingDueLater.name), findsNothing);
    expect(find.textContaining('this window'), findsNothing);
  });

  testWidgets('no-data with a standing one-liner shows the one-liner and '
      'suppresses the pill (never contradict a standing assessment)', (
    tester,
  ) async {
    await pump(
      tester,
      agentHealth: health(
        agentId: 'goal-1',
        reportOneLiner: 'Waiting on the first samples.',
        withSpec: false,
      ),
    );

    expect(find.text('No data'), findsNothing);
    expect(find.text('Waiting on the first samples.'), findsOneWidget);
  });

  testWidgets('tapping the header opens the goal detail route', (
    tester,
  ) async {
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);

    await pump(
      tester,
      agentHealth: health(
        agentId: 'goal-1',
        trackStatus: GoalTrackStatus.onTrack,
      ),
      progressView: progress(),
    );

    await tester.tap(find.text('Fitness'));
    await tester.pump();
    expect(navigated, ['/goals/details/goal-1']);
  });

  testWidgets('the header paints no hover overlay — it is a card region, '
      'not a button', (tester) async {
    await pump(
      tester,
      agentHealth: health(
        agentId: 'goal-1',
        trackStatus: GoalTrackStatus.onTrack,
      ),
      progressView: progress(),
    );

    final ink = tester.widget<InkWell>(
      find
          .ancestor(of: find.text('Fitness'), matching: find.byType(InkWell))
          .first,
    );
    expect(ink.hoverColor, Colors.transparent);
    expect(
      ink.overlayColor?.resolve({WidgetState.hovered}),
      Colors.transparent,
    );

    // No hover state does not mean invisible to keyboards: Tab landing on
    // the header draws the quiet-ink focus ring.
    Finder ring() => find.ancestor(
      of: find.text('Fitness'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.position == DecorationPosition.foreground &&
            (widget.decoration as BoxDecoration).border != null,
      ),
    );
    expect(ring(), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(ring(), findsOneWidget);
  });

  testWidgets('a significant trend renders the shared direction chip', (
    tester,
  ) async {
    await pump(
      tester,
      agentHealth: health(
        agentId: 'goal-1',
        trackStatus: GoalTrackStatus.onTrack,
        direction: GoalHealthDirection.up,
      ),
      progressView: progress(),
    );

    // The same chip the agents list and detail header use — one trend
    // vocabulary across every goal surface.
    expect(find.byType(GoalHealthDirectionChip), findsOneWidget);
    expect(find.byIcon(LottiIcons.trendingUp), findsOneWidget);
  });

  testWidgets('a pending revision proposal surfaces as a header chip — the '
      'list-level signal that the goal needs approval', (tester) async {
    await pump(
      tester,
      agentHealth: health(
        agentId: 'goal-1',
        trackStatus: GoalTrackStatus.onTrack,
        pendingProposals: 1,
      ),
      progressView: progress(),
    );
    expect(find.text('Proposal awaiting review'), findsOneWidget);
  });

  testWidgets('no pending proposal, no chip', (tester) async {
    await pump(
      tester,
      agentHealth: health(
        agentId: 'goal-1',
        trackStatus: GoalTrackStatus.onTrack,
      ),
      progressView: progress(),
    );
    expect(find.text('Proposal awaiting review'), findsNothing);
  });

  testWidgets('a narrow card stacks the strip below the identity block', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      agentHealth: health(
        agentId: 'goal-1',
        trackStatus: GoalTrackStatus.onTrack,
      ),
      progressView: progress(),
    );

    // Phone branch: the goal-level strip starts below the title instead of
    // trailing it on the same row.
    final titleRect = tester.getRect(find.text('Fitness'));
    final stripRect = tester.getRect(
      find.byType(DayMarkStrip).first,
    );
    expect(stripRect.top, greaterThan(titleRect.bottom - 1));
  });

  testWidgets('a FAILED first progress read still renders the goal, header '
      'and all — there is nothing left for it to lose', (tester) async {
    await pump(
      tester,
      agentHealth: health(
        agentId: 'goal-1',
        trackStatus: GoalTrackStatus.onTrack,
      ),
      progressFails: true,
    );

    // The card used to carry a spec-derived fallback so a failed progress
    // read could not make every linked habit vanish from the page. With the
    // habit rows gone there is no fallback to keep: the header is sourced
    // from health, not progress, so it survives the failure on its own.
    expect(find.text('Fitness'), findsOneWidget);
    expect(find.text('On track'), findsOneWidget);
    expect(find.byType(HabitActionRow), findsNothing);
    expect(
      find.byKey(Key('unified-goal-goal-1-fallback-${habitFlossing.id}')),
      findsNothing,
    );
  });
}
