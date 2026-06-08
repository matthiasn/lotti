import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/split_buttons/design_system_split_button.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_split_button_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemSplitButtonWidgetbookComponent', () {
    testWidgets('builds the split button overview use case', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemSplitButtonWidgetbookComponent(),
        expectedName: 'Split Buttons',
      );

      expect(find.text('Size Scale'), findsOneWidget);
      expect(find.text('Variant Matrix'), findsOneWidget);
      expect(find.text('Small'), findsAtLeastNWidgets(1));
      expect(find.text('Compact'), findsAtLeastNWidgets(1));
      expect(find.text('Default'), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.keyboard_arrow_down), findsWidgets);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsWidgets);

      await tester.tap(find.byType(DesignSystemSplitButton).first);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
