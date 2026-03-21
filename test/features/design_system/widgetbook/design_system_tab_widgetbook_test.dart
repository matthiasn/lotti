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
      final useCase = component.useCases.single;

      expect(component.name, 'Tabs');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
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
  });
}
