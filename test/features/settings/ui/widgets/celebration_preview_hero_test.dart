import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_params.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/components/celebration/completion_burst.dart';
import 'package:lotti/features/settings/ui/widgets/celebration_preview_hero.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Widget hero({int neighbours = 2}) => makeTestableWidget(
    CelebrationPreviewHero(
      params: CelebrationParams.defaultsFor(CelebrationVariant.confetti),
      neighbours: neighbours,
    ),
  );

  testWidgets('shows the live row plus inert neighbours for context', (
    tester,
  ) async {
    await tester.pumpWidget(hero());
    // Exactly one row is interactive (the live, middle one).
    expect(find.byType(InkWell), findsOneWidget);
    // Neighbours stay unchecked so the only teal/check on screen marks the live
    // row (avoids a salience inversion) — nothing is checked before any tap.
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('tapping the live row checks it and fires a burst', (
    tester,
  ) async {
    await tester.pumpWidget(hero());
    expect(find.byType(CompletionBurst), findsNothing);

    await tester.tap(find.byType(InkWell));
    await tester.pump(); // run the post-frame overlay insert
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // The live row is now the only checked row and a burst is on screen.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byType(CompletionBurst), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion suppresses the burst', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        CelebrationPreviewHero(
          params: CelebrationParams.defaultsFor(CelebrationVariant.sparks),
        ),
        mediaQueryData: phoneMediaQueryData.copyWith(disableAnimations: true),
      ),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The row still checks off (feedback), but no particle burst plays.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byType(CompletionBurst), findsNothing);
  });

  testWidgets('bumping replayTick re-fires the burst without a tap', (
    tester,
  ) async {
    Widget build(int tick) => makeTestableWidget(
      CelebrationPreviewHero(
        params: CelebrationParams.defaultsFor(CelebrationVariant.sparks),
        replayTick: tick,
      ),
    );

    await tester.pumpWidget(build(0));
    expect(find.byType(CompletionBurst), findsNothing);

    // A new tick (a slider was released in the playground) replays the burst.
    await tester.pumpWidget(build(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byType(CompletionBurst), findsOneWidget);

    await tester.pumpAndSettle();
  });
}
