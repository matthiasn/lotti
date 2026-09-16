import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_navigation_tab_bar_widgetbook.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_launcher.dart';
import 'package:material_ui/material_ui.dart';

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

      // The shell showcase floats the mobile launcher with a docked page
      // action. Both chips are inert previews: tapping them pushes no grid,
      // sheet or route on top of the overview (a pushed sheet would add a
      // barrier to the host's own).
      expect(find.byType(MobileNavigationLauncher), findsOneWidget);
      final barriers = find.byType(ModalBarrier).evaluate().length;
      await tester.tap(find.text('Navigate'));
      await tester.tap(find.text('Add a task'));
      await tester.pump();
      expect(find.byType(ModalBarrier), findsNWidgets(barriers));
      expect(find.text('Navigate'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
