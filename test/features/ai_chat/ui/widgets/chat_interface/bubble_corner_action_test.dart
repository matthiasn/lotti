import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/bubble_corner_action.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('BubbleCornerAction', () {
    testWidgets('renders the icon inside a circular elevated surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          BubbleCornerAction(
            tooltip: 'Copy message',
            icon: Icons.copy,
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.copy), findsOneWidget);

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(BubbleCornerAction),
          matching: find.byType(Material),
        ),
      );
      expect(material.shape, const CircleBorder());
      expect(material.elevation, 2);

      final inkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(BubbleCornerAction),
          matching: find.byType(InkWell),
        ),
      );
      expect(inkWell.customBorder, const CircleBorder());
    });

    testWidgets('exposes the tooltip message', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          BubbleCornerAction(
            tooltip: 'Copy message',
            icon: Icons.copy,
            onTap: () {},
          ),
        ),
      );

      expect(find.byTooltip('Copy message'), findsOneWidget);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        makeTestableWidget(
          BubbleCornerAction(
            tooltip: 'Copy message',
            icon: Icons.copy,
            onTap: () => tapCount++,
          ),
        ),
      );

      await tester.tap(find.byType(BubbleCornerAction));
      // Drain the ink ripple with a bounded pump.
      await tester.pump(const Duration(milliseconds: 300));

      expect(tapCount, 1);
    });
  });
}
