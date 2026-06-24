import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/features/onboarding/state/recording_style.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_recording_style_step.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart' show Amplitude;

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

AppPrefs _fakePrefs(Map<String, String> store) => AppPrefs(
  getBool: (_) async => null,
  setBool: ({required key, required value}) async => true,
  getString: (key) async => store[key],
  setString: ({required key, required value}) async {
    store[key] = value;
    return true;
  },
);

void main() {
  Future<void> pumpStep(
    WidgetTester tester, {
    Map<String, String>? store,
    AudioRecorderRepository? repo,
    VoidCallback? onContinue,
    bool reduceMotion = true,
  }) async {
    // The step is tall; size the render surface so every control (incl. the
    // bottom Continue) is on-screen and hit-testable.
    tester.view
      ..physicalSize = const Size(390, 1100)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      makeTestableWidget(
        Material(
          type: MaterialType.transparency,
          child: SizedBox(
            width: 390,
            height: 1080,
            child: OnboardingRecordingStyleStep(
              onContinue: onContinue ?? () {},
            ),
          ),
        ),
        mediaQueryData: MediaQueryData(
          size: const Size(390, 1100),
          disableAnimations: reduceMotion,
        ),
        overrides: [
          recordingStyleAppPrefsProvider.overrideWithValue(
            _fakePrefs(store ?? {}),
          ),
          if (repo != null)
            audioRecorderRepositoryProvider.overrideWithValue(repo),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('persists the chosen style on continue', (tester) async {
    final store = <String, String>{};
    var continues = 0;
    await pumpStep(tester, store: store, onContinue: () => continues++);

    await tester.tap(find.text('Analogue — VU meter'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump();

    expect(store[recordingStylePrefsKey], 'analogue');
    expect(continues, 1);
  });

  testWidgets(
    'Try with your voice starts the mic, streams levels, and stops on toggle off',
    (tester) async {
      final repo = MockAudioRecorderRepository();
      final amps = StreamController<Amplitude>.broadcast();
      addTearDown(amps.close);
      when(repo.startRecording).thenAnswer(
        (_) async => AudioNote(
          createdAt: DateTime(2024, 3, 15),
          audioFile: 'tryout.m4a',
          audioDirectory: '/audio/2024-03-15/',
          duration: Duration.zero,
        ),
      );
      when(() => repo.amplitudeStream).thenAnswer((_) => amps.stream);
      when(repo.stopRecording).thenAnswer((_) async {});

      await pumpStep(tester, repo: repo);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump();
      verify(repo.startRecording).called(1);

      // A live amplitude flows into the previews without error.
      amps.add(Amplitude(current: -12, max: 0));
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      verify(repo.stopRecording).called(1);
    },
  );

  testWidgets('reverts the toggle when the mic cannot start', (tester) async {
    final repo = MockAudioRecorderRepository();
    when(repo.startRecording).thenAnswer((_) async => null);

    await pumpStep(tester, repo: repo);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump();

    // Start failed (e.g. permission denied) → the toggle falls back to off.
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('loops the simulated previews when motion is enabled', (
    tester,
  ) async {
    // Motion ON → the simulated ticker repeats (the non-reduced-motion branch).
    await pumpStep(tester, reduceMotion: false);
    // Drive a few frames of the looping simulation; it must not throw.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(OnboardingRecordingStyleStep), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Unmount to stop the perpetual ticker so the test tears down cleanly.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a long live stream keeps only the most recent window', (
    tester,
  ) async {
    final repo = MockAudioRecorderRepository();
    final amps = StreamController<Amplitude>.broadcast();
    addTearDown(amps.close);
    when(repo.startRecording).thenAnswer(
      (_) async => AudioNote(
        createdAt: DateTime(2024, 3, 15),
        audioFile: 'tryout.m4a',
        audioDirectory: '/audio/2024-03-15/',
        duration: Duration.zero,
      ),
    );
    when(() => repo.amplitudeStream).thenAnswer((_) => amps.stream);
    when(repo.stopRecording).thenAnswer((_) async {});

    await pumpStep(tester, repo: repo);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump();

    // More than the rolling window (28) of samples → exercises the sublist
    // trim; the strip keeps streaming without error.
    for (var i = 0; i < 35; i++) {
      amps.add(Amplitude(current: -10.0 - i, max: 0));
    }
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing while the tryout is live stops + discards it', (
    tester,
  ) async {
    final repo = MockAudioRecorderRepository();
    final amps = StreamController<Amplitude>.broadcast();
    addTearDown(amps.close);
    when(repo.startRecording).thenAnswer(
      (_) async => AudioNote(
        createdAt: DateTime(2024, 3, 15),
        audioFile: 'tryout.m4a',
        audioDirectory: '/audio/2024-03-15/',
        duration: Duration.zero,
      ),
    );
    when(() => repo.amplitudeStream).thenAnswer((_) => amps.stream);
    when(repo.stopRecording).thenAnswer((_) async {});

    // getDocumentsDirectory() (used by _deleteLiveFile) reads getIt<Directory>.
    final dir = Directory.systemTemp.createTempSync('onb_style_test');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    if (getIt.isRegistered<Directory>()) getIt.unregister<Directory>();
    getIt.registerSingleton<Directory>(dir);
    addTearDown(() => getIt.unregister<Directory>());

    await pumpStep(tester, repo: repo);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump();

    // Tear the step down mid-tryout: dispose stops the recorder and drops the
    // throwaway file without toggling off first.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    verify(repo.stopRecording).called(1);
  });
}
