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
    when(() => cubit.stop()).thenAnswer((_) async {});
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
}
