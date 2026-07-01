import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_confirmation_modal_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemConfirmationModalWidgetbookComponent', () {
    testWidgets('builds the confirmation modal overview use case', (
      tester,
    ) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemConfirmationModalWidgetbookComponent(),
        expectedName: 'Confirmation Modal',
      );

      expect(find.text('Destructive'), findsOneWidget);
      expect(find.text('Non-destructive'), findsOneWidget);
      expect(find.byType(DesignSystemButton), findsNWidgets(2));

      await tester.tap(find.text('Open destructive confirmation'));
      await tester.pumpAndSettle();

      expect(find.text('Discard recording?'), findsOneWidget);
      expect(
        find.text(
          'This recording will be deleted. No audio entry, transcript, '
          'or task summary will be created.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Keep Recording'));
      await tester.pumpAndSettle();
      expect(find.text('Discard recording?'), findsNothing);
    });
  });
}
