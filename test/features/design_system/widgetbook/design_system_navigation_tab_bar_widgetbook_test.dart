import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_navigation_tab_bar_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemNavigationTabBarWidgetbookComponent', () {
    testWidgets('builds the tab bar overview use case', (tester) async {
      final component = buildDesignSystemNavigationTabBarWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Tab bar');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Tab Bar Variants'), findsOneWidget);
      expect(find.text('Bottom navigation shell'), findsOneWidget);
      expect(find.text('My Daily'), findsAtLeastNWidgets(3));
      expect(find.text('Tasks'), findsAtLeastNWidgets(1));
      expect(find.text('Projects'), findsAtLeastNWidgets(1));
      expect(find.text('Insights'), findsAtLeastNWidgets(1));
      await tester.scrollUntilVisible(
        find.text('Sub-components'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Sub-components'), findsOneWidget);
      expect(find.text('Placeholder'), findsOneWidget);
    });
  });
}
