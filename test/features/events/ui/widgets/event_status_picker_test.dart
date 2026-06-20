import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/features/events/ui/widgets/event_status_picker.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('eventStatusLabel', () {
    test('capitalizes the all-caps status label', () {
      expect(eventStatusLabel(EventStatus.tentative), 'Tentative');
      expect(eventStatusLabel(EventStatus.completed), 'Completed');
      expect(eventStatusLabel(EventStatus.rescheduled), 'Rescheduled');
    });
  });

  group('showEventStatusPicker', () {
    Widget opener(EventStatus current, void Function(EventStatus?) onResult) {
      return makeTestableWidget2(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                onResult(
                  await showEventStatusPicker(
                    context: context,
                    current: current,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
    }

    testWidgets('lists every status and returns the tapped one', (
      tester,
    ) async {
      EventStatus? picked;
      var called = false;
      await tester.pumpWidget(
        opener(EventStatus.tentative, (r) {
          picked = r;
          called = true;
        }),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Every status renders as a row.
      for (final status in EventStatus.values) {
        expect(find.text(eventStatusLabel(status)), findsWidgets);
      }

      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      expect(called, isTrue);
      expect(picked, EventStatus.completed);
    });

    testWidgets('marks the current status with a check', (tester) async {
      await tester.pumpWidget(opener(EventStatus.ongoing, (_) {}));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });
}
