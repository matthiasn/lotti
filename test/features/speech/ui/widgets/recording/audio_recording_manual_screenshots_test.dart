/// Deterministic manual screenshots of a take on the recording strip: the
/// strip at the foot of a page, and its tray opened over it.
///
/// Opt in with `LOTTI_SCREENSHOT_DIR=<external-dir>`; generated PNGs are
/// staging inputs for the manual media manifest and are never committed here.
library;

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/chrome/recording_strip_shell.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_origin.dart';
import 'package:lotti/features/speech/state/recording_tray_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_tray.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../daily_os_next/screenshot_harness.dart';

const _linkedTaskId = 'payment-confirmation';
const _categoryId = 'focused-work';
String _t(String en, String de) => manualScreenshotText(en: en, de: de);
AppLocalizations _messages(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;

class _FixedAudioRecorderController extends AudioRecorderController {
  _FixedAudioRecorderController(this.fixedState);

  final AudioRecorderState fixedState;

  @override
  AudioRecorderState build() {
    setCategoryId(_categoryId);
    return fixedState;
  }

  /// A new live level, as the recorder reports one every 20 ms.
  // As the recorder does: every sample advances the take by 20 ms.
  void tick(double dbfs) => state = state.copyWith(
    dBFS: dbfs,
    progress: state.progress + const Duration(milliseconds: 20),
  );
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

      testWidgets('$viewport recording strip — $theme', (tester) async {
        await _pumpActiveRecording(
          tester,
          device: device,
          brightness: brightness,
        );

        expect(find.byType(RecordingStrip), findsOneWidget);
        expect(find.text('00:42'), findsOneWidget);
        await captureScreenshot(
          tester,
          'recording_strip_${viewport}_$theme',
          subdir: 'manual',
        );
      });

      testWidgets('$viewport active audio recording — $theme', (tester) async {
        await _pumpActiveRecording(
          tester,
          device: device,
          brightness: brightness,
          trayOpen: true,
        );
        final messages = _messages(tester);

        expect(find.byType(RecordingStripTray), findsOneWidget);
        expect(find.text('00:42'), findsOneWidget);
        expect(find.byKey(const ValueKey('stop_recording')), findsOneWidget);
        // The title on one line, and no option under the controls.
        expect(find.text(messages.recordingStripRecordingFor), findsNothing);
        expect(find.byType(Switch), findsNothing);
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
  bool trayOpen = false,
}) async {
  applyScreenshotDevice(tester, device);
  // The take started on the task; the user has since gone to the calendar,
  // so the strip offers the way back.
  final nav = MockNavService();
  final route = ValueNotifier<String>('/calendar');
  addTearDown(route.dispose);
  when(() => nav.activeRoute).thenAnswer((_) => route.value);
  when(() => nav.activeRouteChanges).thenReturn(route);
  late _FixedAudioRecorderController controller;
  final fixedState = AudioRecorderState(
    status: AudioRecorderStatus.recording,
    // The ticks below bring it to 0:00:42.
    progress: const Duration(milliseconds: 37200),
    dBFS: -12,
    inlineHostVisible: false,
    linkedId: _linkedTaskId,
    origin: const RecordingOrigin(
      route: '/tasks/$_linkedTaskId',
      subjectId: _linkedTaskId,
    ),
  );

  await tester.pumpWidget(
    RepaintBoundary(
      key: screenshotBoundaryKey,
      child: ProviderScope(
        overrides: [
          audioRecorderControllerProvider.overrideWith(
            () => controller = _FixedAudioRecorderController(fixedState),
          ),
          // The strip names the task it records for.
          journalDbProvider.overrideWithValue(_journalDbWithTask()),
          navServiceProvider.overrideWithValue(nav),
        ],
        child: MaterialApp(
          builder: LegacyMaterialBridge.builder,
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.dark
              ? DesignSystemTheme.dark()
              : DesignSystemTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: manualScreenshotLocale,
          home: RecordingStripShell(
            omitAudio: false,
            child: Scaffold(
              appBar: AppBar(
                title: Text(_t('Wednesday', 'Mittwoch')),
              ),
              body: Center(
                child: Text(
                  _t('Habitat walk-through', 'Habitat-Rundgang'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  if (trayOpen) {
    ProviderScope.containerOf(
      tester.element(find.byType(RecordingStripShell)),
    ).read(recordingTrayControllerProvider.notifier).open();
  }
  await settleFrames(tester, 8);
  // A few seconds of speech-shaped levels, so the bars show a take in
  // progress rather than their resting baseline.
  for (var i = 0; i < RecordingLevelLine.levelWindow; i++) {
    controller.tick(-38 + 26 * math.sin(i / 3).abs());
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// A journal holding the one task the strip records for.
MockJournalDb _journalDbWithTask() {
  final db = MockJournalDb();
  when(() => db.journalEntityById(_linkedTaskId)).thenAnswer(
    (_) async => testTask.copyWith(
      data: testTask.data.copyWith(
        title: _t(
          'Inspect orbital penguin habitat',
          'Pinguin-Habitat im Orbit inspizieren',
        ),
      ),
    ),
  );
  return db;
}
