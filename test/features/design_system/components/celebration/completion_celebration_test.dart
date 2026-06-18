import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/celebration/completion_burst.dart';
import 'package:lotti/features/design_system/components/celebration/completion_celebration.dart';
import 'package:lotti/features/design_system/components/celebration/completion_glow.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const childKey = Key('celebration-child');
  Widget child() => const SizedBox(key: childKey, width: 200, height: 80);

  testWidgets('renders its child and stays inert at rest', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        CompletionCelebration(completed: false, child: child()),
      ),
    );

    expect(find.byKey(childKey), findsOneWidget);
    // No transition has happened, so neither celebration beat is on screen.
    expect(find.byType(CompletionGlow), findsNothing);
    expect(find.byType(CompletionBurst), findsNothing);
  });

  testWidgets(
    'plays glow + burst and fires onCelebrate on the false → true edge',
    (tester) async {
      var celebrateCount = 0;
      Widget tree({required bool completed}) => makeTestableWidget(
        CompletionCelebration(
          completed: completed,
          onCelebrate: () => celebrateCount++,
          child: child(),
        ),
      );

      await tester.pumpWidget(tree(completed: false));
      expect(celebrateCount, 0);

      // Flip to complete: the callback fires and the timeline starts.
      await tester.pumpWidget(tree(completed: true));
      expect(celebrateCount, 1);

      // The glow is inline and live immediately; the spark burst spawns into
      // the app overlay on the next frame and runs its own timeline. Pump into
      // the window where both beats are simultaneously on screen (glow window
      // 0.08–0.78, burst 0.12–0.96 of 1400ms).
      await tester.pump(const Duration(milliseconds: 200)); // build the overlay
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CompletionGlow), findsOneWidget);
      expect(find.byType(CompletionBurst), findsOneWidget);

      // After the timeline completes both beats clear themselves (the overlay
      // burst removes its own entry).
      await tester.pumpAndSettle();
      expect(find.byType(CompletionGlow), findsNothing);
      expect(find.byType(CompletionBurst), findsNothing);
    },
  );

  testWidgets('does not play when already complete on first build', (
    tester,
  ) async {
    var celebrateCount = 0;
    await tester.pumpWidget(
      makeTestableWidget(
        CompletionCelebration(
          completed: true,
          onCelebrate: () => celebrateCount++,
          child: child(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 560));
    // No false→true transition occurred, so nothing celebrates.
    expect(celebrateCount, 0);
    expect(find.byType(CompletionGlow), findsNothing);
    expect(find.byType(CompletionBurst), findsNothing);
  });

  testWidgets('reduced motion keeps a static glow but suppresses the burst', (
    tester,
  ) async {
    Widget tree({required bool completed}) => makeTestableWidget(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: CompletionCelebration(completed: completed, child: child()),
        ),
      ),
    );

    await tester.pumpWidget(tree(completed: false));
    await tester.pumpWidget(tree(completed: true));
    await tester.pump(const Duration(milliseconds: 560));

    expect(find.byType(CompletionGlow), findsOneWidget);
    expect(find.byType(CompletionBurst), findsNothing);
    final glow = tester.widget<CompletionGlow>(find.byType(CompletionGlow));
    expect(glow.staticGlow, isTrue);

    await tester.pumpAndSettle();
  });

  testWidgets('anchorScale pops the child during the celebration', (
    tester,
  ) async {
    Widget tree({required bool completed}) => makeTestableWidget(
      CompletionCelebration(
        completed: completed,
        anchorScale: true,
        child: child(),
      ),
    );

    await tester.pumpWidget(tree(completed: false));
    await tester.pumpWidget(tree(completed: true));
    // ~0.09 into the 1400ms timeline — inside the anchorScale window (first
    // 25%), so the child is scaled past its resting size.
    await tester.pump(const Duration(milliseconds: 120));

    final maxScale = tester
        .widgetList<Transform>(
          find.ancestor(
            of: find.byKey(childKey),
            matching: find.byType(Transform),
          ),
        )
        .map((t) => t.transform.getMaxScaleOnAxis())
        .fold<double>(1, (m, s) => s > m ? s : m);
    expect(maxScale, greaterThan(1.0));

    await tester.pumpAndSettle();
  });

  testWidgets('showBurst: false plays only the glow', (tester) async {
    Widget tree({required bool completed}) => makeTestableWidget(
      CompletionCelebration(
        completed: completed,
        showBurst: false,
        child: child(),
      ),
    );

    await tester.pumpWidget(tree(completed: false));
    await tester.pumpWidget(tree(completed: true));
    await tester.pump(const Duration(milliseconds: 560));

    expect(find.byType(CompletionGlow), findsOneWidget);
    expect(find.byType(CompletionBurst), findsNothing);

    await tester.pumpAndSettle();
  });

  testWidgets('animate: false fires onCelebrate but skips the visuals', (
    tester,
  ) async {
    var celebrateCount = 0;
    Widget tree({required bool completed}) => makeTestableWidget(
      CompletionCelebration(
        completed: completed,
        animate: false,
        onCelebrate: () => celebrateCount++,
        child: child(),
      ),
    );

    await tester.pumpWidget(tree(completed: false));
    await tester.pumpWidget(tree(completed: true));

    // The haptic hook still fires — only the visual beats are gated.
    expect(celebrateCount, 1);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CompletionGlow), findsNothing);
    expect(find.byType(CompletionBurst), findsNothing);

    await tester.pumpAndSettle();
  });

  group('spawnCompletionBurst', () {
    // Renders an anchor whose context is captured, plus a toggle to remove it —
    // so a test can fire a burst from the anchor and then unmount it, the way
    // completing the last checklist item collapses its row in the same frame.
    Future<void Function({required bool show})> pumpAnchor(
      WidgetTester tester, {
      required void Function(BuildContext) onContext,
      bool disableAnimations = false,
    }) async {
      late void Function(void Function()) setOuter;
      var visible = true;
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: disableAnimations),
              child: StatefulBuilder(
                builder: (context, setState) {
                  setOuter = setState;
                  return SizedBox(
                    width: 40,
                    height: 40,
                    child: visible
                        ? Builder(
                            builder: (c) {
                              onContext(c);
                              return const SizedBox.expand();
                            },
                          )
                        : const SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
        ),
      );
      return ({required bool show}) => setOuter(() => visible = show);
    }

    testWidgets('fires into the overlay and survives the anchor unmounting', (
      tester,
    ) async {
      late BuildContext anchorContext;
      final toggle = await pumpAnchor(
        tester,
        onContext: (c) => anchorContext = c,
      );

      // Fire from the anchor, then remove it in the same frame.
      spawnCompletionBurst(
        anchorContext,
        count: 16,
        duration: const Duration(milliseconds: 850),
      );
      toggle(show: false);

      await tester.pump(); // run post-frame spawn + remove the anchor
      await tester.pump(const Duration(milliseconds: 100)); // build + start
      await tester.pump(const Duration(milliseconds: 300)); // into the window

      // The burst is live in the overlay even though its anchor is long gone.
      expect(find.byType(CompletionBurst), findsOneWidget);

      // It removes its own overlay entry once the timeline completes.
      await tester.pumpAndSettle();
      expect(find.byType(CompletionBurst), findsNothing);
    });

    testWidgets('is suppressed under reduced motion', (tester) async {
      late BuildContext anchorContext;
      await pumpAnchor(
        tester,
        onContext: (c) => anchorContext = c,
        disableAnimations: true,
      );

      spawnCompletionBurst(anchorContext);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CompletionBurst), findsNothing);
    });
  });
}
