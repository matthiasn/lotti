import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DsPill', () {
    Future<void> pump(WidgetTester tester, Widget child) {
      return tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Theme(
            data: DesignSystemTheme.dark(),
            child: Scaffold(body: Center(child: child)),
          ),
        ),
      );
    }

    testWidgets('renders the label text', (tester) async {
      await pump(
        tester,
        const DsPill(variant: DsPillVariant.filled, label: 'Hello'),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('measures 28px tall', (tester) async {
      await pump(
        tester,
        const DsPill(variant: DsPillVariant.filled, label: 'Hi'),
      );

      final size = tester.getSize(find.byType(DsPill));
      expect(size.height, DsPill.height);
    });

    testWidgets('filled variant fills with surface.enabled', (tester) async {
      await pump(
        tester,
        const DsPill(variant: DsPillVariant.filled, label: 'Filled'),
      );

      final decorated = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(DsPill),
              matching: find.byType(DecoratedBox),
            ),
          )
          .first;
      final decoration = decorated.decoration as BoxDecoration;
      expect(decoration.color, dsTokensDark.colors.surface.enabled);
    });

    testWidgets('tinted variant uses pillColor at 18% alpha', (tester) async {
      const accent = Color(0xFFD65E5C);
      await pump(
        tester,
        const DsPill(
          variant: DsPillVariant.tinted,
          label: 'P0',
          color: accent,
        ),
      );

      final decoration =
          tester
                  .widgetList<DecoratedBox>(
                    find.descendant(
                      of: find.byType(DsPill),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .first
                  .decoration
              as BoxDecoration;
      expect(decoration.color, accent.withValues(alpha: 0.18));
    });

    testWidgets('outline variant draws a 50% alpha border', (tester) async {
      const accent = Color(0xFF4AB6E8);
      await pump(
        tester,
        const DsPill(
          variant: DsPillVariant.outline,
          label: 'Due',
          color: accent,
        ),
      );

      final decoration =
          tester
                  .widgetList<DecoratedBox>(
                    find.descendant(
                      of: find.byType(DsPill),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .first
                  .decoration
              as BoxDecoration;
      expect(decoration.border?.top.color, accent.withValues(alpha: 0.5));
    });

    testWidgets('muted variant paints a dashed border', (tester) async {
      await pump(
        tester,
        const DsPill(variant: DsPillVariant.muted, label: 'No estimate'),
      );

      // The muted variant uses CustomPaint instead of a DecoratedBox shell.
      expect(
        find.descendant(
          of: find.byType(DsPill),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );

      final richText = tester.widget<RichText>(
        find.descendant(
          of: find.byType(DsPill),
          matching: find.byType(RichText),
        ),
      );
      expect(richText.text.style?.fontStyle, FontStyle.italic);
    });

    testWidgets('fires onTap when tapped', (tester) async {
      var taps = 0;
      await pump(
        tester,
        DsPill(
          variant: DsPillVariant.filled,
          label: 'Tap me',
          onTap: () => taps++,
        ),
      );

      await tester.tap(find.byType(DsPill));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('omits InkWell when onTap is null', (tester) async {
      await pump(
        tester,
        const DsPill(variant: DsPillVariant.filled, label: 'Static'),
      );

      expect(
        find.descendant(
          of: find.byType(DsPill),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('renders leading and trailing slots', (tester) async {
      await pump(
        tester,
        const DsPill(
          variant: DsPillVariant.filled,
          label: 'Status',
          leading: Icon(Icons.circle, key: ValueKey('lead'), size: 14),
          trailing: Icon(Icons.expand_more, key: ValueKey('tail'), size: 14),
        ),
      );

      expect(find.byKey(const ValueKey('lead')), findsOneWidget);
      expect(find.byKey(const ValueKey('tail')), findsOneWidget);
    });
  });

  group('DsGhostChip', () {
    Future<void> pump(WidgetTester tester, Widget child) {
      return tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Theme(
            data: DesignSystemTheme.dark(),
            child: Scaffold(body: Center(child: child)),
          ),
        ),
      );
    }

    testWidgets('renders an add icon and forwards taps', (tester) async {
      var taps = 0;
      await pump(
        tester,
        DsGhostChip(label: 'Add label', onTap: () => taps++),
      );

      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.text('Add label'), findsOneWidget);

      await tester.tap(find.byType(DsGhostChip));
      await tester.pump();
      expect(taps, 1);
    });
  });
}
