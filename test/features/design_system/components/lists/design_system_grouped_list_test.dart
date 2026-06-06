import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpList(WidgetTester tester) {
    return tester.pumpWidget(
      makeTestableWidget2(
        Theme(
          data: DesignSystemTheme.dark(),
          child: const Scaffold(
            body: DesignSystemGroupedList(
              children: [Text('Row 1'), Text('Row 2')],
            ),
          ),
        ),
      ),
    );
  }

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
  });
}
