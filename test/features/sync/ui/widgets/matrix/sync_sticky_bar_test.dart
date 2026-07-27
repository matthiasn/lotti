import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_sticky_bar.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester) => tester.pumpWidget(
    makeTestableWidget(
      const SyncStickyBar(child: Text('Send settings')),
    ),
  );

  BoxDecoration decorationOf(WidgetTester tester) =>
      tester
              .widget<DecoratedBox>(
                find.descendant(
                  of: find.byType(SyncStickyBar),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .decoration
          as BoxDecoration;

  group('SyncStickyBar', () {
    testWidgets('renders its action', (tester) async {
      await pumpBar(tester);
      expect(find.text('Send settings'), findsOneWidget);
    });

    testWidgets('draws a top edge so scrolled content is not sliced', (
      tester,
    ) async {
      // As a bare surface-coloured box over a body painted the same colour, a
      // sentence cut off underneath read as a truncation bug, not an edge.
      await pumpBar(tester);

      final border = decorationOf(tester).border!;
      expect(border.top.style, BorderStyle.solid);
      expect(border.bottom.style, BorderStyle.none);
    });

    testWidgets('sits on the surface colour, not a tinted panel', (
      tester,
    ) async {
      await pumpBar(tester);

      final context = tester.element(find.byType(SyncStickyBar));
      expect(
        decorationOf(tester).color,
        Theme.of(context).colorScheme.surface,
      );
    });

    testWidgets('pads its action to the modal page rail', (tester) async {
      await pumpBar(tester);

      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(SyncStickyBar),
          matching: find.byType(Padding),
        ),
      );
      expect(padding.padding, WoltModalConfig.pagePadding);
    });

    testWidgets('takes its edge colour from the design system', (tester) async {
      await pumpBar(tester);

      final tokens = tester.element(find.byType(SyncStickyBar)).designTokens;
      expect(
        (decorationOf(tester).border! as Border).top.color,
        tokens.colors.text.lowEmphasis,
      );
    });
  });
}
