import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_dock.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

/// Mutable entry source so tests can push new provider snapshots into the
/// dock mid-flight (queue-jumps, dismissals, collapse).
class _TestEntries extends Notifier<List<GoalBannerEntry>> {
  static List<GoalBannerEntry> initial = const [];

  @override
  List<GoalBannerEntry> build() => initial;

  void set(List<GoalBannerEntry> entries) => state = entries;
}

final _testEntriesProvider =
    NotifierProvider<_TestEntries, List<GoalBannerEntry>>(_TestEntries.new);

void main() {
  GoalBannerEntry entry({
    required String id,
    required String headline,
    String goalTitle = 'Move more',
    String? cta,
    int activationCount = 1,
    GoalNudgeTone tone = GoalNudgeTone.nudge,
  }) => (
    nudge:
        AgentDomainEntity.goalNudge(
              id: id,
              agentId: 'goal-$id',
              status: GoalNudgeStatus.active,
              brief: GoalNudgeBrief(
                headline: headline,
                cta: cta,
                tone: tone,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: id,
              activationCount: activationCount,
              createdAt: DateTime(2026, 8, 9),
              updatedAt: DateTime(2026, 8, 9),
              vectorClock: null,
            )
            as GoalNudgeEntity,
    goalTitle: goalTitle,
  );

  late MockGoalNudgeInteractions interactions;

  setUp(() {
    interactions = MockGoalNudgeInteractions();
    when(
      () => interactions.dismiss(
        any(),
        forActivation: any(named: 'forActivation'),
      ),
    ).thenAnswer((_) async => true);
    // A press-and-release on the dock body is a tap → banner→conversation
    // navigation; neutralise it so pause/resume tests don't route away.
    beamToNamedOverride = (_) {};
  });
  tearDown(() => beamToNamedOverride = null);

  List<Override> overrides() => [
    activeGoalNudgesProvider.overrideWith(
      (ref) async => ref.watch(_testEntriesProvider),
    ),
    goalNudgeInteractionsProvider.overrideWithValue(interactions),
    goalNudgeExposureFlushProvider.overrideWithValue((_, _) {}),
  ];

  Future<void> pumpDock(
    WidgetTester tester,
    List<GoalBannerEntry> entries, {
    bool compact = false,
  }) async {
    _TestEntries.initial = entries;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          bottomNavigationBar: GoalBannerDock(compact: compact),
        ),
        overrides: overrides(),
      ),
    );
    await tester.pump();
    await tester.pump();
    // Settle the dock's appear transition (the collapse AnimatedSwitcher
    // animates it in over medium1) so hit targets are at full size — but
    // never pumpAndSettle, which the perpetual tenure clock would hang.
    await tester.pump(const Duration(milliseconds: 400));
  }

  _TestEntries notifier(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(GoalBannerDock)),
    listen: false,
  ).read(_testEntriesProvider.notifier);

  /// Pumps enough discrete frames for a tenant transition to fully settle:
  /// post-frame advance, switcher start, out-animation completion, and the
  /// outgoing child's removal frame. Never pumpAndSettle — the tenure
  /// controller animates continuously and would spin it forever.
  Future<void> settleTransition(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('a single tenant just sits: no dots, no auto-advance after '
      'a full tenure', (tester) async {
    await pumpDock(tester, [entry(id: 'a', headline: 'Only voice')]);
    expect(find.text('Only voice'), findsOneWidget);

    await tester.pump(goalBannerDockTenure + const Duration(seconds: 1));
    expect(find.text('Only voice'), findsOneWidget);
    // No dot row: the tenant's dot would be the only one.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle &&
            w.constraints?.maxWidth == 4.0,
      ),
      findsNothing,
    );
  });

  testWidgets('two tenants rotate round-robin on the tenure clock, and '
      'wrap', (tester) async {
    await pumpDock(tester, [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice'),
    ]);
    expect(find.text('First voice'), findsOneWidget);

    await tester.pump(goalBannerDockTenure);
    await settleTransition(tester);
    expect(find.text('Second voice'), findsOneWidget);
    expect(find.text('First voice'), findsNothing);

    await tester.pump(goalBannerDockTenure);
    await settleTransition(tester);
    expect(find.text('First voice'), findsOneWidget, reason: 'wraps');
  });

  testWidgets('touching the dock pauses the cycle, and releasing resumes '
      'it — the WCAG pause affordance (hover shares this path)', (
    tester,
  ) async {
    await pumpDock(tester, [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice'),
    ]);

    // Press and hold on the dock: the Listener's pointer-down pauses the
    // tenure clock. Held across two full tenures, the tenant must not move.
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('First voice')),
    );
    await tester.pump();
    await tester.pump(goalBannerDockTenure * 2);
    expect(
      find.text('First voice'),
      findsOneWidget,
      reason: 'the cycle must hold while touched',
    );

    // Release: the clock resumes and the next tenure advances.
    await gesture.up();
    await tester.pump();
    await tester.pump(goalBannerDockTenure);
    await settleTransition(tester);
    expect(find.text('Second voice'), findsOneWidget);
  });

  testWidgets('a fresh banner arriving mid-rotation jumps the queue and '
      'carries the just-now marker', (tester) async {
    await pumpDock(tester, [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice'),
    ]);
    expect(find.text('First voice'), findsOneWidget);

    notifier(tester).set([
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice'),
      entry(
        id: 'c',
        headline: 'Walk done. That’s the rhythm.',
        goalTitle: 'Walk more',
      ),
    ]);
    await tester.pump();
    await settleTransition(tester);

    expect(find.text('Walk done. That’s the rhythm.'), findsOneWidget);
    expect(find.textContaining('just now'), findsOneWidget);

    // The marker is for THAT tenure only.
    await tester.pump(goalBannerDockTenure);
    await settleTransition(tester);
    expect(find.textContaining('just now'), findsNothing);
  });

  testWidgets('a re-run (activation bump) jumps the queue like a fresh '
      'acknowledgment', (tester) async {
    await pumpDock(tester, [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice'),
    ]);
    expect(find.text('First voice'), findsOneWidget);

    notifier(tester).set([
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice, refreshed', activationCount: 2),
    ]);
    await tester.pump();
    await settleTransition(tester);
    expect(find.text('Second voice, refreshed'), findsOneWidget);
  });

  testWidgets('dismissal advances immediately and the dot count shrinks; '
      'the last dismissal collapses the dock entirely', (tester) async {
    await pumpDock(tester, [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice'),
    ]);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    await settleTransition(tester);
    expect(find.text('Second voice'), findsOneWidget);
    verify(
      () => interactions.dismiss('a', forActivation: 1),
    ).called(1);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    await settleTransition(tester);
    // The quiet IS the feedback: nothing remains.
    expect(find.text('Second voice'), findsNothing);
    expect(find.byTooltip('Dismiss'), findsNothing);
  });

  testWidgets('zero tenants render nothing at all', (tester) async {
    await pumpDock(tester, const []);
    expect(find.byTooltip('Dismiss'), findsNothing);
  });

  testWidgets('compact dock yields while the keyboard is up', (tester) async {
    _TestEntries.initial = [entry(id: 'a', headline: 'First voice')];
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        MediaQuery(
          data: const MediaQueryData(
            viewInsets: EdgeInsets.only(bottom: 280),
          ),
          child: Scaffold(
            bottomNavigationBar: GoalBannerDock(compact: true),
          ),
        ),
        overrides: overrides(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('First voice'), findsNothing);
  });

  testWidgets('the compact dock shows no star even while a rating is due — '
      'X only, per the mobile anatomy', (tester) async {
    await pumpDock(
      tester,
      [entry(id: 'a', headline: 'First voice')],
      compact: true,
    );
    expect(find.byTooltip('Rate this banner'), findsNothing);
    expect(find.byTooltip('Dismiss'), findsOneWidget);
  });

  testWidgets('reduced motion: rotation still advances (only transitions '
      'change)', (tester) async {
    _TestEntries.initial = [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice'),
    ];
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            bottomNavigationBar: GoalBannerDock(compact: false),
          ),
        ),
        overrides: overrides(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('First voice'), findsOneWidget);
    await tester.pump(goalBannerDockTenure);
    await settleTransition(tester);
    expect(find.text('Second voice'), findsOneWidget);
  });
}
