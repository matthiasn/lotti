import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_card.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
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
      () => interactions.dismiss(
        any(),
        forActivation: any(named: 'forActivation'),
      ),
    ).thenAnswer((_) async {});
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

  testWidgets('the X dismisses the ad — the terminal verdict that starts '
      'the quiet window', (tester) async {
    await pumpCard(tester);
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    verify(
      () => interactions.dismiss('ad-1', forActivation: 1),
    ).called(1);
  });

  testWidgets('swiping the banner away dismisses it — the second gesture '
      'ADR 0055 specifies', (tester) async {
    await pumpCard(tester);
    await tester.drag(
      find.byType(Dismissible),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();
    verify(
      () => interactions.dismiss('ad-1', forActivation: 1),
    ).called(1);
  });

  testWidgets('picking a star records the rating FOR THE ACTIVATION the '
      'user saw', (tester) async {
    await pumpCard(tester);
    await tester.tap(find.text('Your shoes filed a missing person report.'));
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
    await tester.tap(find.text('Your shoes filed a missing person report.'));
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
    await tester.tap(find.text('Your shoes filed a missing person report.'));
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
    await tester.tap(find.text('Your shoes filed a missing person report.'));
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

  testWidgets('a rated activation stops responding to taps', (tester) async {
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
    await tester.tap(find.text('Your shoes filed a missing person report.'));
    await tester.pumpAndSettle();
    expect(find.text('How was this banner?'), findsNothing);
  });
}
