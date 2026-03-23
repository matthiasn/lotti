import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_time_picker.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_time_picker_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemTimePickerWidgetbookComponent', () {
    testWidgets('builds the time picker overview use case', (tester) async {
      final component = buildDesignSystemTimePickerWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Time picker');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Time Formats'), findsOneWidget);
      expect(find.byType(DesignSystemTimePicker), findsNWidgets(2));
    });
  });
}
