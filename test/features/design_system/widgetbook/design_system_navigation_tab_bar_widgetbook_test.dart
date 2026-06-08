import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_navigation_tab_bar_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemNavigationTabBarWidgetbookComponent', () {
    testWidgets('builds the tab bar overview use case', (tester) async {
      tester.view
        ..physicalSize = const Size(1400, 1000)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemNavigationTabBarWidgetbookComponent(),
        expectedName: 'Tab bar',
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
