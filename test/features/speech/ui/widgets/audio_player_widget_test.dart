import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_player_state.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/services/audio_waveform_service.dart';
import 'package:lotti/features/speech/state/audio_waveform_provider.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/features/speech/ui/widgets/progress/audio_progress_bar.dart';
import 'package:lotti/features/speech/ui/widgets/progress/audio_waveform_scrubber.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/audio_player_controller.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/entry_tools.dart';
import 'package:material_ui/material_ui.dart';
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
  JournalAudio? lastPlayedAudioNote;

  @override
  AudioPlayerState build() => _state;

  @override
  Future<void> playAudioNote(JournalAudio audioNote) async {
    lastPlayedAudioNote = audioNote;
  }

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
    Duration buffered = Duration.zero,
    JournalAudio? audioNote,
  }) {
    return AudioPlayerState(
      status: status,
      totalDuration: totalDuration,
      progress: progress,
      pausedAt: pausedAt,
      speed: speed,
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
    Locale? locale,
  }) async {
    controller = _FakeAudioPlayerController(state);

    when(
      () => waveformService.loadWaveform(
        journalAudio,
        targetBuckets: any(named: 'targetBuckets'),
      ),
    ).thenAnswer((_) async => waveformData);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: AudioPlayerWidget(journalAudio),
            ),
          ),
        ),
        overrides: [
          audioPlayerControllerProvider.overrideWith(() => controller),
        ],
        theme: ThemeData(useMaterial3: true, brightness: brightness),
        locale: locale,
      ),
    );

    await tester.pump();
  }

  testWidgets('renders the audio card with minimal controls', (
    WidgetTester tester,
  ) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.playing,
      totalDuration: journalAudio.data.duration,
      progress: const Duration(seconds: 45),
      pausedAt: Duration.zero,
      speed: 1,
      buffered: const Duration(minutes: 1),
      audioNote: journalAudio,
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    expect(find.byType(AudioProgressBar), findsOneWidget);
    expect(find.text('1x'), findsOneWidget);
    expect(find.bySemanticsLabel('Pause audio'), findsOneWidget);
    expect(find.byIcon(LottiIcons.description), findsNothing);
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
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    expect(find.bySemanticsLabel('Play audio'), findsOneWidget);
  });

  testWidgets('localizes player controls for assistive technology', (
    tester,
  ) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.stopped,
      totalDuration: journalAudio.data.duration,
      progress: Duration.zero,
      pausedAt: Duration.zero,
      speed: 1,
    );

    await pumpPlayer(
      tester,
      journalAudio: journalAudio,
      state: state,
      locale: const Locale('de'),
    );

    expect(find.bySemanticsLabel('Audio abspielen'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Wiedergabegeschwindigkeit, 1x'),
      findsOneWidget,
    );
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
      buffered: const Duration(seconds: 6),
      audioNote: journalAudio,
    );

    await pumpPlayer(
      tester,
      journalAudio: journalAudio,
      state: state,
      waveformData: AudioWaveformData(
        amplitudes: const <double>[0.3, 0.6, 0.9],
      ),
    );

    expect(find.byType(AudioWaveformScrubber), findsOneWidget);
    expect(find.byType(AudioProgressBar), findsNothing);
  });

  testWidgets('keeps the waveform on screen while it reloads', (
    WidgetTester tester,
  ) async {
    final journalAudio = buildJournalAudio();
    await pumpPlayer(
      tester,
      journalAudio: journalAudio,
      state: buildState(
        status: AudioPlayerStatus.stopped,
        totalDuration: journalAudio.data.duration,
        progress: Duration.zero,
        pausedAt: Duration.zero,
        speed: 1,
      ),
      waveformData: AudioWaveformData(
        amplitudes: const <double>[0.3, 0.6, 0.9],
      ),
    );
    expect(find.byType(AudioWaveformScrubber), findsOneWidget);

    // A reload that has not answered yet: the drawn waveform stays, rather
    // than dropping back to the plain bar until the answer lands.
    final pending = Completer<AudioWaveformData?>();
    when(
      () => waveformService.loadWaveform(
        journalAudio,
        targetBuckets: any(named: 'targetBuckets'),
      ),
    ).thenAnswer((_) => pending.future);
    ProviderScope.containerOf(
      tester.element(find.byType(AudioPlayerWidget)),
    ).invalidate(audioWaveformProvider);
    await tester.pump();

    expect(find.byType(AudioWaveformScrubber), findsOneWidget);
    expect(find.byType(AudioProgressBar), findsNothing);
    pending.complete(null);
  });

  testWidgets('keeps the waveform when a width change asks for a different '
      'bar count that has not loaded yet', (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    AudioPlayerState stopped() => buildState(
      status: AudioPlayerStatus.stopped,
      totalDuration: journalAudio.data.duration,
      progress: Duration.zero,
      pausedAt: Duration.zero,
      speed: 1,
    );
    final amplitudes = List<double>.filled(40, 0.5);
    await pumpPlayer(
      tester,
      journalAudio: journalAudio,
      state: stopped(),
      waveformData: AudioWaveformData(amplitudes: amplitudes),
    );
    final before = tester.widget<AudioWaveformScrubber>(
      find.byType(AudioWaveformScrubber),
    );
    expect(before.amplitudes, amplitudes);

    // Narrower: fewer bars, so a provider instance that has no answer yet.
    final pending = Completer<AudioWaveformData?>();
    when(
      () => waveformService.loadWaveform(
        journalAudio,
        targetBuckets: any(named: 'targetBuckets'),
      ),
    ).thenAnswer((_) => pending.future);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: AudioPlayerWidget(journalAudio),
            ),
          ),
        ),
        overrides: [
          audioPlayerControllerProvider.overrideWith(() => controller),
        ],
        theme: ThemeData(useMaterial3: true),
      ),
    );
    await tester.pump();

    final verification = verify(
      () => waveformService.loadWaveform(
        journalAudio,
        targetBuckets: captureAny(named: 'targetBuckets'),
      ),
    );
    expect(verification.captured.toSet().length, greaterThan(1));
    expect(
      tester
          .widget<AudioWaveformScrubber>(find.byType(AudioWaveformScrubber))
          .amplitudes,
      amplitudes,
    );
    expect(find.byType(AudioProgressBar), findsNothing);

    // The answer for the new width replaces what was drawn.
    final narrower = List<double>.filled(20, 0.8);
    pending.complete(AudioWaveformData(amplitudes: narrower));
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<AudioWaveformScrubber>(find.byType(AudioWaveformScrubber))
          .amplitudes,
      narrower,
    );
  });

  testWidgets('the waveform keeps its width when the time label gains or '
      'loses its hours field', (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    const total = Duration(hours: 1, minutes: 5);
    double waveformWidth() =>
        tester.getSize(find.byType(AudioProgressBar)).width;

    // At rest the label is the length, "01:05:00".
    await pumpPlayer(
      tester,
      journalAudio: journalAudio,
      state: buildState(
        status: AudioPlayerStatus.stopped,
        totalDuration: total,
        progress: Duration.zero,
        pausedAt: Duration.zero,
        speed: 1,
      ),
    );
    expect(find.text('01:05:00'), findsOneWidget);
    final atRest = waveformWidth();

    // Loaded, the label is the position: "00:30", then "01:00:30".
    for (final position in const [
      Duration(seconds: 30),
      Duration(hours: 1, seconds: 30),
    ]) {
      await tester.pumpWidget(Container());
      await pumpPlayer(
        tester,
        journalAudio: journalAudio,
        state: buildState(
          status: AudioPlayerStatus.playing,
          totalDuration: total,
          progress: position,
          pausedAt: Duration.zero,
          speed: 1,
          audioNote: journalAudio,
        ),
      );
      expect(find.text(formatElapsed(position)), findsOneWidget);
      expect(waveformWidth(), atRest);
    }
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
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    await tester.tap(find.bySemanticsLabel('Play audio'));
    await tester.pump();

    expect(controller.lastPlayedAudioNote?.meta.id, journalAudio.meta.id);
  });

  testWidgets(
    'tapping play on an inactive card never sequences setAudioNote and play '
    'as two separate calls',
    (WidgetTester tester) async {
      // The regression this guards: as two un-awaited calls, `play()` ran
      // while `setAudioNote()` was still resolving the path, re-opened the
      // previously selected recording and played *that* instead. The widget
      // must hand the controller one atomic request.
      final journalAudio = buildJournalAudio();
      final state = buildState(
        status: AudioPlayerStatus.stopped,
        totalDuration: journalAudio.data.duration,
        progress: Duration.zero,
        pausedAt: Duration.zero,
        speed: 1,
      );

      await pumpPlayer(tester, journalAudio: journalAudio, state: state);

      await tester.tap(find.bySemanticsLabel('Play audio'));
      await tester.pump();

      expect(controller.lastAudioNoteSet, isNull);
      expect(controller.playWasCalled, isFalse);
      expect(controller.lastPlayedAudioNote, same(journalAudio));
    },
  );

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
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    // Speed belongs to the loaded recording: any other player's control is
    // a disabled button, not a live-looking one that does nothing.
    final speedButton = tester.widget<DesignSystemButton>(
      find.widgetWithText(DesignSystemButton, '1.5x'),
    );
    expect(speedButton.onPressed, isNull);

    await tester.tap(find.text('1.5x'), warnIfMissed: false);
    await tester.pump();
    expect(controller.lastSpeedSet, isNull);
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
    testWidgets('tapping ${transition.label} cycles to ${transition.next}x', (
      WidgetTester tester,
    ) async {
      final journalAudio = buildJournalAudio();
      final state = buildState(
        status: AudioPlayerStatus.playing,
        totalDuration: journalAudio.data.duration,
        progress: const Duration(seconds: 5),
        pausedAt: Duration.zero,
        speed: transition.current,
        audioNote: journalAudio,
      );

      await pumpPlayer(tester, journalAudio: journalAudio, state: state);

      await tester.tap(find.text(transition.label));
      await tester.pump();

      expect(controller.lastSpeedSet, transition.next);
    });
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
      audioNote: journalAudio,
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    // The loaded recording's label is its position, and the scrubber runs
    // against the state's length (03:00), not the entry's stored 05:00.
    expect(find.text('00:30'), findsOneWidget);
    expect(find.text('05:00'), findsNothing);
    expect(
      tester.widget<AudioProgressBar>(find.byType(AudioProgressBar)).total,
      const Duration(minutes: 3),
    );
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
      audioNote: journalAudio,
    );

    await pumpPlayer(tester, journalAudio: journalAudio, state: state);

    // Should not throw and should render
    expect(find.byType(AudioProgressBar), findsOneWidget);
  });

  testWidgets('a non-default speed is never painted as an error', (
    WidgetTester tester,
  ) async {
    final journalAudio = buildJournalAudio();
    await pumpPlayer(
      tester,
      journalAudio: journalAudio,
      state: buildState(
        status: AudioPlayerStatus.playing,
        totalDuration: journalAudio.data.duration,
        progress: const Duration(seconds: 5),
        pausedAt: Duration.zero,
        speed: 1.5,
        audioNote: journalAudio,
      ),
    );

    final label = find.text('1.5x');
    final theme = Theme.of(tester.element(label));
    final color = DefaultTextStyle.of(tester.element(label)).style.color;
    expect(color, isNot(theme.colorScheme.error));
    expect(
      color,
      isNot(theme.extension<DsTokens>()!.colors.alert.error.defaultColor),
    );
  });

  testWidgets('is one 40 px row at phone and desktop widths', (
    WidgetTester tester,
  ) async {
    final journalAudio = buildJournalAudio();
    for (final width in <double>[300, 720]) {
      await tester.pumpWidget(Container());
      await pumpPlayer(
        tester,
        journalAudio: journalAudio,
        state: buildState(
          status: AudioPlayerStatus.playing,
          totalDuration: journalAudio.data.duration,
          progress: const Duration(seconds: 5),
          pausedAt: Duration.zero,
          speed: 1.75,
          audioNote: journalAudio,
        ),
        width: width,
      );
      expect(tester.getSize(find.byType(AudioPlayerWidget)).height, 40);
      // Time and speed share the play control's row.
      final playCenter = tester.getCenter(
        find.byKey(const Key('audio_player_play_button_surface')),
      );
      expect(tester.getCenter(find.text('00:05')).dy, playCenter.dy);
      expect(tester.getCenter(find.text('1.75x')).dy, playCenter.dy);
    }
  });

  testWidgets('shows correct buffered progress', (WidgetTester tester) async {
    final journalAudio = buildJournalAudio();
    final state = buildState(
      status: AudioPlayerStatus.playing,
      totalDuration: const Duration(minutes: 5),
      progress: const Duration(seconds: 30),
      pausedAt: Duration.zero,
      speed: 1,
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
            expectedIcon: LottiIcons.pause,
            expectedProgress: activeProgress,
          ),
          (
            name: 'paused shows play icon and retains progress',
            status: AudioPlayerStatus.paused,
            active: true,
            expectedIcon: LottiIcons.play,
            expectedProgress: activeProgress,
          ),
          (
            name: 'stopped shows play icon and resets progress to zero',
            status: AudioPlayerStatus.stopped,
            active: false,
            expectedIcon: LottiIcons.play,
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
          audioNote: c.active ? journalAudio : null,
        );

        await pumpPlayer(tester, journalAudio: journalAudio, state: state);

        // Button icon reflects the playing/non-playing distinction.
        expect(find.byIcon(c.expectedIcon), findsOneWidget);
        expect(
          find.byIcon(
            c.expectedIcon == LottiIcons.pause
                ? LottiIcons.play
                : LottiIcons.pause,
          ),
          findsNothing,
        );

        // Progress bar value is the live progress only while active.
        final progressBar = tester.widget<AudioProgressBar>(
          find.byType(AudioProgressBar),
        );
        expect(progressBar.progress, c.expectedProgress);
        expect(progressBar.enabled, c.active);

        // One label: the position while loaded, the length at rest.
        expect(
          find.text(
            formatElapsed(c.active ? activeProgress : totalDuration),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            formatElapsed(c.active ? totalDuration : activeProgress),
          ),
          findsNothing,
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

    testWidgets('play button surface adapts to dark token in dark theme', (
      WidgetTester tester,
    ) async {
      final journalAudio = buildJournalAudio();
      final state = buildState(
        status: AudioPlayerStatus.paused,
        totalDuration: journalAudio.data.duration,
        progress: const Duration(seconds: 5),
        pausedAt: const Duration(seconds: 5),
        speed: 1,
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
    });

    test('progress color resolves to interactive token in light theme', () {
      final colors = resolveAudioProgressColors(
        ThemeData(
          useMaterial3: true,
        ).copyWith(extensions: const [dsTokensLight]),
      );

      expect(colors.progress, dsTokensLight.colors.interactive.enabled);
    });

    test('progress track uses a perceivable (>=3:1) token, not a hairline', () {
      final colors = resolveAudioProgressColors(
        ThemeData(
          useMaterial3: true,
        ).copyWith(extensions: const [dsTokensDark]),
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
        audioNote: journalAudio,
      );

      await pumpPlayer(tester, journalAudio: journalAudio, state: state);

      // The Figma redesign drops the animated ring painter that previously
      // wrapped the play button.
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });
  });
}
