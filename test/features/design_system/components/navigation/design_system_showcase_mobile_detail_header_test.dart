import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_showcase_mobile_detail_header.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Widget wrap(Widget child) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(
          body: Center(child: child),
        ),
      ),
    );
  }

  group('DesignSystemShowcaseMobileDetailHeader', () {
    testWidgets('renders the Figma back control styling', (tester) async {
      await tester.pumpWidget(
        wrap(
          const DesignSystemShowcaseMobileDetailHeader(
            foregroundColor: Colors.white,
          ),
        ),
      );
      await tester.pump();

      final backText = tester.widget<Text>(find.text('Back'));

      expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
      expect(backText.style?.fontSize, 14);
      expect(backText.style?.fontWeight, FontWeight.w400);
      expect(backText.style?.height, closeTo(20 / 14, 0.001));
    });

    testWidgets('invokes onBack when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrap(
          DesignSystemShowcaseMobileDetailHeader(
            foregroundColor: Colors.white,
            onBack: () => tapped = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Back'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
