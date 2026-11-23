import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:material_ui/material_ui.dart';

import '../widget_test_utils.dart';

void main() {
  group('EventStatusX.localizedLabel', () {
    testWidgets('returns the English label for every status', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        makeTestableWidget2(
          Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        {
          for (final status in EventStatus.values)
            status: status.localizedLabel(ctx),
        },
        {
          EventStatus.tentative: 'Tentative',
          EventStatus.planned: 'Planned',
          EventStatus.ongoing: 'Ongoing',
          EventStatus.completed: 'Completed',
          EventStatus.cancelled: 'Cancelled',
          EventStatus.postponed: 'Postponed',
          EventStatus.rescheduled: 'Rescheduled',
          EventStatus.missed: 'Missed',
        },
      );
    });

    testWidgets('gives every status a distinct label', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        makeTestableWidget2(
          Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      final labels = EventStatus.values.map((s) => s.localizedLabel(ctx));
      expect(labels.toSet(), hasLength(EventStatus.values.length));
    });
  });
}
