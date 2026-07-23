import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list_corners.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpList(
    WidgetTester tester, {
    List<Widget> children = const [Text('Row 1'), Text('Row 2')],
  }) {
    return tester.pumpWidget(
      makeTestableWidget2(
        Theme(
          data: DesignSystemTheme.dark(),
          child: Scaffold(
            body: DesignSystemGroupedList(
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  BorderRadius? cornersOf(WidgetTester tester, String text) =>
      DesignSystemGroupedListCorners.maybeOf(tester.element(find.text(text)));

  group('DesignSystemGroupedList', () {
    testWidgets('paints token background, border, and corner radius', (
      tester,
    ) async {
      await pumpList(tester);

      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(DesignSystemGroupedList),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, dsTokensDark.colors.background.level02);
      expect(
        decoration.border!.top.color,
        dsTokensDark.colors.decorative.level01,
      );
      expect(
        decoration.borderRadius,
        BorderRadius.circular(dsTokensDark.radii.m),
      );
    });

    testWidgets('clips children with the same radius and renders them all', (
      tester,
    ) async {
      await pumpList(tester);

      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(DesignSystemGroupedList),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(dsTokensDark.radii.m));
      expect(find.text('Row 1'), findsOneWidget);
      expect(find.text('Row 2'), findsOneWidget);
    });

    testWidgets('applies the horizontal step5 outer padding', (tester) async {
      await pumpList(tester);

      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(DesignSystemGroupedList),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(
        padding.padding,
        EdgeInsets.symmetric(horizontal: dsTokensDark.spacing.step5),
      );
    });

    testWidgets('outline-only variant leaves the host surface unpainted', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.dark(),
            child: const Scaffold(
              body: DesignSystemGroupedList(
                filled: false,
                children: [Text('Outlined row')],
              ),
            ),
          ),
        ),
      );

      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(DesignSystemGroupedList),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, isNull);
      expect(
        decoration.border!.top.color,
        dsTokensDark.colors.decorative.level01,
      );
    });
  });

  group('DesignSystemGroupedList corner scopes', () {
    testWidgets('first child owns only the top corners', (tester) async {
      await pumpList(
        tester,
        children: const [Text('First'), Text('Middle'), Text('Last')],
      );

      expect(
        cornersOf(tester, 'First'),
        BorderRadius.vertical(top: Radius.circular(dsTokensDark.radii.m)),
      );
    });

    testWidgets('middle children get no corner scope', (tester) async {
      await pumpList(
        tester,
        children: const [Text('First'), Text('Middle'), Text('Last')],
      );

      expect(cornersOf(tester, 'Middle'), isNull);
    });

    testWidgets('last child owns only the bottom corners', (tester) async {
      await pumpList(
        tester,
        children: const [Text('First'), Text('Middle'), Text('Last')],
      );

      expect(
        cornersOf(tester, 'Last'),
        BorderRadius.vertical(bottom: Radius.circular(dsTokensDark.radii.m)),
      );
    });

    testWidgets('a sole child owns all four corners', (tester) async {
      await pumpList(tester, children: const [Text('Only')]);

      expect(
        cornersOf(tester, 'Only'),
        BorderRadius.circular(dsTokensDark.radii.m),
      );
    });
  });
}
