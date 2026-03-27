import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/tabs/design_system_tab.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_tab_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemTabWidgetbookComponent', () {
    testWidgets('builds the tabs overview use case', (tester) async {
      final component = buildDesignSystemTabWidgetbookComponent();
      final overviewUseCase = component.useCases.firstWhere(
        (uc) => uc.name == 'Overview',
      );

      expect(component.name, 'Tabs');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: overviewUseCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Size Scale'), findsOneWidget);
      expect(find.text('State Matrix'), findsOneWidget);
      expect(find.text('Small'), findsOneWidget);
      expect(find.text('Default'), findsAtLeastNWidgets(2));
      expect(find.text('Hover'), findsAtLeastNWidgets(1));
      expect(find.text('Pressed'), findsAtLeastNWidgets(1));
      expect(find.text('Activated'), findsAtLeastNWidgets(1));
      expect(find.text('Disabled'), findsAtLeastNWidgets(1));
      expect(find.text('Pending'), findsAtLeastNWidgets(1));
      expect(find.byType(DesignSystemTab), findsNWidgets(12));

      await tester.tap(find.byType(DesignSystemTab).first);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('builds the tab bar use case with interactive selection', (
      tester,
    ) async {
      final component = buildDesignSystemTabWidgetbookComponent();
      final tabBarUseCase = component.useCases.firstWhere(
        (uc) => uc.name == 'Tab Bar',
      );

      expect(component.useCases.length, 2);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: tabBarUseCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      // Should render 3 tabs
      expect(find.byType(DesignSystemTab), findsNWidgets(3));

      // Tap second tab to verify selection changes
      await tester.tap(find.byType(DesignSystemTab).at(1));
      await tester.pump();

      // Verify the second tab is now selected
      final secondTab = tester.widget<DesignSystemTab>(
        find.byType(DesignSystemTab).at(1),
      );
      expect(secondTab.selected, isTrue);
    });
  });
}
