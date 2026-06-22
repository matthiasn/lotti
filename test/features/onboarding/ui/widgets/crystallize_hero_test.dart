import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/onboarding/ui/widgets/crystallize_hero.dart';

import '../../../../widget_test_utils.dart';

void main() {
  // Distinct colours so we can assert they reach the rendered widgets.
  const accent = Color(0xFF00C2A8);
  const cardColor = Color(0xFFF5F5F5);
  const onCardColor = Color(0xFF1A1A1A);
  const ghostColor = Color(0xFF9E9E9E);

  // The hero contains a fixed-width 260px card whose checklist rows lay out
  // their label at the text's natural width. Under the default test font
  // (every glyph is one em wide) the labels are far wider than with the real
  // proportional font, so each checklist Row would report a harmless
  // horizontal overflow. We shrink text with a small textScaler so the
  // labels fit the fixed card and no overflow is reported — this is a
  // test-font accommodation, not a change to widget behaviour.
  const baseSize = Size(390, 844);
  const fitText = TextScaler.linear(0.5);

  Widget buildHero({MediaQueryData? mediaQueryData}) => makeTestableWidget(
    const SizedBox(
      width: 360,
      height: 264,
      child: CrystallizeHero(
        accent: accent,
        cardColor: cardColor,
        onCardColor: onCardColor,
        ghostColor: ghostColor,
      ),
    ),
    mediaQueryData:
        mediaQueryData ??
        const MediaQueryData(size: baseSize, textScaler: fitText),
  );

  group('CrystallizeHero', () {
    testWidgets(
      'reduced motion shows the static resolved card with title and items',
      (tester) async {
        await tester.pumpWidget(
          buildHero(
            mediaQueryData: const MediaQueryData(
              size: baseSize,
              textScaler: fitText,
              disableAnimations: true,
            ),
          ),
        );
        // Static path: the tree settles because the controller is stopped.
        await tester.pump();

        expect(find.byType(CrystallizeHero), findsOneWidget);
        // Resolved card is fully shown in reduced motion: title + both items.
        expect(find.text('Car & health errands'), findsOneWidget);
        expect(find.text('Call the dentist'), findsOneWidget);
        expect(find.text('Book car service'), findsOneWidget);
        // Ghost phrases exist in the tree but at zero opacity.
        expect(find.text('"remind me to call the dentist"'), findsOneWidget);
        expect(find.text('"and book the car service"'), findsOneWidget);

        // Ghost layer fully transparent in reduced motion.
        final ghostOpacity = tester.widget<Opacity>(
          find
              .ancestor(
                of: find.text('"remind me to call the dentist"'),
                matching: find.byType(Opacity),
              )
              .last,
        );
        expect(ghostOpacity.opacity, 0.0);

        // Card layer fully opaque in reduced motion.
        final cardOpacity = tester.widget<Opacity>(
          find
              .ancestor(
                of: find.text('Car & health errands'),
                matching: find.byType(Opacity),
              )
              .last,
        );
        expect(cardOpacity.opacity, 1.0);

        // The accent colour reaches the check icons.
        final icon = tester.widget<Icon>(find.byType(Icon).first);
        expect(icon.color, accent);
        expect(icon.icon, Icons.check_rounded);

        // Title uses the onCard colour.
        final title = tester.widget<Text>(find.text('Car & health errands'));
        expect(title.style?.color, onCardColor);

        // Ghost phrase uses the ghost colour.
        final ghost = tester.widget<Text>(
          find.text('"remind me to call the dentist"'),
        );
        expect(ghost.style?.color, ghostColor);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'animated mode advances across timeline phases without error',
      (tester) async {
        await tester.pumpWidget(
          buildHero(
            mediaQueryData: const MediaQueryData(
              size: baseSize,
              textScaler: fitText,
            ),
          ),
        );
        // First frame of the repeating animation.
        await tester.pump();
        expect(find.byType(CrystallizeHero), findsOneWidget);
        expect(tester.takeException(), isNull);

        // The loop is 6s. Step through it so the build runs across the ghost
        // window, card window, title-in, item appear and tick segments.
        // 400ms steps stay under the 1s/pump guidance while sampling many
        // distinct timeline values across the full loop.
        for (var i = 0; i < 16; i++) {
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
        }

        // Content widgets are still present after advancing the controller.
        expect(find.text('Car & health errands'), findsOneWidget);
        expect(find.text('Call the dentist'), findsOneWidget);
        expect(find.text('Book car service'), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      },
    );

    testWidgets('animated mode keeps repeating after a full loop elapses', (
      tester,
    ) async {
      await tester.pumpWidget(buildHero());
      await tester.pump();

      // Advance well past one 6s loop to exercise the repeat() restart.
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(CrystallizeHero), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'ghost layer opacity changes between early and later animated frames',
      (tester) async {
        await tester.pumpWidget(buildHero());
        await tester.pump();

        double ghostOpacityNow() => tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.text('"remind me to call the dentist"'),
                    matching: find.byType(Opacity),
                  )
                  .last,
            )
            .opacity;

        // Sample opacity near the start of the loop (ghost fading in/holding).
        await tester.pump(const Duration(milliseconds: 600));
        final early = ghostOpacityNow();

        // Sample later in the loop, after the ghost window has closed and the
        // card window is active (ghost should have faded back out).
        await tester.pump(const Duration(milliseconds: 3000));
        final later = ghostOpacityNow();

        // Both are valid opacities and the value moved across the timeline,
        // proving the animation actually drives the windowed opacities.
        expect(early, inInclusiveRange(0.0, 1.0));
        expect(later, inInclusiveRange(0.0, 1.0));
        expect(early, isNot(equals(later)));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('disposes cleanly when removed from the tree', (tester) async {
      await tester.pumpWidget(buildHero());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);

      // Replace with an empty tree to trigger State.dispose().
      await tester.pumpWidget(makeTestableWidget(const SizedBox()));
      await tester.pump();

      expect(find.byType(CrystallizeHero), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
