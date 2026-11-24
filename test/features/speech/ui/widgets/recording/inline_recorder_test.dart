import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_voice_waveform.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_origin.dart';
import 'package:lotti/features/speech/state/recording_return.dart';
import 'package:lotti/features/speech/state/recording_start_guard.dart';
import 'package:lotti/features/speech/ui/widgets/recording/inline_recorder.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/recording_levels.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';
import '../../../../relationships/helpers/check_in_speech_fakes.dart';

void main() {
  late FakeAudioRecorderController recorder;
  final recorded = <(String, Duration)>[];
  final failed = <InlineRecordingFailure>[];
  var discarded = 0;

  setUp(() {
    recorded.clear();
    failed.clear();
    discarded = 0;
  });

  Future<void> pump(
    WidgetTester tester, {
    List<Override> extraOverrides = const [],
    AudioRecordingFailure? recordFailure,
    String? stopResult = 'audio-1',
    bool stopThrows = false,
    Completer<void>? stopGate,
    String? runningFor,
    bool showStatus = false,
    String? discardMessage,
    Widget? footer,
  }) async {
    recorder = FakeAudioRecorderController(
      recordFailure: recordFailure,
      stopResult: stopResult,
      stopThrows: stopThrows,
      runningFor: runningFor,
    )..stopGate = stopGate;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        InlineRecorder(
          linkedId: 'person-1',
          categoryId: 'category-7',
          showStatus: showStatus,
          discardMessage: discardMessage,
          footer: footer,
          onRecorded: (id, length) => recorded.add((id, length)),
          onDiscarded: () => discarded++,
          onFailed: failed.add,
        ),
        overrides: [
          audioRecorderControllerProvider.overrideWith(() => recorder),
          ...extraOverrides,
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Finder key(String name) => find.byKey(ValueKey(name));

  /// Pumps a confirmation modal's transition through, frame by frame. Not
  /// `pumpAndSettle`: while the take is live the visualizer keeps moving,
  /// so the tree never settles.
  Future<void> settleModal(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// What a control announces itself as.
  String? labelOf(WidgetTester tester, String name) =>
      tester.getSemantics(key(name)).label;

  /// Whether a control takes a tap.
  bool enabled(WidgetTester tester, String name) => tester
      .getSemantics(key(name))
      .getSemanticsData()
      .flagsCollection
      .isEnabled
      .toBoolOrNull()!;

  testWidgets('starts recording on mount, linked to the person, with '
      'transcription left to the caller, and hides the floating indicator', (
    tester,
  ) async {
    await pump(tester);

    expect(recorder.recordCalls, [
      (linkedId: 'person-1', handledByCaller: true),
    ]);
    expect(recorder.categoryIds, ['category-7']);
    expect(recorder.inlineHostVisibleLog, [true]);
    expect(failed, isEmpty);
  });

  group("the recorder's anatomy", () {
    testWidgets('the level line over the transport row — discard, pause, '
        'then the timed Stop — and a footer under them when the host has '
        'one', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, footer: const Text('an option'));

      expect(find.byType(RecordingTransportControls), findsOneWidget);
      final line = tester.getRect(find.byType(RecordingLevelLine));
      final controls = tester.getRect(find.byType(RecordingTransportControls));
      expect(line.bottom, lessThan(controls.top));
      expect(
        controls.bottom,
        lessThan(tester.getRect(find.text('an option')).top),
      );
      // Discard, pause, Stop: the recorder's order on every surface, Stop
      // last as on the recording strip.
      final discard = tester.getRect(key('cancel_recording'));
      final pause = tester.getRect(key('pause_resume_button'));
      final stop = tester.getRect(key('stop_recording'));
      expect(discard.right, lessThan(pause.left));
      expect(pause.right, lessThan(stop.left));
      // Each is named for a reader, the same on every surface.
      expect(labelOf(tester, 'stop_recording'), 'Stop');
      expect(labelOf(tester, 'cancel_recording'), 'Discard');
      semantics.dispose();
    });

    testWidgets('the level line moves with the voice', (tester) async {
      await pump(tester);
      for (var i = 1; i <= 4; i++) {
        recorder.tick(progress: Duration(milliseconds: 20 * i), dBFS: -18);
        await tester.pump();
      }
      expect(
        tester
            .widget<DesignSystemVoiceWaveform>(
              find.byType(DesignSystemVoiceWaveform),
            )
            .levels,
        List.filled(4, normaliseDbfs(-18)),
      );
    });

    for (final showStatus in [false, true]) {
      testWidgets('the take starting is announced once: by the level line '
          'where no status line says so — status line: $showStatus', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, showStatus: showStatus);
        final node = tester.getSemantics(find.byType(RecordingLevelLine));
        expect(node.label, 'Recording started');
        expect(node.flagsCollection.isLiveRegion, !showStatus);
        semantics.dispose();
      });
    }

    testWidgets("Stop carries the sheet's time, and a reader hears it in "
        'words', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      recorder.tick(progress: const Duration(seconds: 83));
      await tester.pump();
      final controls = tester.widget<RecordingTransportControls>(
        find.byType(RecordingTransportControls),
      );
      expect(controls.progress, const Duration(seconds: 83));
      expect(find.text('01:23'), findsOneWidget);
      expect(
        tester.getSemantics(key('stop_recording')).value,
        '1 minute 23 seconds',
      );
      semantics.dispose();
    });
  });

  testWidgets("a refused start is reported in the composer's own terms, "
      'and leaves nothing to pause or stop', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, recordFailure: AudioRecordingFailure.permissionDenied);
    expect(failed, [InlineRecordingFailure.microphoneDenied]);
    expect(recorded, isEmpty);
    expect(enabled(tester, 'stop_recording'), isFalse);
    expect(enabled(tester, 'pause_resume_button'), isFalse);
    semantics.dispose();
  });

  testWidgets('a start the recorder refuses as busy or failed is a failed '
      'start', (tester) async {
    await pump(tester, recordFailure: AudioRecordingFailure.busy);
    expect(failed, [InlineRecordingFailure.startFailed]);
  });

  // `record()` on a running recorder toggles it off; attaching to this
  // subject's take never calls it, never refiles it, and only hides the
  // indicator.
  testWidgets("attaching to this subject's running take never calls record", (
    tester,
  ) async {
    await pump(tester, runningFor: 'person-1');
    expect(recorder.recordCalls, isEmpty);
    expect(recorder.categoryIds, isEmpty);
    expect(recorder.inlineHostVisibleLog, [true]);

    await tester.tap(key('stop_recording'));
    await tester.pump();
    expect(recorded, [('audio-1', Duration.zero)]);
  });

  testWidgets('mounted on a host that is already on its way out, it leaves '
      "a running take's indicator alone and starts nothing", (tester) async {
    recorder = FakeAudioRecorderController(runningFor: 'person-1');
    final show = ValueNotifier(false);
    addTearDown(show.dispose);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                child: ValueListenableBuilder<bool>(
                  valueListenable: show,
                  builder: (context, shown, _) => shown
                      ? InlineRecorder(
                          linkedId: 'person-1',
                          categoryId: 'category-7',
                          onRecorded: (id, length) =>
                              recorded.add((id, length)),
                          onDiscarded: () => discarded++,
                          onFailed: failed.add,
                        )
                      : const Text('waiting'),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
        overrides: [
          audioRecorderControllerProvider.overrideWith(() => recorder),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Dismissed; the recorder only mounts during the exit animation.
    Navigator.of(tester.element(find.text('waiting'))).pop();
    await tester.pump();
    show.value = true;
    await tester.pump();
    expect(find.byType(InlineRecorder), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Hiding the indicator here would leave the take with no Stop anywhere.
    expect(recorder.inlineHostVisibleLog, isEmpty);
    expect(recorder.recordCalls, isEmpty);
    expect(failed, isEmpty);
  });

  testWidgets('a take running for someone else is never taken over: it is '
      'refused as busy, record is not called, and that take keeps running', (
    tester,
  ) async {
    // The recorder's `record()` is a toggle: called now it would stop the
    // other take and file it under this subject.
    await pump(tester, runningFor: 'someone-else');

    expect(failed, [InlineRecordingFailure.recorderBusy]);
    expect(recorder.recordCalls, isEmpty);
    expect(recorder.stopCalls, 0);
    expect(recorder.inlineHostVisibleLog, isEmpty);
    expect(recorded, isEmpty);
  });

  testWidgets('a host dismissed while the microphone is still starting '
      'never gets a take started behind it', (tester) async {
    recorder = FakeAudioRecorderController()..recordGate = Completer<void>();
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                child: InlineRecorder(
                  linkedId: 'person-1',
                  categoryId: 'category-7',
                  onRecorded: (id, length) => recorded.add((id, length)),
                  onDiscarded: () => discarded++,
                  onFailed: failed.add,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
        overrides: [
          audioRecorderControllerProvider.overrideWith(() => recorder),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(recorder.recordCalls, hasLength(1));

    // Dismissed, and still mounted for its exit animation, when the
    // microphone comes up.
    Navigator.of(tester.element(find.byType(InlineRecorder))).pop();
    await tester.pump();
    expect(find.byType(InlineRecorder), findsOneWidget);
    recorder.recordGate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      ProviderScope.containerOf(
        tester.element(find.text('open')),
      ).read(audioRecorderControllerProvider).status,
      AudioRecorderStatus.stopped,
    );
    expect(failed, isEmpty);
  });

  testWidgets('a take already running for this subject is attached to, '
      'without the host having to say so', (tester) async {
    await pump(tester, runningFor: 'person-1');

    expect(failed, isEmpty);
    expect(recorder.recordCalls, isEmpty);
    expect(recorder.inlineHostVisibleLog, [true]);
    await tester.tap(key('stop_recording'));
    await tester.pump();
    expect(recorded, [('audio-1', Duration.zero)]);
  });

  test("a recording's length is spoken in words", () async {
    final messages = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      spokenClockLabel(messages, const Duration(seconds: 23)),
      '23 seconds',
    );
    expect(
      spokenClockLabel(messages, const Duration(minutes: 2, seconds: 5)),
      '2 minutes 5 seconds',
    );
    expect(spokenClockLabel(messages, Duration.zero), '0 seconds');
  });

  testWidgets('Stop hands back the entry and the length the clock stood at', (
    tester,
  ) async {
    await pump(tester);
    recorder.tick(progress: const Duration(seconds: 23), dBFS: -20);
    await tester.pump();
    expect(find.text('00:23'), findsOneWidget);

    await tester.tap(key('stop_recording'));
    await tester.pump();
    await tester.pump();

    expect(recorder.stopCalls, 1);
    expect(recorded, [('audio-1', const Duration(seconds: 23))]);
  });

  for (final (name, stopResult, stopThrows) in [
    ('saves nothing', null, false),
    ('throws', 'audio-1', true),
  ]) {
    testWidgets('a stop that $name is a recording not saved — never a start '
        'that failed', (tester) async {
      await pump(tester, stopResult: stopResult, stopThrows: stopThrows);
      await tester.tap(key('stop_recording'));
      await tester.pump();
      await tester.pump();

      expect(recorder.stopCalls, 1);
      expect(failed, [InlineRecordingFailure.notSaved]);
      expect(recorded, isEmpty);
    });
  }

  testWidgets('every control goes quiet while a stop is in flight', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final gate = Completer<void>();
    await pump(tester, stopGate: gate);
    await tester.tap(key('stop_recording'));
    await tester.pump();

    for (final name in [
      'pause_resume_button',
      'cancel_recording',
      'stop_recording',
    ]) {
      expect(enabled(tester, name), isFalse, reason: name);
    }
    // A second press while the first is in flight stops nothing twice.
    await tester.tap(key('stop_recording'), warnIfMissed: false);
    expect(recorder.stopCalls, 1);
    gate.complete();
    await tester.pump();
    expect(recorded, hasLength(1));
    semantics.dispose();
  });

  testWidgets('Discard asks first; confirming cancels and says so, backing '
      'out keeps recording', (tester) async {
    await pump(tester);
    await tester.tap(key('cancel_recording'));
    await settleModal(tester);
    expect(find.text('Discard recording?'), findsOneWidget);
    // The recorder's own words, where the host has none.
    expect(
      find.textContaining('This recording will be deleted.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Keep recording'));
    await settleModal(tester);
    expect(recorder.cancelCalls, 0);
    expect(discarded, 0);

    await tester.tap(key('cancel_recording'));
    await settleModal(tester);
    await tester.tap(find.text('Discard').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(recorder.cancelCalls, 1);
    expect(discarded, 1);
  });

  testWidgets("a host's own words say what a discard loses", (tester) async {
    await pump(tester, discardMessage: 'The audio goes; the note stays.');
    await tester.tap(key('cancel_recording'));
    await settleModal(tester);
    expect(find.text('The audio goes; the note stays.'), findsOneWidget);
    expect(
      find.textContaining('This recording will be deleted.'),
      findsNothing,
    );
  });

  testWidgets('with no subject it records a take that stands on its own, '
      'and still never takes over a take running for a subject', (
    tester,
  ) async {
    Future<void> pumpUnlinked(FakeAudioRecorderController controller) async {
      recorder = controller;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          InlineRecorder(
            linkedId: null,
            transcriptionHandledByCaller: false,
            onRecorded: (id, length) => recorded.add((id, length)),
            onDiscarded: () => discarded++,
            onFailed: failed.add,
          ),
          overrides: [
            audioRecorderControllerProvider.overrideWith(() => recorder),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    await pumpUnlinked(FakeAudioRecorderController());
    expect(recorder.recordCalls, [(linkedId: null, handledByCaller: false)]);
    expect(failed, isEmpty);

    await pumpUnlinked(FakeAudioRecorderController(runningFor: 'a-task'));
    expect(failed, [InlineRecordingFailure.recorderBusy]);
    expect(recorder.recordCalls, isEmpty);
  });

  group('the origin a take starts from', () {
    testWidgets('is the route on screen, with the offset the page reported, '
        'so a take handed to the strip knows its way back', (tester) async {
      final nav = MockNavService();
      when(() => nav.activeRoute).thenReturn('/people/person-1');
      final scroll = RecordingOriginScroll()
        ..report('/people/person-1', 240)
        ..report('/tasks', 12);
      await pump(
        tester,
        extraOverrides: [
          navServiceProvider.overrideWithValue(nav),
          recordingOriginScrollProvider.overrideWithValue(scroll),
        ],
      );

      expect(recorder.recordOrigins, [
        const RecordingOrigin(
          route: '/people/person-1',
          subjectId: 'person-1',
          scrollOffset: 240,
        ),
      ]);
    });

    testWidgets('is none where navigation is not wired up — the take still '
        'starts, with no way back', (tester) async {
      await pump(tester);

      expect(recorder.recordCalls, hasLength(1));
      expect(recorder.recordOrigins, [null]);
    });
  });

  testWidgets('Pause and Resume toggle the recorder and the control', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    expect(labelOf(tester, 'pause_resume_button'), 'Pause');
    await tester.tap(key('pause_resume_button'));
    await tester.pump();
    expect(recorder.pauseCalls, 1);
    expect(labelOf(tester, 'pause_resume_button'), 'Resume');
    // The live region says so too, as it says "recording" while live.
    expect(find.bySemanticsLabel('Paused'), findsOneWidget);
    await tester.tap(key('pause_resume_button'));
    await tester.pump();
    expect(recorder.resumeCalls, 1);
    expect(labelOf(tester, 'pause_resume_button'), 'Pause');
    semantics.dispose();
  });

  testWidgets("the composer's recorder leaves the status to its header", (
    tester,
  ) async {
    await pump(tester);
    expect(
      find.byKey(const ValueKey('check-in-recorder-status')),
      findsNothing,
    );
  });

  testWidgets('where the host has no header of its own it says Recording '
      'or Paused in the header grammar', (tester) async {
    await pump(tester, showStatus: true);
    recorder.tick(progress: const Duration(seconds: 3));
    await tester.pump();
    final status = find.byKey(const ValueKey('check-in-recorder-status'));
    expect(
      find.descendant(of: status, matching: find.text('Recording')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: status, matching: find.byType(DesignSystemBadge)),
      findsOneWidget,
    );

    await recorder.pause();
    await tester.pump();
    expect(
      find.descendant(of: status, matching: find.text('Paused')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: status, matching: find.byIcon(LottiIcons.pause)),
      findsOneWidget,
    );
  });

  testWidgets('the clock ticks in place: crossing a digit boundary moves '
      'nothing beneath it', (tester) async {
    await pump(tester);
    recorder.tick(progress: const Duration(seconds: 9));
    await tester.pump();
    List<Rect> controls() => [
      for (final name in [
        'cancel_recording',
        'stop_recording',
        'pause_resume_button',
      ])
        tester.getRect(key(name)),
    ];
    final before = controls();
    final stopBefore = before[1];

    // The timer and both its neighbours: same size, same place.
    recorder.tick(progress: const Duration(minutes: 59, seconds: 59));
    await tester.pump();
    expect(find.text('59:59'), findsOneWidget);
    expect(controls(), before);

    // Past the hour the time grows its hour digit; the row stays on its
    // centre line.
    recorder.tick(progress: const Duration(hours: 1));
    await tester.pump();
    expect(find.text('01:00:00'), findsOneWidget);
    expect(
      tester.getRect(key('stop_recording')).center,
      stopBefore.center,
    );
  });

  // The sheet brings the indicator back once it has closed; the recorder
  // itself leaves the recording running, the recording sheet's own rule.
  testWidgets('leaving neither stops nor discards the recording', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(recorder.stopCalls, 0);
    expect(recorder.cancelCalls, 0);
  });
}
