import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/features/tts/ui/widgets/tts_speed_selector.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('TtsSpeedSelector.formatSpeed', () {
    test('drops trailing zero for whole speeds, keeps decimals otherwise', () {
      expect(TtsSpeedSelector.formatSpeed(1), '1');
      expect(TtsSpeedSelector.formatSpeed(2), '2');
      expect(TtsSpeedSelector.formatSpeed(0.5), '0.5');
      expect(TtsSpeedSelector.formatSpeed(1.25), '1.25');
    });
  });

  // The toggle stacks an invisible bold ghost under each visible label, so a
  // plain find.text matches two Texts — the visible one is the Stack's last.
  Finder visible(String label) => find.text(label).last;

  Future<void> pump(
    WidgetTester tester, {
    required double value,
    required ValueChanged<double> onChanged,
    double width = 400,
  }) {
    return tester.pumpWidget(
      makeTestableWidget(
        // A bounded width is required by the fill-width (`expand`) toggle.
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: TtsSpeedSelector(value: value, onChanged: onChanged),
          ),
        ),
      ),
    );
  }

  testWidgets('renders every speed step', (tester) async {
    await pump(tester, value: 1, onChanged: (_) {});
    for (final speed in kTtsSpeedSequence) {
      expect(visible(TtsSpeedSelector.formatSpeed(speed)), findsOneWidget);
    }
  });

  testWidgets('reports the tapped speed', (tester) async {
    double? picked;
    await pump(tester, value: 1, onChanged: (v) => picked = v);

    await tester.tap(visible('1.5'));
    expect(picked, 1.5);
  });

  testWidgets('marks the active step teal + semibold, others quiet', (
    tester,
  ) async {
    await pump(tester, value: 1.5, onChanged: (_) {});

    final tokens = tester.element(find.byType(TtsSpeedSelector)).designTokens;
    final selected = tester.widget<Text>(visible('1.5'));
    final unselected = tester.widget<Text>(visible('1'));

    expect(selected.style?.color, tokens.colors.interactive.enabled);
    expect(selected.style?.fontWeight, FontWeight.w600);
    expect(unselected.style?.color, tokens.colors.text.mediumEmphasis);
  });

  testWidgets('announces the active step as a selected button', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, value: 1.5, onChanged: (_) {});

    expect(
      tester.getSemantics(find.bySemanticsLabel('1.5')),
      isSemantics(isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('1')),
      isSemantics(isButton: true, isSelected: false),
    );
    handle.dispose();
  });

  testWidgets('fits all seven steps at a phone width without overflowing', (
    tester,
  ) async {
    await pump(tester, value: 1, onChanged: (_) {}, width: 360);

    expect(tester.takeException(), isNull);
    expect(visible('0.5'), findsOneWidget);
    expect(visible('2'), findsOneWidget);
  });
}
