import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_typography_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemTypographyWidgetbookComponent', () {
    testWidgets('builds the typography overview use case', (tester) async {
      final component = buildDesignSystemTypographyWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Typography');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Light Scale'), findsOneWidget);
      expect(find.text('Dark Scale'), findsOneWidget);
      expect(find.text('Font Family'), findsOneWidget);
      expect(find.text('Font Weights'), findsOneWidget);
      expect(find.text('Figures'), findsOneWidget);
      expect(find.text('Display 0 / Inter Bold'), findsAtLeastNWidgets(1));
      expect(find.text('OVERLINE / INTER BOLD'), findsAtLeastNWidgets(1));
    });
  });
}
