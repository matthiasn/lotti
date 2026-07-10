import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_input_shader.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/state/recording_style.dart';
import 'package:lotti/features/onboarding/ui/widgets/recording_style_picker.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const accent = Color(0xFF00C2A8);

  Future<void> pumpPicker(
    WidgetTester tester, {
    RecordingStyle selected = RecordingStyle.modern,
    void Function(RecordingStyle)? onSelect,
    bool tryingWithVoice = false,
    ValueChanged<bool>? onToggle,
    double vu = -6,
    double dBFS = -20,
    List<double> amplitudes = const [0.2, 0.5, 0.8, 0.4, 0.6],
    DsTokens surfaceTokens = dsTokensDark,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        Material(
          type: MaterialType.transparency,
          child: SizedBox(
            width: 390,
            height: 844,
            child: SingleChildScrollView(
              child: RecordingStylePicker(
                accent: accent,
                colorScheme: const ColorScheme.dark(),
                surfaceTokens: surfaceTokens,
                analogueLabel: 'Analogue',
                modernLabel: 'Modern',
                tryWithVoiceLabel: 'Try with your voice',
                selected: selected,
                onSelect: onSelect ?? (_) {},
                tryingWithVoice: tryingWithVoice,
                onToggleTryWithVoice: onToggle ?? (_) {},
                vu: vu,
                dBFS: dBFS,
                amplitudes: amplitudes,
              ),
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

  testWidgets('renders both styled pairs and the try-with-voice toggle', (
    tester,
  ) async {
    await pumpPicker(tester);

    expect(find.text('Modern'), findsOneWidget);
    expect(find.text('Analogue'), findsOneWidget);
    expect(find.text('Try with your voice'), findsOneWidget);

    // The modern pair shows the orb shader; the analogue pair the VU meter;
    // both pairs carry a waveform.
    expect(find.byType(AiVoiceInputShader), findsOneWidget);
    expect(find.byType(AnalogVuMeter), findsOneWidget);
    expect(find.byType(LiveWaveform), findsNWidgets(2));
  });

  testWidgets('the selected style shows the checked radio cue', (
    tester,
  ) async {
    await pumpPicker(tester); // default selection is modern
    // Exactly one card is selected at a time.
    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);
  });

  testWidgets(
    'the unselected card rests at the idle level; the selected one reflects '
    'the injected live level',
    (tester) async {
      await pumpPicker(
        tester,
        vu: 2,
        dBFS: -3,
        amplitudes: const [0.9, 0.9, 0.9],
      );

      final shader = tester.widget<AiVoiceInputShader>(
        find.byType(AiVoiceInputShader),
      );
      final meter = tester.widget<AnalogVuMeter>(find.byType(AnalogVuMeter));

      // Modern is selected → its shader rides the injected dBFS.
      expect(shader.dbfs, -3);
      // Analogue is unselected → its meter rests at the idle constants.
      expect(meter.vu, -20);
      expect(meter.dBFS, -80);
    },
  );

  testWidgets('tapping a style card reports the selection', (tester) async {
    final picked = <RecordingStyle>[];
    await pumpPicker(tester, onSelect: picked.add);

    await tester.tap(find.text('Analogue'));
    await tester.tap(find.text('Modern'));
    expect(picked, [RecordingStyle.analogue, RecordingStyle.modern]);
  });

  testWidgets('a style card activates via the keyboard (focus + Enter)', (
    tester,
  ) async {
    final picked = <RecordingStyle>[];
    await pumpPicker(tester, onSelect: picked.add);

    // The cards are InkWells (not bare GestureDetectors), so they take focus
    // and respond to the activate key — operable for keyboard/switch users.
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
    await pumpPicker(tester, onToggle: toggles.add);

    await tester.tap(find.byType(Switch));
    expect(toggles, [true]);
  });

  testWidgets(
    'card text follows the injected surfaceTokens, not a hardcoded dark '
    'theme',
    (tester) async {
      // Regression coverage: the cards used to hardcode `dsTokensDark`
      // regardless of the host page's theme, which read as low-contrast,
      // washed-out text when embedded in a page using the light tokens.
      await pumpPicker(tester, surfaceTokens: dsTokensLight);

      final modernLabel = tester.widget<Text>(find.text('Modern'));
      expect(modernLabel.style?.color, dsTokensLight.colors.text.highEmphasis);
      expect(
        modernLabel.style?.color,
        isNot(dsTokensDark.colors.text.highEmphasis),
      );
    },
  );
}
