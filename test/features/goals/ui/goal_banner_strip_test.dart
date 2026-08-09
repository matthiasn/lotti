import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/service/goal_nudge_interactions.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_strip.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

class _MockInteractions extends Mock implements GoalNudgeInteractions {}

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

  late _MockInteractions interactions;
  late List<(String, Duration)> exposures;

  List<Override> overrides(List<GoalBannerEntry> entries) => [
    activeGoalNudgesProvider.overrideWith((ref) async => entries),
    goalNudgeInteractionsProvider.overrideWithValue(interactions),
    goalNudgeExposureFlushProvider.overrideWithValue(
      (nudgeId, visibleFor) => exposures.add((nudgeId, visibleFor)),
    ),
  ];

  setUp(() {
    interactions = _MockInteractions();
    exposures = [];
    when(() => interactions.dismiss(any())).thenAnswer((_) async {});
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

  testWidgets('the X dismisses the ad — the terminal verdict that starts '
      'the quiet window', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const GoalBannerStrip(),
        overrides: overrides([(nudge: nudge(), goalTitle: 'Move more')]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    verify(() => interactions.dismiss('ad-1')).called(1);
  });

  testWidgets('tapping the banner opens the rating sheet; picking a star '
      'records it for this activation', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const GoalBannerStrip(),
        overrides: overrides([(nudge: nudge(), goalTitle: 'Move more')]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Your shoes filed a missing person report.'));
    await tester.pumpAndSettle();
    expect(find.text('How was this banner?'), findsOneWidget);

    await tester.tap(find.byTooltip('4'));
    await tester.pumpAndSettle();
    verify(
      () => interactions.recordRating('ad-1', rating: 4),
    ).called(1);
  });

  testWidgets('skipping the rating records the skip so the prompt never '
      'nags again this activation', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const GoalBannerStrip(),
        overrides: overrides([(nudge: nudge(), goalTitle: 'Move more')]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your shoes filed a missing person report.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    verify(
      () => interactions.recordRating('ad-1', skipped: true),
    ).called(1);
  });

  testWidgets('a rated activation stops responding to taps', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const GoalBannerStrip(),
        overrides: overrides([
          (
            nudge: nudge(
              ratings: [
                GoalNudgeRating(
                  activation: 1,
                  ratedAt: DateTime(2026, 8, 9, 12),
                  rating: 5,
                ),
              ],
            ),
            goalTitle: 'Move more',
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your shoes filed a missing person report.'));
    await tester.pumpAndSettle();
    expect(find.text('How was this banner?'), findsNothing);
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
}
