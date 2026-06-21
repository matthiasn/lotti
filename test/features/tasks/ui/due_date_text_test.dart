import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/tasks/ui/due_date_text.dart';

import '../../../test_helper.dart';

void main() {
  // Reference "today" for all cases. The widget defaults to a *relative*
  // phrasing for dates within a week (in either direction) and an *absolute*
  // date for anything further out; tapping flips to the other representation.
  final fakeNow = DateTime(2025, 6, 15, 12);

  Future<void> pump(
    WidgetTester tester,
    DateTime dueDate, {
    bool dark = false,
  }) {
    final child = DueDateText(dueDate: dueDate);
    return tester.pumpWidget(
      dark ? DarkWidgetTestBench(child: child) : WidgetTestBench(child: child),
    );
  }

  group('DueDateText', () {
    testWidgets('displays icon and a single text label', (tester) async {
      await withClock(Clock(() => fakeNow), () async {
        await pump(tester, DateTime(2025, 6, 20)); // +5 days (near)
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byIcon(Icons.event_rounded), findsOneWidget);
        expect(find.byType(Text), findsOneWidget);
      });
    });

    testWidgets('displays "Due Today" for today', (tester) async {
      await withClock(Clock(() => fakeNow), () async {
        await pump(tester, DateTime(2025, 6, 15));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Due Today'), findsOneWidget);
      });
    });

    testWidgets('defaults to relative phrasing for near dates', (tester) async {
      await withClock(Clock(() => fakeNow), () async {
        await pump(tester, DateTime(2025, 6, 20)); // +5 days (within a week)
        await tester.pump(const Duration(milliseconds: 100));

        // Relative is the default for near dates — no tap needed.
        expect(find.text('Due in 5 days'), findsOneWidget);
        expect(
          find.text(DateFormat.yMMMd().format(DateTime(2025, 6, 20))),
          findsNothing,
        );
      });
    });

    testWidgets('defaults to the absolute date for far dates', (tester) async {
      await withClock(Clock(() => fakeNow), () async {
        await pump(tester, DateTime(2025, 7, 5)); // +20 days (beyond a week)
        await tester.pump(const Duration(milliseconds: 100));

        final absoluteText = DateFormat.yMMMd().format(DateTime(2025, 7, 5));
        expect(find.text(absoluteText), findsOneWidget);
        expect(find.text('Due in 20 days'), findsNothing);
      });
    });

    testWidgets('taps a far date to reveal the relative phrasing', (
      tester,
    ) async {
      await withClock(Clock(() => fakeNow), () async {
        await pump(tester, DateTime(2025, 7, 5)); // +20 days (far → absolute)
        await tester.pump(const Duration(milliseconds: 100));

        final absoluteText = DateFormat.yMMMd().format(DateTime(2025, 7, 5));
        expect(find.text(absoluteText), findsOneWidget);

        await tester.tap(find.text(absoluteText));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Due in 20 days'), findsOneWidget);
      });
    });

    testWidgets('taps a near date to reveal the absolute date', (tester) async {
      await withClock(Clock(() => fakeNow), () async {
        await pump(tester, DateTime(2025, 6, 20)); // +5 days (near → relative)
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Due in 5 days'), findsOneWidget);

        await tester.tap(find.text('Due in 5 days'));
        await tester.pump(const Duration(milliseconds: 100));

        final absoluteText = DateFormat.yMMMd().format(DateTime(2025, 6, 20));
        expect(find.text(absoluteText), findsOneWidget);
      });
    });

    testWidgets('shows "Due Tomorrow" for +1 day by default', (tester) async {
      await withClock(Clock(() => fakeNow), () async {
        await pump(tester, DateTime(2025, 6, 16));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Due Tomorrow'), findsOneWidget);
        expect(find.textContaining('1 days'), findsNothing);
      });
    });

    testWidgets('shows "Due Yesterday" for -1 day by default', (tester) async {
      await withClock(Clock(() => fakeNow), () async {
        await pump(tester, DateTime(2025, 6, 14));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Due Yesterday'), findsOneWidget);
        expect(find.textContaining('1 days'), findsNothing);
      });
    });

    testWidgets('shows "Overdue by 3 days" for a recent past date', (
      tester,
    ) async {
      await withClock(Clock(() => fakeNow), () async {
        await pump(tester, DateTime(2025, 6, 12)); // -3 days (near)
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Overdue by 3 days'), findsOneWidget);
      });
    });

    testWidgets('toggles back to absolute on the second tap (far date)', (
      tester,
    ) async {
      await withClock(Clock(() => fakeNow), () async {
        await pump(tester, DateTime(2025, 7, 5)); // +20 days (far → absolute)
        await tester.pump(const Duration(milliseconds: 100));

        final absoluteText = DateFormat.yMMMd().format(DateTime(2025, 7, 5));

        await tester.tap(find.text(absoluteText));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Due in 20 days'), findsOneWidget);

        await tester.tap(find.text('Due in 20 days'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(absoluteText), findsOneWidget);
      });
    });

    testWidgets('applies a non-urgent color for far future dates', (
      tester,
    ) async {
      await withClock(Clock(() => fakeNow), () async {
        await pump(tester, DateTime(2025, 6, 25)); // +10 days, not urgent
        await tester.pump(const Duration(milliseconds: 100));

        final icon = tester.widget<Icon>(find.byIcon(Icons.event_rounded));
        expect(icon.color, isNotNull);
      });
    });

    testWidgets('keeps "Due Today" across a tap', (tester) async {
      await withClock(Clock(() => fakeNow), () async {
        await pump(tester, DateTime(2025, 6, 15));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Due Today'), findsOneWidget);

        await tester.tap(find.text('Due Today'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Due Today'), findsOneWidget);
      });
    });

    testWidgets('renders in dark mode', (tester) async {
      await withClock(Clock(() => fakeNow), () async {
        await pump(tester, DateTime(2025, 6, 20), dark: true);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(DueDateText), findsOneWidget);
        expect(find.byIcon(Icons.event_rounded), findsOneWidget);
      });
    });
  });
}
