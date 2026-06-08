import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_search_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemSearchWidgetbookComponent', () {
    testWidgets('builds the search overview use case', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemSearchWidgetbookComponent(),
        expectedName: 'Search',
      );

      expect(find.text('Size Scale'), findsOneWidget);
      expect(find.text('Filled'), findsOneWidget);
      expect(find.text('Type user'), findsAtLeastNWidgets(1));
      expect(find.text('Lotti search'), findsAtLeastNWidgets(1));
      expect(find.byType(DesignSystemSearch), findsNWidgets(4));
    });
  });
}
