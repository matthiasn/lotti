import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/hold_to_confirm.dart';

import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child) => makeTestableWidget2(
  child,
  mediaQueryData: const MediaQueryData(size: Size(600, 600)),
);

void main() {
  group('HoldToConfirm', () {
    testWidgets('fires onConfirmed once after the full hold duration', (
      tester,
    ) async {
      var fires = 0;
      await tester.pumpWidget(
        _wrap(
          Material(
            child: Center(
              child: HoldToConfirm(
                onConfirmed: () => fires++,
                holdDuration: const Duration(milliseconds: 200),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Touch-down starts the fill.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToConfirm)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(fires, 0);

      // Hold for the full duration → onConfirmed fires exactly once.
      await tester.pump(const Duration(milliseconds: 220));
      await gesture.up();
      await tester.pump();
      expect(fires, 1);

      // Repeated taps after completion are ignored.
      final second = await tester.startGesture(
        tester.getCenter(find.byType(HoldToConfirm)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await second.up();
      expect(fires, 1);
    });

    testWidgets('releasing before completion bleeds off — no fire', (
      tester,
    ) async {
      var fires = 0;
      await tester.pumpWidget(
        _wrap(
          Material(
            child: Center(
              child: HoldToConfirm(
                onConfirmed: () => fires++,
                holdDuration: const Duration(milliseconds: 400),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToConfirm)),
      );
      // Release after only ~25% of the hold duration.
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      // Let the reverse animation drain.
      await tester.pump(const Duration(milliseconds: 500));
      expect(fires, 0);
    });
  });
}
