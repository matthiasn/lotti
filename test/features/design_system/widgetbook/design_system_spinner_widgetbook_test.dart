import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_spinner_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemSpinnerWidgetbookComponent', () {
    testWidgets('builds the spinner overview use case', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemSpinnerWidgetbookComponent(),
        expectedName: 'Spinner & loaders',
      );

      expect(find.text('Spinners'), findsOneWidget);
      expect(find.text('Skeletons'), findsOneWidget);
      expect(find.byType(DesignSystemSpinner), findsNWidgets(2));
      expect(find.byType(DesignSystemSkeleton), findsNWidgets(2));

      // The spinner's defining behaviour is a repeating rotation animation.
      // Both the spinners and skeletons drive a `..repeat()` AnimationController,
      // each of which schedules a transient frame callback while ticking — so a
      // freshly pumped overview must have pending transient callbacks. A static
      // (non-animating) image would report zero.
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });
  });
}
