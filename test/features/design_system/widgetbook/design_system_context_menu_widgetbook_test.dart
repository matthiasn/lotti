import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_context_menu_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemContextMenuWidgetbookComponent', () {
    testWidgets('builds the context menu overview use case', (tester) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemContextMenuWidgetbookComponent(),
        expectedName: 'Context menu',
      );

      expect(find.text('Context Menu Variants'), findsOneWidget);
      expect(find.byType(DesignSystemContextMenu), findsNWidgets(4));

      // The described variant: rows with a second line, a quiet row set
      // apart, on an outlined surface.
      final described = tester
          .widgetList<DesignSystemContextMenu>(
            find.byType(DesignSystemContextMenu),
          )
          .last;
      expect(described.outlined, isTrue);
      expect(described.items.first.description, 'What choosing item 1 does');
      expect(described.items.last.isQuiet, isTrue);
      expect(described.items.last.startsGroup, isTrue);
      expect(find.text('What choosing item 1 does'), findsOneWidget);

      // Its rows are live: a tap on a described row, and on the quiet one,
      // goes through without a throw.
      await tester.ensureVisible(find.text('Quiet item'));
      await tester.pump();
      await tester.tap(find.text('What choosing item 1 does'));
      await tester.tap(find.text('Quiet item'));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Interaction smoke: tapping the first DesignSystemContextMenu (interactive or not)
      // must not throw — covers tap plumbing on the overview page.
      await tester.tap(
        find.byType(DesignSystemContextMenu).first,
        warnIfMissed: false,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
