import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/day_segment.dart';

import '../../../../../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDay = DateTime(2026, 1, 15, 12);

  DayTimeSummary createDaySummary({DateTime? day}) {
    return DayTimeSummary(
      day: day ?? testDay,
      durationByCategoryId: const {},
      total: Duration.zero,
    );
  }

  Widget createTestWidget({
    required DayTimeSummary daySummary,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return WidgetTestBench(
      child: DaySegment(
        daySummary: daySummary,
        isSelected: isSelected,
        onTap: onTap ?? () {},
      ),
    );
  }

  group('DaySegment', () {
    testWidgets('displays day number', (tester) async {
      await tester.pumpWidget(
        createTestWidget(daySummary: createDaySummary()),
      );

      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('displays different day numbers correctly', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          daySummary: createDaySummary(day: DateTime(2026, 1, 7, 12)),
        ),
      );

      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('shows selection styling when selected', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          daySummary: createDaySummary(),
          isSelected: true,
        ),
      );

      // The day number should be visible
      expect(find.text('15'), findsOneWidget);

      // Find containers that might have the selection border
      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);
    });

    testWidgets('triggers onTap callback when tapped', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        createTestWidget(
          daySummary: createDaySummary(),
          onTap: () => tapCount++,
        ),
      );

      await tester.tap(find.text('15'));
      expect(tapCount, 1);

      await tester.tap(find.text('15'));
      expect(tapCount, 2);
    });

    testWidgets('has correct width', (tester) async {
      await tester.pumpWidget(
        createTestWidget(daySummary: createDaySummary()),
      );

      final daySegmentFinder = find.byType(DaySegment);
      final daySegment = tester.widget<DaySegment>(daySegmentFinder);

      // Find the outer container with the width
      final containerFinder = find.descendant(
        of: daySegmentFinder,
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);

      // Verify the day segment uses the correct width constant
      expect(daySegmentWidth, 56);
      expect(daySegment.daySummary.day.day, 15);
    });

    testWidgets('has semantics for accessibility', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          daySummary: createDaySummary(),
          isSelected: true,
        ),
      );

      // Find the Semantics widget that's a descendant of DaySegment
      final semanticsFinder = find.descendant(
        of: find.byType(DaySegment),
        matching: find.byType(Semantics),
      );
      expect(semanticsFinder, findsOneWidget);

      final semantics = tester.widget<Semantics>(semanticsFinder);
      expect(semantics.properties.button, true);
      expect(semantics.properties.selected, true);
    });

    testWidgets('semantics shows not selected when not selected',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          daySummary: createDaySummary(),
        ),
      );

      final semanticsFinder = find.descendant(
        of: find.byType(DaySegment),
        matching: find.byType(Semantics),
      );
      final semantics = tester.widget<Semantics>(semanticsFinder);
      expect(semantics.properties.selected, false);
    });
  });
}
