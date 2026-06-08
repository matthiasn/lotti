import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_scrollbar_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemScrollbarWidgetbookComponent', () {
    testWidgets('builds the scrollbar overview use case', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemScrollbarWidgetbookComponent(),
        expectedName: 'Scrollbar',
      );

      expect(find.text('Scrollbar Sizes'), findsOneWidget);
      expect(find.byType(DesignSystemScrollbar), findsNWidgets(2));

      // Interaction smoke: tapping the first DesignSystemScrollbar (interactive or not)
      // must not throw — covers tap plumbing on the overview page.
      await tester.tap(
        find.byType(DesignSystemScrollbar).first,
        warnIfMissed: false,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
