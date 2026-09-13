import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
import 'package:lotti/features/design_system/widgetbook/ds_tiered_text_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDsTieredTextWidgetbookComponent', () {
    testWidgets('shows the same ladder shedding at three widths', (
      tester,
    ) async {
      await pumpWidgetbookOverview(
        tester,
        buildDsTieredTextWidgetbookComponent(),
        expectedName: 'Tiered text',
      );

      expect(find.text('Tiered text at three widths'), findsOneWidget);
      expect(find.byType(DsTieredText), findsNWidgets(3));
      // Wide: the whole wording. Narrow: the person. Narrowest: the bare
      // name, ellipsized rather than a wider tier clipped.
      expect(find.text('with Pip · last spoke Sat 1 Aug'), findsOneWidget);
      expect(find.text('with Pip'), findsOneWidget);
      expect(find.text('Pip'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
