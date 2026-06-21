import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/events/ui/widgets/event_card.dart';
import 'package:lotti/features/events/ui/widgets/event_feature_card.dart';

import '../../test_utils.dart';

void main() {
  group('EventFeatureCard', () {
    testWidgets('renders a wide hero banner at desktop widths', (tester) async {
      await pumpEventComponent(
        tester,
        width: 720,
        EventFeatureCard(
          data: buildEventCardData(
            title: 'Marathon 2026',
            status: EventStatus.planned,
            stars: 0,
            coverImage: testImage(),
          ),
        ),
      );

      // Wide layout uses the hero banner — no nested vertical EventCard.
      expect(find.byType(EventCard), findsNothing);
      final title = tester.widget<Text>(find.text('Marathon 2026'));
      final ctx = tester.element(find.text('Marathon 2026'));
      // Title uses the larger heading2 style in the banner.
      expect(
        title.style?.fontSize,
        ctx.designTokens.typography.styles.heading.heading2.fontSize,
      );
      expect(find.text('A surprise rooftop party.'), findsOneWidget);
    });

    testWidgets('degrades to a vertical EventCard on phone widths', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        EventFeatureCard(data: buildEventCardData(coverImage: testImage())),
      );

      expect(find.byType(EventCard), findsOneWidget);
      final aspect = tester.widget<AspectRatio>(
        find.descendant(
          of: find.byType(EventCard),
          matching: find.byType(AspectRatio),
        ),
      );
      // Phone featured fallback uses the shorter 16:9 cover.
      expect(aspect.aspectRatio, 16 / 9);
    });

    testWidgets('invokes onTap in both layouts', (tester) async {
      var wideTaps = 0;
      await pumpEventComponent(
        tester,
        width: 720,
        EventFeatureCard(
          data: buildEventCardData(coverImage: testImage()),
          onTap: () => wideTaps++,
        ),
      );
      await tester.tap(find.text("Anna's 30th Birthday"));
      expect(wideTaps, 1);

      var narrowTaps = 0;
      await pumpEventComponent(
        tester,
        EventFeatureCard(
          data: buildEventCardData(coverImage: testImage()),
          onTap: () => narrowTaps++,
        ),
      );
      await tester.tap(find.text("Anna's 30th Birthday"));
      expect(narrowTaps, 1);
    });
  });
}
