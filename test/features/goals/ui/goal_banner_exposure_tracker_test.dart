import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_exposure_tracker.dart';

import '../../../widget_test_utils.dart';

/// The tracker's episode accounting is exercised through a minimal host — a
/// fixed-size box under the tracker — rather than a full banner, so the
/// tests bind to the visibility contract, not to banner rendering.
void main() {
  late List<(String, Duration)> exposures;

  List<Override> overrides() => [
    goalNudgeExposureFlushProvider.overrideWithValue(
      (nudgeId, visibleFor) => exposures.add((nudgeId, visibleFor)),
    ),
  ];

  setUp(() => exposures = []);

  Widget tracked({String id = 'ad-1', double height = 80}) =>
      GoalBannerExposureTracker(
        key: ValueKey(id),
        nudgeId: id,
        child: SizedBox(height: height, child: const Placeholder()),
      );

  testWidgets('one episode is flushed when the tracker leaves the tree', (
    tester,
  ) async {
    final sameOverrides = overrides();
    await tester.pumpWidget(
      makeTestableWidget(tracked(), overrides: sameOverrides),
    );
    await tester.pumpAndSettle();
    expect(exposures, isEmpty);

    await tester.pumpWidget(
      makeTestableWidget(const SizedBox.shrink(), overrides: sameOverrides),
    );
    await tester.pumpAndSettle();
    expect(exposures, hasLength(1));
    expect(exposures.single.$1, 'ad-1');
  });

  testWidgets('hiding the tab flushes the episode WITHOUT unmounting — '
      'separate appearances never merge', (tester) async {
    final sameOverrides = overrides();
    Widget host({required bool visible}) => makeTestableWidget(
      TickerMode(enabled: visible, child: tracked()),
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

  testWidgets('scrolling the tracker out of the viewport flushes its '
      'episode — off-screen time never counts', (tester) async {
    final sameOverrides = overrides();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        ListView(
          children: [
            tracked(),
            const SizedBox(height: 3000),
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

  testWidgets('a sibling growing in above moves the tracker across the '
      'viewport boundary with NO scroll gesture — the same element updates '
      'in place (didUpdateWidget), and its post-frame recheck flushes the '
      'now-hidden episode', (tester) async {
    final sameOverrides = overrides();
    // A SingleChildScrollView (not a lazily-built ListView) keeps every
    // child mounted regardless of scroll position — the tracker must stay
    // ELEMENT-STABLE while sliding off-screen, not be torn down by list
    // virtualization.
    Widget host({required double leadingHeight}) => makeTestableWidgetNoScroll(
      SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(key: const ValueKey('leading'), height: leadingHeight),
            tracked(),
            const SizedBox(height: 3000),
          ],
        ),
      ),
      overrides: sameOverrides,
    );

    await tester.pumpWidget(host(leadingHeight: 0));
    await tester.pumpAndSettle();
    expect(exposures, isEmpty);
    final elementBefore = tester.element(
      find.byType(GoalBannerExposureTracker),
    );

    // Only content ABOVE the tracker grows, pushing it below the fold. The
    // scroll offset stays at 0: no ScrollNotification carries this news.
    await tester.pumpWidget(host(leadingHeight: 3000));
    await tester.pumpAndSettle();

    final elementAfter = tester.element(
      find.byType(GoalBannerExposureTracker),
    );
    expect(
      identical(elementBefore, elementAfter),
      isTrue,
      reason:
          'the SAME element updates via didUpdateWidget rather than '
          'being torn down and remounted',
    );
    expect(
      exposures,
      hasLength(1),
      reason:
          "didUpdateWidget's _recheckAfterFrame caught the tracker "
          'sliding out of the viewport and flushed its episode',
    );
    expect(exposures.single.$1, 'ad-1');
  });

  testWidgets('backgrounding the app flushes the episode — pocket time '
      'never counts as exposure', (tester) async {
    final sameOverrides = overrides();
    await tester.pumpWidget(
      makeTestableWidget(tracked(), overrides: sameOverrides),
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
