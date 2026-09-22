import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/ds_menu_glyph.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

const _ink = Color(0xFF00AA88);

Future<void> _pump(
  WidgetTester tester, {
  double size = 24,
  Color color = _ink,
  TextDirection direction = TextDirection.ltr,
}) => tester.pumpWidget(
  makeTestableWidgetWithScaffold(
    Directionality(
      textDirection: direction,
      child: IconTheme(
        data: IconThemeData(size: size, color: color),
        child: const DsMenuGlyph(),
      ),
    ),
  ),
);

Finder get _paint => find.descendant(
  of: find.byType(DsMenuGlyph),
  matching: find.byType(CustomPaint),
);

void main() {
  group('DsMenuGlyph', () {
    testWidgets('occupies a square of the ambient icon size', (tester) async {
      await _pump(tester, size: 32);

      expect(tester.getSize(find.byType(DsMenuGlyph)), const Size.square(32));
    });

    testWidgets('draws a long stroke over a short one, both from the leading '
        'edge, in the ambient colour', (tester) async {
      await _pump(tester);

      // In a 24 box: strokes 3 thick, so round caps start 1.5 in; the long
      // stroke spans the box, the short one two thirds of it; their centres
      // sit 11 apart around the middle.
      expect(
        _paint,
        paints
          ..line(
            p1: const Offset(1.5, 6.5),
            p2: const Offset(22.5, 6.5),
            color: _ink,
            strokeWidth: 3,
          )
          ..line(
            p1: const Offset(1.5, 17.5),
            p2: const Offset(14.5, 17.5),
            color: _ink,
            strokeWidth: 3,
          ),
      );
    });

    testWidgets('rounds the ends of both strokes', (tester) async {
      await _pump(tester);

      // `paints..line` cannot see the cap, so read it off each drawLine call.
      bool roundCapped(Symbol method, List<dynamic> arguments) =>
          method == #drawLine &&
          (arguments[2] as Paint).strokeCap == StrokeCap.round;

      expect(
        _paint,
        paints
          ..something(roundCapped)
          ..something(roundCapped),
      );
    });

    testWidgets('mirrors under a right-to-left reading direction', (
      tester,
    ) async {
      await _pump(tester, direction: TextDirection.rtl);

      expect(
        _paint,
        paints
          ..line(p1: const Offset(22.5, 6.5), p2: const Offset(1.5, 6.5))
          ..line(p1: const Offset(22.5, 17.5), p2: const Offset(9.5, 17.5)),
      );
    });

    testWidgets('scales its strokes with the icon size', (tester) async {
      await _pump(tester, size: 48);

      expect(
        _paint,
        paints
          ..line(
            p1: const Offset(3, 13),
            p2: const Offset(45, 13),
            strokeWidth: 6,
          )
          ..line(
            p1: const Offset(3, 35),
            p2: const Offset(29, 35),
            strokeWidth: 6,
          ),
      );
    });

    testWidgets('repaints in the new colour when the icon theme changes', (
      tester,
    ) async {
      await _pump(tester);
      await _pump(tester, color: const Color(0xFFCC3300));

      expect(
        _paint,
        paints
          ..line(color: const Color(0xFFCC3300))
          ..line(color: const Color(0xFFCC3300)),
      );
    });

    testWidgets('does not repaint for an identical theme', (tester) async {
      await _pump(tester);
      final painter = tester.widget<CustomPaint>(_paint).painter!;

      await _pump(tester);
      final rebuilt = tester.widget<CustomPaint>(_paint).painter!;

      expect(rebuilt.shouldRepaint(painter), isFalse);
    });
  });
}
