import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_card.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  GoalNudgeEntity nudge({List<GoalNudgeRating> ratings = const []}) =>
      AgentDomainEntity.goalNudge(
            id: 'ad-1',
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

  List<Override> overrides() => [
    goalNudgeInteractionsProvider.overrideWithValue(interactions),
  ];

  setUp(() {
    interactions = MockGoalNudgeInteractions();
    when(
      () => interactions.snooze(
        any(),
        duration: any(named: 'duration'),
        forActivation: any(named: 'forActivation'),
      ),
    ).thenAnswer((_) async => DateTime.utc(2030));
    when(
      () => interactions.dismissForDay(
        any(),
        forActivation: any(named: 'forActivation'),
      ),
    ).thenAnswer((_) async => DateTime.utc(2030));
    when(
      () => interactions.recordRating(
        any(),
        rating: any(named: 'rating'),
        skipped: any(named: 'skipped'),
        forActivation: any(named: 'forActivation'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<void> pumpCard(
    WidgetTester tester, {
    List<GoalNudgeRating> ratings = const [],
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        // The failure notices go through the ScaffoldMessenger, which
        // needs a Scaffold to present on.
        Scaffold(
          body: GoalBannerCard(
            entry: (nudge: nudge(ratings: ratings), goalTitle: 'Move more'),
          ),
        ),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the primary Snooze action reveals contextual durations', (
    tester,
  ) async {
    await pumpCard(tester);
    await tester.tap(find.text('Snooze'));
    await tester.pumpAndSettle();
    expect(find.text('When should it come back?'), findsOneWidget);
    await tester.tap(find.text('6 hours'));
    await tester.pumpAndSettle();
    verify(
      () => interactions.snooze(
        'ad-1',
        duration: GoalBannerSnoozeDuration.sixHours,
        forActivation: 1,
      ),
    ).called(1);
  });

  testWidgets('a snooze write that throws surfaces the retry notice and '
      'leaves the card in place — the tap did not remove it', (tester) async {
    when(
      () => interactions.snooze(
        any(),
        duration: any(named: 'duration'),
        forActivation: any(named: 'forActivation'),
      ),
    ).thenAnswer((_) async => throw StateError('sync write failed'));
    await pumpCard(tester);
    await tester.tap(find.text('Snooze'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 hour'));
    await tester.pumpAndSettle();
    expect(
      find.text("That didn't save — please try again."),
      findsOneWidget,
    );
    expect(find.byType(GoalBannerCard), findsOneWidget);
    expect(
      find.text('Your shoes filed a missing person report.'),
      findsOneWidget,
    );
  });

  testWidgets('day dismissal is de-emphasized behind the snooze sheet', (
    tester,
  ) async {
    await pumpCard(tester);
    expect(find.text('Dismiss for today'), findsNothing);
    await tester.tap(find.text('Snooze'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Dismiss for today')).dy,
      greaterThan(tester.getBottomLeft(find.text('8 hours')).dy),
    );
    await tester.tap(find.text('Dismiss for today'));
    await tester.pumpAndSettle();
    verify(
      () => interactions.dismissForDay('ad-1', forActivation: 1),
    ).called(1);
  });

  testWidgets('there is no direct dismiss button or swipe-dismiss shortcut', (
    tester,
  ) async {
    await pumpCard(tester);
    expect(find.byType(Dismissible), findsNothing);
    expect(find.byTooltip('Dismiss'), findsNothing);
    expect(find.text('Snooze'), findsOneWidget);
  });

  testWidgets('picking a star records the rating FOR THE ACTIVATION the '
      'user saw', (tester) async {
    await pumpCard(tester);
    await tester.tap(find.byTooltip('Rate this banner'));
    await tester.pumpAndSettle();
    expect(find.text('How was this banner?'), findsOneWidget);
    await tester.tap(find.byTooltip('4'));
    await tester.pumpAndSettle();
    verify(
      () => interactions.recordRating('ad-1', rating: 4, forActivation: 1),
    ).called(1);
  });

  testWidgets('a failed rating write surfaces the retry notice instead of '
      'an uncaught error', (tester) async {
    when(
      () => interactions.recordRating(
        any(),
        rating: any(named: 'rating'),
        skipped: any(named: 'skipped'),
        forActivation: any(named: 'forActivation'),
      ),
    ).thenAnswer((_) async => throw StateError('sync write failed'));
    await pumpCard(tester);
    await tester.tap(find.byTooltip('Rate this banner'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('4'));
    await tester.pumpAndSettle();
    expect(
      find.text("That didn't save — please try again."),
      findsOneWidget,
    );
  });

  testWidgets('the Skip button records a skip', (tester) async {
    await pumpCard(tester);
    await tester.tap(find.byTooltip('Rate this banner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    verify(
      () => interactions.recordRating(
        'ad-1',
        skipped: true,
        forActivation: 1,
      ),
    ).called(1);
  });

  testWidgets('swiping the sheet away consumes NOTHING — the rating '
      'opportunity survives an accidental dismiss', (tester) async {
    await pumpCard(tester);
    await tester.tap(find.byTooltip('Rate this banner'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    verifyNever(
      () => interactions.recordRating(
        any(),
        rating: any(named: 'rating'),
        skipped: any(named: 'skipped'),
        forActivation: any(named: 'forActivation'),
      ),
    );
  });

  testWidgets('a rated activation loses its star — one outcome per run', (
    tester,
  ) async {
    await pumpCard(
      tester,
      ratings: [
        GoalNudgeRating(
          activation: 1,
          ratedAt: DateTime(2026, 8, 9, 12),
          rating: 5,
        ),
      ],
    );
    expect(find.byTooltip('Rate this banner'), findsNothing);
    expect(find.text('Snooze'), findsOneWidget);
  });

  testWidgets('the CTA pill is a real button: tapping it navigates to the '
      'goal', (tester) async {
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);
    await pumpCard(tester);
    await tester.tap(find.text('Lace up now'));
    await tester.pumpAndSettle();
    expect(navigated, ['/agents/details/goal-1']);
  });

  testWidgets('a host-provided CTA handler replaces navigation — on the goal '
      'detail page the pill must anchor, not self-navigate', (tester) async {
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);
    var anchored = 0;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: GoalBannerCard(
            entry: (nudge: nudge(), goalTitle: 'Move more'),
            onCtaPressed: () => anchored++,
          ),
        ),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lace up now'));
    await tester.pumpAndSettle();

    expect(anchored, 1);
    expect(navigated, isEmpty);
  });

  testWidgets('consuming the rating never reflows the header — the star '
      'sits in a fixed slot, so Snooze does not move', (tester) async {
    await pumpCard(tester);
    final snoozeBefore = tester.getTopLeft(find.text('Snooze'));
    expect(find.byTooltip('Rate this banner'), findsOneWidget);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: GoalBannerCard(
            entry: (
              nudge: nudge(
                ratings: [
                  GoalNudgeRating(
                    activation: 1,
                    ratedAt: DateTime(2026, 8, 9, 12),
                    rating: 4,
                  ),
                ],
              ),
              goalTitle: 'Move more',
            ),
          ),
        ),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Rate this banner'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Snooze')),
      snoozeBefore,
      reason: 'the vacated star slot must keep its width',
    );
  });

  testWidgets('uses the compact top inset while preserving card padding on '
      'the other edges', (tester) async {
    await pumpCard(tester);

    final padding = tester.widget<Padding>(
      find.byKey(const ValueKey('goal-banner-content-padding')),
    );
    final context = tester.element(find.byType(GoalBannerCard));
    final spacing = context.designTokens.spacing;

    expect(
      padding.padding,
      EdgeInsets.fromLTRB(
        spacing.cardPadding,
        spacing.step2,
        spacing.cardPadding,
        spacing.cardPadding,
      ),
    );
  });

  testWidgets("tapping the banner opens its goal's page — the "
      'banner→conversation flow', (tester) async {
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);
    await pumpCard(tester);
    await tester.tap(find.text('Your shoes filed a missing person report.'));
    await tester.pumpAndSettle();
    expect(navigated, ['/agents/details/goal-1']);
    expect(find.text('How was this banner?'), findsNothing);
  });
}
