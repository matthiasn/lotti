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
  });
}
