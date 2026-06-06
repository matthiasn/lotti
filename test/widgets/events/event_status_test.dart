import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/widgets/events/event_status.dart';

import '../../widget_test_utils.dart';

void main() {
  group('EventStatusWidget', () {
    // One parameterized loop covers every EventStatus variant: label text
    // and status-colored background (alpha 153) per variant.
    for (final status in EventStatus.values) {
      testWidgets('renders label and background color for $status', (
        tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(EventStatusWidget(status)),
        );

        expect(find.text(status.label), findsOneWidget);

        final chip = tester.widget<Chip>(find.byType(Chip));
        expect(chip.backgroundColor, status.color.withAlpha(153));
        expect(chip.visualDensity, VisualDensity.compact);
      });
    }
  });
}
