import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/events/ui/widgets/event_summary_card.dart';

import '../../test_utils.dart';

void main() {
  group('EventSummaryCard', () {
    testWidgets('packs title, meta, snippet and metric counts', (tester) async {
      await pumpEventComponent(
        tester,
        EventSummaryCard(data: buildEventCardData(coverImage: testImage())),
      );

      expect(find.text("Anna's 30th Birthday"), findsOneWidget);
      // The meta line is a single rich line (category · date).
      expect(find.textContaining('Friends'), findsOneWidget);
      expect(find.textContaining('Sat, 12 May'), findsOneWidget);
      expect(find.text('A surprise rooftop party.'), findsOneWidget);
      // Rating star + one-decimal value (top-right), then the contents counts
      // as icon + localized word.
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.text('5.0'), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);
      expect(find.text('24 photos'), findsOneWidget);
      expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
      expect(find.text('2 tasks'), findsOneWidget);
    });

    testWidgets('hides the status for a completed event', (tester) async {
      await pumpEventComponent(
        tester,
        EventSummaryCard(data: buildEventCardData(coverImage: testImage())),
      );
      expect(find.text('Completed'), findsNothing);
    });

    testWidgets('surfaces the status for a not-completed event', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        EventSummaryCard(
          data: buildEventCardData(
            status: EventStatus.planned,
            stars: 0,
            coverImage: testImage(),
          ),
        ),
      );
      expect(find.textContaining('Planned'), findsOneWidget);
      // A not-yet-happened, unrated event shows no rating metric, but its
      // prep-task count still surfaces.
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      // The prep-task count still surfaces for an upcoming event.
      expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
      expect(find.text('2 tasks'), findsOneWidget);
    });

    testWidgets('shows no rating for a completed but unrated event', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        EventSummaryCard(
          data: buildEventCardData(stars: 0, coverImage: testImage()),
        ),
      );
      // A completed event with no rating must not read as "rated 0".
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('shows a half-star rating label', (tester) async {
      await pumpEventComponent(
        tester,
        EventSummaryCard(data: buildEventCardData(stars: 4.5)),
      );
      expect(find.text('4.5'), findsOneWidget);
    });

    testWidgets('uses localized singular/plural count words', (tester) async {
      await pumpEventComponent(
        tester,
        EventSummaryCard(
          data: buildEventCardData(photoCount: 1, taskCount: 24),
        ),
      );
      expect(find.text('1 photo'), findsOneWidget);
      expect(find.text('24 tasks'), findsOneWidget);
    });

    testWidgets('omits the metric row when there is nothing to show', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        EventSummaryCard(
          data: buildEventCardData(
            status: EventStatus.planned,
            stars: 0,
            photoCount: 0,
            taskCount: 0,
          ),
        ),
      );
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.photo_library_rounded), findsNothing);
      expect(find.byIcon(Icons.task_alt_rounded), findsNothing);
    });

    testWidgets('falls back to the category glyph when there is no cover', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        EventSummaryCard(data: buildEventCardData()),
      );
      // No cover image → EventCoverImage renders its fallback glyph.
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
    });

    testWidgets('is tappable', (tester) async {
      var taps = 0;
      await pumpEventComponent(
        tester,
        EventSummaryCard(
          data: buildEventCardData(coverImage: testImage()),
          onTap: () => taps++,
        ),
      );
      await tester.tap(find.byType(EventSummaryCard));
      expect(taps, 1);
    });
  });
}
