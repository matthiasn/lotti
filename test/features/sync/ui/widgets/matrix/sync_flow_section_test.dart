import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_flow_section.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  DsTokens tokensOf(WidgetTester tester) =>
      tester.element(find.byType(SyncFlowSection)).designTokens;

  group('SyncFlowSection', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SyncFlowSection(
            child: Text('Section Content'),
          ),
        ),
      );

      expect(find.text('Section Content'), findsOneWidget);
    });

    testWidgets('delegates its surface to the design-system section card', (
      tester,
    ) async {
      // The whole point of the delegation: every sync card restyles with the
      // design system instead of holding a colorScheme + literal-alpha copy.
      // Padding is zeroed on the card so the accent bar can use the gutter.
      await tester.pumpWidget(
        makeTestableWidget(
          const SyncFlowSection(
            child: Text('Content'),
          ),
        ),
      );

      final card = tester.widget<DesignSystemSectionCard>(
        find.byType(DesignSystemSectionCard),
      );
      expect(card.padding, EdgeInsets.zero);
    });

    testWidgets('applies the card-padding token by default', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SyncFlowSection(
            child: Text('Content'),
          ),
        ),
      );

      final tokens = tokensOf(tester);
      final padding = tester.widget<Padding>(find.byType(Padding).last);
      expect(padding.padding, EdgeInsets.all(tokens.spacing.cardPadding));
    });

    testWidgets('accepts custom padding', (tester) async {
      const customPadding = EdgeInsets.symmetric(horizontal: 8);

      await tester.pumpWidget(
        makeTestableWidget(
          const SyncFlowSection(
            padding: customPadding,
            child: Text('Content'),
          ),
        ),
      );

      final padding = tester.widget<Padding>(find.byType(Padding).last);
      expect(padding.padding, customPadding);
    });

    testWidgets('draws the accent bar in the padding gutter', (tester) async {
      // A flagged card must keep the exact content rail of its unflagged
      // siblings — the bar rides the gutter, not the content column.
      await tester.pumpWidget(
        makeTestableWidget(
          const SyncFlowSection(
            accentColor: Colors.amber,
            child: Text('Content'),
          ),
        ),
      );

      final tokens = tokensOf(tester);
      final bar = tester.widget<DecoratedBox>(
        find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == Colors.amber,
        ),
      );
      expect(
        (bar.decoration as BoxDecoration).borderRadius,
        BorderRadius.circular(tokens.radii.badgesPills),
      );

      final positioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.byWidget(bar),
          matching: find.byType(Positioned),
        ),
      );
      expect(
        positioned.left,
        (tokens.spacing.cardPadding - tokens.spacing.step2) / 2,
      );

      // And the content rail is unchanged: same default padding as an
      // unflagged card.
      final padding = tester.widget<Padding>(find.byType(Padding).last);
      expect(padding.padding, EdgeInsets.all(tokens.spacing.cardPadding));
    });
  });
}
