import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/nudges/model/nudge_entity_view.dart';
import 'package:lotti/features/nudges/state/nudge_banner_providers.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_actions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_utils/material_ui_finders.dart';
import '../../../widget_test_utils.dart';

/// The shared banner-action contract (`showNudgeBannerSnoozeSheet`,
/// `showNudgeBannerRatingSheet`) used by BOTH the card and the dock — its
/// own path-mirrored suite, so neither caller's widget test owns behaviour
/// the other relies on. Caller-specific wiring (which button, which
/// gesture) stays in each widget suite.
void main() {
  setUpAll(registerAllFallbackValues);

  NudgeBannerEntry entryFor({int activationCount = 1}) => (
    nudge: NudgeEntityView.of(
      AgentDomainEntity.goalNudge(
        id: 'ad-1',
        agentId: 'goal-1',
        status: NudgeStatus.active,
        brief: const NudgeBrief(
          headline: 'h',
          tone: NudgeTone.nudge,
          animation: NudgeBannerAnimation.steady,
        ),
        briefDigest: 'd',
        activationCount: activationCount,
        createdAt: DateTime(2026, 8, 9),
        updatedAt: DateTime(2026, 8, 9),
        vectorClock: null,
      ),
    )!,
    subjectTitle: 'Move more',
    kind: NudgeBannerKind.goal,
    tapRoute: '/goals/details/goal-1',
  );

  late MockNudgeInteractions interactions;
  final persistedDeadline = DateTime.utc(2030);

  setUp(() {
    interactions = MockNudgeInteractions();
    when(
      () => interactions.snooze(
        any(),
        duration: any(named: 'duration'),
        forActivation: any(named: 'forActivation'),
      ),
    ).thenAnswer((_) async => persistedDeadline);
    when(
      () => interactions.dismissForDay(
        any(),
        forActivation: any(named: 'forActivation'),
      ),
    ).thenAnswer((_) async => persistedDeadline);
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
          nudgeInteractionsProvider.overrideWithValue(interactions),
        ],
      ),
    );
    return (ctx, widgetRef);
  }

  ProviderContainer containerOf(BuildContext ctx) =>
      ProviderScope.containerOf(ctx, listen: false);

  group('showNudgeBannerSnoozeSheet', () {
    testWidgets('snooze choices are prominent and day dismissal is last', (
      tester,
    ) async {
      final (ctx, ref) = await host(tester);
      unawaited(showNudgeBannerSnoozeSheet(ctx, ref, entryFor()));
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
      final resultFuture = showNudgeBannerSnoozeSheet(ctx, ref, entryFor());
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 hours'));
      await tester.pumpAndSettle();

      final result = await resultFuture;
      expect(result, isTrue);
      expect(
        containerOf(ctx).read(locallySnoozedNudgeDeadlinesProvider)['ad-1'],
        (activation: 1, until: persistedDeadline),
      );
      verify(
        () => interactions.snooze(
          'ad-1',
          duration: NudgeBannerSnoozeDuration.threeHours,
          forActivation: 1,
        ),
      ).called(1);
    });

    testWidgets('day dismissal is the secondary path and never snoozes', (
      tester,
    ) async {
      final (ctx, ref) = await host(tester);
      final resultFuture = showNudgeBannerSnoozeSheet(ctx, ref, entryFor());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dismiss for today'));
      await tester.pumpAndSettle();

      expect(await resultFuture, isTrue);
      expect(
        containerOf(ctx).read(locallySnoozedNudgeDeadlinesProvider)['ad-1'],
        (activation: 1, until: persistedDeadline),
      );
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
      final resultFuture = showNudgeBannerSnoozeSheet(ctx, ref, entryFor());
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
      ).thenAnswer((_) async => null);
      final (ctx, ref) = await host(tester);
      final resultFuture = showNudgeBannerSnoozeSheet(ctx, ref, entryFor());
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
          duration: NudgeBannerSnoozeDuration.sixHours,
          forActivation: 1,
        ),
      ).called(1);
    });

    testWidgets('a dismissal committed before midnight is not extended when '
        'the transaction completes after midnight', (tester) async {
      final persistedMidnight = DateTime.utc(2026, 8, 13, 22);
      when(
        () => interactions.dismissForDay(
          any(),
          forActivation: any(named: 'forActivation'),
        ),
      ).thenAnswer((_) async => persistedMidnight);

      await withClock(
        Clock.fixed(persistedMidnight.add(const Duration(seconds: 1))),
        () async {
          final (ctx, ref) = await host(tester);
          final resultFuture = showNudgeBannerSnoozeSheet(ctx, ref, entryFor());
          await tester.pumpAndSettle();
          await tester.tap(find.text('Dismiss for today'));
          await tester.pumpAndSettle();

          expect(await resultFuture, isTrue);
          expect(
            containerOf(ctx).read(locallySnoozedNudgeDeadlinesProvider),
            isNot(contains('ad-1')),
          );
        },
      );
    });
  });

  testWidgets('the 8-hour preset maps to its exact duration', (tester) async {
    final (ctx, ref) = await host(tester);
    unawaited(showNudgeBannerSnoozeSheet(ctx, ref, entryFor()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('8 hours'));
    await tester.pumpAndSettle();
    verify(
      () => interactions.snooze(
        'ad-1',
        duration: NudgeBannerSnoozeDuration.eightHours,
        forActivation: 1,
      ),
    ).called(1);
  });

  group('showNudgeBannerRatingSheet', () {
    testWidgets('picking a star records the rating for the shown activation', (
      tester,
    ) async {
      final (ctx, ref) = await host(tester);
      unawaited(showNudgeBannerRatingSheet(ctx, ref, entryFor()));
      await tester.pumpAndSettle();
      await tester.tap(findMaterialTooltip('4'));
      await tester.pumpAndSettle();
      verify(
        () => interactions.recordRating('ad-1', rating: 4, forActivation: 1),
      ).called(1);
    });

    testWidgets('the Skip button records a skip', (tester) async {
      final (ctx, ref) = await host(tester);
      unawaited(showNudgeBannerRatingSheet(ctx, ref, entryFor()));
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
      unawaited(showNudgeBannerRatingSheet(ctx, ref, entryFor()));
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
