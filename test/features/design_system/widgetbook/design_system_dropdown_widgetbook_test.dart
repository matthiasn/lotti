import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_dropdown_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemDropdownWidgetbookComponent', () {
    testWidgets('builds the dropdown overview use case', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemDropdownWidgetbookComponent(),
        expectedName: 'Dropdowns',
      );

      expect(find.text('Combobox'), findsOneWidget);
      expect(find.text('Dropdown list'), findsOneWidget);
      expect(find.text('Multiselect'), findsOneWidget);
      expect(find.byType(DesignSystemDropdown), findsNWidgets(3));
      expect(find.byType(RawScrollbar), findsNWidgets(2));

      await tester.tap(find.text('Input').first);
      await tester.pump();

      expect(find.byType(RawScrollbar), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  });
}
