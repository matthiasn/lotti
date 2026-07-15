import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';

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
}
