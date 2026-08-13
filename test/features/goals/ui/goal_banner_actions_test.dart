import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_actions.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

/// The shared banner-action contract (`showGoalBannerSnoozeSheet`,
/// `showGoalBannerRatingSheet`) used by BOTH the card and the dock — its
/// own path-mirrored suite, so neither caller's widget test owns behaviour
/// the other relies on. Caller-specific wiring (which button, which
/// gesture) stays in each widget suite.
void main() {
  setUpAll(registerAllFallbackValues);

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

  setUp(() {
    interactions = MockGoalNudgeInteractions();
    when(
      () => interactions.snooze(
        any(),
        duration: any(named: 'duration'),
        forActivation: any(named: 'forActivation'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => interactions.dismissForDay(
        any(),
        forActivation: any(named: 'forActivation'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => interactions.recordRating(
        any(),
        rating: any(named: 'rating'),
        skipped: any(named: 'skipped'),
        forActivation: any(named: 'forActivation'),
      ),
    ).thenAnswer((_) async {});
  });

  // A minimal host on the shared harness that exposes a real
  // (BuildContext, WidgetRef) pair via a Consumer under a Scaffold (the
  // ScaffoldMessenger the failure notices present on).
  Future<(BuildContext, WidgetRef)> host(WidgetTester tester) async {
    late BuildContext ctx;
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              ctx = context;
              widgetRef = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
        overrides: [
          goalNudgeInteractionsProvider.overrideWithValue(interactions),
        ],
      ),
    );
    return (ctx, widgetRef);
  }

  ProviderContainer containerOf(BuildContext ctx) =>
      ProviderScope.containerOf(ctx, listen: false);

  group('showGoalBannerSnoozeSheet', () {
    testWidgets('snooze choices are prominent and day dismissal is last', (
      tester,
    ) async {
      final (ctx, ref) = await host(tester);
      unawaited(showGoalBannerSnoozeSheet(ctx, ref, entryFor()));
      await tester.pumpAndSettle();

      expect(find.text('Snooze banner'), findsOneWidget);
      expect(find.text('When should it come back?'), findsOneWidget);
      for (final label in ['1 hour', '3 hours', '6 hours', '8 hours']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        tester.getTopLeft(find.text('Dismiss for today')).dy,
        greaterThan(tester.getBottomLeft(find.text('8 hours')).dy),
      );
    });

    testWidgets('a persisted snooze suppresses retained data immediately', (
      tester,
    ) async {
      final (ctx, ref) = await host(tester);
      final resultFuture = showGoalBannerSnoozeSheet(ctx, ref, entryFor());
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 hours'));
      await tester.pumpAndSettle();

      final result = await resultFuture;
      expect(result, isTrue);
      expect(
        containerOf(ctx).read(locallySnoozedNudgeDeadlinesProvider),
        contains('ad-1'),
      );
      verify(
        () => interactions.snooze(
          'ad-1',
          duration: GoalBannerSnoozeDuration.threeHours,
          forActivation: 1,
        ),
      ).called(1);
    });

    testWidgets('day dismissal is the secondary path and never snoozes', (
      tester,
    ) async {
      final (ctx, ref) = await host(tester);
      final resultFuture = showGoalBannerSnoozeSheet(ctx, ref, entryFor());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dismiss for today'));
      await tester.pumpAndSettle();

      expect(await resultFuture, isTrue);
      verify(
        () => interactions.dismissForDay('ad-1', forActivation: 1),
      ).called(1);
      verifyNever(
        () => interactions.snooze(
          any(),
          duration: any(named: 'duration'),
          forActivation: any(named: 'forActivation'),
        ),
      );
    });

    testWidgets('a failed snooze surfaces the retry notice and reports false', (
      tester,
    ) async {
      when(
        () => interactions.snooze(
          any(),
          duration: any(named: 'duration'),
          forActivation: any(named: 'forActivation'),
        ),
      ).thenAnswer((_) async => throw StateError('sync down'));
      final (ctx, ref) = await host(tester);
      final resultFuture = showGoalBannerSnoozeSheet(ctx, ref, entryFor());
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 hour'));
      await tester.pumpAndSettle();

      expect(await resultFuture, isFalse);
      expect(
        find.text("That didn't save — please try again."),
        findsOneWidget,
      );
    });

    testWidgets('a stale rejected snooze never hides the banner locally', (
      tester,
    ) async {
      when(
        () => interactions.snooze(
          any(),
          duration: any(named: 'duration'),
          forActivation: any(named: 'forActivation'),
        ),
      ).thenAnswer((_) async => false);
      final (ctx, ref) = await host(tester);
      final resultFuture = showGoalBannerSnoozeSheet(ctx, ref, entryFor());
      await tester.pumpAndSettle();
      await tester.tap(find.text('6 hours'));
      await tester.pumpAndSettle();

      expect(await resultFuture, isFalse);
      expect(
        containerOf(ctx).read(locallySnoozedNudgeDeadlinesProvider),
        isNot(contains('ad-1')),
      );
      verify(
        () => interactions.snooze(
          'ad-1',
          duration: GoalBannerSnoozeDuration.sixHours,
          forActivation: 1,
        ),
      ).called(1);
    });
  });

  group('showGoalBannerRatingSheet', () {
    testWidgets('picking a star records the rating for the shown activation', (
      tester,
    ) async {
      final (ctx, ref) = await host(tester);
      unawaited(showGoalBannerRatingSheet(ctx, ref, entryFor()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('4'));
      await tester.pumpAndSettle();
      verify(
        () => interactions.recordRating('ad-1', rating: 4, forActivation: 1),
      ).called(1);
    });

    testWidgets('the Skip button records a skip', (tester) async {
      final (ctx, ref) = await host(tester);
      unawaited(showGoalBannerRatingSheet(ctx, ref, entryFor()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      verify(
        () =>
            interactions.recordRating('ad-1', skipped: true, forActivation: 1),
      ).called(1);
    });

    testWidgets('a barrier dismissal consumes NOTHING — the one rating '
        'opportunity survives an accidental swipe-away', (tester) async {
      final (ctx, ref) = await host(tester);
      unawaited(showGoalBannerRatingSheet(ctx, ref, entryFor()));
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
  });
}
