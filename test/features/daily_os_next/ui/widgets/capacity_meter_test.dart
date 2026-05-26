import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/capacity_meter.dart';

import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child) => makeTestableWidget2(
  child,
  mediaQueryData: const MediaQueryData(size: Size(400, 400)),
);

void main() {
  group('CapacityMeter', () {
    testWidgets('renders a linear progress value from scheduled capacity', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Material(
            child: CapacityMeter(scheduledMinutes: 315, capacityMinutes: 480),
          ),
        ),
      );
      await tester.pump();

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(315 / 480, 0.001));
    });

    testWidgets('clamps over-capacity progress to a full bar', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Material(
            child: CapacityMeter(scheduledMinutes: 540, capacityMinutes: 480),
          ),
        ),
      );
      await tester.pump();

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 1);
    });
  });
}
