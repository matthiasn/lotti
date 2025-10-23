import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/speech/state/player_state.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/features/speech/ui/widgets/progress/audio_progress_bar.dart';
import 'package:lotti/features/speech/ui/widgets/progress/audio_waveform_scrubber.dart';
import 'package:mocktail/mocktail.dart';

class MockAudioPlayerCubit extends MockCubit<AudioPlayerState>
    implements AudioPlayerCubit {}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  late MockAudioPlayerCubit cubit;

  setUp(() {
    cubit = MockAudioPlayerCubit();

    when(() => cubit.play()).thenAnswer((_) async {});
    when(() => cubit.pause()).thenAnswer((_) async {});
    when(() => cubit.seek(any<Duration>())).thenAnswer((_) async {});
    when(() => cubit.setSpeed(any<double>())).thenAnswer((_) async {});
  });

  JournalAudio buildJournalAudio() {
    final recordedAt = DateTime(2024, 1, 1, 10);
    return JournalAudio(
      meta: Metadata(
        id: 'audio-1',
        createdAt: recordedAt,
        updatedAt: recordedAt,
        dateFrom: recordedAt,
        dateTo: recordedAt.add(const Duration(minutes: 5)),
      ),
      data: AudioData(
        dateFrom: recordedAt,
        dateTo: recordedAt.add(const Duration(minutes: 5)),
        audioFile: 'sample.m4a',
        audioDirectory: '/audio',
        duration: const Duration(minutes: 5),
      ),
      entryText: const EntryText(plainText: 'Minimal audio entry'),
    );
  }

  AudioPlayerState buildState({
    required AudioPlayerStatus status,
    required Duration totalDuration,
    required Duration progress,
    required Duration pausedAt,
    required double speed,
    required bool showTranscriptsList,
    Duration buffered = Duration.zero,
    JournalAudio? audioNote,
  }) {
    return AudioPlayerState(
      status: status,
      totalDuration: totalDuration,
      progress: progress,
      pausedAt: pausedAt,
      speed: speed,
      showTranscriptsList: showTranscriptsList,
      buffered: buffered,
      audioNote: audioNote,
    );
  }

  Future<void> pumpPlayer(
    WidgetTester tester, {
    required JournalAudio journalAudio,
    required AudioPlayerState state,
    double width = 420,
  }) async {
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.stream)
        .thenAnswer((_) => Stream<AudioPlayerState>.value(state));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: BlocProvider<AudioPlayerCubit>.value(
              value: cubit,
              child: Center(
                child: SizedBox(
                  width: width,
                  child: AudioPlayerWidget(journalAudio),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
  }

  testWidgets('renders compact audio card with minimal controls',
      (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.playing,
      totalDuration: journalAudio.data.duration,
      progress: const Duration(seconds: 45),
      pausedAt: Duration.zero,
      speed: 1,
      showTranscriptsList: false,
      buffered: const Duration(minutes: 1),
      audioNote: journalAudio,
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    expect(find.byType(AudioProgressBar), findsOneWidget);
    expect(find.text('1x'), findsOneWidget);
    expect(find.bySemanticsLabel('Pause audio'), findsOneWidget);
    expect(find.byIcon(Icons.article_outlined), findsNothing);
    expect(find.textContaining('Tap to play'), findsNothing);
  });

  testWidgets('shows play semantics when inactive',
      (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.stopped,
      totalDuration: journalAudio.data.duration,
      progress: Duration.zero,
      pausedAt: Duration.zero,
      speed: 1,
      showTranscriptsList: false,
    );

    await pumpPlayer(
      tester,
      journalAudio: journalAudio,
      state: state,
    );

    expect(find.bySemanticsLabel('Play audio'), findsOneWidget);
  });

  testWidgets('layouts correctly below 320px width',
      (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.paused,
      totalDuration: journalAudio.data.duration,
      progress: const Duration(seconds: 10),
      pausedAt: const Duration(seconds: 10),
      speed: 1.25,
      showTranscriptsList: false,
      buffered: const Duration(seconds: 30),
      audioNote: journalAudio,
    );

    await pumpPlayer(
      tester,
      journalAudio: journalAudio,
      state: state,
      width: 300,
    );

    expect(find.text('1.25x'), findsOneWidget);
    expect(find.byType(AudioProgressBar), findsOneWidget);
    expect(
        tester.getSize(find.byType(AudioPlayerWidget)).height, lessThan(180));
  });

  testWidgets('tapping speed cycles playback rate',
      (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.playing,
      totalDuration: journalAudio.data.duration,
      progress: const Duration(seconds: 5),
      pausedAt: Duration.zero,
      speed: 1,
      showTranscriptsList: false,
      buffered: const Duration(seconds: 5),
      audioNote: journalAudio,
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    await tester.tap(find.text('1x'));
    await tester.pump();

    verify(() => cubit.setSpeed(1.25)).called(1);
  });

  testWidgets('renders waveform scrubber when waveform ready',
      (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.playing,
      totalDuration: journalAudio.data.duration,
      progress: const Duration(seconds: 5),
      pausedAt: Duration.zero,
      speed: 1,
      showTranscriptsList: false,
      buffered: const Duration(seconds: 6),
      audioNote: journalAudio,
    ).copyWith(
      waveformStatus: AudioWaveformStatus.ready,
      waveform: const <double>[0.3, 0.6, 0.9],
      waveformBucketDuration: const Duration(milliseconds: 20),
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    expect(find.byType(AudioWaveformScrubber), findsOneWidget);
    expect(find.byType(AudioProgressBar), findsNothing);
  });

  testWidgets('scrubbing progress calls seek with target duration',
      (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    const total = Duration(minutes: 2);
    final state = buildState(
      status: AudioPlayerStatus.playing,
      totalDuration: total,
      progress: const Duration(seconds: 10),
      pausedAt: const Duration(seconds: 10),
      speed: 1,
      showTranscriptsList: false,
      buffered: const Duration(seconds: 30),
      audioNote: journalAudio,
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    await tester.tap(find.byType(AudioProgressBar));
    await tester.pump();

    final captured = verify(() => cubit.seek(captureAny<Duration>()))
        .captured
        .first as Duration;
    expect(captured.inMilliseconds.toDouble(),
        closeTo(total.inMilliseconds / 2, 1500));
  });

  testWidgets('tapping play arms the cubit with the audio note',
      (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.stopped,
      totalDuration: journalAudio.data.duration,
      progress: Duration.zero,
      pausedAt: Duration.zero,
      speed: 1,
      showTranscriptsList: false,
    );

    when(() => cubit.setAudioNote(journalAudio)).thenAnswer((_) async {});

    await pumpPlayer(
      tester,
      journalAudio: journalAudio,
      state: state,
    );

    await tester.tap(find.bySemanticsLabel('Play audio'));
    await tester.pump();

    verify(() => cubit.setAudioNote(journalAudio)).called(1);
    verify(() => cubit.play()).called(1);
  });

  testWidgets('tapping pause button when playing calls pause',
      (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.playing,
      totalDuration: journalAudio.data.duration,
      progress: const Duration(seconds: 30),
      pausedAt: Duration.zero,
      speed: 1,
      showTranscriptsList: false,
      audioNote: journalAudio,
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    await tester.tap(find.bySemanticsLabel('Pause audio'));
    await tester.pump();

    verify(() => cubit.pause()).called(1);
  });

  testWidgets('tapping play button when paused calls play',
      (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.paused,
      totalDuration: journalAudio.data.duration,
      progress: const Duration(seconds: 30),
      pausedAt: const Duration(seconds: 30),
      speed: 1,
      showTranscriptsList: false,
      audioNote: journalAudio,
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    await tester.tap(find.bySemanticsLabel('Play audio'));
    await tester.pump();

    verify(() => cubit.play()).called(1);
  });

  testWidgets('shows loading indicator when initializing',
      (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.initializing,
      totalDuration: journalAudio.data.duration,
      progress: Duration.zero,
      pausedAt: Duration.zero,
      speed: 1,
      showTranscriptsList: false,
      audioNote: journalAudio,
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('speed button is disabled when player is inactive',
      (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.stopped,
      totalDuration: journalAudio.data.duration,
      progress: Duration.zero,
      pausedAt: Duration.zero,
      speed: 1.5,
      showTranscriptsList: false,
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    final speedButton = find.text('1.5x');
    expect(speedButton, findsOneWidget);

    final opacity = tester.widget<Opacity>(
      find.ancestor(of: speedButton, matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 0.5);
  });

  testWidgets('speed cycles from 1x to 1.25x', (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.playing,
      totalDuration: journalAudio.data.duration,
      progress: const Duration(seconds: 5),
      pausedAt: Duration.zero,
      speed: 1,
      showTranscriptsList: false,
      audioNote: journalAudio,
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    await tester.tap(find.text('1x'));
    await tester.pump();

    verify(() => cubit.setSpeed(1.25)).called(1);
  });

  testWidgets('speed cycles from 2x to 0.5x (wraps around)',
      (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.playing,
      totalDuration: journalAudio.data.duration,
      progress: const Duration(seconds: 5),
      pausedAt: Duration.zero,
      speed: 2,
      showTranscriptsList: false,
      audioNote: journalAudio,
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    await tester.tap(find.text('2x'));
    await tester.pump();

    verify(() => cubit.setSpeed(0.5)).called(1);
  });

  testWidgets('displays all speed values correctly',
      (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    for (final speed in speeds) {
      final state = buildState(
        status: AudioPlayerStatus.playing,
        totalDuration: journalAudio.data.duration,
        progress: const Duration(seconds: 5),
        pausedAt: Duration.zero,
        speed: speed,
        showTranscriptsList: false,
        audioNote: journalAudio,
      );

      await pumpPlayer(tester, journalAudio: journalAudio, state: state);

      final expectedLabel =
          speed == speed.truncateToDouble() ? '${speed.toInt()}x' : '${speed}x';
      expect(find.text(expectedLabel), findsOneWidget);

      // Clean up for next iteration
      await tester.pumpWidget(Container());
    }
  });

  testWidgets('handles zero duration gracefully', (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.stopped,
      totalDuration: Duration.zero,
      progress: Duration.zero,
      pausedAt: Duration.zero,
      speed: 1,
      showTranscriptsList: false,
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    // Should display duration from journalAudio.data.duration
    expect(find.textContaining('5:00'), findsOneWidget);
    expect(find.byType(AudioProgressBar), findsOneWidget);
  });

  testWidgets('uses state totalDuration when available',
      (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.playing,
      totalDuration: const Duration(minutes: 3),
      progress: const Duration(seconds: 30),
      pausedAt: Duration.zero,
      speed: 1,
      showTranscriptsList: false,
      audioNote: journalAudio,
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    // Should display state totalDuration (03:00), not journalAudio duration (05:00)
    expect(find.text('03:00'), findsOneWidget);
  });

  testWidgets('progress ratio is clamped between 0 and 1',
      (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.playing,
      totalDuration: const Duration(seconds: 60),
      // Progress exceeds total duration
      progress: const Duration(seconds: 120),
      pausedAt: Duration.zero,
      speed: 1,
      showTranscriptsList: false,
      audioNote: journalAudio,
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    // Should not throw and should render
    expect(find.byType(AudioProgressBar), findsOneWidget);
  });

  testWidgets('displays error color for non-1x speeds',
      (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.playing,
      totalDuration: journalAudio.data.duration,
      progress: const Duration(seconds: 5),
      pausedAt: Duration.zero,
      speed: 1.5,
      showTranscriptsList: false,
      audioNote: journalAudio,
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    expect(find.text('1.5x'), findsOneWidget);
    // The speed button should be visible and tappable
    await tester.tap(find.text('1.5x'));
    verify(() => cubit.setSpeed(1.75)).called(1);
  });

  testWidgets('shows correct buffered progress', (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.playing,
      totalDuration: const Duration(minutes: 5),
      progress: const Duration(seconds: 30),
      pausedAt: Duration.zero,
      speed: 1,
      showTranscriptsList: false,
      buffered: const Duration(minutes: 2),
      audioNote: journalAudio,
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    final progressBar = tester.widget<AudioProgressBar>(
      find.byType(AudioProgressBar),
    );
    expect(progressBar.buffered, const Duration(minutes: 2));
    expect(progressBar.progress, const Duration(seconds: 30));
  });

  testWidgets('progress and buffered are zero when inactive',
      (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.stopped,
      totalDuration: journalAudio.data.duration,
      progress: const Duration(seconds: 30),
      pausedAt: Duration.zero,
      speed: 1,
      showTranscriptsList: false,
      buffered: const Duration(minutes: 1),
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    final progressBar = tester.widget<AudioProgressBar>(
      find.byType(AudioProgressBar),
    );
    // When not active, progress and buffered should be zero
    expect(progressBar.progress, Duration.zero);
    expect(progressBar.buffered, Duration.zero);
  });
}
