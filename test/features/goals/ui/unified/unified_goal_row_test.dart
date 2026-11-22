import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/design_system/components/lists/grouped_card_row_surface.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_health_direction.dart';
import 'package:lotti/features/goals/ui/unified/goal_companion.dart';
import 'package:lotti/features/goals/ui/unified/unified_goal_row.dart';
import 'package:lotti/features/goals/ui/unified/unified_goal_status.dart';
import 'package:lotti/features/habits/ui/widgets/habit_action_row.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_widgets.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/day_indicators/day_mark_strip.dart';
import 'package:material_ui/material_ui.dart';
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
    bool healthFails = false,
    ThemeData? theme,
    bool companion = false,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        UnifiedGoalRow(identity: identity('goal-1', 'Fitness')),
        theme: theme,
        overrides: [
          if (companion)
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(flagName == enableCompanionFlag),
            ),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => healthFails
                ? throw StateError('health read failed')
                : agentHealth,
          ),
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
    if (companion) {
      // She ticks for as long as she is mounted: pump frames, never settle.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    } else {
      await tester.pumpAndSettle();
    }
  }

  for (final theme in [DesignSystemTheme.light(), DesignSystemTheme.dark()]) {
    testWidgets('draws no frame of its own in ${theme.brightness.name} mode '
        "— the list's rows card is its surface", (tester) async {
      await pump(
        tester,
        agentHealth: health(
          agentId: 'goal-1',
          trackStatus: GoalTrackStatus.onTrack,
        ),
        progressView: progress(),
        theme: theme,
      );

      expect(find.byType(GroupedCardRowSurface), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(UnifiedGoalRow),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Material &&
                widget.shape is RoundedRectangleBorder &&
                (widget.shape! as RoundedRectangleBorder).side !=
                    BorderSide.none,
          ),
        ),
        findsNothing,
      );
    });
  }

  testWidgets('the title has its line to itself: the status sits under it '
      'as a glyph and a word, never a pill beside it', (tester) async {
    await pump(
      tester,
      agentHealth: health(
        agentId: 'goal-1',
        trackStatus: GoalTrackStatus.offTrack,
        deficit: 1,
      ),
      progressView: progress(),
    );

    final title = tester.getRect(
      find.byKey(const ValueKey('unified-goal-row-title')),
    );
    final status = tester.getRect(find.byType(UnifiedGoalStatusMark));
    expect(status.top, greaterThanOrEqualTo(title.bottom));
    expect(find.textContaining('Behind'), findsOneWidget);
  });

  testWidgets('assistive tech meets the row as one button: title, status '
      'and summary in one sentence', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      agentHealth: health(
        agentId: 'goal-1',
        trackStatus: GoalTrackStatus.offTrack,
        deficit: 1,
      ),
      progressView: progress(),
    );

    final node = tester.getSemantics(find.byType(GroupedCardRowSurface));
    final data = node.getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(
      data.label,
      'Fitness, Behind · 1 successful day needed to recover, '
      '1 of 2 habits on track',
    );
    handle.dispose();
  });

  testWidgets('a failed health read says so on the row instead of leaving it '
      'blank', (tester) async {
    await pump(
      tester,
      agentHealth: health(
        agentId: 'goal-1',
        trackStatus: GoalTrackStatus.onTrack,
      ),
      healthFails: true,
    );

    expect(
      find.byKey(const ValueKey('unified-goal-row-health-failed')),
      findsOneWidget,
    );
    expect(find.byType(UnifiedGoalStatusMark), findsNothing);
  });

  group('the companion', () {
    testWidgets('stands in for the persona chip, wearing its status wash, '
        'while her flag is on', (tester) async {
      await pump(
        tester,
        agentHealth: health(
          agentId: 'goal-1',
          trackStatus: GoalTrackStatus.onTrack,
        ),
        progressView: progress(),
        companion: true,
      );

      expect(find.byType(NudgeBannerPersonaChip), findsNothing);
      final bust = tester.widget<GoalCompanionBust>(
        find.byType(GoalCompanionBust),
      );
      expect(
        bust.pose,
        (mood: CompanionMood.bright, gesture: GestureName.thumbs),
      );
      // Dressed for the goal's own agent, as on its page.
      expect(bust.agentId, 'goal-1');
      final tokens = tester
          .element(find.byType(GoalCompanionBust))
          .designTokens;
      expect(
        bust.fill,
        unifiedGoalStatusColor(
          UnifiedGoalStatus.onTrack,
          tokens.colors,
        ).withValues(alpha: SurfaceAlphas.washChip),
      );
      // She leads the header, before the goal's name.
      expect(
        tester.getRect(find.byType(GoalCompanionBust)).right,
        lessThan(tester.getRect(find.text('Fitness')).left),
      );
    });

    for (final (status, mood, gesture) in [
      (GoalTrackStatus.atRisk, CompanionMood.busy, GestureName.think),
      (GoalTrackStatus.offTrack, CompanionMood.frazzled, GestureName.palmsDown),
      (
        GoalTrackStatus.insufficientData,
        CompanionMood.sleepy,
        GestureName.listen,
      ),
    ]) {
      testWidgets('holds ${gesture.name}, ${mood.name}, on a goal that is '
          '${status.name}', (
        tester,
      ) async {
        await pump(
          tester,
          agentHealth: health(agentId: 'goal-1', trackStatus: status),
          progressView: progress(),
          companion: true,
        );

        expect(
          tester.widget<GoalCompanionBust>(find.byType(GoalCompanionBust)).pose,
          (mood: mood, gesture: gesture),
        );
      });
    }

    testWidgets('is not shown while her flag is off', (tester) async {
      await pump(
        tester,
        agentHealth: health(
          agentId: 'goal-1',
          trackStatus: GoalTrackStatus.onTrack,
        ),
        progressView: progress(),
      );

      expect(find.byType(GoalCompanionBust), findsNothing);
      expect(find.byType(NudgeBannerPersonaChip), findsOneWidget);
    });
  });

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

  testWidgets('keyboard focus fills the row like hover does', (tester) async {
    await pump(
      tester,
      agentHealth: health(
        agentId: 'goal-1',
        trackStatus: GoalTrackStatus.onTrack,
      ),
      progressView: progress(),
    );
    final tokens = tester.element(find.byType(UnifiedGoalRow)).designTokens;
    Finder fill() => find.descendant(
      of: find.byType(GroupedCardRowSurface),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            (widget.decoration as BoxDecoration).color ==
                tokens.colors.surface.hover,
      ),
    );
    expect(fill(), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(fill(), findsOneWidget);
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
