import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_toggle_widgetbook.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('buildDesignSystemToggleWidgetbookComponent', () {
    testWidgets('builds the toggle overview use case', (tester) async {
      final component = buildDesignSystemToggleWidgetbookComponent();
      final useCase = component.useCases.single;

      expect(component.name, 'Toggle');
      expect(useCase.name, 'Overview');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(builder: useCase.builder),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Size Scale'), findsOneWidget);
      expect(find.text('Variant Matrix'), findsOneWidget);
      expect(find.text('Small'), findsAtLeastNWidgets(1));
      expect(find.text('Default'), findsAtLeastNWidgets(2));
      expect(find.text('Hover'), findsAtLeastNWidgets(1));
      expect(find.text('Disabled'), findsAtLeastNWidgets(1));
      expect(find.byType(DesignSystemToggle), findsNWidgets(38));

      await tester.tap(find.byType(DesignSystemToggle).first);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
