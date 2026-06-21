import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/events/ui/widgets/event_overlay_pill.dart';

import '../../test_utils.dart';

void main() {
  group('EventOverlayPill', () {
    testWidgets('shows a colour dot + label when dotColor is set', (
      tester,
    ) async {
      await pumpEventComponent(
        tester,
        const EventOverlayPill(label: 'Friends', dotColor: Colors.pink),
      );

      expect(find.text('Friends'), findsOneWidget);
      // The pill container + the colour dot container.
      expect(
        find.descendant(
          of: find.byType(EventOverlayPill),
          matching: find.byType(Container),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('shows only the label when no dotColor', (tester) async {
      await pumpEventComponent(
        tester,
        const EventOverlayPill(label: 'in 8 weeks'),
      );

      expect(find.text('in 8 weeks'), findsOneWidget);
      // Just the pill container, no dot.
      expect(
        find.descendant(
          of: find.byType(EventOverlayPill),
          matching: find.byType(Container),
        ),
        findsOneWidget,
      );
    });
  });
}
