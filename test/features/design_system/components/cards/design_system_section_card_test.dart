import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<BuildContext> pumpCard(
    WidgetTester tester, {
    VoidCallback? onTap,
    EdgeInsets? padding,
    EdgeInsets? margin,
    Widget child = const Text('body'),
  }) async {
    late BuildContext captured;
    await tester.pumpWidget(
      makeTestableWidget(
        Builder(
          builder: (context) {
            captured = context;
            return DesignSystemSectionCard(
              onTap: onTap,
              padding: padding,
              margin: margin,
              child: child,
            );
          },
        ),
      ),
    );
    await tester.pump();
    return captured;
  }

  BoxDecoration decorationOf(WidgetTester tester) {
    final decoratedBox = tester.widget<DecoratedBox>(
      find.byType(DecoratedBox).first,
    );
    return decoratedBox.decoration as BoxDecoration;
  }

  testWidgets(
    'renders a flat level02 surface with radii.l corners and a '
    'decorative hairline border',
    (tester) async {
      final context = await pumpCard(tester);
      expect(find.text('body'), findsOneWidget);

      final tokens = context.designTokens;
      final decoration = decorationOf(tester);
      expect(decoration.color, tokens.colors.background.level02);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(tokens.radii.l),
      );
      expect(
        decoration.border,
        Border.all(color: tokens.colors.decorative.level01),
      );
      expect(decoration.gradient, isNull);
      // Flat by design: no shadow, matching the list-card treatment.
      expect(decoration.boxShadow, isNull);
    },
  );

  testWidgets('defaults to step5 padding and honors an override', (
    tester,
  ) async {
    final context = await pumpCard(tester);
    final defaultPadding = tester.widget<Padding>(
      find
          .ancestor(of: find.text('body'), matching: find.byType(Padding))
          .first,
    );
    expect(
      defaultPadding.padding,
      EdgeInsets.all(context.designTokens.spacing.step5),
    );

    const custom = EdgeInsets.fromLTRB(1, 2, 3, 4);
    await pumpCard(tester, padding: custom);
    final overridden = tester.widget<Padding>(
      find
          .ancestor(of: find.text('body'), matching: find.byType(Padding))
          .first,
    );
    expect(overridden.padding, custom);
  });

  testWidgets('margin wraps the card only when provided', (tester) async {
    await pumpCard(tester);
    expect(
      find.ancestor(
        of: find.byType(DecoratedBox).first,
        matching: find.byType(Padding),
      ),
      findsNothing,
    );

    const margin = EdgeInsets.all(9);
    await pumpCard(tester, margin: margin);
    final marginPadding = tester.widget<Padding>(
      find
          .ancestor(
            of: find.byType(DecoratedBox).first,
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(marginPadding.padding, margin);
  });

  testWidgets('without onTap, no InkWell is rendered', (tester) async {
    await pumpCard(tester);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('onTap fires and renders an InkWell', (tester) async {
    var tapped = 0;
    await pumpCard(tester, onTap: () => tapped++);
    expect(find.byType(InkWell), findsOneWidget);

    await tester.tap(find.text('body'));
    // Only the InkWell ripple animates here; a bounded pump avoids
    // pumpAndSettle's timeout risk.
    await tester.pump(const Duration(milliseconds: 200));
    expect(tapped, 1);
  });
}
