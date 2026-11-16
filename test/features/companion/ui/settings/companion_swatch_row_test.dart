import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/ui/settings/companion_swatch_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const swatch = TapTargets.minimum;
  const gap = 8.0;
  double widthOf(int n) => n * swatch + (n - 1) * gap;

  group('companionSwatchRowWidth', () {
    test('all of them where they fit one row', () {
      expect(
        companionSwatchRowWidth(count: 7, available: 600, gap: gap),
        widthOf(7),
      );
      // Exactly: the last gap is not needed.
      expect(
        companionSwatchRowWidth(count: 7, available: widthOf(7), gap: gap),
        widthOf(7),
      );
    });

    test('shared out evenly where they do not: nine as five and four, '
        'seven as four and three — never a lone one left over', () {
      // Room for eight: nine would break eight and one.
      expect(
        companionSwatchRowWidth(count: 9, available: widthOf(8), gap: gap),
        widthOf(5),
      );
      // Room for six: seven would break six and one.
      expect(
        companionSwatchRowWidth(count: 7, available: widthOf(6), gap: gap),
        widthOf(4),
      );
      // Room for four: nine take three rows of three.
      expect(
        companionSwatchRowWidth(count: 9, available: widthOf(4), gap: gap),
        widthOf(3),
      );
    });

    test('never narrower than one swatch, however little room', () {
      expect(
        companionSwatchRowWidth(count: 5, available: 10, gap: gap),
        widthOf(1),
      );
    });

    test('unbounded room, or none to lay out, is one row', () {
      expect(
        companionSwatchRowWidth(
          count: 9,
          available: double.infinity,
          gap: gap,
        ),
        widthOf(9),
      );
      expect(
        companionSwatchRowWidth(count: 0, available: 300, gap: gap),
        widthOf(0),
      );
    });
  });

  group('CompanionSwatchRow', () {
    final colours = [
      for (var i = 0; i < 9; i++)
        (value: i, colour: Color(0xFF000000 + i * 0x101010), label: 'Tone $i'),
    ];

    Future<List<int>> pump(WidgetTester tester, double width) async {
      final picked = <int>[];
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: CompanionSwatchRow<int>(
                  swatches: colours,
                  selected: 2,
                  onSelected: picked.add,
                ),
              ),
            ),
          ),
        ),
      );
      return picked;
    }

    List<int> rows(WidgetTester tester) {
      final tops = <double, int>{};
      for (var i = 0; i < 9; i++) {
        final top = tester
            .getTopLeft(find.byKey(ValueKey('companionSwatch-$i')))
            .dy;
        tops[top] = (tops[top] ?? 0) + 1;
      }
      return tops.values.toList();
    }

    testWidgets('nine swatches with room for eight break five and four', (
      tester,
    ) async {
      final gap = await _gap(tester);
      await pump(tester, 8 * swatch + 7 * gap);

      expect(rows(tester), [5, 4]);
    });

    testWidgets('with room for all they stand in one row', (tester) async {
      await pump(tester, 600);

      expect(rows(tester), [9]);
    });

    testWidgets('a tap picks its swatch, and each says its name and whether '
        'it is the one selected', (tester) async {
      final picked = await pump(tester, 600);

      await tester.tap(find.byKey(const ValueKey('companionSwatch-4')));
      expect(picked, [4]);

      final selected = tester.getSemantics(
        find.byKey(const ValueKey('companionSwatch-2')),
      );
      final other = tester.getSemantics(
        find.byKey(const ValueKey('companionSwatch-4')),
      );
      expect(selected.label, 'Tone 2');
      expect(selected.flagsCollection.isSelected.toBoolOrNull(), isTrue);
      expect(other.label, 'Tone 4');
      expect(other.flagsCollection.isSelected.toBoolOrNull(), isFalse);
    });
  });
}

/// The design system's gap between two swatches.
Future<double> _gap(WidgetTester tester) async {
  late double gap;
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Builder(
        builder: (context) {
          gap = context.designTokens.spacing.step2;
          return const SizedBox();
        },
      ),
    ),
  );
  return gap;
}
