import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/events/ui/widgets/event_cover_image.dart';

import '../../test_utils.dart';

void main() {
  group('EventCoverImage', () {
    testWidgets('renders the image when one is provided', (tester) async {
      await pumpEventComponent(
        tester,
        EventCoverImage(image: testImage(), fallbackColor: Colors.blue),
        height: 120,
      );

      expect(find.byType(Image), findsOneWidget);
      // No fallback glyph when a real image is present.
      expect(find.byIcon(Icons.event_rounded), findsNothing);
    });

    testWidgets('renders a fallback glyph + gradient when image is null', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        const EventCoverImage(image: null, fallbackColor: Colors.blue),
        height: 120,
      );

      expect(find.byType(Image), findsNothing);
      // The default fallback glyph.
      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
    });

    testWidgets('maps cropX to the FittedBox horizontal alignment', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        EventCoverImage(
          image: testImage(),
          fallbackColor: Colors.blue,
          cropX: 0.25,
        ),
        height: 120,
      );

      final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
      // alignmentX = cropX * 2 - 1
      expect(fittedBox.alignment, const Alignment(-0.5, 0));
      expect(fittedBox.fit, BoxFit.cover);
    });

    testWidgets('hero scrim adds the global darken + two gradients', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        EventCoverImage(
          image: testImage(),
          fallbackColor: Colors.blue,
          scrim: EventCoverScrim.hero,
        ),
        height: 200,
      );
      final inCover = find.byType(EventCoverImage);
      // The hero variant paints a full ColoredBox darken + top & bottom
      // gradient DecoratedBoxes.
      expect(
        find.descendant(of: inCover, matching: find.byType(ColoredBox)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: inCover, matching: find.byType(DecoratedBox)),
        findsNWidgets(2),
      );
    });

    testWidgets('card scrim paints a single gradient over the image', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        EventCoverImage(image: testImage(), fallbackColor: Colors.blue),
        height: 120,
      );
      expect(
        find.descendant(
          of: find.byType(EventCoverImage),
          matching: find.byType(DecoratedBox),
        ),
        findsOneWidget,
      );
    });

    testWidgets('none scrim paints no gradient/darken over the image', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        EventCoverImage(
          image: testImage(),
          fallbackColor: Colors.blue,
          scrim: EventCoverScrim.none,
        ),
        height: 120,
      );
      final inCover = find.byType(EventCoverImage);
      expect(
        find.descendant(of: inCover, matching: find.byType(ColoredBox)),
        findsNothing,
      );
      expect(
        find.descendant(of: inCover, matching: find.byType(DecoratedBox)),
        findsNothing,
      );
    });

    testWidgets('renders overlay child on top of the cover', (tester) async {
      await pumpEventComponent(
        tester,
        EventCoverImage(
          image: testImage(),
          fallbackColor: Colors.blue,
          child: const Text('overlay'),
        ),
        height: 120,
      );
      expect(find.text('overlay'), findsOneWidget);
    });
  });
}
