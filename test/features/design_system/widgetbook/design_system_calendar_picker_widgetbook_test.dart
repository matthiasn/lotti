import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_calendar_picker.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_calendar_picker_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemCalendarPickerWidgetbookComponent', () {
    testWidgets('builds the calendar picker overview use case', (tester) async {
      final component = buildDesignSystemCalendarPickerWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Calendar picker');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

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
  });
}
