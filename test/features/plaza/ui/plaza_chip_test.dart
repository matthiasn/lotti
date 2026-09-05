import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/ui/plaza_chip.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    builder: LegacyMaterialBridge.builder,
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('every measure is a fraction of the font size', (tester) async {
    await tester.pumpWidget(
      host(
        const PlazaChip(
          label: 'OPEN',
          fill: Color(0xFF123456),
          ink: Color(0xFFABCDEF),
          fontPx: 20,
        ),
      ),
    );
    final container = tester.widget<Container>(find.byType(Container));
    expect(
      container.padding,
      const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFF123456));
    expect(decoration.borderRadius, BorderRadius.circular(7));
    final text = tester.widget<Text>(find.text('OPEN'));
    expect(text.style!.fontSize, 20);
    expect(text.style!.fontWeight, FontWeight.w700);
    expect(text.style!.letterSpacing, 1);
    expect(text.style!.color, const Color(0xFFABCDEF));
    expect(text.style!.fontFamily, PlazaStyle.fontText);
    // A plain chip is not a button.
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('with onTap it is a button that reports the tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        PlazaChip(
          label: 'fly there',
          fill: PlazaStyle.teal,
          ink: Colors.black,
          fontPx: 12,
          onTap: () => taps++,
        ),
      ),
    );
    final ink = tester.widget<InkWell>(find.byType(InkWell));
    expect(ink.hoverColor, PlazaStyle.tealHover);
    expect(ink.borderRadius!.topLeft.x, closeTo(4.2, 1e-9));
    // The fill is ink on the Material, under the hover wash, not a
    // Container over it.
    expect(find.byType(Container), findsNothing);
    final fill = tester.widget<Ink>(find.byType(Ink));
    expect((fill.decoration! as BoxDecoration).color, PlazaStyle.teal);
    final padding = fill.padding! as EdgeInsets;
    expect(padding.left, closeTo(9.6, 1e-9));
    expect(padding.top, closeTo(3, 1e-9));
    await tester.tap(find.text('fly there'));
    expect(taps, 1);
  });
}
