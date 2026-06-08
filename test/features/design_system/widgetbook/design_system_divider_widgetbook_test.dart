import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_divider_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemDividerWidgetbookComponent', () {
    testWidgets('builds the divider overview use case', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemDividerWidgetbookComponent(),
        expectedName: 'Divider',
      );

      expect(find.text('Variant Matrix'), findsOneWidget);
      expect(find.text('Horizontal'), findsOneWidget);
      expect(find.text('With label'), findsOneWidget);
      expect(find.text('Vertical'), findsOneWidget);
      expect(find.text('DIVIDER LABEL'), findsOneWidget);
      expect(find.byType(DesignSystemDivider), findsNWidgets(3));
    });
  });
}
