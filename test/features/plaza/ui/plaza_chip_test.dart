import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/ui/plaza_chip.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
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
    await tester.tap(find.text('fly there'));
    expect(taps, 1);
  });
}
