import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';

import '../../../../test_helper.dart';

/// Tests for vertical spacing reduction in ChecklistItemWidget
///
/// Coverage: Ensures padding was reduced from 4 to 2 pixels per commit a58095840
void main() {
  group('ChecklistItemWidget Spacing Tests', () {
    testWidgets('outer padding is exactly 2 pixels vertically', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
          ),
        ),
      );

      // Find the outer Padding widget that wraps the MouseRegion
      final paddingFinder = find.descendant(
        of: find.byType(ChecklistItemWidget),
        matching: find.byType(Padding),
      );

      expect(paddingFinder, findsWidgets);

      // Find the specific Padding with vertical: 2
      final paddings = tester.widgetList<Padding>(paddingFinder);
      final outerPadding = paddings.firstWhere(
        (padding) =>
            padding.padding is EdgeInsets &&
            (padding.padding as EdgeInsets).top == 2 &&
            (padding.padding as EdgeInsets).bottom == 2 &&
            (padding.padding as EdgeInsets).left == 0 &&
            (padding.padding as EdgeInsets).right == 0,
      );

      expect(outerPadding.padding, const EdgeInsets.symmetric(vertical: 2));
    });

    testWidgets('inner contentPadding has correct spacing', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
          ),
        ),
      );

      final checkboxListTile =
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));

      // Verify contentPadding matches the compact style (reduced left/right, no vertical)
      expect(
        checkboxListTile.contentPadding,
        const EdgeInsets.symmetric(horizontal: 5),
      );
    });

    testWidgets('spacing remains consistent when item is checked',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistItemWidget(
            title: 'Test Item',
            isChecked: true,
            onChanged: (_) {},
          ),
        ),
      );

      // Verify inner padding
      final checkboxListTile =
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
      expect(
        checkboxListTile.contentPadding,
        const EdgeInsets.symmetric(horizontal: 5),
      );

      // Verify outer padding
      final paddingFinder = find.descendant(
        of: find.byType(ChecklistItemWidget),
        matching: find.byType(Padding),
      );

      final paddings = tester.widgetList<Padding>(paddingFinder);
      final hasCorrectOuterPadding = paddings.any(
        (padding) =>
            padding.padding is EdgeInsets &&
            (padding.padding as EdgeInsets).top == 2 &&
            (padding.padding as EdgeInsets).bottom == 2 &&
            (padding.padding as EdgeInsets).left == 0 &&
            (padding.padding as EdgeInsets).right == 0,
      );

      expect(hasCorrectOuterPadding, isTrue);
    });

    testWidgets('spacing remains consistent when toggling checked state',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
          ),
        ),
      );

      // Get initial spacing
      var checkboxListTile =
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
      final initialPadding = checkboxListTile.contentPadding;

      // Toggle checkbox
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify spacing unchanged
      checkboxListTile =
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
      expect(checkboxListTile.contentPadding, initialPadding);
      expect(
        checkboxListTile.contentPadding,
        const EdgeInsets.symmetric(horizontal: 5),
      );

      // Let completion highlight timer finish to avoid pending timers.
      await tester.pump(checklistCompletionAnimationDuration);
      await tester.pump();
    });

    testWidgets('spacing is consistent in edit mode', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
            onTitleChange: (_) {},
          ),
        ),
      );

      // Enter edit mode
      await tester.tap(find.byIcon(Icons.edit).first);
      await tester.pump();

      // Verify spacing in edit mode
      final checkboxListTile =
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
      expect(
        checkboxListTile.contentPadding,
        const EdgeInsets.symmetric(horizontal: 5),
      );

      final paddingFinder = find.descendant(
        of: find.byType(ChecklistItemWidget),
        matching: find.byType(Padding),
      );

      final paddings = tester.widgetList<Padding>(paddingFinder);
      final hasCorrectOuterPadding = paddings.any(
        (padding) =>
            padding.padding is EdgeInsets &&
            (padding.padding as EdgeInsets).top == 2 &&
            (padding.padding as EdgeInsets).bottom == 2,
      );

      expect(hasCorrectOuterPadding, isTrue);
    });

    testWidgets('spacing is reduced compared to legacy 4px padding',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
          ),
        ),
      );

      // Find outer padding
      final paddingFinder = find.descendant(
        of: find.byType(ChecklistItemWidget),
        matching: find.byType(Padding),
      );

      final paddings = tester.widgetList<Padding>(paddingFinder);
      final outerPadding = paddings.firstWhere(
        (padding) =>
            padding.padding is EdgeInsets &&
            (padding.padding as EdgeInsets).top == 2 &&
            (padding.padding as EdgeInsets).bottom == 2,
      );

      // Verify it's 2, not the legacy 4
      final edgeInsets = outerPadding.padding as EdgeInsets;
      expect(edgeInsets.vertical, 4.0); // 2 top + 2 bottom = 4 total
      expect(edgeInsets.top, 2.0); // Was 4 in legacy code
      expect(edgeInsets.bottom, 2.0); // Was 4 in legacy code
    });

    testWidgets('multiple items have consistent compact spacing',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Column(
            children: [
              ChecklistItemWidget(
                title: 'Item 1',
                isChecked: false,
                onChanged: (_) {},
              ),
              ChecklistItemWidget(
                title: 'Item 2',
                isChecked: true,
                onChanged: (_) {},
              ),
              ChecklistItemWidget(
                title: 'Item 3',
                isChecked: false,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      );

      // Find all CheckboxListTile widgets
      final checkboxTiles = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );

      // Verify all have the same compact padding
      for (final tile in checkboxTiles) {
        expect(
          tile.contentPadding,
          const EdgeInsets.symmetric(horizontal: 5),
        );
      }

      // Verify all outer paddings are consistent
      final allPaddings = tester.widgetList<Padding>(find.byType(Padding));
      final outerPaddings = allPaddings.where(
        (padding) =>
            padding.padding is EdgeInsets &&
            (padding.padding as EdgeInsets).top == 2 &&
            (padding.padding as EdgeInsets).bottom == 2 &&
            (padding.padding as EdgeInsets).horizontal == 0,
      );

      // Should have 3 items with correct outer padding
      expect(outerPaddings.length, 3);
    });

    testWidgets('vertical space per item is 2+2=4px total', (tester) async {
      // outer padding (2 top, 2 bottom) + contentPadding (0 top, 0 bottom) = 4px vertical
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
          ),
        ),
      );

      final checkboxListTile =
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
      final contentPadding = checkboxListTile.contentPadding! as EdgeInsets;

      final paddingFinder = find.descendant(
        of: find.byType(ChecklistItemWidget),
        matching: find.byType(Padding),
      );
      final paddings = tester.widgetList<Padding>(paddingFinder);
      final outerPadding = paddings.firstWhere(
        (padding) =>
            padding.padding is EdgeInsets &&
            (padding.padding as EdgeInsets).top == 2,
      );
      final outerEdgeInsets = outerPadding.padding as EdgeInsets;

      // Total vertical space = outer + content
      final totalVertical = outerEdgeInsets.vertical + contentPadding.vertical;
      expect(totalVertical, 4.0);
    });
  });
}
