import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/widgets/sync_well.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  BoxDecoration decorationOf(WidgetTester tester) =>
      tester
              .widget<DecoratedBox>(
                find.descendant(
                  of: find.byType(SyncWell),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .decoration
          as BoxDecoration;

  group('SyncWell', () {
    testWidgets('recesses content one level below the sheet surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(const SyncWell(child: Text('content'))),
      );

      final tokens = tester.element(find.byType(SyncWell)).designTokens;
      final decoration = decorationOf(tester);
      // Level 01 on a level-02 sheet: an inset, not an elevation — so no
      // border and no shadow by default.
      expect(decoration.color, tokens.colors.background.level01);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(tokens.radii.m),
      );
      expect(decoration.border, isNull);
      expect(decoration.boxShadow, isNull);
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('a toned border turns the well into a credential frame', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) => SyncWell(
              borderColor:
                  context.designTokens.colors.alert.warning.defaultColor,
              child: const Text('secret'),
            ),
          ),
        ),
      );

      final tokens = tester.element(find.byType(SyncWell)).designTokens;
      final border = decorationOf(tester).border! as Border;
      expect(border.top.color, tokens.colors.alert.warning.defaultColor);
    });

    testWidgets('honours a custom radius and padding', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) {
              final tokens = context.designTokens;
              return SyncWell(
                radius: tokens.radii.sectionCards,
                padding: EdgeInsets.all(tokens.spacing.step6),
                child: const Text('padded'),
              );
            },
          ),
        ),
      );

      final tokens = tester.element(find.byType(SyncWell)).designTokens;
      expect(
        decorationOf(tester).borderRadius,
        BorderRadius.circular(tokens.radii.sectionCards),
      );
      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(SyncWell),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, EdgeInsets.all(tokens.spacing.step6));
    });
  });
}
