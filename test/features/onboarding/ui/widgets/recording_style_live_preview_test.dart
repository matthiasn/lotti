import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/features/onboarding/ui/widgets/recording_style_live_preview.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart' show Amplitude;

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

AudioNote _throwawayNote() => AudioNote(
  createdAt: DateTime(2024, 3, 15),
  audioFile: 'tryout.m4a',
  audioDirectory: '/audio/2024-03-15/',
  duration: Duration.zero,
);

/// Stubs a successful live-mic tryout: `startRecording` resolves with a
/// throwaway note, `amplitudeStream` streams from [amps], and
/// `stopRecording` completes cleanly.
void _stubLiveRecording(
  MockAudioRecorderRepository repo,
  StreamController<Amplitude> amps,
) {
  when(repo.startRecording).thenAnswer((_) async => _throwawayNote());
  when(() => repo.amplitudeStream).thenAnswer((_) => amps.stream);
  when(repo.stopRecording).thenAnswer((_) async {});
}

void main() {
  Future<void> pumpPreview(
    WidgetTester tester, {
    required List<RecordingStyleLivePreviewState> states,
    AudioRecorderRepository? repo,
    bool reduceMotion = true,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        Material(
          type: MaterialType.transparency,
          child: RecordingStyleLivePreview(
            builder: (context, state) {
              states.add(state);
              return Switch(
                value: state.tryingWithVoice,
                onChanged: state.onToggleTryWithVoice,
              );
            },
          ),
        ),
        mediaQueryData: MediaQueryData(disableAnimations: reduceMotion),
        overrides: [
          if (repo != null)
            audioRecorderRepositoryProvider.overrideWithValue(repo),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('reduced motion holds a static frame (no extra rebuilds)', (
    tester,
  ) async {
    final states = <RecordingStyleLivePreviewState>[];
    await pumpPreview(tester, states: states);
    final rebuildsAfterInitial = states.length;

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // The sim ticker is stopped under reduced motion, so nothing schedules
    // further frames/rebuilds beyond the initial build.
    expect(states.length, rebuildsAfterInitial);
    expect(tester.takeException(), isNull);
  });

  testWidgets('motion on loops and varies the simulated level', (
    tester,
  ) async {
    final states = <RecordingStyleLivePreviewState>[];
    await pumpPreview(tester, states: states, reduceMotion: false);
    states.clear();

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(states, isNotEmpty);
    final dbfsValues = states.map((s) => s.level.dbfs).toSet();
    expect(dbfsValues.length, greaterThan(1));

    // Unmount to stop the perpetual ticker so the test tears down cleanly.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'try with voice starts the mic and streams live levels into the builder',
    (tester) async {
      final repo = MockAudioRecorderRepository();
      final amps = StreamController<Amplitude>.broadcast();
      addTearDown(amps.close);
      _stubLiveRecording(repo, amps);

      final states = <RecordingStyleLivePreviewState>[];
      await pumpPreview(tester, states: states, repo: repo);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump();
      verify(repo.startRecording).called(1);

      amps.add(Amplitude(current: -12, max: 0));
      await tester.pump();

      final last = states.last;
      expect(last.tryingWithVoice, isTrue);
      expect(last.level.dbfs, -12);
      // 0 VU ≈ -18 dBFS, so VU ≈ dBFS + 18, clamped to the meter range.
      expect(last.level.vu, (-12.0 + 18).clamp(-20.0, 3.0));
    },
  );

  testWidgets('toggling off stops the mic', (tester) async {
    final repo = MockAudioRecorderRepository();
    final amps = StreamController<Amplitude>.broadcast();
    addTearDown(amps.close);
    _stubLiveRecording(repo, amps);

    final states = <RecordingStyleLivePreviewState>[];
    await pumpPreview(tester, states: states, repo: repo);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    verify(repo.stopRecording).called(1);
    // Once the tryout stops, the display falls back to the simulated level
    // (not the live level's rest constant, which is only an internal
    // placeholder while `_liveNote` is non-null).
    expect(states.last.tryingWithVoice, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'toggling off while the recorder is still starting discards immediately',
    (tester) async {
      final repo = MockAudioRecorderRepository();
      final startCompleter = Completer<AudioNote?>();
      when(repo.startRecording).thenAnswer((_) => startCompleter.future);
      when(repo.stopRecording).thenAnswer((_) async {});

      final states = <RecordingStyleLivePreviewState>[];
      await pumpPreview(tester, states: states, repo: repo);

      await tester.tap(find.byType(Switch)); // toggles on, awaits start
      await tester.pump();
      await tester.tap(find.byType(Switch)); // toggles off before it resolves
      await tester.pump();

      startCompleter.complete(_throwawayNote());
      await tester.pump();
      await tester.pump();

      verify(repo.stopRecording).called(1);
      expect(states.last.tryingWithVoice, isFalse);
    },
  );

  testWidgets('startRecording returning null reverts the toggle', (
    tester,
  ) async {
    final repo = MockAudioRecorderRepository();
    when(repo.startRecording).thenAnswer((_) async => null);

    final states = <RecordingStyleLivePreviewState>[];
    await pumpPreview(tester, states: states, repo: repo);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump();

    expect(states.last.tryingWithVoice, isFalse);
  });

  testWidgets('a long live stream keeps only the most recent window', (
    tester,
  ) async {
    final repo = MockAudioRecorderRepository();
    final amps = StreamController<Amplitude>.broadcast();
    addTearDown(amps.close);
    _stubLiveRecording(repo, amps);

    final states = <RecordingStyleLivePreviewState>[];
    await pumpPreview(tester, states: states, repo: repo);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump();

    // More than the rolling window (28) of samples → exercises the sublist
    // trim; the stream keeps flowing without error.
    for (var i = 0; i < 35; i++) {
      amps.add(Amplitude(current: -10.0 - i, max: 0));
    }
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(states.last.level.amplitudes.length, lessThanOrEqualTo(28));
  });

  testWidgets('disposing while the tryout is live stops + discards it', (
    tester,
  ) async {
    final repo = MockAudioRecorderRepository();
    final amps = StreamController<Amplitude>.broadcast();
    addTearDown(amps.close);
    _stubLiveRecording(repo, amps);

    // getDocumentsDirectory() (used by _deleteLiveFile) reads getIt<Directory>.
    final dir = Directory.systemTemp.createTempSync('recording_style_test');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    if (getIt.isRegistered<Directory>()) getIt.unregister<Directory>();
    getIt.registerSingleton<Directory>(dir);
    addTearDown(() => getIt.unregister<Directory>());

    final states = <RecordingStyleLivePreviewState>[];
    await pumpPreview(tester, states: states, repo: repo);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump();

    // Tear the widget down mid-tryout: dispose stops the recorder and drops
    // the throwaway file without toggling off first.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    verify(repo.stopRecording).called(1);
  });

  testWidgets(
    'disposing while startRecording() is still pending stops the recorder '
    'once it resolves',
    (tester) async {
      // Regression: if the widget is disposed before `startRecording()`
      // resolves, `_liveNote` is still null when `dispose()` runs, so it
      // can't stop anything there. The recorder must still be stopped once
      // the pending start resolves after disposal — otherwise the mic keeps
      // recording after the screen is gone.
      final repo = MockAudioRecorderRepository();
      final startCompleter = Completer<AudioNote?>();
      when(repo.startRecording).thenAnswer((_) => startCompleter.future);
      when(repo.stopRecording).thenAnswer((_) async {});

      final states = <RecordingStyleLivePreviewState>[];
      await pumpPreview(tester, states: states, repo: repo);

      await tester.tap(find.byType(Switch)); // starts, awaits the mic
      await tester.pump();

      // Unmount entirely (not just toggle off) before the start resolves.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      verifyNever(repo.stopRecording);

      startCompleter.complete(_throwawayNote());
      await tester.pump();
      await tester.pump();

      verify(repo.stopRecording).called(1);
    },
  );
}
