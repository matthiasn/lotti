import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/capacity_donut.dart';

import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child) => makeTestableWidget2(
  child,
  mediaQueryData: const MediaQueryData(size: Size(400, 400)),
);

void main() {
  group('CapacityDonut', () {
    testWidgets('renders the scheduled hours plus the of-capacity label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Material(
            child: CapacityDonut(scheduledMinutes: 315, capacityMinutes: 480),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('5h15m'), findsOneWidget);
      expect(find.text('of 8h'), findsOneWidget);
    });

    testWidgets('renders 0 hours as 0h', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Material(
            child: CapacityDonut(scheduledMinutes: 0, capacityMinutes: 480),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('0h'), findsOneWidget);
    });
  });
}
