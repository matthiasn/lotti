import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/goals/ui/goal_banner_animated_text.dart';

import '../../../widget_test_utils.dart';

void main() {
  Widget host(GoalBannerAnimation animation, {bool reduced = false}) =>
      makeTestableWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: SizedBox(
            width: 300,
            child: GoalBannerAnimatedText(
              text: 'Your inner couch potato is winning.',
              animation: animation,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );

  testWidgets('reduced motion degrades every preset to plain text', (
    tester,
  ) async {
    for (final animation in GoalBannerAnimation.values) {
      await tester.pumpWidget(host(animation, reduced: true));
      await tester.pump();
      expect(
        find.text('Your inner couch potato is winning.'),
        findsOneWidget,
        reason: '$animation must degrade to plain text',
      );
      expect(tester.hasRunningAnimations, isFalse, reason: '$animation');
    }
  });

  testWidgets('animated presets run a repeating controller and still '
      'render the copy', (tester) async {
    for (final animation in [
      GoalBannerAnimation.pulse,
      GoalBannerAnimation.wave,
      GoalBannerAnimation.glitch,
    ]) {
      await tester.pumpWidget(host(animation));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isTrue, reason: '$animation');
      await tester.pumpWidget(const SizedBox.shrink());
    }
    // Wave splits into words instead of one text run.
    await tester.pumpWidget(host(GoalBannerAnimation.wave));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('winning.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the typewriter reveals characters over the cycle', (
    tester,
  ) async {
    await tester.pumpWidget(host(GoalBannerAnimation.typewriter));
    await tester.pump(const Duration(milliseconds: 200));
    final partial = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((t) => t.isNotEmpty && t.length < 35);
    expect(partial, isNotEmpty, reason: 'mid-cycle shows a prefix');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('marquee falls back to a single ellipsized line when the '
      'text fits', (tester) async {
    await tester.pumpWidget(host(GoalBannerAnimation.marquee));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('Your inner couch potato is winning.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // A `SizedBox` alone cannot force overflow here: `makeTestableWidget`
  // hosts content in a vertical `SingleChildScrollView`, whose cross axis
  // is TIGHT to the surface width, and `SizedBox.enforce` cannot shrink a
  // tight incoming constraint below the surface size. Only shrinking the
  // test surface itself (`tester.view.physicalSize`) produces a real
  // narrow `constraints.maxWidth` for the marquee's `LayoutBuilder`.
  void useNarrowSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(60, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('marquee lays the line out at its full text width inside '
      'the clip — translation actually reveals the tail', (tester) async {
    useNarrowSurface(tester);
    await tester.pumpWidget(
      makeTestableWidget(
        const GoalBannerAnimatedText(
          text: 'Your inner couch potato is winning.',
          animation: GoalBannerAnimation.marquee,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
    await tester.pump();
    final line = tester.getSize(
      find.descendant(
        of: find.byType(GoalBannerAnimatedText),
        matching: find.text('Your inner couch potato is winning.'),
      ),
    );
    expect(
      line.width,
      greaterThan(60),
      reason: 'a viewport-clamped line would have nothing to reveal',
    );
  });

  testWidgets('marquee scrolls when the text overflows its line', (
    tester,
  ) async {
    useNarrowSurface(tester);
    await tester.pumpWidget(
      makeTestableWidget(
        const GoalBannerAnimatedText(
          text: 'Your inner couch potato is winning again today.',
          animation: GoalBannerAnimation.marquee,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    // OverflowBox lifts the viewport's max-width clamp inside the clip —
    // without it the translated line would have nothing to reveal.
    expect(find.byType(OverflowBox), findsOneWidget);
    expect(find.byType(ClipRect), findsWidgets);
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('marquee actually translates the overflowing line, and the '
      'offset changes over the cycle instead of sitting still', (
    tester,
  ) async {
    useNarrowSurface(tester);
    await tester.pumpWidget(
      makeTestableWidget(
        const GoalBannerAnimatedText(
          text: 'Your inner couch potato is winning again today.',
          animation: GoalBannerAnimation.marquee,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
    await tester.pump();

    Offset translateOffsetOf(Finder host) {
      final transform = tester.widget<Transform>(
        find.descendant(
          of: host,
          matching: find.byType(Transform),
        ),
      );
      // Transform.translate stores its offset as a pure-translation matrix;
      // decode the two translation components directly.
      final storage = transform.transform.storage;
      return Offset(storage[12], storage[13]);
    }

    final host = find.byType(GoalBannerAnimatedText);

    // At the very start of the cycle the marquee sits at its resting
    // (untranslated) position: sin(-pi/2) maps to t == 0 via the standard
    // curve, so travel * t == 0.
    final atStart = translateOffsetOf(host);
    expect(
      atStart.dx,
      moreOrLessEquals(0, epsilon: 0.01),
      reason: 'cycle start holds at the untranslated resting position',
    );

    await tester.pump(const Duration(milliseconds: 750));
    final atQuarterCycle = translateOffsetOf(host);
    expect(
      atQuarterCycle.dx,
      isNot(moreOrLessEquals(atStart.dx, epsilon: 0.01)),
      reason: 'the offset must change as the controller advances',
    );
    expect(
      atQuarterCycle.dx,
      lessThan(0),
      reason: 'the overflowing line scrolls leftward to reveal its tail',
    );
    // No vertical motion — marquee only ever travels horizontally.
    expect(atQuarterCycle.dy, 0);

    await tester.pump(const Duration(milliseconds: 750));
    final atHalfCycle = translateOffsetOf(host);
    expect(
      atHalfCycle.dx,
      isNot(moreOrLessEquals(atQuarterCycle.dx, epsilon: 0.01)),
      reason: 'motion continues past the quarter-cycle mark',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('flipping to reduced motion stops the running controller', (
    tester,
  ) async {
    await tester.pumpWidget(host(GoalBannerAnimation.pulse));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(host(GoalBannerAnimation.pulse, reduced: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('runaway copy is capped at two ellipsized lines', (
    tester,
  ) async {
    final longCopy = 'Your inner couch potato is winning ' * 12;
    for (final animation in const [
      GoalBannerAnimation.steady,
      GoalBannerAnimation.pulse,
      GoalBannerAnimation.glitch,
    ]) {
      await tester.pumpWidget(
        makeTestableWidget(
          SizedBox(
            width: 300,
            child: GoalBannerAnimatedText(
              text: longCopy,
              animation: animation,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
      await tester.pump();
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(GoalBannerAnimatedText),
          matching: find.text(longCopy),
        ),
      );
      expect(text.maxLines, 2, reason: '$animation caps the headline');
      expect(
        text.overflow,
        TextOverflow.ellipsis,
        reason: '$animation ellipsizes',
      );
    }
  });

  testWidgets('wave degrades to the bounded steady text when the copy '
      'would exceed the line cap', (tester) async {
    final longCopy = 'Your inner couch potato is winning ' * 12;
    await tester.pumpWidget(
      makeTestableWidget(
        SizedBox(
          width: 300,
          child: GoalBannerAnimatedText(
            text: longCopy,
            animation: GoalBannerAnimation.wave,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
    await tester.pump();
    // No per-word Wrap: the copy renders as one capped Text instead of
    // bobbing off the card.
    expect(
      find.descendant(
        of: find.byType(GoalBannerAnimatedText),
        matching: find.byType(Wrap),
      ),
      findsNothing,
    );
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(GoalBannerAnimatedText),
        matching: find.text(longCopy),
      ),
    );
    expect(text.maxLines, 2);
  });

  testWidgets('the typewriter exposes the FULL headline to screen readers '
      'while the visual prefix is still typing', (tester) async {
    await tester.pumpWidget(host(GoalBannerAnimation.typewriter));
    await tester.pump(const Duration(milliseconds: 100));
    // Early in the cycle only a prefix is painted…
    final semantics = tester.getSemantics(
      find.bySemanticsLabel('Your inner couch potato is winning.'),
    );
    // …but assistive tech always hears the whole copy.
    expect(semantics.label, 'Your inner couch potato is winning.');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a preset swap under the same element resyncs the '
      'controller — synced rows keep animating (or stop)', (tester) async {
    await tester.pumpWidget(host(GoalBannerAnimation.steady));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(host(GoalBannerAnimation.pulse));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      tester.hasRunningAnimations,
      isTrue,
      reason: 'steady→pulse must start the stopped controller',
    );

    await tester.pumpWidget(host(GoalBannerAnimation.steady));
    await tester.pump();
    expect(
      tester.hasRunningAnimations,
      isFalse,
      reason: 'pulse→steady must stop the invisible controller',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
