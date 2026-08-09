import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_typing_indicator.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

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
  // Reduced motion is read through `MediaQuery.disableAnimationsOf`, so the
  // tests drive it the way the widget actually observes it — a rebuild with a
  // different MediaQuery is exactly what an OS toggle produces.
  Widget subject({bool reduceMotion = false}) => makeTestableWidgetNoScroll(
    const Center(child: EvolutionTypingIndicator()),
    mediaQueryData: MediaQueryData(disableAnimations: reduceMotion),
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

    testWidgets('announces itself to assistive technology, and hides the '
        'decorative dots from it', (tester) async {
      await tester.pumpWidget(subject());
      await tester.pump();

      final context = tester.element(find.byType(EvolutionTypingIndicator));
      final handle = tester.ensureSemantics();

      // Without this a screen reader hears nothing at all between sending a
      // message and the reply arriving, with the composer disabled meanwhile.
      final node = tester.getSemantics(
        find.byType(EvolutionTypingIndicator).first,
      );
      expect(node.label, context.messages.agentRitualTypingSemantics);
      expect(node.flagsCollection.isLiveRegion, isTrue);

      // The dots themselves are decorative and must not be announced.
      expect(node.childrenCount, 0);

      handle.dispose();
    });

    testWidgets('starts pulsing when reduced motion is switched off while it '
        'is on screen — a model can compose for minutes', (tester) async {
      await tester.pumpWidget(subject(reduceMotion: true));
      await tester.pump();
      final parked = dotOpacities(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(dotOpacities(tester), parked);

      await tester.pumpWidget(subject());
      await tester.pump(const Duration(milliseconds: 300));

      expect(dotOpacities(tester), isNot(parked));
    });

    testWidgets('stops when reduced motion is switched on mid-response — '
        'sampling the flag once at mount would pulse on regardless', (
      tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(subject(reduceMotion: true));
      await tester.pump();
      final parked = dotOpacities(tester);
      await tester.pump(const Duration(milliseconds: 600));

      expect(dotOpacities(tester), parked);
      await tester.pumpAndSettle();
    });

    testWidgets('holds still under reduced motion — a perpetual animation '
        'would otherwise pulse for as long as the agent is thinking', (
      tester,
    ) async {
      await tester.pumpWidget(subject(reduceMotion: true));
      await tester.pump();
      final first = dotOpacities(tester);

      await tester.pump(const Duration(milliseconds: 600));
      expect(dotOpacities(tester), first);

      // And with the controller parked, the tester can settle.
      await tester.pumpAndSettle();
    });
  });
}
