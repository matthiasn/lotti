import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/popovers/design_system_popover_anchor.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemPopoverAnchor', () {
    Widget subject({double? width, Widget? child}) => Align(
      alignment: Alignment.topLeft,
      child: DesignSystemPopoverAnchor(
        semanticsLabel: 'Options',
        width: width ?? DesignSystemContextMenu.defaultWidth,
        builder: (context, {required toggle, required isOpen}) => TextButton(
          onPressed: toggle,
          child: Text(isOpen ? 'Close' : 'Open'),
        ),
        child: child ?? const Text('Content'),
      ),
    );

    testWidgets('the trigger toggles the content on its surface', (
      tester,
    ) async {
      await tester.pumpWidget(makeTestableWidgetWithScaffold(subject()));

      expect(find.text('Content'), findsNothing);
      expect(find.byType(DesignSystemPopoverSurface), findsNothing);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget, reason: 'isOpen reported');
      expect(
        tester.getSize(find.byType(DesignSystemPopoverSurface)).width,
        DesignSystemContextMenu.defaultWidth,
      );
      expect(
        tester.getSemantics(find.byType(DesignSystemPopoverSurface)).label,
        startsWith('Options'),
      );

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('content interaction leaves it open; outside tap closes', (
      tester,
    ) async {
      var presses = 0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          subject(
            child: TextButton(
              onPressed: () => presses++,
              child: const Text('Inside'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Inside'));
      await tester.pumpAndSettle();
      expect(presses, 1);
      expect(
        find.text('Inside'),
        findsOneWidget,
        reason: 'The content decides when it is done, not the popover.',
      );

      await tester.tapAt(const Offset(700, 500));
      await tester.pumpAndSettle();
      expect(find.text('Inside'), findsNothing);
    });

    testWidgets('a caller can widen the surface', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(subject(width: 420)),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(DesignSystemPopoverSurface)).width,
        420,
      );
    });
  });
}
