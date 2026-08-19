import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/tooltips/ds_tooltip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  // The overlay wraps the provided rich message in its own root span, so the
  // styled spans sit at unspecified depth — collect the text-bearing leaves.
  List<TextSpan> leaves(InlineSpan root) {
    final result = <TextSpan>[];
    root.visitChildren((span) {
      if (span is TextSpan && span.text != null) result.add(span);
      return true;
    });
    return result;
  }

  Future<TestGesture> hover(WidgetTester tester, Finder target) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(target));
    return gesture;
  }

  testWidgets('styles the tooltip as the design-system floating surface, '
      'not the stock grey slab', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Center(
          child: DsTooltip(
            message: 'Quiet fact',
            child: Text('target'),
          ),
        ),
      ),
    );

    final tokens = tester.element(find.text('target')).designTokens;
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    final decoration = tooltip.decoration! as BoxDecoration;
    expect(decoration.color, tokens.colors.background.level01);
    expect(
      decoration.borderRadius,
      BorderRadius.circular(tokens.radii.s),
    );
    expect(
      decoration.border,
      Border.all(color: tokens.colors.decorative.level01),
    );
    expect(decoration.boxShadow, isNotNull);
    expect(decoration.boxShadow, isNotEmpty);

    // The single-line form carries the reading ink itself.
    final gesture = await hover(tester, find.text('target'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));
    final rich = tester.widget<RichText>(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText() == 'Quiet fact',
      ),
    );
    expect(
      leaves(rich.text).single.style?.color,
      tokens.colors.text.highEmphasis,
    );
    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
  });

  testWidgets('the titled form leads with a semibold subject line and keeps '
      'the body a step quieter', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Center(
          child: DsTooltip(
            title: 'Tue, Aug 11',
            message: 'No entry',
            child: Text('target'),
          ),
        ),
      ),
    );

    final tokens = tester.element(find.text('target')).designTokens;
    final gesture = await hover(tester, find.text('target'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));

    final rich = tester.widget<RichText>(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText() == 'Tue, Aug 11\nNo entry',
      ),
    );
    final spans = leaves(rich.text);
    expect(spans.first.style?.color, tokens.colors.text.highEmphasis);
    expect(
      spans.first.style?.fontWeight,
      tokens.typography.weight.semiBold,
    );
    expect(spans.last.style?.color, tokens.colors.text.mediumEmphasis);
    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
  });

  testWidgets('waits ~300ms before showing, so a cursor crossing a dense '
      'strip does not strobe', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Center(
          child: DsTooltip(
            message: 'Quiet fact',
            child: Text('target'),
          ),
        ),
      ),
    );

    final gesture = await hover(tester, find.text('target'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Quiet fact', findRichText: true), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Quiet fact', findRichText: true), findsOneWidget);
    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
  });

  testWidgets('forwards preferBelow so callers can keep the tip off the row '
      'being read', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Center(
          child: DsTooltip(
            message: 'Quiet fact',
            preferBelow: false,
            child: Text('target'),
          ),
        ),
      ),
    );

    expect(
      tester.widget<Tooltip>(find.byType(Tooltip)).preferBelow,
      isFalse,
    );
  });
}
