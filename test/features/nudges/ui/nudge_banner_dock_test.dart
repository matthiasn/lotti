import 'dart:math';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/nudges/model/nudge_entity_view.dart';
import 'package:lotti/features/nudges/state/nudge_banner_providers.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_animated_text.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_dock.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_widgets.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

/// Mutable entry source so tests can push new provider snapshots into the
/// dock mid-flight (queue-jumps, snoozes, collapse).
class _TestEntries extends Notifier<List<NudgeBannerEntry>> {
  static List<NudgeBannerEntry> initial = const [];

  @override
  List<NudgeBannerEntry> build() => initial;

  // ignore: avoid_setters_without_getters
  set entries(List<NudgeBannerEntry> value) => state = value;
}

final _testEntriesProvider =
    NotifierProvider<_TestEntries, List<NudgeBannerEntry>>(_TestEntries.new);

/// The registered banner source under test — the shape every kind's real
/// source has (`activeGoalNudgesProvider`).
final _testSourceProvider = FutureProvider<List<NudgeBannerEntry>>(
  (ref) async => ref.watch(_testEntriesProvider),
);

void main() {
  setUpAll(registerAllFallbackValues);

  NudgeBannerEntry entry({
    required String id,
    required String headline,
    String subjectTitle = 'Move more',
    NudgeBannerKind kind = NudgeBannerKind.goal,
    String? tagline,
    String? cta,
    int activationCount = 1,
    NudgeTone tone = NudgeTone.nudge,
    NudgeBannerAnimation animation = NudgeBannerAnimation.steady,
    DateTime? staleAt,
    DateTime? snoozedUntil,
    DateTime? dismissedForDayAt,
  }) => (
    nudge: NudgeEntityView.of(
      kind == NudgeBannerKind.goal
          ? AgentDomainEntity.goalNudge(
              id: id,
              agentId: 'goal-$id',
              status: NudgeStatus.active,
              brief: NudgeBrief(
                headline: headline,
                tagline: tagline,
                cta: cta,
                tone: tone,
                animation: animation,
              ),
              briefDigest: id,
              activationCount: activationCount,
              staleAt: staleAt,
              snoozedUntil: snoozedUntil,
              dismissedForDayAt: dismissedForDayAt,
              createdAt: DateTime(2026, 8, 9),
              updatedAt: DateTime(2026, 8, 9),
              vectorClock: null,
            )
          : AgentDomainEntity.relationshipNudge(
              id: id,
              agentId: 'relationship-$id',
              status: NudgeStatus.active,
              brief: NudgeBrief(
                headline: headline,
                tagline: tagline,
                cta: cta,
                tone: tone,
                animation: animation,
              ),
              briefDigest: id,
              activationCount: activationCount,
              staleAt: staleAt,
              snoozedUntil: snoozedUntil,
              dismissedForDayAt: dismissedForDayAt,
              createdAt: DateTime(2026, 8, 9),
              updatedAt: DateTime(2026, 8, 9),
              vectorClock: null,
            ),
    )!,
    subjectTitle: subjectTitle,
    kind: kind,
    // The destination follows the KIND, as the real sources build it: a
    // relationship tenant that routed to a goal page would let a
    // People-surface navigation test pass while sending the user to the
    // wrong feature entirely.
    tapRoute: switch (kind) {
      NudgeBannerKind.goal => '/goals/details/goal-$id',
      NudgeBannerKind.relationship => '/people/person-$id',
    },
  );

  late MockNudgeInteractions interactions;

  setUp(() {
    interactions = MockNudgeInteractions();
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
    // A press-and-release on the dock body is a tap → banner→conversation
    // navigation; neutralise it so pause/resume tests don't route away.
    beamToNamedOverride = (_) {};
  });
  tearDown(() => beamToNamedOverride = null);

  List<Override> overrides() => [
    nudgeBannerSourcesProvider.overrideWithValue([_testSourceProvider]),
    nudgeInteractionsProvider.overrideWithValue(interactions),
    nudgeExposureFlushProvider.overrideWithValue((_, _) {}),
  ];

  Future<void> pumpDock(
    WidgetTester tester,
    List<NudgeBannerEntry> entries, {
    bool compact = false,
    NudgeBannerSurface surface = NudgeBannerSurface.tasks,
  }) async {
    _TestEntries.initial = entries;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          bottomNavigationBar: NudgeBannerDock(
            compact: compact,
            surface: surface,
          ),
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
    tester.element(find.byType(NudgeBannerDock)),
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

  test('visibility filtering is shared by the dock and its reserved lane', () {
    final now = DateTime.utc(2026, 8, 11, 12);
    final visible = visibleNudgeBannerEntries(
      entries: [
        entry(id: 'visible', headline: 'Visible voice'),
        entry(
          id: 'stale',
          headline: 'Stale voice',
          staleAt: now.subtract(const Duration(minutes: 1)),
        ),
        entry(
          id: 'dismissed',
          headline: 'Dismissed voice',
          dismissedForDayAt: now,
        ),
        entry(
          id: 'snoozed',
          headline: 'Snoozed voice',
          snoozedUntil: now.add(const Duration(hours: 1)),
        ),
      ],
      locallySnoozedDeadlines: const {},
      surface: NudgeBannerSurface.tasks,
      now: now,
    );

    expect(visible.map((entry) => entry.nudge.id), ['visible']);
  });

  test('nudgeBannerShellHiddenUntil reports the LATEST active quiet deadline '
      '— snooze, rest-of-day dismissal or the local echo — and null once '
      'every interval has passed', () {
    final now = DateTime(2026, 8, 11, 12);

    // Visible: no quiet interval at all.
    expect(
      nudgeBannerShellHiddenUntil(
        entry(id: 'plain', headline: 'Visible'),
        locallySnoozedDeadlines: const {},
        now: now,
      ),
      isNull,
    );

    // A durable snooze reports its own deadline.
    expect(
      nudgeBannerShellHiddenUntil(
        entry(
          id: 'snoozed',
          headline: 'Snoozed',
          snoozedUntil: now.add(const Duration(hours: 3)),
        ),
        locallySnoozedDeadlines: const {},
        now: now,
      ),
      now.add(const Duration(hours: 3)).toUtc(),
    );

    // A rest-of-day dismissal hides until the next local midnight.
    expect(
      nudgeBannerShellHiddenUntil(
        entry(id: 'dismissed', headline: 'Dismissed', dismissedForDayAt: now),
        locallySnoozedDeadlines: const {},
        now: now,
      ),
      DateTime(2026, 8, 12),
    );

    // The optimistic local echo counts for ITS activation — and the latest
    // of several active deadlines wins.
    expect(
      nudgeBannerShellHiddenUntil(
        entry(
          id: 'echoed',
          headline: 'Echoed',
          snoozedUntil: now.add(const Duration(hours: 1)),
        ),
        locallySnoozedDeadlines: {
          'echoed': (
            activation: 1,
            until: now.add(const Duration(hours: 6)),
          ),
        },
        now: now,
      ),
      now.add(const Duration(hours: 6)),
    );

    // A stale-activation echo and an expired snooze decide nothing.
    expect(
      nudgeBannerShellHiddenUntil(
        entry(
          id: 'expired',
          headline: 'Expired',
          activationCount: 2,
          snoozedUntil: now.subtract(const Duration(minutes: 1)),
        ),
        locallySnoozedDeadlines: {
          'expired': (
            activation: 1,
            until: now.add(const Duration(hours: 6)),
          ),
        },
        now: now,
      ),
      isNull,
    );
  });

  test('local suppression never hides a newer activation of the same row', () {
    final now = DateTime.utc(2026, 8, 11, 12);
    final visible = visibleNudgeBannerEntries(
      entries: [
        entry(
          id: 'rerun',
          headline: 'Fresh activation',
          activationCount: 2,
        ),
      ],
      locallySnoozedDeadlines: {
        'rerun': (
          activation: 1,
          until: now.add(const Duration(hours: 12)),
        ),
      },
      surface: NudgeBannerSurface.tasks,
      now: now,
    );

    expect(visible.map((entry) => entry.nudge.id), ['rerun']);
  });

  testWidgets('the People surface hides goal tenants and speaks '
      'relationship ones with their own semantic label (ADR 0059)', (
    tester,
  ) async {
    await pumpDock(
      tester,
      [
        entry(id: 'g1', headline: 'Goal voice'),
        entry(
          id: 'r1',
          headline: 'Call Anna — five weeks.',
          kind: NudgeBannerKind.relationship,
          subjectTitle: 'Anna',
        ),
      ],
      surface: NudgeBannerSurface.people,
    );

    expect(find.text('Goal voice'), findsNothing);
    expect(find.text('Call Anna — five weeks.'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Relationship banner for Anna')),
      findsOneWidget,
    );
  });

  testWidgets('a relationship tenant stays off no surface — it also speaks '
      'on the goal surfaces', (tester) async {
    await pumpDock(tester, [
      entry(
        id: 'r1',
        headline: 'Call Anna — five weeks.',
        kind: NudgeBannerKind.relationship,
        subjectTitle: 'Anna',
      ),
    ]);
    expect(find.text('Call Anna — five weeks.'), findsOneWidget);
  });

  testWidgets(
    'the rotation survives a surface whose tenants are all filtered out — '
    "the shell swaps one mounted dock's surface, it does not remount it",
    (tester) async {
      _TestEntries.initial = [
        entry(id: 'v1', headline: 'Voice one'),
        entry(id: 'v2', headline: 'Voice two'),
      ];
      // One dock element for the whole test, exactly as the shell mounts it:
      // only the `surface` property changes as the user switches tabs.
      final surface = ValueNotifier(NudgeBannerSurface.tasks);
      addTearDown(surface.dispose);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            bottomNavigationBar: ValueListenableBuilder(
              valueListenable: surface,
              builder: (_, value, _) =>
                  NudgeBannerDock(compact: false, surface: value),
            ),
          ),
          overrides: overrides(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Voice one'), findsOneWidget);

      // Park on People, where every goal tenant is filtered out, long
      // enough for the tenure to run out with nothing to advance to.
      surface.value = NudgeBannerSurface.people;
      await tester.pump();
      await settleTransition(tester);
      expect(find.text('Voice one'), findsNothing);
      await tester.pump(nudgeBannerDockTenure + const Duration(seconds: 1));
      await tester.pump();

      // Back on Tasks the cycle must be running again.
      surface.value = NudgeBannerSurface.tasks;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Voice one'), findsOneWidget);
      await tester.pump(nudgeBannerDockTenure);
      await settleTransition(tester);
      expect(
        find.text('Voice two'),
        findsOneWidget,
        reason: 'the tenure died on the empty surface and never restarted',
      );
    },
  );

  testWidgets('a single tenant just sits: no dots, no auto-advance after '
      'a full tenure', (tester) async {
    await pumpDock(tester, [entry(id: 'a', headline: 'Only voice')]);
    expect(find.text('Only voice'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Goal banner for Move more')),
      findsOneWidget,
    );

    await tester.pump(nudgeBannerDockTenure + const Duration(seconds: 1));
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

  testWidgets('the task-page dock honors the banner animation preset', (
    tester,
  ) async {
    await pumpDock(tester, [
      entry(
        id: 'pulse',
        headline: 'Animated standing voice',
        animation: NudgeBannerAnimation.pulse,
      ),
    ]);

    expect(find.byType(NudgeBannerAnimatedText), findsOneWidget);
    final samples = <double>[];
    for (var i = 0; i < 4; i++) {
      samples.add(tester.widget<Opacity>(find.byType(Opacity)).opacity);
      await tester.pump(const Duration(milliseconds: 750));
    }

    expect(samples.reduce(max) - samples.reduce(min), greaterThan(0.2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('desktop and compact docks show the full animated headline', (
    tester,
  ) async {
    final animated = entry(
      id: 'pulse',
      headline: 'Animated standing voice',
      animation: NudgeBannerAnimation.pulse,
    );

    await pumpDock(tester, [animated]);
    expect(
      tester
          .widget<NudgeBannerAnimatedText>(
            find.byType(NudgeBannerAnimatedText),
          )
          .maxLines,
      isNull,
    );

    await pumpDock(tester, [animated], compact: true);
    expect(
      tester
          .widget<NudgeBannerAnimatedText>(
            find.byType(NudgeBannerAnimatedText),
          )
          .maxLines,
      isNull,
    );
    // The COMPACT (bottom) dock names its goal too — compact trims the CTA
    // and button labels for width, never the attribution.
    expect(find.byType(NudgeBannerPersonaChip), findsOneWidget);
    expect(find.text('Move more'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the dock spans its host, NAMES its goal, and omits the '
      'tagline', (tester) async {
    await pumpDock(tester, [
      entry(
        id: 'tagline',
        headline: 'Your shoes are getting suspicious.',
        tagline: 'One walk puts the rumors to bed.',
        subjectTitle: 'Walk',
      ),
    ]);

    expect(find.text('One walk puts the rumors to bed.'), findsNothing);
    // The voice must not be anonymous: the persona chip and the goal's name
    // attribute the nudge — a dock tenant reads as SOME goal speaking.
    expect(find.text('Walk'), findsOneWidget);
    expect(find.byType(NudgeBannerPersonaChip), findsOneWidget);
    expect(
      tester.getSize(find.byType(NudgeBannerDock)).width,
      tester.getSize(find.byType(Scaffold)).width,
    );
  });

  testWidgets('the desktop tenant uses the full banner frame width', (
    tester,
  ) async {
    await pumpDock(tester, [
      entry(
        id: 'wide',
        headline: 'Ghost feet detected',
        tagline: 'Your sneakers would like the whole available lane.',
        cta: 'Go touch grass',
      ),
    ]);

    final frame = find.byKey(const ValueKey('nudge-banner-dock-frame'));
    final tenant = find.byKey(const ValueKey('nudge-banner-dock-tenant'));
    expect(frame, findsOneWidget);
    expect(tenant, findsOneWidget);
    final frameRect = tester.getRect(frame);
    final tenantRect = tester.getRect(tenant);
    expect(tenantRect.center.dx, frameRect.center.dx);
    expect(tenantRect.width, closeTo(frameRect.width, 2));
    final snoozeRect = tester.getRect(
      find.byKey(const ValueKey('nudge-banner-dock-snooze')),
    );
    expect(frameRect.right - snoozeRect.right, lessThan(20));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('nudge-banner-copy-region')))
          .width,
      greaterThan(frameRect.width * 0.4),
      reason:
          'a short CTA must not reserve half the dock from the copy — the '
          'persona chip and its gap are the only other fixed claims',
    );
  });

  testWidgets('two tenants rotate round-robin on the tenure clock, and '
      'wrap', (tester) async {
    await pumpDock(tester, [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice'),
    ]);
    expect(find.text('First voice'), findsOneWidget);

    await tester.pump(nudgeBannerDockTenure);
    await settleTransition(tester);
    expect(find.text('Second voice'), findsOneWidget);
    expect(find.text('First voice'), findsNothing);

    await tester.pump(nudgeBannerDockTenure);
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
    await tester.pump(nudgeBannerDockTenure * 2);
    expect(
      find.text('First voice'),
      findsOneWidget,
      reason: 'the cycle must hold while touched',
    );

    // Release: the clock resumes and the next tenure advances.
    await gesture.up();
    await tester.pump();
    await tester.pump(nudgeBannerDockTenure);
    await settleTransition(tester);
    expect(find.text('Second voice'), findsOneWidget);
  });

  testWidgets('mouse hover pauses the cycle and moving away resumes it', (
    tester,
  ) async {
    await pumpDock(tester, [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice'),
    ]);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    // Enter from outside so the MouseRegion sees an enter transition.
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('First voice')));
    await tester.pump();

    await tester.pump(nudgeBannerDockTenure * 2);
    expect(
      find.text('First voice'),
      findsOneWidget,
      reason: 'the cycle holds while hovered',
    );

    await gesture.moveTo(Offset.zero);
    await tester.pump();
    await tester.pump(nudgeBannerDockTenure);
    await settleTransition(tester);
    expect(find.text('Second voice'), findsOneWidget);
  });

  testWidgets('a fresh banner arriving mid-rotation jumps the queue', (
    tester,
  ) async {
    await pumpDock(tester, [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice'),
    ]);
    expect(find.text('First voice'), findsOneWidget);

    notifier(tester).entries = [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice'),
      entry(
        id: 'c',
        headline: 'Walk done. That’s the rhythm.',
        tagline: 'One more outing keeps the streak alive.',
        subjectTitle: 'Walk more',
      ),
    ];
    await tester.pump();
    await settleTransition(tester);

    expect(find.text('Walk done. That’s the rhythm.'), findsOneWidget);
    expect(find.textContaining('just now'), findsNothing);
    expect(find.text('One more outing keeps the streak alive.'), findsNothing);

    await tester.pump(nudgeBannerDockTenure);
    await settleTransition(tester);
    expect(find.textContaining('just now'), findsNothing);
  });

  testWidgets('when two fresh banners arrive in one refresh, the NEWEST '
      '(first, newest-first order) takes the slot', (tester) async {
    await pumpDock(tester, [entry(id: 'a', headline: 'First voice')]);
    expect(find.text('First voice'), findsOneWidget);

    // Two new voices arrive at once, newest-first: 'c' then 'b'. The newest
    // acknowledgment ('c') must jump the queue, not the older 'b'.
    notifier(tester).entries = [
      entry(id: 'c', headline: 'Newest voice'),
      entry(id: 'b', headline: 'Older new voice'),
      entry(id: 'a', headline: 'First voice'),
    ];
    await tester.pump();
    await settleTransition(tester);
    expect(find.text('Newest voice'), findsOneWidget);
    expect(find.text('Older new voice'), findsNothing);
  });

  testWidgets('a re-run (activation bump) jumps the queue like a fresh '
      'acknowledgment', (tester) async {
    await pumpDock(tester, [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice'),
    ]);
    expect(find.text('First voice'), findsOneWidget);

    notifier(tester).entries = [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice, refreshed', activationCount: 2),
    ];
    await tester.pump();
    await settleTransition(tester);
    expect(find.text('Second voice, refreshed'), findsOneWidget);
  });

  testWidgets('a second tenant arriving beside a lone one takes the slot '
      '(a fresh voice) and the cycle then rotates', (tester) async {
    await pumpDock(tester, [entry(id: 'a', headline: 'First voice')]);
    // Lone tenant: the tenure clock is stopped.
    await tester.pump(nudgeBannerDockTenure * 2);
    expect(find.text('First voice'), findsOneWidget);

    // A second voice appears: a banner arriving after the dock is already
    // rotating is a fresh voice — it jumps the slot immediately.
    notifier(tester).entries = [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice'),
    ];
    await tester.pump();
    await settleTransition(tester);
    expect(find.text('Second voice'), findsOneWidget);

    // The cycle resumed: one tenure later it rotates on to the other tenant.
    await tester.pump(nudgeBannerDockTenure);
    await settleTransition(tester);
    expect(find.text('First voice'), findsOneWidget);
  });

  testWidgets('a cancelled touch releases the pause', (tester) async {
    await pumpDock(tester, [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice'),
    ]);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('First voice')),
    );
    await tester.pump();
    // Cancel (not release): the pointer-cancel path must also resume.
    await gesture.cancel();
    await tester.pump();
    await tester.pump(nudgeBannerDockTenure);
    await settleTransition(tester);
    expect(find.text('Second voice'), findsOneWidget);
  });

  testWidgets('snooze advances immediately and the dot count shrinks; '
      'the last snooze collapses the dock entirely', (tester) async {
    await pumpDock(tester, [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice'),
    ]);

    await tester.tap(find.text('Snooze'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('1 hour'));
    await tester.pump();
    await settleTransition(tester);
    expect(find.text('Second voice'), findsOneWidget);
    verify(
      () => interactions.snooze(
        'a',
        duration: NudgeBannerSnoozeDuration.oneHour,
        forActivation: 1,
      ),
    ).called(1);

    await tester.tap(find.text('Snooze'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('1 hour'));
    await tester.pump();
    await settleTransition(tester);
    // The quiet IS the feedback: nothing remains.
    expect(find.text('Second voice'), findsNothing);
    expect(find.text('Snooze'), findsNothing);
  });

  testWidgets('removing the middle tenant advances to its SUCCESSOR, not '
      'back to the first — no rewind', (tester) async {
    await pumpDock(tester, [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice'),
      entry(id: 'c', headline: 'Third voice'),
    ]);

    // Advance to the middle tenant (b).
    await tester.pump(nudgeBannerDockTenure);
    await settleTransition(tester);
    expect(find.text('Second voice'), findsOneWidget);

    // b leaves (expired/superseded elsewhere): the dock must show c, the
    // successor — showing 'a' again would replay a banner just moved past.
    notifier(tester).entries = [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'c', headline: 'Third voice'),
    ];
    await tester.pump();
    await settleTransition(tester);
    expect(find.text('Third voice'), findsOneWidget);
    expect(find.text('First voice'), findsNothing);
  });

  testWidgets('backgrounding the app pauses the cycle; resuming restarts '
      'it', (tester) async {
    await pumpDock(tester, [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice'),
    ]);
    expect(find.text('First voice'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    // Held across two tenures while backgrounded — a rotation nobody can
    // see is wasted motion.
    await tester.pump(nudgeBannerDockTenure * 2);
    expect(find.text('First voice'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(nudgeBannerDockTenure);
    await settleTransition(tester);
    expect(find.text('Second voice'), findsOneWidget);
  });

  testWidgets('the desktop dock renders the CTA pill and the rating star '
      'when an outcome is due, and rating opens the sheet', (tester) async {
    when(
      () => interactions.recordRating(
        any(),
        rating: any(named: 'rating'),
        skipped: any(named: 'skipped'),
        forActivation: any(named: 'forActivation'),
      ),
    ).thenAnswer((_) async {});
    await pumpDock(tester, [
      entry(id: 'a', headline: 'First voice', cta: 'Log a walk'),
    ]);
    expect(find.text('Log a walk'), findsOneWidget);
    expect(find.byTooltip('Rate this banner'), findsOneWidget);

    await tester.tap(find.byTooltip('Rate this banner'));
    await tester.pumpAndSettle();
    expect(find.text('How was this banner?'), findsOneWidget);
  });

  testWidgets('tapping the desktop dock CTA opens the goal', (tester) async {
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    await pumpDock(tester, [
      entry(id: 'a', headline: 'First voice', cta: 'Log a walk'),
    ]);
    await tester.tap(find.text('Log a walk'));
    await tester.pump();
    expect(navigated, ['/goals/details/goal-a']);
  });

  testWidgets('tapping a relationship tenant on People opens that person, '
      'not a goal', (tester) async {
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    await pumpDock(
      tester,
      [
        entry(
          id: 'anna',
          headline: 'Call Anna — five weeks.',
          cta: 'Say hello',
          kind: NudgeBannerKind.relationship,
          subjectTitle: 'Anna',
        ),
      ],
      surface: NudgeBannerSurface.people,
    );

    await tester.tap(find.text('Say hello'));
    await tester.pump();

    expect(navigated, ['/people/person-anna']);
  });

  testWidgets('compact dock has no swipe-dismiss and snoozes from its action', (
    tester,
  ) async {
    await pumpDock(
      tester,
      [entry(id: 'a', headline: 'First voice')],
      compact: true,
    );
    expect(find.byType(Dismissible), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('nudge-banner-dock-snooze')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('3 hours'));
    await tester.pump(const Duration(milliseconds: 400));
    verify(
      () => interactions.snooze(
        'a',
        duration: NudgeBannerSnoozeDuration.threeHours,
        forActivation: 1,
      ),
    ).called(1);
  });

  testWidgets('an entry past its staleAt never takes the slot', (
    tester,
  ) async {
    await pumpDock(tester, [
      (
        nudge: NudgeEntityView.of(
          AgentDomainEntity.goalNudge(
            id: 'stale',
            agentId: 'goal-stale',
            status: NudgeStatus.active,
            brief: const NudgeBrief(
              headline: 'Stale voice',
              tone: NudgeTone.nudge,
              animation: NudgeBannerAnimation.steady,
            ),
            briefDigest: 'stale',
            staleAt: DateTime.utc(2000),
            createdAt: DateTime(2026, 8, 9),
            updatedAt: DateTime(2026, 8, 9),
            vectorClock: null,
          ),
        )!,
        subjectTitle: 'Move more',
        kind: NudgeBannerKind.goal,
        tapRoute: '/goals/details/goal-stale',
      ),
      entry(id: 'fresh', headline: 'Fresh voice'),
    ]);
    expect(find.text('Fresh voice'), findsOneWidget);
    expect(find.text('Stale voice'), findsNothing);
  });

  testWidgets('a local snooze hides only its retained banner immediately', (
    tester,
  ) async {
    await pumpDock(tester, [
      entry(id: 'a', headline: 'Quiet now'),
      entry(id: 'b', headline: 'Still here'),
    ]);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NudgeBannerDock)),
      listen: false,
    );

    container
        .read(locallySnoozedNudgeDeadlinesProvider.notifier)
        .add('a', 1, DateTime.utc(2099));
    await settleTransition(tester);

    expect(find.text('Quiet now'), findsNothing);
    expect(find.text('Still here'), findsOneWidget);
  });

  testWidgets('zero tenants render nothing at all', (tester) async {
    await pumpDock(tester, const []);
    expect(
      find.byKey(const ValueKey('nudge-banner-dock-snooze')),
      findsNothing,
    );
  });

  testWidgets('the compact dock shows no star and keeps its snooze action', (
    tester,
  ) async {
    await pumpDock(
      tester,
      [entry(id: 'a', headline: 'First voice')],
      compact: true,
    );
    expect(find.byTooltip('Rate this banner'), findsNothing);
    expect(
      find.byKey(const ValueKey('nudge-banner-dock-snooze')),
      findsOneWidget,
    );
  });

  testWidgets('reduced motion: rotation still advances (only transitions '
      'change)', (tester) async {
    _TestEntries.initial = [
      entry(id: 'a', headline: 'First voice'),
      entry(id: 'b', headline: 'Second voice'),
    ];
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const Scaffold(
              bottomNavigationBar: NudgeBannerDock(
                compact: false,
                surface: NudgeBannerSurface.tasks,
              ),
            ),
          ),
        ),
        overrides: overrides(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('First voice'), findsOneWidget);
    await tester.pump(nudgeBannerDockTenure);
    await settleTransition(tester);
    expect(find.text('Second voice'), findsOneWidget);
  });
}
