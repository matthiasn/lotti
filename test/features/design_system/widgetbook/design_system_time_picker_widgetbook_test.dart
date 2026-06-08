import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_time_picker.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_time_picker_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemTimePickerWidgetbookComponent', () {
    testWidgets('builds the time picker overview use case', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemTimePickerWidgetbookComponent(),
        expectedName: 'Time picker',
      );

      expect(find.text('Time Formats'), findsOneWidget);
      expect(find.byType(DesignSystemTimePicker), findsNWidgets(2));

      // Interaction smoke: tapping the first DesignSystemTimePicker (interactive or not)
      // must not throw — covers tap plumbing on the overview page.
      await tester.tap(
        find.byType(DesignSystemTimePicker).first,
        warnIfMissed: false,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
