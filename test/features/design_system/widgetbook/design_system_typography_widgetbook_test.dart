import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_typography_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemTypographyWidgetbookComponent', () {
    testWidgets('shows only light scale panel in light mode', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemTypographyWidgetbookComponent(),
        expectedName: 'Typography',
      );

      expect(find.text('Light Scale'), findsOneWidget);
      expect(find.text('Dark Scale'), findsNothing);
      expect(find.text('Font Family'), findsOneWidget);
      expect(find.text('Font Weights'), findsOneWidget);
      expect(find.text('Figures'), findsOneWidget);
      expect(find.text('Display 0 / Inter Bold'), findsAtLeastNWidgets(1));
      expect(find.text('OVERLINE / INTER BOLD'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows only dark scale panel in dark mode', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemTypographyWidgetbookComponent(),
        expectedName: 'Typography',
        theme: DesignSystemTheme.dark(),
      );

      expect(find.text('Dark Scale'), findsOneWidget);
      expect(find.text('Light Scale'), findsNothing);
    });
  });
}
