import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/ui/widgets/time_span_bar.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('TimeSpanBar', () {
    testWidgets('renders the start, end and elapsed-duration labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget2(
          const Scaffold(
            body: TimeSpanBar(
              startLabel: '13:00',
              endLabel: '15:30',
              durationLabel: '2h 30m',
            ),
          ),
        ),
      );

      expect(find.text('13:00'), findsOneWidget);
      expect(find.text('15:30'), findsOneWidget);
      expect(find.text('2h 30m'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });
  });
}
