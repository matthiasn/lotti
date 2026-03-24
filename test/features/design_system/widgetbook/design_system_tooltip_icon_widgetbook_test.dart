import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/tooltip_icons/design_system_tooltip_icon.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_tooltip_icon_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemTooltipIconWidgetbookComponent', () {
    testWidgets('builds the tooltip icon overview use case', (tester) async {
      final component = buildDesignSystemTooltipIconWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Tooltip icon');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Tooltip Icon'), findsOneWidget);
      expect(find.byType(DesignSystemTooltipIcon), findsNWidgets(3));
    });
  });
}
