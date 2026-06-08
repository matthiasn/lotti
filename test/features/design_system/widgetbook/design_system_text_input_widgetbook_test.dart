import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_text_input_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemTextInputWidgetbookComponent', () {
    testWidgets('builds the text input overview use case', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemTextInputWidgetbookComponent(),
        expectedName: 'Text input',
      );

      expect(find.text('Input Variants'), findsOneWidget);
      expect(find.byType(DesignSystemTextInput), findsNWidgets(6));

      // Interaction smoke: tapping the first DesignSystemTextInput (interactive or not)
      // must not throw — covers tap plumbing on the overview page.
      await tester.tap(
        find.byType(DesignSystemTextInput).first,
        warnIfMissed: false,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
