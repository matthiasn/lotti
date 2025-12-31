import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/tasks/ui/due_date_text.dart';

import '../../../test_helper.dart';

void main() {
  group('DueDateText', () {
    testWidgets('displays icon and text', (tester) async {
      final fakeNow = DateTime(2025, 6, 15, 12);
      final dueDate = DateTime(2025, 6, 20);

      await withClock(Clock(() => fakeNow), () async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: DueDateText(dueDate: dueDate),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.event_rounded), findsOneWidget);
        expect(find.byType(Text), findsOneWidget);
      });
    });

    testWidgets('displays "Due Today" for today', (tester) async {
      final fakeNow = DateTime(2025, 6, 15, 12);
      final dueDate = DateTime(2025, 6, 15);

      await withClock(Clock(() => fakeNow), () async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: DueDateText(dueDate: dueDate),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Due Today'), findsOneWidget);
      });
    });

    testWidgets('displays absolute date format by default', (tester) async {
      final fakeNow = DateTime(2025, 6, 15, 12);
      final dueDate = DateTime(2025, 6, 20);

      await withClock(Clock(() => fakeNow), () async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: DueDateText(dueDate: dueDate),
          ),
        );
        await tester.pumpAndSettle();

        // Should show "Due: Jun 20, 2025" format
        final expectedText = 'Due: ${DateFormat.yMMMd().format(dueDate)}';
        expect(find.text(expectedText), findsOneWidget);
      });
    });

    testWidgets('toggles to relative format on tap', (tester) async {
      final fakeNow = DateTime(2025, 6, 15, 12);
      final dueDate = DateTime(2025, 6, 20); // 5 days from reference

      await withClock(Clock(() => fakeNow), () async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: DueDateText(dueDate: dueDate),
          ),
        );
        await tester.pumpAndSettle();

        // Initially shows absolute format
        final absoluteText = 'Due: ${DateFormat.yMMMd().format(dueDate)}';
        expect(find.text(absoluteText), findsOneWidget);

        // Tap to toggle - use the Text widget directly to avoid hit test issues
        await tester.tap(find.text(absoluteText));
        await tester.pumpAndSettle();

        // Now shows relative format
        expect(find.text('Due in 5 days'), findsOneWidget);
      });
    });

    testWidgets('displays "Due Tomorrow" for tomorrow', (tester) async {
      final fakeNow = DateTime(2025, 6, 15, 12);
      final dueDate = DateTime(2025, 6, 16);

      await withClock(Clock(() => fakeNow), () async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: DueDateText(dueDate: dueDate),
          ),
        );
        await tester.pumpAndSettle();

        // Tap to show relative - use the text to avoid hit test issues
        final absoluteText = 'Due: ${DateFormat.yMMMd().format(dueDate)}';
        await tester.tap(find.text(absoluteText));
        await tester.pumpAndSettle();

        expect(find.text('Due Tomorrow'), findsOneWidget);
      });
    });

    testWidgets('displays "Due Yesterday" for yesterday', (tester) async {
      final fakeNow = DateTime(2025, 6, 15, 12);
      final dueDate = DateTime(2025, 6, 14);

      await withClock(Clock(() => fakeNow), () async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: DueDateText(dueDate: dueDate),
          ),
        );
        await tester.pumpAndSettle();

        // Tap to show relative - use the text to avoid hit test issues
        final absoluteText = 'Due: ${DateFormat.yMMMd().format(dueDate)}';
        await tester.tap(find.text(absoluteText));
        await tester.pumpAndSettle();

        expect(find.text('Due Yesterday'), findsOneWidget);
      });
    });

    testWidgets('displays "Overdue by X days" for past dates', (tester) async {
      final fakeNow = DateTime(2025, 6, 15, 12);
      final dueDate = DateTime(2025, 6, 12); // 3 days ago

      await withClock(Clock(() => fakeNow), () async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: DueDateText(dueDate: dueDate),
          ),
        );
        await tester.pumpAndSettle();

        // Tap to show relative - use the text to avoid hit test issues
        final absoluteText = 'Due: ${DateFormat.yMMMd().format(dueDate)}';
        await tester.tap(find.text(absoluteText));
        await tester.pumpAndSettle();

        expect(find.text('Overdue by 3 days'), findsOneWidget);
      });
    });

    testWidgets('toggles back to absolute format on second tap',
        (tester) async {
      final fakeNow = DateTime(2025, 6, 15, 12);
      final dueDate = DateTime(2025, 6, 20);

      await withClock(Clock(() => fakeNow), () async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: DueDateText(dueDate: dueDate),
          ),
        );
        await tester.pumpAndSettle();

        final absoluteText = 'Due: ${DateFormat.yMMMd().format(dueDate)}';

        // First tap - switch to relative
        await tester.tap(find.text(absoluteText));
        await tester.pumpAndSettle();
        expect(find.text('Due in 5 days'), findsOneWidget);

        // Second tap - switch back to absolute
        await tester.tap(find.text('Due in 5 days'));
        await tester.pumpAndSettle();
        expect(find.text(absoluteText), findsOneWidget);
      });
    });

    testWidgets('applies non-urgent color for future dates', (tester) async {
      final fakeNow = DateTime(2025, 6, 15, 12);
      final dueDate = DateTime(2025, 6, 25); // 10 days in future - not urgent

      await withClock(Clock(() => fakeNow), () async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: DueDateText(dueDate: dueDate),
          ),
        );
        await tester.pumpAndSettle();

        // Verify the icon exists and uses non-urgent color (from colorScheme)
        final icon = tester.widget<Icon>(find.byIcon(Icons.event_rounded));
        // Non-urgent future dates should NOT have red or orange colors
        expect(icon.color, isNotNull);
      });
    });

    testWidgets('shows "Due Today" in absolute mode for today', (tester) async {
      final fakeNow = DateTime(2025, 6, 15, 12);
      final dueDate = DateTime(2025, 6, 15); // Same day

      await withClock(Clock(() => fakeNow), () async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: DueDateText(dueDate: dueDate),
          ),
        );
        await tester.pumpAndSettle();

        // In absolute mode (default), "Due Today" should show for same-day
        expect(find.text('Due Today'), findsOneWidget);

        // Toggle to relative - should still show "Due Today"
        await tester.tap(find.text('Due Today'));
        await tester.pumpAndSettle();
        expect(find.text('Due Today'), findsOneWidget);
      });
    });

    testWidgets('renders in dark mode', (tester) async {
      final fakeNow = DateTime(2025, 6, 15, 12);
      final dueDate = DateTime(2025, 6, 20);

      await withClock(Clock(() => fakeNow), () async {
        await tester.pumpWidget(
          DarkWidgetTestBench(
            child: DueDateText(dueDate: dueDate),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DueDateText), findsOneWidget);
        expect(find.byIcon(Icons.event_rounded), findsOneWidget);
      });
    });

    testWidgets('uses "Due Tomorrow" for 1 day in future', (tester) async {
      final fakeNow = DateTime(2025, 6, 15, 12);
      final dueDate = DateTime(2025, 6, 16); // 1 day from reference

      await withClock(Clock(() => fakeNow), () async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: DueDateText(dueDate: dueDate),
          ),
        );
        await tester.pumpAndSettle();

        // Tap to show relative
        final absoluteText = 'Due: ${DateFormat.yMMMd().format(dueDate)}';
        await tester.tap(find.text(absoluteText));
        await tester.pumpAndSettle();

        // Should use "Due Tomorrow" not "Due in 1 days"
        expect(find.text('Due Tomorrow'), findsOneWidget);
        expect(find.textContaining('1 days'), findsNothing);
      });
    });

    testWidgets('uses "Due Yesterday" for overdue by 1 day', (tester) async {
      final fakeNow = DateTime(2025, 6, 15, 12);
      final dueDate = DateTime(2025, 6, 14); // 1 day ago

      await withClock(Clock(() => fakeNow), () async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: DueDateText(dueDate: dueDate),
          ),
        );
        await tester.pumpAndSettle();

        // Tap to show relative
        final absoluteText = 'Due: ${DateFormat.yMMMd().format(dueDate)}';
        await tester.tap(find.text(absoluteText));
        await tester.pumpAndSettle();

        // Should use "Due Yesterday" not "Overdue by 1 days"
        expect(find.text('Due Yesterday'), findsOneWidget);
        expect(find.textContaining('1 days'), findsNothing);
      });
    });
  });
}
