import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_divider_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemDividerWidgetbookComponent', () {
    testWidgets('builds the divider overview use case', (tester) async {
      final component = buildDesignSystemDividerWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Divider');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Variant Matrix'), findsOneWidget);
      expect(find.text('Horizontal'), findsOneWidget);
      expect(find.text('With label'), findsOneWidget);
      expect(find.text('Vertical'), findsOneWidget);
      expect(find.text('DIVIDER LABEL'), findsOneWidget);
      expect(find.byType(DesignSystemDivider), findsNWidgets(3));
    });
  });
}
