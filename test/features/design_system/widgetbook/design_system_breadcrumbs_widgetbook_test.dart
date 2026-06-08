import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/breadcrumbs/design_system_breadcrumbs.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_breadcrumbs_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemBreadcrumbsWidgetbookComponent', () {
    testWidgets('builds the breadcrumbs overview use case', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemBreadcrumbsWidgetbookComponent(),
        expectedName: 'Breadcrumbs',
      );

      expect(find.text('State Matrix'), findsOneWidget);
      expect(find.text('Breadcrumb Trail'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Breadcrumbs'), findsAtLeastNWidgets(1));
      expect(find.byType(DesignSystemBreadcrumbs), findsNWidgets(9));
    });
  });
}
