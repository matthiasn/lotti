import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/pairing_check_code_view.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpView(WidgetTester tester, {Key? codeKey}) =>
      tester.pumpWidget(
        makeTestableWidget(
          PairingCheckCodeView(
            code: '6BA-6DF',
            caption: "If it doesn't match, don't connect.",
            codeKey: codeKey,
          ),
        ),
      );

  group('PairingCheckCodeView', () {
    testWidgets('shows the code and what to do with it', (tester) async {
      await pumpView(tester);

      expect(find.text('6BA-6DF'), findsOneWidget);
      expect(find.text("If it doesn't match, don't connect."), findsOneWidget);
    });

    testWidgets('renders the code at heading rank, above its caption', (
      tester,
    ) async {
      // Both devices are asked to look identical; when the inviting side used
      // a smaller rank, the same string looked like two different values.
      await pumpView(tester);

      final tokens = tester
          .element(find.byType(PairingCheckCodeView))
          .designTokens;
      final code = tester.widget<Text>(find.text('6BA-6DF'));
      final caption = tester.widget<Text>(
        find.text("If it doesn't match, don't connect."),
      );

      expect(
        code.style?.fontSize,
        tokens.typography.styles.heading.heading1.fontSize,
      );
      // Mono: the code is a compare-me identifier, not prose, and both
      // sides must render the identical face.
      expect(code.style?.fontFamily, 'Inconsolata');
      expect(
        caption.style?.fontSize,
        tokens.typography.styles.body.bodySmall.fontSize,
      );
      expect(code.style!.fontSize, greaterThan(caption.style!.fontSize!));
    });

    testWidgets('names the value with an overline when asked', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const PairingCheckCodeView(
            code: '6BA-6DF',
            caption: 'Compare on both screens.',
            label: 'Check code',
          ),
        ),
      );

      // Uppercased into the overline register: without a name, six
      // characters between a QR and "paste this code there" read as the
      // thing to paste.
      expect(find.text('CHECK CODE'), findsOneWidget);
    });

    testWidgets('uses tabular figures so the digits align to compare', (
      tester,
    ) async {
      await pumpView(tester);

      expect(
        tester.widget<Text>(find.text('6BA-6DF')).style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    testWidgets('applies codeKey to the code itself', (tester) async {
      await pumpView(tester, codeKey: const Key('check_code'));

      expect(
        tester.widget<Text>(find.byKey(const Key('check_code'))).data,
        '6BA-6DF',
      );
    });
  });
}
