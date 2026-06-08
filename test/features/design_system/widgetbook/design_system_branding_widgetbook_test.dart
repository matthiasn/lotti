import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/branding/design_system_brand_logo.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_branding_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemBrandingWidgetbookComponent', () {
    testWidgets('builds the branding overview use case', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemBrandingWidgetbookComponent(),
        expectedName: 'Branding',
      );

      expect(find.byType(DesignSystemBrandLogo), findsOneWidget);

      // The rendered logo honours its configured height.
      final logo = tester.widget<DesignSystemBrandLogo>(
        find.byType(DesignSystemBrandLogo),
      );
      expect(
        tester.getSize(find.byType(DesignSystemBrandLogo)).height,
        logo.height,
      );
    });
  });
}
