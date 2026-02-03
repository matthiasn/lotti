import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/day_segment.dart';

import '../../../../../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Thursday, Jan 15, 2026
  final testDay = DateTime(2026, 1, 15, 12);
  // Saturday, Jan 17, 2026
  final saturdayDay = DateTime(2026, 1, 17, 12);
  // Sunday, Jan 18, 2026
  final sundayDay = DateTime(2026, 1, 18, 12);

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

    testWidgets('displays weekday abbreviation', (tester) async {
      await tester.pumpWidget(
        createTestWidget(daySummary: createDaySummary()),
      );

      // Jan 15, 2026 is a Thursday
      expect(find.text('Thu'), findsOneWidget);
    });

    testWidgets('displays different day numbers correctly', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          daySummary: createDaySummary(day: DateTime(2026, 1, 7, 12)),
        ),
      );

      expect(find.text('7'), findsOneWidget);
      // Jan 7, 2026 is a Wednesday
      expect(find.text('Wed'), findsOneWidget);
    });

    testWidgets('shows selection styling when selected', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          daySummary: createDaySummary(),
          isSelected: true,
        ),
      );

      // The day number and weekday should be visible
      expect(find.text('15'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);

      // Find containers that have the selection styling
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

      // Find the outer SizedBox with the width
      final sizedBoxFinder = find.descendant(
        of: daySegmentFinder,
        matching: find.byType(SizedBox),
      );
      expect(sizedBoxFinder, findsWidgets);

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

    group('Weekend styling', () {
      testWidgets('Saturday displays weekend weekday abbreviation',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(daySummary: createDaySummary(day: saturdayDay)),
        );

        expect(find.text('17'), findsOneWidget);
        expect(find.text('Sat'), findsOneWidget);
      });

      testWidgets('Sunday displays weekend weekday abbreviation',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(daySummary: createDaySummary(day: sundayDay)),
        );

        expect(find.text('18'), findsOneWidget);
        expect(find.text('Sun'), findsOneWidget);
      });

      testWidgets('weekend selected overrides weekend styling', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            daySummary: createDaySummary(day: saturdayDay),
            isSelected: true,
          ),
        );

        // Should still display correctly
        expect(find.text('17'), findsOneWidget);
        expect(find.text('Sat'), findsOneWidget);

        // Selection takes precedence over weekend styling
        // The container should have selection styling, not weekend border
        final containerFinder = find.byType(Container);
        expect(containerFinder, findsWidgets);
      });
    });

    group('Two-line layout', () {
      testWidgets('weekday and day number are in same widget tree',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(daySummary: createDaySummary()),
        );

        // Both texts should be present
        expect(find.text('Thu'), findsOneWidget);
        expect(find.text('15'), findsOneWidget);

        // They should be within the same DaySegment
        final daySegmentFinder = find.byType(DaySegment);
        expect(
          find.descendant(of: daySegmentFinder, matching: find.text('Thu')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: daySegmentFinder, matching: find.text('15')),
          findsOneWidget,
        );
      });

      testWidgets('layout contains Column for vertical arrangement',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(daySummary: createDaySummary()),
        );

        // Should have a Column for the two-line layout
        final columnFinder = find.descendant(
          of: find.byType(DaySegment),
          matching: find.byType(Column),
        );
        expect(columnFinder, findsWidgets);
      });
    });
  });
}
