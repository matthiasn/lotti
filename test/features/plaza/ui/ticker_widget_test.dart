import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:lotti/features/plaza/ui/ticker_widget.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

const _text = 'Project Waddle   ·   7 need attention   ·   3 in progress';

Widget _host({double heightMeters = 1.9, double pxPerMeter = 40}) =>
    makeTestableWidget2(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width:
              TickerWidget.periodMeters(_text, heightMeters, 12) * pxPerMeter,
          height: heightMeters * pxPerMeter,
          child: TickerWidget(
            text: _text,
            heightMeters: heightMeters,
            pxPerMeter: pxPerMeter,
          ),
        ),
      ),
    );

void main() {
  testWidgets('one period: the text once, from the left, and nothing moves', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(find.text(_text), findsOneWidget);
    final text = tester.widget<Text>(find.text(_text));
    expect(text.style!.fontSize, closeTo(1.9 * 40 * 0.62, 1e-9));
    expect(text.style!.color, PlazaStyle.teal);
    expect(text.maxLines, 1);
    expect(text.softWrap, isFalse);
    // Flush left: the gap is on the right, where the next period begins.
    expect(tester.getTopLeft(find.text(_text)).dx, 0);
    expect(find.byType(ValueListenableBuilder<double>), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getTopLeft(find.text(_text)).dx, 0);
  });

  test('the period is the text plus a gap: four glyphs or half the band', () {
    final text = TickerWidget.textMeters(_text, 1.9);
    expect(text, greaterThan(0));
    // A narrow band: the gap is four glyph heights.
    expect(
      TickerWidget.periodMeters(_text, 1.9, 4),
      closeTo(text + 4 * 1.9 * TickerWidget.glyphFraction, 1e-9),
    );
    // A wide band: half its width.
    expect(TickerWidget.periodMeters(_text, 1.9, 40), closeTo(text + 20, 1e-9));
    // Type scales with the band: twice the height, twice the width.
    expect(TickerWidget.textMeters(_text, 3.8), closeTo(2 * text, 1e-6));
    expect(TickerWidget.textMeters('', 1.9), 0);
  });
}
