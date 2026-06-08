import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/tooltip_icons/design_system_tooltip_icon.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_tooltip_icon_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemTooltipIconWidgetbookComponent', () {
    testWidgets('builds the tooltip icon overview use case', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemTooltipIconWidgetbookComponent(),
        expectedName: 'Tooltip icon',
      );

      expect(find.text('Tooltip Icon'), findsOneWidget);
      expect(find.byType(DesignSystemTooltipIcon), findsNWidgets(3));

      // Interaction smoke: tapping the first DesignSystemTooltipIcon (interactive or not)
      // must not throw — covers tap plumbing on the overview page.
      await tester.tap(
        find.byType(DesignSystemTooltipIcon).first,
        warnIfMissed: false,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
