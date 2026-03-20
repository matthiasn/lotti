import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/radio_buttons/design_system_radio_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_radio_button_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemRadioButtonWidgetbookComponent', () {
    testWidgets('builds the radio overview use case', (tester) async {
      final component = buildDesignSystemRadioButtonWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Radio buttons');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Size Scale'), findsOneWidget);
      expect(find.text('State Matrix'), findsOneWidget);
      expect(find.text('Default'), findsAtLeastNWidgets(1));
      expect(find.text('Hover'), findsOneWidget);
      expect(find.text('Disabled'), findsOneWidget);
      expect(find.byType(DesignSystemRadioButton), findsAtLeastNWidgets(1));

      await tester.tap(find.byType(DesignSystemRadioButton).first);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
