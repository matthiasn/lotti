import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_input_shader.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/onboarding/state/recording_style.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_recording_style_view.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const accent = Color(0xFF00C2A8);

  Future<void> pumpView(
    WidgetTester tester, {
    RecordingStyle selected = RecordingStyle.modern,
    void Function(RecordingStyle)? onSelect,
    bool tryingWithVoice = false,
    ValueChanged<bool>? onToggle,
    VoidCallback? onContinue,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        // The real flow hosts this inside the modal's Scaffold; mirror that so
        // the Material Switch finds its ancestor.
        Material(
          type: MaterialType.transparency,
          child: SizedBox(
            width: 390,
            height: 844,
            child: OnboardingRecordingStyleView(
              accent: accent,
              colorScheme: const ColorScheme.dark(),
              title: 'How should recording look?',
              explanation: 'Pick a style — change it any time in Settings.',
              analogueLabel: 'Analogue',
              modernLabel: 'Modern',
              tryWithVoiceLabel: 'Try with your voice',
              continueLabel: 'Continue',
              selected: selected,
              onSelect: onSelect ?? (_) {},
              tryingWithVoice: tryingWithVoice,
              onToggleTryWithVoice: onToggle ?? (_) {},
              onContinue: onContinue ?? () {},
              vu: -6,
              dBFS: -20,
              amplitudes: const [0.2, 0.5, 0.8, 0.4, 0.6],
            ),
          ),
        ),
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          disableAnimations: true,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders both styled pairs, the toggle and continue', (
    tester,
  ) async {
    await pumpView(tester);

    expect(find.text('How should recording look?'), findsOneWidget);
    expect(find.text('Modern'), findsOneWidget);
    expect(find.text('Analogue'), findsOneWidget);
    expect(find.text('Try with your voice'), findsOneWidget);
    expect(find.widgetWithText(DesignSystemButton, 'Continue'), findsOneWidget);

    // The modern pair shows the orb shader; the analogue pair the VU meter;
    // both pairs carry a waveform.
    expect(find.byType(AiVoiceInputShader), findsOneWidget);
    expect(find.byType(AnalogVuMeter), findsOneWidget);
    expect(find.byType(LiveWaveform), findsNWidgets(2));
  });

  testWidgets('the selected style shows the checked radio cue', (tester) async {
    await pumpView(tester); // default selection is modern
    // Exactly one card is selected at a time.
    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);
  });

  testWidgets('tapping a style card reports the selection', (tester) async {
    final picked = <RecordingStyle>[];
    await pumpView(tester, onSelect: picked.add);

    await tester.tap(find.text('Analogue'));
    await tester.tap(find.text('Modern'));
    expect(picked, [RecordingStyle.analogue, RecordingStyle.modern]);
  });

  testWidgets('a style card activates via the keyboard (focus + Enter)', (
    tester,
  ) async {
    final picked = <RecordingStyle>[];
    await pumpView(tester, onSelect: picked.add);

    // The cards are InkWells (not bare GestureDetectors), so they take focus
    // and respond to the activate key — operable for keyboard/switch users.
    // The Analogue label sits under the card's InkWell, so the enclosing focus
    // node is the card's.
    final focusNode = Focus.of(tester.element(find.text('Analogue')))
      ..requestFocus();
    await tester.pump();
    expect(focusNode.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(picked, [RecordingStyle.analogue]);
  });

  testWidgets('the try-with-voice switch reports its change', (tester) async {
    final toggles = <bool>[];
    await pumpView(tester, onToggle: toggles.add);

    await tester.tap(find.byType(Switch));
    expect(toggles, [true]);
  });

  testWidgets('Continue fires its callback', (tester) async {
    var continues = 0;
    await pumpView(tester, onContinue: () => continues++);

    await tester.tap(find.widgetWithText(DesignSystemButton, 'Continue'));
    expect(continues, 1);
  });
}
