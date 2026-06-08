import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_list_item_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemListItemWidgetbookComponent', () {
    testWidgets('builds the list item overview use case', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemListItemWidgetbookComponent(),
        expectedName: 'List',
      );

      expect(find.text('List Item Variants'), findsOneWidget);
      expect(
        find.byType(DesignSystemListItem),
        findsAtLeastNWidgets(5),
      );

      // Interaction smoke: tapping the first DesignSystemListItem (interactive or not)
      // must not throw — covers tap plumbing on the overview page.
      await tester.tap(
        find.byType(DesignSystemListItem).first,
        warnIfMissed: false,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
