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

  testWidgets('marquee scrolls when the text overflows its line', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const SizedBox(
          width: 60,
          child: GoalBannerAnimatedText(
            text: 'Your inner couch potato is winning again today.',
            animation: GoalBannerAnimation.marquee,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ClipRect), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
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
}
