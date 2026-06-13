import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/features/tts/ui/widgets/tts_speed_selector.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('TtsSpeedSelector.formatSpeed', () {
    test('drops trailing zero for whole speeds, keeps decimals otherwise', () {
      expect(TtsSpeedSelector.formatSpeed(1), '1×');
      expect(TtsSpeedSelector.formatSpeed(2), '2×');
      expect(TtsSpeedSelector.formatSpeed(0.5), '0.5×');
      expect(TtsSpeedSelector.formatSpeed(1.25), '1.25×');
    });
  });

  Future<void> pump(
    WidgetTester tester, {
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return tester.pumpWidget(
      makeTestableWidget(
        Center(
          child: TtsSpeedSelector(value: value, onChanged: onChanged),
        ),
      ),
    );
  }

  testWidgets('renders every speed step', (tester) async {
    await pump(tester, value: 1, onChanged: (_) {});
    for (final speed in kTtsSpeedSequence) {
      expect(find.text(TtsSpeedSelector.formatSpeed(speed)), findsOneWidget);
    }
  });

  testWidgets('reports the tapped speed', (tester) async {
    double? picked;
    await pump(tester, value: 1, onChanged: (v) => picked = v);

    await tester.tap(find.text('1.5×'));
    expect(picked, 1.5);
  });

  testWidgets('marks the active step as selected (not the others)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, value: 1.5, onChanged: (_) {});

    expect(
      tester.getSemantics(find.bySemanticsLabel('1.5×')),
      isSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('1×')),
      isSemantics(isSelected: false),
    );
    handle.dispose();
  });
}
