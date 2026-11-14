import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_chip_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemChipWidgetbookComponent', () {
    testWidgets('builds the chip overview use case', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemChipWidgetbookComponent(),
        expectedName: 'Chips',
      );

      expect(find.text('Combination Scale'), findsOneWidget);
      expect(find.text('State Matrix'), findsOneWidget);
      expect(find.text('Activated'), findsOneWidget);
      expect(find.text('Chip label'), findsAtLeastNWidgets(1));

      await tester.tap(find.byType(DesignSystemChip).first);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('shows one chip per size, named after it, so each touch '
        "size's pill can be compared in its target", (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemChipWidgetbookComponent(),
        expectedName: 'Chips',
      );
      // Below the fold of the page's own list.
      await tester.scrollUntilVisible(
        find.text('Size Scale'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pump();

      for (final size in DesignSystemChipSize.values) {
        final chip = tester.widget<DesignSystemChip>(
          find.widgetWithText(DesignSystemChip, size.name),
        );
        expect(chip.size, size, reason: size.name);
        expect(chip.outlined, isTrue);
      }
    });
  });
}
