import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_textarea_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemTextareaWidgetbookComponent', () {
    testWidgets('builds the textarea overview use case', (tester) async {
      final component = buildDesignSystemTextareaWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Textarea');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Textarea Variants'), findsOneWidget);
      expect(find.byType(DesignSystemTextarea), findsNWidgets(6));
    });
  });
}
