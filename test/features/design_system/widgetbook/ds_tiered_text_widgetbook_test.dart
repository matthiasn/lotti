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
      expect(find.byType(DsTieredText), findsNWidgets(5));
      // Wide: the whole wording. Narrow: the person. Narrowest: the bare
      // name, ellipsized rather than a wider tier clipped.
      expect(find.text('with Pip · last spoke Sat 1 Aug'), findsOneWidget);
      expect(find.text('with Pip'), findsOneWidget);
      expect(find.text('Pip'), findsOneWidget);
      // The two-ink pair: the wide one keeps its detail in the tail style,
      // the narrow one sheds it.
      final twoInk = tester
          .widgetList<DsTieredText>(find.byType(DsTieredText))
          .where((w) => w.tailStyle != null)
          .toList();
      expect(twoInk, hasLength(2));
      expect(
        find.text('Last run failed · 20 min ago', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Last run failed', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
