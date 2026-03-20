import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_checkbox_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemCheckboxWidgetbookComponent', () {
    testWidgets('builds the checkbox overview use case', (tester) async {
      final component = buildDesignSystemCheckboxWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Checkbox');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Combination Scale'), findsOneWidget);
      expect(find.text('State Matrix'), findsOneWidget);
      expect(find.text('Checkbox label'), findsWidgets);
      expect(find.text('Disabled'), findsOneWidget);

      await tester.tap(find.byType(DesignSystemCheckbox).first);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
