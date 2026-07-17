/// Deterministic manual screenshots for the active audio-recording sheet.
///
/// Opt in with `LOTTI_SCREENSHOT_DIR=<external-dir>`; generated PNGs are
/// staging inputs for the manual media manifest and are never committed here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/onboarding/state/recording_style.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_visibility.dart';
import 'package:lotti/features/speech/state/checkbox_visibility_provider.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:lotti/widgets/ui/lotti_animated_checkbox.dart';

import '../../../../daily_os_next/screenshot_harness.dart';

const _linkedTaskId = 'payment-confirmation';
const _categoryId = 'focused-work';
String _t(String en, String de) => manualScreenshotText(en: en, de: de);
AppLocalizations _messages(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
const ValueKey<String> _openRecordingKey = ValueKey<String>(
  'open-audio-recording',
);

class _FixedAudioRecorderController extends AudioRecorderController {
  _FixedAudioRecorderController(this.fixedState);

  final AudioRecorderState fixedState;

  @override
  AudioRecorderState build() => fixedState;
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'audio recording manual screenshot harness (opt-in)',
      () {},
      skip: 'Set LOTTI_SCREENSHOT_DIR to capture manual screenshots.',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  for (final device in [proDevice, desktopDevice]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final viewport = device.isPhone ? 'mobile' : 'desktop';
      final theme = brightness.name;

      testWidgets('$viewport active audio recording — $theme', (tester) async {
        await _pumpActiveRecording(
          tester,
          device: device,
          brightness: brightness,
        );
        final messages = _messages(tester);

        expect(find.byType(AudioRecordingModalContent), findsOneWidget);
        expect(find.text('0:00:42'), findsOneWidget);
        expect(find.text(messages.audioRecordingStop), findsOneWidget);
        expect(
          find.widgetWithText(
            LottiAnimatedCheckbox,
            messages.speechModalTitle,
          ),
          findsOneWidget,
        );
        await captureScreenshot(
          tester,
          'recording_active_${viewport}_$theme',
          subdir: 'manual',
        );
      });
    }
  }
}

Future<void> _pumpActiveRecording(
  WidgetTester tester, {
  required ScreenshotDevice device,
  required Brightness brightness,
}) async {
  applyScreenshotDevice(tester, device);
  final fixedState = AudioRecorderState(
    status: AudioRecorderStatus.recording,
    progress: const Duration(seconds: 42),
    vu: 1.5,
    dBFS: -12,
    showIndicator: false,
    modalVisible: true,
    linkedId: _linkedTaskId,
    enableSpeechRecognition: true,
  );

  await tester.pumpWidget(
    RepaintBoundary(
      key: screenshotBoundaryKey,
      child: ProviderScope(
        overrides: [
          audioRecorderControllerProvider.overrideWith(
            () => _FixedAudioRecorderController(fixedState),
          ),
          realtimeAvailableProvider.overrideWith((ref) async => false),
          recordingStyleAppPrefsProvider.overrideWithValue(
            _modernRecordingStylePreferences,
          ),
          checkboxVisibilityProvider((
            categoryId: _categoryId,
            linkedId: _linkedTaskId,
          )).overrideWithValue(
            const AutomaticPromptVisibility(speech: true),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.dark
              ? DesignSystemTheme.dark()
              : DesignSystemTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: manualScreenshotLocale,
          home: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(
                  _t(
                    'Inspect orbital penguin habitat',
                    'Pinguin-Habitat im Orbit inspizieren',
                  ),
                ),
              ),
              body: Center(
                child: FilledButton.icon(
                  key: _openRecordingKey,
                  onPressed: () => AudioRecordingModal.show(
                    context,
                    linkedId: _linkedTaskId,
                    categoryId: _categoryId,
                  ),
                  icon: const Icon(Icons.mic_rounded),
                  label: Text(
                    _t(
                      'Record habitat update',
                      'Habitat-Update aufnehmen',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(_openRecordingKey));
  await settleFrames(tester, 8);
}

const _modernRecordingStylePreferences = AppPrefs(
  getBool: _getBoolPreference,
  setBool: _setBoolPreference,
  getString: _getStringPreference,
  setString: _setStringPreference,
);

Future<bool?> _getBoolPreference(String key) async => null;

Future<bool> _setBoolPreference({
  required String key,
  required bool value,
}) async => true;

Future<String?> _getStringPreference(String key) async =>
    key == recordingStylePrefsKey ? 'modern' : null;

Future<bool> _setStringPreference({
  required String key,
  required String value,
}) async => true;
