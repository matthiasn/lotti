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

  const title = 'Car & health errands';
  const items = ['Call the dentist', 'Book the car service'];
  const spokenLines = [
    '"remind me to call the dentist"',
    '"and book the car service"',
  ];
  const categoryLabel = 'Personal';

  // The default test font lays out every glyph one em wide, so the centred
  // ghost phrases (plain Text, no wrapping) are far wider than with the real
  // proportional font and would report a harmless horizontal overflow. A small
  // textScaler shrinks them to fit the canvas — a test-font accommodation, not
  // a change to widget behaviour. (Card labels wrap via Expanded regardless.)
  const baseSize = Size(390, 844);
  const fitText = TextScaler.linear(0.5);

  Widget buildHero({
    bool loop = false,
    bool reduceMotion = false,
    List<String> taskItems = items,
    List<String> lines = spokenLines,
    String? category = categoryLabel,
  }) => makeTestableWidget(
    SizedBox(
      width: 360,
      height: 320,
      child: CrystallizeHero(
        accent: accent,
        cardColor: cardColor,
        onCardColor: onCardColor,
        ghostColor: ghostColor,
        title: title,
        items: taskItems,
        spokenLines: lines,
        categoryLabel: category,
        loop: loop,
      ),
    ),
    mediaQueryData: MediaQueryData(
      size: baseSize,
      textScaler: fitText,
      disableAnimations: reduceMotion,
    ),
  );

  Opacity outerOpacityOf(WidgetTester tester, Finder of) =>
      tester.widget<Opacity>(
        find.ancestor(of: of, matching: find.byType(Opacity)).last,
      );

  group('CrystallizeHero', () {
    testWidgets('reduced motion shows the static resolved card', (
      tester,
    ) async {
      await tester.pumpWidget(buildHero(reduceMotion: true));
      await tester.pump();

      // Resolved card fully shown: category pill, title, both items.
      expect(find.text(categoryLabel), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(find.text('Call the dentist'), findsOneWidget);
      expect(find.text('Book the car service'), findsOneWidget);

      // Ghost layer present but fully transparent; card layer fully opaque.
      expect(outerOpacityOf(tester, find.text(spokenLines.first)).opacity, 0.0);
      expect(outerOpacityOf(tester, find.text(title)).opacity, 1.0);

      // Colours reach the rendered widgets.
      final icon = tester.widget<Icon>(find.byIcon(Icons.check_rounded).first);
      expect(icon.color, accent);
      expect(tester.widget<Text>(find.text(title)).style?.color, onCardColor);
      expect(
        tester.widget<Text>(find.text(spokenLines.first)).style?.color,
        ghostColor,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('one-shot reveal plays once and lands on the resolved card', (
      tester,
    ) async {
      await tester.pumpWidget(buildHero());
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Step through the 1800ms reveal (ghost window, card window, title, item
      // appears + ticks) in sub-second steps, asserting no overflow/error.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
      }

      // Resolved: title, both items, both ticks, and the category pill.
      expect(find.text(title), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      expect(find.text(categoryLabel), findsOneWidget);
      // After the one-shot completes the card layer is fully opaque.
      expect(outerOpacityOf(tester, find.text(title)).opacity, 1.0);
    });

    testWidgets('ghost opacity moves across the reveal timeline', (
      tester,
    ) async {
      await tester.pumpWidget(buildHero());
      await tester.pump();

      double ghostOpacity() =>
          outerOpacityOf(tester, find.text(spokenLines.first)).opacity;

      // Near the ghost-window peak.
      await tester.pump(const Duration(milliseconds: 200));
      final early = ghostOpacity();
      // After the ghost window has closed and the card has taken over.
      await tester.pump(const Duration(milliseconds: 1200));
      final later = ghostOpacity();

      expect(early, inInclusiveRange(0.0, 1.0));
      expect(later, inInclusiveRange(0.0, 1.0));
      expect(early, isNot(equals(later)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('loop mode keeps repeating after a full loop elapses', (
      tester,
    ) async {
      await tester.pumpWidget(buildHero(loop: true));
      await tester.pump();

      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(CrystallizeHero), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a title-only card when there are no items', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildHero(reduceMotion: true, taskItems: const [], lines: const []),
      );
      await tester.pump();

      expect(find.text(title), findsOneWidget);
      // No checklist rows means no check icons.
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('omits the category pill when none is provided', (
      tester,
    ) async {
      await tester.pumpWidget(buildHero(reduceMotion: true, category: null));
      await tester.pump();

      expect(find.text(categoryLabel), findsNothing);
      expect(find.text(title), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposes cleanly when removed from the tree', (tester) async {
      await tester.pumpWidget(buildHero());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(makeTestableWidget(const SizedBox()));
      await tester.pump();

      expect(find.byType(CrystallizeHero), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
