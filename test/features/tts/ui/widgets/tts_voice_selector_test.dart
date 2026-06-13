import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/ui/widgets/tts_voice_selector.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required String voiceId,
    required ValueChanged<String> onChanged,
  }) {
    return tester.pumpWidget(
      makeTestableWidget(
        TtsVoiceSelector(voiceId: voiceId, onChanged: onChanged),
      ),
    );
  }

  testWidgets('lists all ten voices grouped female then male', (tester) async {
    await pump(tester, voiceId: 'F1', onChanged: (_) {});

    for (var i = 1; i <= 5; i++) {
      expect(find.text('Female $i'), findsOneWidget);
      expect(find.text('Male $i'), findsOneWidget);
    }
    // The two group headers (exact 'Female' / 'Male', distinct from the rows).
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('Male'), findsOneWidget);
  });

  testWidgets('marks exactly the selected voice with a filled check', (
    tester,
  ) async {
    await pump(tester, voiceId: 'F3', onChanged: (_) {});

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.circle_outlined), findsNWidgets(9));
  });

  testWidgets('reports the tapped voice id', (tester) async {
    String? picked;
    await pump(tester, voiceId: 'F1', onChanged: (id) => picked = id);

    await tester.tap(find.text('Male 3'));
    expect(picked, 'M3');
  });
}
