import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_ai_assistant_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_ai_icon_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemAiIconWidgetbookComponent', () {
    testWidgets('renders the overview page with all variants', (
      tester,
    ) async {
      final component = buildDesignSystemAiIconWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'AI Icon');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      // Should render 3 AI icon variants
      expect(
        find.byType(DesignSystemAiAssistantButton),
        findsNWidgets(3),
      );

      // Labels should be present
      expect(find.text('Interactive'), findsOneWidget);
      expect(find.text('Variant 2'), findsOneWidget);
      expect(find.text('Disabled'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
