import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/events/ui/widgets/event_cover_image.dart';

import '../../test_utils.dart';

/// An [ImageProvider] whose load fails immediately, to exercise the cover
/// image's error fallback.
class _BrokenImage extends ImageProvider<_BrokenImage> {
  @override
  Future<_BrokenImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_BrokenImage>(this);

  @override
  ImageStreamCompleter loadImage(
    _BrokenImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(Future<ImageInfo>.error('broken'));
}

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

    testWidgets('maps cropX to the cover image alignment', (tester) async {
      await pumpEventComponent(
        tester,
        EventCoverImage(
          image: testImage(),
          fallbackColor: Colors.blue,
          cropX: 0.25,
        ),
        height: 120,
      );

      final image = tester.widget<Image>(find.byType(Image));
      // alignmentX = cropX * 2 - 1
      expect(image.alignment, const Alignment(-0.5, 0));
      expect(image.fit, BoxFit.cover);
    });

    testWidgets('clamps out-of-range cropX before computing alignment', (
      tester,
    ) async {
      // Malformed crop data must not push alignment beyond the [-1, 1] span.
      for (final (cropX, expected) in [(1.8, 1.0), (-0.5, -1.0)]) {
        await pumpEventComponent(
          tester,
          EventCoverImage(
            image: testImage(),
            fallbackColor: Colors.blue,
            cropX: cropX,
          ),
          height: 120,
        );
        final image = tester.widget<Image>(find.byType(Image));
        expect(
          image.alignment,
          Alignment(expected, 0),
          reason: 'cropX=$cropX',
        );
      }
    });

    testWidgets('falls back to the gradient when the image fails to load', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        EventCoverImage(image: _BrokenImage(), fallbackColor: Colors.blue),
        height: 120,
      );
      await tester.pump();

      // The error builder swaps the failed image for the fallback glyph.
      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
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
