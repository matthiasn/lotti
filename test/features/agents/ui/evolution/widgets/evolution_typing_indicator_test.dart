import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_typing_indicator.dart';

import '../../../../../widget_test_utils.dart';

/// Reads the opacity of each dot, left to right.
List<double> dotOpacities(WidgetTester tester) => tester
    .widgetList<Opacity>(
      find.descendant(
        of: find.byType(EvolutionTypingIndicator),
        matching: find.byType(Opacity),
      ),
    )
    .map((o) => o.opacity)
    .toList();

void main() {
  Widget subject() => makeTestableWidgetNoScroll(
    const Center(child: EvolutionTypingIndicator()),
  );

  group('EvolutionTypingIndicator', () {
    testWidgets('renders three dots', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pump();

      expect(dotOpacities(tester), hasLength(3));
    });

    testWidgets('the dots pulse out of phase — a wave travelling across '
        'them, not three blinking together', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pump();

      // Sample a few points in the cycle; at no point may all three dots
      // share one opacity, which is what a naive single-animation version
      // would produce.
      for (final step in [0, 150, 300, 450]) {
        await tester.pump(Duration(milliseconds: step));
        final opacities = dotOpacities(tester);
        expect(
          opacities.toSet(),
          hasLength(greaterThan(1)),
          reason: 'all three dots identical at +${step}ms: $opacities',
        );
      }
    });

    testWidgets('every dot stays visible — the wave dims, it never blanks a '
        'dot out of existence', (tester) async {
      await tester.pumpWidget(subject());

      for (var step = 0; step < 6; step++) {
        await tester.pump(const Duration(milliseconds: 200));
        for (final opacity in dotOpacities(tester)) {
          expect(opacity, greaterThanOrEqualTo(0.25));
          expect(opacity, lessThanOrEqualTo(1.0));
        }
      }
    });

    testWidgets('holds still under reduced motion — a perpetual animation '
        'would otherwise pulse for as long as the agent is thinking', (
      tester,
    ) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(subject());
      await tester.pump();
      final first = dotOpacities(tester);

      await tester.pump(const Duration(milliseconds: 600));
      expect(dotOpacities(tester), first);

      // And with the controller parked, the tester can settle.
      await tester.pumpAndSettle();
    });
  });
}
