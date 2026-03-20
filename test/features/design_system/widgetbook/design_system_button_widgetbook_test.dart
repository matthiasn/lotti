import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_button_widgetbook.dart';
import 'package:widgetbook/widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemWidgetbookFolder', () {
    testWidgets('builds the combined overview use case', (tester) async {
      final folder = buildDesignSystemWidgetbookFolder();
      final component = folder.children!.single as WidgetbookComponent;
      final useCase = component.useCases.single;

      expect(folder.name, 'Design System');
      expect(component.name, 'Buttons');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Size Scale'), findsOneWidget);
      expect(find.text('Variant Matrix'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
    });
  });
}
