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

    testWidgets('sits one level above the page surface', (
      tester,
    ) async {
      // An opaque shelf, visibly distinct from the page it pins to — as page
      // background it read as content sliced by an invisible edge.
      await pumpBar(tester);

      final tokens = tester.element(find.byType(SyncStickyBar)).designTokens;
      expect(
        decorationOf(tester).color,
        tokens.colors.background.level02,
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

    testWidgets('takes its edge colour from the divider token', (tester) async {
      // A decorative stroke, not text ink: borders share the divider token so
      // they cannot drift from every other hairline.
      await pumpBar(tester);

      final tokens = tester.element(find.byType(SyncStickyBar)).designTokens;
      expect(
        (decorationOf(tester).border! as Border).top.color,
        tokens.colors.decorative.level01,
      );
    });
  });
}
