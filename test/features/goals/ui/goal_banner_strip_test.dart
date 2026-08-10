import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_strip.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  GoalNudgeEntity nudge({
    String id = 'ad-1',
    List<GoalNudgeRating> ratings = const [],
  }) =>
      AgentDomainEntity.goalNudge(
            id: id,
            agentId: 'goal-1',
            status: GoalNudgeStatus.active,
            brief: const GoalNudgeBrief(
              headline: 'Your shoes filed a missing person report.',
              tagline: 'Six days of quiet soles.',
              cta: 'Lace up now',
              tone: GoalNudgeTone.nudge,
              animation: GoalBannerAnimation.steady,
            ),
            briefDigest: 'd',
            createdAt: DateTime(2026, 8, 9),
            updatedAt: DateTime(2026, 8, 9),
            vectorClock: null,
            ratings: ratings,
          )
          as GoalNudgeEntity;

  late MockGoalNudgeInteractions interactions;
  late List<(String, Duration)> exposures;

  List<Override> overrides(List<GoalBannerEntry> entries) => [
    activeGoalNudgesProvider.overrideWith((ref) async => entries),
    goalNudgeInteractionsProvider.overrideWithValue(interactions),
    goalNudgeExposureFlushProvider.overrideWithValue(
      (nudgeId, visibleFor) => exposures.add((nudgeId, visibleFor)),
    ),
  ];

  setUp(() {
    interactions = MockGoalNudgeInteractions();
    exposures = [];
    when(
      () => interactions.dismiss(
        any(),
        forActivation: any(named: 'forActivation'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => interactions.recordRating(
        any(),
        rating: any(named: 'rating'),
        skipped: any(named: 'skipped'),
      ),
    ).thenAnswer((_) async {});
  });

  testWidgets('renders copy, goal attribution, and CTA', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const GoalBannerStrip(),
        overrides: overrides([(nudge: nudge(), goalTitle: 'Move more')]),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Your shoes filed a missing person report.'),
      findsOneWidget,
    );
    expect(find.text('Six days of quiet soles.'), findsOneWidget);
    expect(find.text('Lace up now'), findsOneWidget);
    expect(find.text('Move more'), findsOneWidget);
  });

  testWidgets('shrinks to nothing with no active ads', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(const GoalBannerStrip(), overrides: overrides([])),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SizedBox), findsWidgets);
    expect(find.byTooltip('Dismiss'), findsNothing);
  });

  testWidgets('one exposure episode is flushed when the banner leaves the '
      'tree', (tester) async {
    final sameOverrides = overrides([
      (nudge: nudge(), goalTitle: 'Move more'),
    ]);
    await tester.pumpWidget(
      makeTestableWidget(const GoalBannerStrip(), overrides: sameOverrides),
    );
    await tester.pumpAndSettle();
    expect(exposures, isEmpty);

    // Same scope, same overrides — only the child changes, unmounting the
    // banner and its tracker.
    await tester.pumpWidget(
      makeTestableWidget(const SizedBox.shrink(), overrides: sameOverrides),
    );
    await tester.pumpAndSettle();
    expect(exposures, hasLength(1));
    expect(exposures.single.$1, 'ad-1');
  });

  testWidgets('at most two banners render — the rest stay reachable on '
      "their goal's detail page", (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const GoalBannerStrip(),
        overrides: overrides([
          (nudge: nudge(), goalTitle: 'One'),
          (nudge: nudge(id: 'ad-2'), goalTitle: 'Two'),
          (nudge: nudge(id: 'ad-3'), goalTitle: 'Three'),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Dismiss'), findsNWidgets(2));
    expect(find.text('Three'), findsNothing);
  });

  testWidgets('hiding the tab flushes the episode WITHOUT unmounting — '
      'separate appearances never merge', (tester) async {
    final sameOverrides = overrides([
      (nudge: nudge(), goalTitle: 'Move more'),
    ]);
    Widget host({required bool visible}) => makeTestableWidget(
      TickerMode(enabled: visible, child: const GoalBannerStrip()),
      overrides: sameOverrides,
    );
    await tester.pumpWidget(host(visible: true));
    await tester.pumpAndSettle();
    expect(exposures, isEmpty);

    await tester.pumpWidget(host(visible: false));
    await tester.pumpAndSettle();
    expect(exposures, hasLength(1), reason: 'transition flushes its episode');

    // Returning and leaving again is a SECOND episode.
    await tester.pumpWidget(host(visible: true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(visible: false));
    await tester.pumpAndSettle();
    expect(exposures, hasLength(2));
  });

  testWidgets('scrolling the banner out of the viewport flushes its '
      'episode — off-screen time never counts', (tester) async {
    final sameOverrides = overrides([
      (nudge: nudge(), goalTitle: 'Move more'),
    ]);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        ListView(
          children: const [
            GoalBannerStrip(),
            SizedBox(height: 3000),
          ],
        ),
        overrides: sameOverrides,
      ),
    );
    await tester.pumpAndSettle();
    expect(exposures, isEmpty);

    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(
      exposures,
      hasLength(1),
      reason: 'scroll-out ends the episode without unmounting',
    );

    // Scrolling back starts a SECOND episode, flushed on unmount.
    await tester.drag(find.byType(ListView), const Offset(0, 1500));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const SizedBox.shrink(),
        overrides: sameOverrides,
      ),
    );
    await tester.pumpAndSettle();
    expect(exposures, hasLength(2));
  });

  testWidgets('backgrounding the app flushes the episode — pocket time '
      'never counts as exposure', (tester) async {
    final sameOverrides = overrides([
      (nudge: nudge(), goalTitle: 'Move more'),
    ]);
    await tester.pumpWidget(
      makeTestableWidget(const GoalBannerStrip(), overrides: sameOverrides),
    );
    await tester.pumpAndSettle();
    expect(exposures, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(exposures, hasLength(1), reason: 'leaving resumed flushes');

    // Resuming starts a fresh episode, flushed on unmount as usual.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpWidget(
      makeTestableWidget(const SizedBox.shrink(), overrides: sameOverrides),
    );
    await tester.pumpAndSettle();
    expect(exposures, hasLength(2));
  });
}
