import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_text_input_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemTextInputWidgetbookComponent', () {
    testWidgets('builds the text input overview use case', (tester) async {
      final component = buildDesignSystemTextInputWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Text input');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Input Variants'), findsOneWidget);
      expect(find.byType(DesignSystemTextInput), findsNWidgets(6));
    });
  });
}
