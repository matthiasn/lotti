import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_calendar_picker.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_calendar_picker_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemCalendarPickerWidgetbookComponent', () {
    // January 15, 2026 is a Thursday.
    final testDate = DateTime(2026, 1, 15);

    Future<void> pumpOverview(WidgetTester tester) async {
      final component = buildDesignSystemCalendarPickerWidgetbookComponent(
        initialDate: testDate,
      );
      final useCase = component.useCases.single;

      expect(component.name, 'Calendar picker');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );
    }

    Finder dayInPicker(String label) => find.descendant(
      of: find.byType(DesignSystemCalendarPicker),
      matching: find.text(label),
    );

    testWidgets('builds the calendar picker overview use case', (tester) async {
      await pumpOverview(tester);

      expect(find.text('Date Cards'), findsOneWidget);
      expect(find.text('Calendar Views'), findsOneWidget);
      expect(find.text('Calendar Picker'), findsOneWidget);
      expect(find.text('Weekly Calendar'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('January 2026'), findsOneWidget);
      expect(find.byType(DesignSystemCalendarPicker), findsOneWidget);
      expect(find.byType(DesignSystemCalendarDateCard), findsNWidgets(10));

      await tester.tap(find.byType(DesignSystemCalendarDateCard).first);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('navigates to a different month via the month rail', (
      tester,
    ) async {
      await pumpOverview(tester);

      expect(find.text('January 2026'), findsOneWidget);

      // Feb may be outside the visible month rail viewport — scroll it in.
      final febFinder = find.text('Feb');
      await tester.ensureVisible(febFinder);
      await tester.pumpAndSettle();
      await tester.tap(febFinder);
      await tester.pump();

      expect(find.text('February 2026'), findsOneWidget);
    });

    testWidgets('selects a date and extends to range', (tester) async {
      await pumpOverview(tester);

      // Tap day 20 inside the picker grid.
      await tester.ensureVisible(dayInPicker('20'));
      await tester.pumpAndSettle();
      await tester.tap(dayInPicker('20'));
      await tester.pump();

      expect(tester.takeException(), isNull);

      // Tap day 23 to create a range (20–23).
      await tester.tap(dayInPicker('23'));
      await tester.pump();

      expect(tester.takeException(), isNull);

      // Tap day 25 to reset to single selection.
      await tester.tap(dayInPicker('25'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('today button navigates back and selects today', (
      tester,
    ) async {
      await pumpOverview(tester);

      // Navigate to December 2025 via the month rail.
      final decFinder = find.text('Dec');
      await tester.ensureVisible(decFinder);
      await tester.pumpAndSettle();
      await tester.tap(decFinder);
      await tester.pump();

      expect(find.text('December 2025'), findsOneWidget);

      // Tap Today button to return to January 2026.
      final todayFinder = dayInPicker('Today');
      await tester.ensureVisible(todayFinder);
      await tester.pumpAndSettle();
      await tester.tap(todayFinder);
      await tester.pump();

      expect(find.text('January 2026'), findsOneWidget);
    });

    testWidgets('deselects a date when tapping the same day twice', (
      tester,
    ) async {
      await pumpOverview(tester);

      // Select day 22 inside the picker (unique enough to not clash).
      final day22 = dayInPicker('22');
      await tester.ensureVisible(day22);
      await tester.pumpAndSettle();
      await tester.tap(day22);
      await tester.pump();

      // Tap the same day again to deselect.
      await tester.tap(day22);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
