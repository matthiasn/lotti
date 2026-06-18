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

      // ~0.4 into the 1400ms timeline both beats are live (glow window
      // 0.08–0.78, burst 0.12–0.96).
      await tester.pump(const Duration(milliseconds: 560));
      expect(find.byType(CompletionGlow), findsOneWidget);
      expect(find.byType(CompletionBurst), findsOneWidget);

      // After the timeline completes both beats clear themselves.
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
}
