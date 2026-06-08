import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_badge_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemBadgeWidgetbookComponent', () {
    testWidgets('builds the badge overview use case', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemBadgeWidgetbookComponent(),
        expectedName: 'Badges',
      );

      expect(find.text('Type Scale'), findsOneWidget);
      expect(find.text('Status Matrix'), findsOneWidget);
      expect(find.text('Dot'), findsOneWidget);
      expect(find.text('Primary'), findsAtLeastNWidgets(1));
      expect(find.text('Outlined'), findsAtLeastNWidgets(1));
    });
  });
}
