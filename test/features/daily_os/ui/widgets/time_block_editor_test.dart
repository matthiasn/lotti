import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_block_editor.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_time_picker.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';

import '../../../../widget_test_utils.dart';

void main() {
  final testDate = DateTime(2026, 3, 15);
  final testBlock = PlannedBlock(
    id: 'block-1',
    categoryId: 'cat-work',
    startTime: DateTime(2026, 3, 15, 9),
    endTime: DateTime(2026, 3, 15, 12),
  );

  Future<void> pumpEditor(
    WidgetTester tester, {
    PlannedBlock? block,
    ValueChanged<PlannedBlock>? onChanged,
    VoidCallback? onDelete,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SizedBox(
          width: 400,
          child: TimeBlockEditor(
            block: block ?? testBlock,
            planDate: testDate,
            onChanged: onChanged ?? (_) {},
            onDelete: onDelete ?? () {},
          ),
        ),
        theme: DesignSystemTheme.light(),
      ),
    );
  }

  group('TimeBlockEditor', () {
    testWidgets('renders start and end time labels', (tester) async {
      await pumpEditor(tester);

      expect(find.text('9:00 AM'), findsOneWidget);
      expect(find.text('12:00 PM'), findsOneWidget);
    });

    testWidgets('renders dash separator and outer time container', (
      tester,
    ) async {
      await pumpEditor(tester);

      expect(find.text('-'), findsOneWidget);
      // Schedule icon removed to match Figma design
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    });

    testWidgets('renders delete button', (tester) async {
      await pumpEditor(tester);

      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('calls onDelete when delete button tapped', (tester) async {
      var deleted = false;
      await pumpEditor(tester, onDelete: () => deleted = true);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pump();

      expect(deleted, isTrue);
    });

    testWidgets('no time picker visible initially', (tester) async {
      await pumpEditor(tester);

      expect(find.byType(DesignSystemTimePicker), findsNothing);
    });

    testWidgets('tapping start time shows time picker', (tester) async {
      await pumpEditor(tester);

      await tester.tap(find.text('9:00 AM'));
      await tester.pumpAndSettle();

      expect(find.byType(DesignSystemTimePicker), findsOneWidget);
    });

    testWidgets('tapping end time shows time picker', (tester) async {
      await pumpEditor(tester);

      await tester.tap(find.text('12:00 PM'));
      await tester.pumpAndSettle();

      expect(find.byType(DesignSystemTimePicker), findsOneWidget);
    });

    testWidgets('tapping active start time again hides picker', (
      tester,
    ) async {
      await pumpEditor(tester);

      // Open
      await tester.tap(find.text('9:00 AM'));
      await tester.pumpAndSettle();
      expect(find.byType(DesignSystemTimePicker), findsOneWidget);

      // Close
      await tester.tap(find.text('9:00 AM'));
      await tester.pumpAndSettle();
      expect(find.byType(DesignSystemTimePicker), findsNothing);
    });

    testWidgets('formats PM times correctly', (tester) async {
      final pmBlock = PlannedBlock(
        id: 'block-pm',
        categoryId: 'cat-1',
        startTime: DateTime(2026, 3, 15, 15, 30),
        endTime: DateTime(2026, 3, 15, 17, 45),
      );

      await pumpEditor(tester, block: pmBlock);

      expect(find.text('3:30 PM'), findsOneWidget);
      expect(find.text('5:45 PM'), findsOneWidget);
    });

    testWidgets('formats 12:00 noon correctly', (tester) async {
      final noonBlock = PlannedBlock(
        id: 'block-noon',
        categoryId: 'cat-1',
        startTime: DateTime(2026, 3, 15, 12),
        endTime: DateTime(2026, 3, 15, 13),
      );

      await pumpEditor(tester, block: noonBlock);

      expect(find.text('12:00 PM'), findsOneWidget);
      expect(find.text('1:00 PM'), findsOneWidget);
    });

    testWidgets('formats midnight correctly as 12:00am', (tester) async {
      final midnightBlock = PlannedBlock(
        id: 'block-mid',
        categoryId: 'cat-1',
        startTime: DateTime(2026, 3, 15),
        endTime: DateTime(2026, 3, 15, 1),
      );

      await pumpEditor(tester, block: midnightBlock);

      expect(find.text('12:00 AM'), findsOneWidget);
      expect(find.text('1:00 AM'), findsOneWidget);
    });

    testWidgets('time labels are wrapped in a rounded outer container', (
      tester,
    ) async {
      await pumpEditor(tester);

      // The outer container wraps both time labels and the dash
      // Verify the structure: find Container ancestors of the dash text
      final dashFinder = find.text('-');
      expect(dashFinder, findsOneWidget);

      // Both time labels should be within a single Row inside the container
      final startLabel = find.text('9:00 AM');
      final endLabel = find.text('12:00 PM');

      // Both labels and dash are siblings in the same Row
      final commonRow = find.ancestor(
        of: startLabel,
        matching: find.ancestor(
          of: endLabel,
          matching: find.byType(Row),
        ),
      );
      expect(commonRow, findsWidgets);
    });

    testWidgets('switching from start to end picker replaces picker', (
      tester,
    ) async {
      await pumpEditor(tester);

      // Open start picker
      await tester.tap(find.text('9:00 AM'));
      await tester.pumpAndSettle();
      expect(find.byType(DesignSystemTimePicker), findsOneWidget);

      // Switch to end picker
      await tester.tap(find.text('12:00 PM'));
      await tester.pumpAndSettle();
      expect(find.byType(DesignSystemTimePicker), findsOneWidget);

      // Close end picker
      await tester.tap(find.text('12:00 PM'));
      await tester.pumpAndSettle();
      expect(find.byType(DesignSystemTimePicker), findsNothing);
    });

    testWidgets('renders in dark mode without errors', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 400,
            child: TimeBlockEditor(
              block: testBlock,
              planDate: testDate,
              onChanged: (_) {},
              onDelete: () {},
            ),
          ),
          theme: DesignSystemTheme.dark(),
        ),
      );

      expect(find.text('9:00 AM'), findsOneWidget);
      expect(find.text('12:00 PM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    group('_updateTime logic', () {
      /// Helper to open a picker and invoke its onTimeChanged callback.
      Future<void> openPickerAndSetTime(
        WidgetTester tester, {
        required String tapLabel,
        required TimeOfDay newTime,
      }) async {
        await tester.tap(find.text(tapLabel));
        await tester.pumpAndSettle();

        final picker = tester.widget<DesignSystemTimePicker>(
          find.byType(DesignSystemTimePicker),
        );
        picker.onTimeChanged(newTime);
        await tester.pump();
      }

      testWidgets(
        'changing start time within valid range calls onChanged '
        'with updated startTime',
        (tester) async {
          PlannedBlock? result;
          await pumpEditor(tester, onChanged: (b) => result = b);

          await openPickerAndSetTime(
            tester,
            tapLabel: '9:00 AM',
            newTime: const TimeOfDay(hour: 10, minute: 30),
          );

          expect(result, isNotNull);
          expect(result!.startTime, DateTime(2026, 3, 15, 10, 30));
          expect(result!.endTime, DateTime(2026, 3, 15, 12));
        },
      );

      testWidgets(
        'changing end time within valid range calls onChanged '
        'with updated endTime',
        (tester) async {
          PlannedBlock? result;
          await pumpEditor(tester, onChanged: (b) => result = b);

          await openPickerAndSetTime(
            tester,
            tapLabel: '12:00 PM',
            newTime: const TimeOfDay(hour: 14, minute: 0),
          );

          expect(result, isNotNull);
          expect(result!.startTime, DateTime(2026, 3, 15, 9));
          expect(result!.endTime, DateTime(2026, 3, 15, 14));
        },
      );

      testWidgets(
        'moving start past end auto-adjusts end to start + 1 hour',
        (tester) async {
          PlannedBlock? result;
          await pumpEditor(tester, onChanged: (b) => result = b);

          // Start at 9, end at 12 — move start to 13 (past end)
          await openPickerAndSetTime(
            tester,
            tapLabel: '9:00 AM',
            newTime: const TimeOfDay(hour: 13, minute: 0),
          );

          expect(result, isNotNull);
          expect(result!.startTime, DateTime(2026, 3, 15, 13));
          expect(result!.endTime, DateTime(2026, 3, 15, 14));
        },
      );

      testWidgets(
        'moving start equal to end auto-adjusts end to start + 1 hour',
        (tester) async {
          PlannedBlock? result;
          await pumpEditor(tester, onChanged: (b) => result = b);

          // Start at 9, end at 12 — move start to 12 (equal to end)
          await openPickerAndSetTime(
            tester,
            tapLabel: '9:00 AM',
            newTime: const TimeOfDay(hour: 12, minute: 0),
          );

          expect(result, isNotNull);
          expect(result!.startTime, DateTime(2026, 3, 15, 12));
          expect(result!.endTime, DateTime(2026, 3, 15, 13));
        },
      );

      testWidgets(
        'moving end before start auto-adjusts start to end - 1 hour',
        (tester) async {
          PlannedBlock? result;
          await pumpEditor(tester, onChanged: (b) => result = b);

          // Start at 9, end at 12 — move end to 8 (before start)
          await openPickerAndSetTime(
            tester,
            tapLabel: '12:00 PM',
            newTime: const TimeOfDay(hour: 8, minute: 0),
          );

          expect(result, isNotNull);
          expect(result!.startTime, DateTime(2026, 3, 15, 7));
          expect(result!.endTime, DateTime(2026, 3, 15, 8));
        },
      );

      testWidgets(
        'moving end equal to start auto-adjusts start to end - 1 hour',
        (tester) async {
          PlannedBlock? result;
          await pumpEditor(tester, onChanged: (b) => result = b);

          // Start at 9, end at 12 — move end to 9 (equal to start)
          await openPickerAndSetTime(
            tester,
            tapLabel: '12:00 PM',
            newTime: const TimeOfDay(hour: 9, minute: 0),
          );

          expect(result, isNotNull);
          expect(result!.startTime, DateTime(2026, 3, 15, 8));
          expect(result!.endTime, DateTime(2026, 3, 15, 9));
        },
      );

      testWidgets(
        'start auto-adjust clamps to midnight when end moved to 0:00',
        (tester) async {
          // Use a block starting at 1:00, ending at 2:00
          final earlyBlock = PlannedBlock(
            id: 'block-early',
            categoryId: 'cat-1',
            startTime: DateTime(2026, 3, 15, 1),
            endTime: DateTime(2026, 3, 15, 2),
          );

          PlannedBlock? result;
          await pumpEditor(
            tester,
            block: earlyBlock,
            onChanged: (b) => result = b,
          );

          // Move end to 0:00 — start would become -1:00 → clamp to midnight
          await openPickerAndSetTime(
            tester,
            tapLabel: '2:00 AM',
            newTime: const TimeOfDay(hour: 0, minute: 0),
          );

          // end (0:00) is not after start (1:00), so auto-adjust makes
          // start = end - 1h = 23:00 previous day, but that's before midnight
          // so it gets clamped to midnight.
          // Then newEnd (0:00) is still not after newStart (midnight = 0:00),
          // so the callback should NOT be invoked (bail out).
          expect(result, isNull);
        },
      );

      testWidgets(
        'end auto-adjust clamps to day end when start moved to 23:30',
        (tester) async {
          final lateBlock = PlannedBlock(
            id: 'block-late',
            categoryId: 'cat-1',
            startTime: DateTime(2026, 3, 15, 22),
            endTime: DateTime(2026, 3, 15, 23),
          );

          PlannedBlock? result;
          await pumpEditor(
            tester,
            block: lateBlock,
            onChanged: (b) => result = b,
          );

          // Move start to 23:30 — end auto-adjusts to 00:30 next day,
          // but clamped to midnight+24h (day end)
          await openPickerAndSetTime(
            tester,
            tapLabel: '10:00 PM',
            newTime: const TimeOfDay(hour: 23, minute: 30),
          );

          expect(result, isNotNull);
          expect(result!.startTime, DateTime(2026, 3, 15, 23, 30));
          // End clamped to day end: midnight + 24h = 2026-03-16 00:00
          expect(result!.endTime, DateTime(2026, 3, 16));
        },
      );

      testWidgets(
        'bail out when end is still not after start after clamping',
        (tester) async {
          // Block from 0:00 to 1:00
          final midnightBlock = PlannedBlock(
            id: 'block-midnight',
            categoryId: 'cat-1',
            startTime: DateTime(2026, 3, 15),
            endTime: DateTime(2026, 3, 15, 1),
          );

          PlannedBlock? result;
          await pumpEditor(
            tester,
            block: midnightBlock,
            onChanged: (b) => result = b,
          );

          // Move end to 0:00 — same as start
          // auto-adjust: start = end - 1h = -1h → clamped to midnight
          // then end (0:00) is not after start (0:00) → bail out
          await openPickerAndSetTime(
            tester,
            tapLabel: '1:00 AM',
            newTime: const TimeOfDay(hour: 0, minute: 0),
          );

          expect(result, isNull);
        },
      );
    });
  });
}
