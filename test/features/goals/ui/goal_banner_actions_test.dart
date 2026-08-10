import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_actions.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

/// The shared banner-action contract (`dismissGoalBanner`,
/// `showGoalBannerRatingSheet`) used by BOTH the card and the dock — its
/// own path-mirrored suite, so neither caller's widget test owns behaviour
/// the other relies on. Caller-specific wiring (which button, which
/// gesture) stays in each widget suite.
void main() {
  GoalBannerEntry entryFor({int activationCount = 1}) => (
    nudge:
        AgentDomainEntity.goalNudge(
              id: 'ad-1',
              agentId: 'goal-1',
              status: GoalNudgeStatus.active,
              brief: const GoalNudgeBrief(
                headline: 'h',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'd',
              activationCount: activationCount,
              createdAt: DateTime(2026, 8, 9),
              updatedAt: DateTime(2026, 8, 9),
              vectorClock: null,
            )
            as GoalNudgeEntity,
    goalTitle: 'Move more',
  );

  late MockGoalNudgeInteractions interactions;
  late ProviderContainer container;

  setUp(() {
    interactions = MockGoalNudgeInteractions();
    container = ProviderContainer(
      overrides: [
        goalNudgeInteractionsProvider.overrideWithValue(interactions),
      ],
    );
    addTearDown(container.dispose);
  });

  // A minimal host that exposes a real (BuildContext, WidgetRef) pair via a
  // Consumer under a Scaffold (the ScaffoldMessenger the failure notices
  // present on).
  Future<(BuildContext, WidgetRef)> host(WidgetTester tester) async {
    late BuildContext ctx;
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: makeTestableWidgetNoScroll(
          Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                ctx = context;
                widgetRef = ref;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    return (ctx, widgetRef);
  }

  group('dismissGoalBanner', () {
    testWidgets('a persisted dismissal suppresses the id and reports true', (
      tester,
    ) async {
      when(
        () => interactions.dismiss(
          any(),
          forActivation: any(named: 'forActivation'),
        ),
      ).thenAnswer((_) async => true);
      final (ctx, ref) = await host(tester);

      final result = await dismissGoalBanner(ctx, ref, entryFor());
      expect(result, isTrue);
      expect(
        container.read(locallyDismissedNudgeIdsProvider).contains('ad-1'),
        isTrue,
      );
      verify(() => interactions.dismiss('ad-1', forActivation: 1)).called(1);
    });

    testWidgets('a declined dismissal (guards refused) reports false and '
        'does NOT suppress the id', (tester) async {
      when(
        () => interactions.dismiss(
          any(),
          forActivation: any(named: 'forActivation'),
        ),
      ).thenAnswer((_) async => false);
      final (ctx, ref) = await host(tester);

      final result = await dismissGoalBanner(ctx, ref, entryFor());
      expect(result, isFalse);
      expect(
        container.read(locallyDismissedNudgeIdsProvider).contains('ad-1'),
        isFalse,
      );
    });

    testWidgets('a thrown dismissal surfaces the retry notice and reports '
        'false', (tester) async {
      when(
        () => interactions.dismiss(
          any(),
          forActivation: any(named: 'forActivation'),
        ),
      ).thenAnswer((_) async => throw StateError('sync down'));
      final (ctx, ref) = await host(tester);

      final result = await dismissGoalBanner(ctx, ref, entryFor());
      await tester.pump();
      expect(result, isFalse);
      expect(
        find.text("That didn't save — please try again."),
        findsOneWidget,
      );
    });
  });
}
