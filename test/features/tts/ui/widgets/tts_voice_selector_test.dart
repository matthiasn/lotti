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

  testWidgets('opens on the selected voice gender and shows its five voices', (
    tester,
  ) async {
    await pump(tester, voiceId: 'F1', onChanged: (_) {});

    for (var i = 1; i <= 5; i++) {
      expect(find.text('Female $i'), findsOneWidget);
    }
    // The other gender's voices are hidden behind the toggle, not stacked.
    for (var i = 1; i <= 5; i++) {
      expect(find.text('Male $i'), findsNothing);
    }
  });

  testWidgets('opens on the male tab when a male voice is selected', (
    tester,
  ) async {
    await pump(tester, voiceId: 'M2', onChanged: (_) {});

    expect(find.text('Male 2'), findsOneWidget);
    expect(find.text('Female 1'), findsNothing);
  });

  testWidgets('the gender toggle swaps which voices are listed', (
    tester,
  ) async {
    await pump(tester, voiceId: 'F1', onChanged: (_) {});

    // The toggle renders the label twice (an invisible width-reserving ghost
    // plus the visible label on top); tap the visible one.
    await tester.tap(find.text('Male').last);
    await tester.pumpAndSettle();

    for (var i = 1; i <= 5; i++) {
      expect(find.text('Male $i'), findsOneWidget);
    }
    expect(find.text('Female 1'), findsNothing);
  });

  testWidgets('marks exactly the selected voice in the shown gender', (
    tester,
  ) async {
    await pump(tester, voiceId: 'F3', onChanged: (_) {});

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    // Only the five female rows render, so four are unselected.
    expect(find.byIcon(Icons.circle_outlined), findsNWidgets(4));
  });

  testWidgets('reports the tapped voice id after switching gender', (
    tester,
  ) async {
    String? picked;
    await pump(tester, voiceId: 'F1', onChanged: (id) => picked = id);

    await tester.tap(find.text('Male').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Male 3'));

    expect(picked, 'M3');
  });
}
