import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets('footer reservation grows with the large-button line height', (
    tester,
  ) async {
    double? standardReservation;
    double? scaledReservation;

    Future<void> pumpReservation(TextScaler textScaler) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              final reservation =
                  DesignSystemGlassActionFooter.reservedHeightFor(context);
              if (textScaler == TextScaler.noScaling) {
                standardReservation = reservation;
              } else {
                scaledReservation = reservation;
              }
              return const SizedBox.shrink();
            },
          ),
          mediaQueryData: MediaQueryData(textScaler: textScaler),
        ),
      );
    }

    await pumpReservation(TextScaler.noScaling);
    await pumpReservation(const TextScaler.linear(2));

    expect(
      standardReservation,
      DesignSystemGlassActionFooter.reservedHeight,
    );
    expect(scaledReservation, greaterThan(standardReservation!));
  });

  for (final dock in DesignSystemGlassStripDock.values) {
    testWidgets('a strip docked to the $dock edge draws its hairline on the '
        'inner edge, where content scrolls in', (tester) async {
      const contentKey = Key('glass-content');
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Align(
            alignment: Alignment.topCenter,
            child: DesignSystemGlassStrip(
              dock: dock,
              child: const SizedBox(key: contentKey, height: 40),
            ),
          ),
        ),
      );

      final strip = tester.getRect(find.byType(DesignSystemGlassStrip));
      final content = tester.getRect(find.byKey(contentKey));
      // A bottom bar's content starts below its 1px hairline; a top bar's
      // content ends above it.
      if (dock == DesignSystemGlassStripDock.bottom) {
        expect(content.top - strip.top, 1);
        expect(content.bottom, strip.bottom);
      } else {
        expect(content.top, strip.top);
        expect(strip.bottom - content.bottom, 1);
      }
    });
  }
}
