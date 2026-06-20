import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/model/audio_player_state.dart';
import 'package:lotti/features/speech/services/audio_waveform_service.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/features/speech/ui/widgets/progress/audio_progress_bar.dart';
import 'package:lotti/features/speech/ui/widgets/progress/audio_waveform_scrubber.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// State-tracking fake used to drive [AudioPlayerWidget] through Riverpod.
///
/// This intentionally does NOT use the centralized
/// `MockAudioPlayerController` from `test/mocks/mocks.dart` (which is a
/// Mocktail `Mock implements AudioPlayerController`). The widget overrides the
/// provider via `audioPlayerControllerProvider.overrideWith(() => controller)`,
/// which requires a real [AudioPlayerController] subclass so Riverpod can run
/// its notifier lifecycle (`build`, state wiring, etc.). A Mocktail mock would
/// not satisfy that contract because it bypasses the generated notifier
/// machinery. Hence this local fake subclasses the controller and records the
/// playback calls the widget makes (`play`/`pause`/`seek`/`setSpeed`/
/// `setAudioNote`) so each interaction test can assert on them.
class _FakeAudioPlayerController extends AudioPlayerController {
  _FakeAudioPlayerController(this._state);

  AudioPlayerState _state;

  @override
  AudioPlayerState get state => _state;

  @override
  set state(AudioPlayerState newState) {
    _state = newState;
  }

  bool playWasCalled = false;
  bool pauseWasCalled = false;
  Duration? lastSeekPosition;
  double? lastSpeedSet;
  JournalAudio? lastAudioNoteSet;

  @override
  AudioPlayerState build() => _state;

  @override
  Future<void> play() async {
    playWasCalled = true;
  }

  @override
  Future<void> pause() async {
    pauseWasCalled = true;
  }

  @override
  Future<void> seek(Duration newPosition) async {
    lastSeekPosition = newPosition;
  }

  @override
  Future<void> setSpeed(double speed) async {
    lastSpeedSet = speed;
  }

  @override
  Future<void> setAudioNote(JournalAudio audioNote) async {
    lastAudioNoteSet = audioNote;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  late _FakeAudioPlayerController controller;
  // Centralized Mocktail mock from test/mocks/mocks.dart; the widget reads it
  // out of getIt through `audioWaveformProvider`. Each `pumpPlayer` call stubs
  // `loadWaveform` for the concrete [JournalAudio] instance under test, so no
  // `any()`/`JournalAudio` fallback registration is required.
  late MockAudioWaveformService waveformService;

  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<LoggingService>(MockLoggingService());
    waveformService = MockAudioWaveformService();
    getIt.registerSingleton<AudioWaveformService>(waveformService);
  });

  tearDown(getIt.reset);

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
    Brightness brightness = Brightness.light,
    AudioWaveformData? waveformData,
  }) async {
    controller = _FakeAudioPlayerController(state);

    when(
      () => waveformService.loadWaveform(
        journalAudio,
        targetBuckets: any(named: 'targetBuckets'),
      ),
    ).thenAnswer((_) async => waveformData);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerControllerProvider.overrideWith(() => controller),
        ],
        child: MaterialApp(
          theme: resolveTestTheme(
            ThemeData(useMaterial3: true, brightness: brightness),
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: AudioPlayerWidget(journalAudio),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
  }

  testWidgets('renders compact audio card with minimal controls', (
    WidgetTester tester,
  ) async {
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

  testWidgets('shows play semantics when inactive', (
    WidgetTester tester,
  ) async {
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

  testWidgets('layouts correctly below 320px width', (
    WidgetTester tester,
  ) async {
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
      tester.getSize(find.byType(AudioPlayerWidget)).height,
      lessThan(180),
    );
  });

  testWidgets('renders waveform scrubber when waveform ready', (
    WidgetTester tester,
  ) async {
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
    );

    await pumpPlayer(
      tester,
      journalAudio: journalAudio,
      state: state,
      waveformData: AudioWaveformData(
        amplitudes: const <double>[0.3, 0.6, 0.9],
        bucketDuration: const Duration(milliseconds: 20),
        audioDuration: journalAudio.data.duration,
      ),
    );

    expect(find.byType(AudioWaveformScrubber), findsOneWidget);
    expect(find.byType(AudioProgressBar), findsNothing);
  });

  testWidgets('scrubbing progress calls seek with target duration', (
    WidgetTester tester,
  ) async {
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

    expect(controller.lastSeekPosition, isNotNull);
    expect(
      controller.lastSeekPosition!.inMilliseconds.toDouble(),
      closeTo(total.inMilliseconds / 2, 1500),
    );
  });

  testWidgets('tapping play arms the controller with the audio note', (
    WidgetTester tester,
  ) async {
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

    await tester.tap(find.bySemanticsLabel('Play audio'));
    await tester.pump();

    expect(controller.lastAudioNoteSet?.meta.id, journalAudio.meta.id);
    expect(controller.playWasCalled, isTrue);
  });

  testWidgets('tapping pause button when playing calls pause', (
    WidgetTester tester,
  ) async {
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

    expect(controller.pauseWasCalled, isTrue);
  });

  testWidgets('tapping play button when paused calls play', (
    WidgetTester tester,
  ) async {
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

    expect(controller.playWasCalled, isTrue);
  });

  testWidgets('shows loading indicator when initializing', (
    WidgetTester tester,
  ) async {
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

  testWidgets('speed button is disabled when player is inactive', (
    WidgetTester tester,
  ) async {
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

    // Kept at full contrast (no dimming wrapper) so it stays a clearly legible
    // control in the resting card, but not interactive until playback is active
    // (no InkWell wrapping it).
    expect(
      find.ancestor(of: speedButton, matching: find.byType(Opacity)),
      findsNothing,
    );
    expect(
      find.ancestor(of: speedButton, matching: find.byType(InkWell)),
      findsNothing,
    );
  });

  // Every transition in the speed sequence is exercised here, including the
  // 2x -> 0.5x wrap-around, instead of duplicating near-identical test bodies
  // for individual rates. Each entry asserts that tapping the speed badge
  // forwards the expected next rate to `controller.setSpeed`.
  final speedTransitions = <({double current, String label, double next})>[
    (current: 0.5, label: '0.5x', next: 0.75),
    (current: 0.75, label: '0.75x', next: 1),
    (current: 1, label: '1x', next: 1.25),
    (current: 1.25, label: '1.25x', next: 1.5),
    (current: 1.5, label: '1.5x', next: 1.75),
    (current: 1.75, label: '1.75x', next: 2),
    (current: 2, label: '2x', next: 0.5),
  ];

  for (final transition in speedTransitions) {
    testWidgets(
      'tapping ${transition.label} cycles to ${transition.next}x',
      (WidgetTester tester) async {
        final journalAudio = buildJournalAudio();
        final state = buildState(
          status: AudioPlayerStatus.playing,
          totalDuration: journalAudio.data.duration,
          progress: const Duration(seconds: 5),
          pausedAt: Duration.zero,
          speed: transition.current,
          showTranscriptsList: false,
          audioNote: journalAudio,
        );

        await pumpPlayer(tester, journalAudio: journalAudio, state: state);

        await tester.tap(find.text(transition.label));
        await tester.pump();

        expect(controller.lastSpeedSet, transition.next);
      },
    );
  }

  testWidgets('displays all speed values correctly', (
    WidgetTester tester,
  ) async {
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

      final expectedLabel = speed == speed.truncateToDouble()
          ? '${speed.toInt()}x'
          : '${speed}x';
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

  testWidgets('uses state totalDuration when available', (
    WidgetTester tester,
  ) async {
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

    // Should display state totalDuration (03:00), not journalAudio duration
    // (05:00) — rendered as the "elapsed / total" value line.
    expect(find.textContaining('03:00'), findsOneWidget);
  });

  testWidgets('progress ratio is clamped between 0 and 1', (
    WidgetTester tester,
  ) async {
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

  testWidgets('speed label uses error color for non-1x speeds only', (
    WidgetTester tester,
  ) async {
    final journalAudio = buildJournalAudio();

    AudioPlayerState stateForSpeed(double speed) => buildState(
      status: AudioPlayerStatus.playing,
      totalDuration: journalAudio.data.duration,
      progress: const Duration(seconds: 5),
      pausedAt: Duration.zero,
      speed: speed,
      showTranscriptsList: false,
      audioNote: journalAudio,
    );

    // Non-1x speed: label text is painted with the theme error color.
    await pumpPlayer(
      tester,
      journalAudio: journalAudio,
      state: stateForSpeed(1.5),
    );
    final fastFinder = find.text('1.5x');
    final errorColor = Theme.of(
      tester.element(fastFinder),
    ).colorScheme.error;
    expect(tester.widget<Text>(fastFinder).style?.color, errorColor);

    // 1x speed: label text is NOT painted with the error color.
    await tester.pumpWidget(Container());
    await pumpPlayer(
      tester,
      journalAudio: journalAudio,
      state: stateForSpeed(1),
    );
    final normalFinder = find.text('1x');
    expect(
      tester.widget<Text>(normalFinder).style?.color,
      isNot(errorColor),
    );
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

  testWidgets('progress and buffered are zero when inactive', (
    WidgetTester tester,
  ) async {
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

  group('status display states', () {
    // Drives the play button icon, progress-bar value, and duration labels
    // across the playing / paused / stopped statuses so each branch of
    // `_PlayButton` / `_PlayerBody` is exercised, not just `playing`.
    const activeProgress = Duration(seconds: 90);
    const totalDuration = Duration(minutes: 5);

    final cases =
        <
          ({
            String name,
            AudioPlayerStatus status,
            bool active,
            IconData expectedIcon,
            Duration expectedProgress,
          })
        >[
          (
            name: 'playing shows pause icon and live progress',
            status: AudioPlayerStatus.playing,
            active: true,
            expectedIcon: Icons.pause_rounded,
            expectedProgress: activeProgress,
          ),
          (
            name: 'paused shows play icon and retains progress',
            status: AudioPlayerStatus.paused,
            active: true,
            expectedIcon: Icons.play_arrow_rounded,
            expectedProgress: activeProgress,
          ),
          (
            name: 'stopped shows play icon and resets progress to zero',
            status: AudioPlayerStatus.stopped,
            active: false,
            expectedIcon: Icons.play_arrow_rounded,
            expectedProgress: Duration.zero,
          ),
        ];

    for (final c in cases) {
      testWidgets(c.name, (WidgetTester tester) async {
        final journalAudio = buildJournalAudio();
        final state = buildState(
          status: c.status,
          totalDuration: totalDuration,
          progress: activeProgress,
          pausedAt: c.status == AudioPlayerStatus.paused
              ? activeProgress
              : Duration.zero,
          speed: 1,
          showTranscriptsList: false,
          audioNote: c.active ? journalAudio : null,
        );

        await pumpPlayer(tester, journalAudio: journalAudio, state: state);

        // Button icon reflects the playing/non-playing distinction.
        expect(find.byIcon(c.expectedIcon), findsOneWidget);
        expect(
          find.byIcon(
            c.expectedIcon == Icons.pause_rounded
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
          ),
          findsNothing,
        );

        // Progress bar value is the live progress only while active.
        final progressBar = tester.widget<AudioProgressBar>(
          find.byType(AudioProgressBar),
        );
        expect(progressBar.progress, c.expectedProgress);
        expect(progressBar.enabled, c.active);

        // Elapsed and total render together as one "elapsed / total" line.
        expect(
          find.textContaining(formatAudioDuration(totalDuration)),
          findsOneWidget,
        );
        // The leading position is shown in that same combined line.
        expect(
          find.textContaining(formatAudioDuration(c.expectedProgress)),
          findsWidgets,
        );
      });
    }
  });

  group('Figma restyle', () {
    const playButtonSurfaceKey = Key('audio_player_play_button_surface');

    testWidgets(
      'play button surface uses interactive surface token in light theme',
      (WidgetTester tester) async {
        final journalAudio = buildJournalAudio();
        final state = buildState(
          status: AudioPlayerStatus.paused,
          totalDuration: journalAudio.data.duration,
          progress: const Duration(seconds: 5),
          pausedAt: const Duration(seconds: 5),
          speed: 1,
          showTranscriptsList: false,
          audioNote: journalAudio,
        );

        await pumpPlayer(tester, journalAudio: journalAudio, state: state);

        final material = tester.widget<Material>(
          find.byKey(playButtonSurfaceKey),
        );
        expect(material.shape, isA<CircleBorder>());
        expect(material.color, dsTokensLight.colors.surface.enabled);
      },
    );

    testWidgets(
      'play button surface adapts to dark token in dark theme',
      (WidgetTester tester) async {
        final journalAudio = buildJournalAudio();
        final state = buildState(
          status: AudioPlayerStatus.paused,
          totalDuration: journalAudio.data.duration,
          progress: const Duration(seconds: 5),
          pausedAt: const Duration(seconds: 5),
          speed: 1,
          showTranscriptsList: false,
          audioNote: journalAudio,
        );

        await pumpPlayer(
          tester,
          journalAudio: journalAudio,
          state: state,
          brightness: Brightness.dark,
        );

        final material = tester.widget<Material>(
          find.byKey(playButtonSurfaceKey),
        );
        expect(material.color, dsTokensDark.colors.surface.enabled);
      },
    );

    test('progress color resolves to interactive token in light theme', () {
      final colors = resolveAudioProgressColors(
        ThemeData(useMaterial3: true).copyWith(
          extensions: const [dsTokensLight],
        ),
      );

      expect(colors.progress, dsTokensLight.colors.interactive.enabled);
    });

    test('progress track uses a perceivable (>=3:1) token, not a hairline', () {
      final colors = resolveAudioProgressColors(
        ThemeData(useMaterial3: true).copyWith(
          extensions: const [dsTokensDark],
        ),
      );

      // lowEmphasis reads as a control boundary (WCAG 1.4.11); the old
      // decorative.level02 sat ~2.2:1 against the card surface.
      expect(colors.track, dsTokensDark.colors.text.lowEmphasis);
      expect(colors.progress, dsTokensDark.colors.interactive.enabled);
    });

    test(
      'progress colors fall back to ColorScheme.primary when tokens absent',
      () {
        final theme = ThemeData(useMaterial3: true);
        final colors = resolveAudioProgressColors(theme);
        expect(colors.progress, theme.colorScheme.primary);
      },
    );

    testWidgets('play button has no progress ring around it', (
      WidgetTester tester,
    ) async {
      final journalAudio = buildJournalAudio();
      final state = buildState(
        status: AudioPlayerStatus.playing,
        totalDuration: journalAudio.data.duration,
        progress: const Duration(seconds: 90),
        pausedAt: Duration.zero,
        speed: 1,
        showTranscriptsList: false,
        audioNote: journalAudio,
      );

      await pumpPlayer(tester, journalAudio: journalAudio, state: state);

      // The Figma redesign drops the animated ring painter that previously
      // wrapped the play button.
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });
  });
}
