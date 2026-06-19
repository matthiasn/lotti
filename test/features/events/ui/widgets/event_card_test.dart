import 'package:flutter/material.dart';
import 'package:flutter_rating/flutter_rating.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/events/ui/widgets/event_card.dart';
import 'package:lotti/features/events/ui/widgets/event_cover_image.dart';

import '../../test_utils.dart';

void main() {
  group('EventCard content', () {
    testWidgets('renders title, date, location and summary', (tester) async {
      await pumpEventComponent(
        tester,
        EventCard(data: buildEventCardData(coverImage: testImage())),
      );

      expect(find.text("Anna's 30th Birthday"), findsOneWidget);
      expect(find.textContaining('Sat, 12 May'), findsOneWidget);
      expect(find.text('Rooftop Bar'), findsOneWidget);
      expect(find.text('A surprise rooftop party.'), findsOneWidget);
    });

    testWidgets('omits summary and location when absent', (tester) async {
      await pumpEventComponent(
        tester,
        EventCard(
          data: buildEventCardData(
            coverImage: testImage(),
            summary: null,
            location: null,
          ),
        ),
      );

      expect(find.text('A surprise rooftop party.'), findsNothing);
      expect(find.byIcon(Icons.place_outlined), findsNothing);
    });

    testWidgets('shows the rating + counts in the footer for a rated event', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        EventCard(data: buildEventCardData(coverImage: testImage())),
      );

      expect(find.byType(StarRating), findsOneWidget);
      expect(find.text('24'), findsOneWidget); // photoCount
      expect(find.text('2'), findsOneWidget); // taskCount
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets(
      'shows a status label for a non-completed, non-upcoming event',
      (
        tester,
      ) async {
        await pumpEventComponent(
          tester,
          EventCard(
            data: buildEventCardData(
              status: EventStatus.ongoing,
              stars: 0,
              coverImage: testImage(),
            ),
          ),
        );

        expect(find.text('Ongoing'), findsOneWidget);
        expect(find.byType(StarRating), findsNothing); // stars == 0
      },
    );

    testWidgets('upcoming event shows neither rating nor status in footer', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        EventCard(
          data: buildEventCardData(
            status: EventStatus.planned,
            stars: 0,
            photoCount: 0,
            coverImage: testImage(),
          ),
        ),
      );

      expect(find.byType(StarRating), findsNothing);
      expect(find.text('Planned'), findsNothing);
    });

    testWidgets('falls back to a glyph cover when no image', (tester) async {
      await pumpEventComponent(
        tester,
        EventCard(data: buildEventCardData()),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
    });

    testWidgets('category name renders as an overlay pill', (tester) async {
      await pumpEventComponent(
        tester,
        EventCard(
          data: buildEventCardData(coverImage: testImage()),
        ),
      );
      expect(find.text('Friends'), findsOneWidget);

      await pumpEventComponent(
        tester,
        EventCard(
          data: buildEventCardData(coverImage: testImage(), categoryName: null),
        ),
      );
      expect(find.text('Friends'), findsNothing);
    });

    testWidgets('uses the provided cover aspect ratio', (tester) async {
      await pumpEventComponent(
        tester,
        EventCard(
          data: buildEventCardData(coverImage: testImage()),
          coverAspect: 16 / 9,
        ),
      );
      final aspect = tester.widget<AspectRatio>(
        find.descendant(
          of: find.byType(EventCard),
          matching: find.byType(AspectRatio),
        ),
      );
      expect(aspect.aspectRatio, 16 / 9);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var tapped = false;
      await pumpEventComponent(
        tester,
        EventCard(
          data: buildEventCardData(coverImage: testImage()),
          onTap: () => tapped = true,
        ),
      );
      await tester.tap(find.text("Anna's 30th Birthday"));
      expect(tapped, isTrue);
    });
  });

  group('EventCoverOverlay', () {
    testWidgets('renders the category pill over the cover', (tester) async {
      await pumpEventComponent(
        tester,
        EventCoverImage(
          image: testImage(),
          fallbackColor: eventPink,
          child: EventCoverOverlay(
            data: buildEventCardData(coverImage: testImage()),
          ),
        ),
        height: 200,
      );
      expect(find.text('Friends'), findsOneWidget);
    });
  });
}
