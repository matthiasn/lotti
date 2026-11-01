import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/events/ui/widgets/event_star_rating.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpRating(
    WidgetTester tester, {
    required double rating,
    ValueChanged<double>? onRatingChanged,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Center(
          child: EventStarRating(
            rating: rating,
            onRatingChanged: onRatingChanged,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The scale each of the five stars currently wears, left to right.
  List<double> starScales(WidgetTester tester) => tester
      .widgetList<AnimatedScale>(find.byType(AnimatedScale))
      .map((scale) => scale.scale)
      .toList();

  /// Clips inside the rating itself — the half star is the only one.
  final starClips = find.descendant(
    of: find.byType(EventStarRating),
    matching: find.byType(ClipRect),
  );

  int glyphCount(IconData icon) => find
      .byWidgetPredicate((w) => w is Icon && w.icon == icon)
      .evaluate()
      .length;

  group('fill', () {
    testWidgets('a whole rating fills that many stars and outlines the rest', (
      tester,
    ) async {
      await pumpRating(tester, rating: 3);

      expect(glyphCount(LottiIconsFilled.star), 3);
      expect(glyphCount(LottiIcons.star), 2);
      expect(starClips, findsNothing);
    });

    testWidgets('a half rating clips one filled star over its outline', (
      tester,
    ) async {
      await pumpRating(tester, rating: 3.5);

      // Three full stars, plus the half star's filled layer.
      expect(glyphCount(LottiIconsFilled.star), 4);
      // The half star's outline, plus the one empty star.
      expect(glyphCount(LottiIcons.star), 2);
      final half = tester.widget<Align>(
        find.descendant(
          of: starClips,
          matching: find.byType(Align),
        ),
      );
      expect(half.widthFactor, 0.5);
      expect(half.alignment, AlignmentDirectional.centerStart);
    });

    testWidgets('zero outlines all five', (tester) async {
      await pumpRating(tester, rating: 0);

      expect(glyphCount(LottiIcons.star), EventStarRating.starCount);
      expect(glyphCount(LottiIconsFilled.star), 0);
    });
  });

  group('setting a rating', () {
    testWidgets('a tap sets the rating to that star', (tester) async {
      final ratings = <double>[];
      await pumpRating(tester, rating: 1, onRatingChanged: ratings.add);

      await tester.tap(find.bySemanticsLabel('Rate 4 of 5 stars'));
      await tester.tap(find.bySemanticsLabel('Rate 1 of 5 stars'));

      expect(ratings, [4.0, 1.0]);
    });

    testWidgets('a long press sets the half below that star', (tester) async {
      final ratings = <double>[];
      await pumpRating(tester, rating: 0, onRatingChanged: ratings.add);

      await tester.longPress(find.bySemanticsLabel('Rate 3 of 5 stars'));

      expect(ratings, [2.5]);
    });

    testWidgets('without a callback the stars are inert and unannounced', (
      tester,
    ) async {
      await pumpRating(tester, rating: 4);

      expect(find.byType(DsQuietInk), findsNothing);
      expect(find.bySemanticsLabel(RegExp('of 5 stars')), findsNothing);
      // Still drawn: the display is read-only, not hidden.
      expect(glyphCount(LottiIconsFilled.star), 4);
    });
  });

  group('hover', () {
    testWidgets('hovering a star lifts that star alone', (tester) async {
      await pumpRating(tester, rating: 2, onRatingChanged: (_) {});
      expect(starScales(tester), [1, 1, 1, 1, 1]);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(
        tester.getCenter(find.bySemanticsLabel('Rate 2 of 5 stars')),
      );
      await tester.pump();

      expect(starScales(tester), [1, EventStarRating.hoverScale, 1, 1, 1]);

      await mouse.moveTo(
        tester.getCenter(find.bySemanticsLabel('Rate 5 of 5 stars')),
      );
      await tester.pump();

      expect(starScales(tester), [1, 1, 1, 1, EventStarRating.hoverScale]);
    });

    testWidgets('the row paints no hover overlay of its own', (tester) async {
      await pumpRating(tester, rating: 2, onRatingChanged: (_) {});

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(
        tester.getCenter(find.bySemanticsLabel('Rate 3 of 5 stars')),
      );
      await tester.pump();

      // Every ink target is a single star with its overlay silenced, so
      // nothing can paint a highlight that spans the row.
      final inks = tester.widgetList<InkWell>(find.byType(InkWell)).toList();
      expect(inks, hasLength(EventStarRating.starCount));
      for (final ink in inks) {
        expect(ink.hoverColor, Colors.transparent);
        expect(ink.customBorder, const CircleBorder());
      }
      final rowWidth = tester.getSize(find.byType(EventStarRating)).width;
      for (final ink in find.byType(InkWell).evaluate()) {
        final size = tester.getSize(find.byWidget(ink.widget));
        expect(size.width, lessThan(rowWidth / 4));
      }
    });

    testWidgets('reduced motion still marks the hovered star, instantly', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Center(
              child: EventStarRating(rating: 0, onRatingChanged: (_) {}),
            ),
          ),
        ),
      );
      await tester.pump();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(
        tester.getCenter(find.bySemanticsLabel('Rate 1 of 5 stars')),
      );
      await tester.pump();

      final scales = tester
          .widgetList<AnimatedScale>(find.byType(AnimatedScale))
          .toList();
      expect(scales.first.scale, EventStarRating.hoverScale);
      expect(scales.first.duration, Duration.zero);
    });
  });
}
