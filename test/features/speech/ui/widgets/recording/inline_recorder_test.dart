import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_input_shader.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_style.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';
import 'package:lotti/features/speech/ui/widgets/recording/inline_recorder.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../widget_test_utils.dart';
import '../../../../relationships/helpers/check_in_speech_fakes.dart';

/// The user's recording look, as the recording sheet's tests seed it.
AppPrefs _stylePrefs(String style) => AppPrefs(
  getBool: (_) async => null,
  setBool: ({required key, required value}) async => true,
  getString: (key) async => key == recordingStylePrefsKey ? style : null,
  setString: ({required key, required value}) async => true,
);

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
    AudioRecordingFailure? recordFailure,
    String? stopResult = 'audio-1',
    bool stopThrows = false,
    Completer<void>? stopGate,
    String? runningFor,
    String style = 'modern',
    bool showStatus = false,
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
          onRecorded: (id, length) => recorded.add((id, length)),
          onDiscarded: () => discarded++,
          onFailed: failed.add,
        ),
        overrides: [
          audioRecorderControllerProvider.overrideWith(() => recorder),
          recordingStyleAppPrefsProvider.overrideWithValue(_stylePrefs(style)),
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
    expect(recorder.modalVisibleLog, [true]);
    expect(failed, isEmpty);
  });

  group("the recording sheet's anatomy", () {
    testWidgets('the shared visualizer, level line and transport row, in '
        'that order, with the timed Stop between discard and pause', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);

      expect(find.byType(RecordingLevelVisualizer), findsOneWidget);
      expect(find.byType(RecordingTransportControls), findsOneWidget);
      final visualizer = tester.getRect(find.byType(RecordingLevelVisualizer));
      final line = tester.getRect(find.byType(RecordingLevelLine));
      final controls = tester.getRect(find.byType(RecordingTransportControls));
      expect(visualizer.bottom, lessThanOrEqualTo(line.top + 0.5));
      expect(line.bottom, lessThan(controls.top));
      // Discard, Stop, Pause: the sheet's order, left to right.
      final discard = tester.getRect(key('check-in-recorder-discard'));
      final pause = tester.getRect(key('check-in-recorder-pause'));
      final stop = tester.getRect(key('check-in-recorder-stop'));
      expect(discard.right, lessThan(stop.left));
      expect(stop.right, lessThan(pause.left));
      // Stop is named for a reader; the discard is this surface's own.
      expect(labelOf(tester, 'check-in-recorder-stop'), 'Stop');
      expect(labelOf(tester, 'check-in-recorder-discard'), 'Discard');
      semantics.dispose();
    });

    for (final (style, type) in [
      ('modern', AiVoiceInputShader),
      ('analogue', AnalogVuMeter),
    ]) {
      testWidgets('draws the look the user chose — $style', (tester) async {
        await pump(tester, style: style);
        recorder.tick(progress: const Duration(seconds: 3), dBFS: -18);
        await tester.pump();
        expect(find.byType(type), findsOneWidget);
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
        tester.getSemantics(key('check-in-recorder-stop')).value,
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
    expect(enabled(tester, 'check-in-recorder-stop'), isFalse);
    expect(enabled(tester, 'check-in-recorder-pause'), isFalse);
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
    expect(recorder.modalVisibleLog, [true]);

    await tester.tap(key('check-in-recorder-stop'));
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
          recordingStyleAppPrefsProvider.overrideWithValue(
            _stylePrefs('modern'),
          ),
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
    expect(recorder.modalVisibleLog, isEmpty);
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
    expect(recorder.modalVisibleLog, isEmpty);
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
          recordingStyleAppPrefsProvider.overrideWithValue(
            _stylePrefs('modern'),
          ),
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
    expect(recorder.modalVisibleLog, [true]);
    await tester.tap(key('check-in-recorder-stop'));
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

    await tester.tap(key('check-in-recorder-stop'));
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
      await tester.tap(key('check-in-recorder-stop'));
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
    await tester.tap(key('check-in-recorder-stop'));
    await tester.pump();

    for (final name in [
      'check-in-recorder-pause',
      'check-in-recorder-discard',
      'check-in-recorder-stop',
    ]) {
      expect(enabled(tester, name), isFalse, reason: name);
    }
    // A second press while the first is in flight stops nothing twice.
    await tester.tap(key('check-in-recorder-stop'), warnIfMissed: false);
    expect(recorder.stopCalls, 1);
    gate.complete();
    await tester.pump();
    expect(recorded, hasLength(1));
    semantics.dispose();
  });

  testWidgets('Discard asks first; confirming cancels and says so, backing '
      'out keeps recording', (tester) async {
    await pump(tester);
    await tester.tap(key('check-in-recorder-discard'));
    await settleModal(tester);
    expect(find.text('Discard recording?'), findsOneWidget);
    // This surface's own words, not the journal recorder's: the audio goes,
    // the check-in stays.
    expect(
      find.text('The audio is deleted. Your check-in stays open.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Keep recording'));
    await settleModal(tester);
    expect(recorder.cancelCalls, 0);
    expect(discarded, 0);

    await tester.tap(key('check-in-recorder-discard'));
    await settleModal(tester);
    await tester.tap(find.text('Discard').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(recorder.cancelCalls, 1);
    expect(discarded, 1);
  });

  testWidgets('Pause and Resume toggle the recorder and the control', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    expect(labelOf(tester, 'check-in-recorder-pause'), 'Pause');
    await tester.tap(key('check-in-recorder-pause'));
    await tester.pump();
    expect(recorder.pauseCalls, 1);
    expect(labelOf(tester, 'check-in-recorder-pause'), 'Resume');
    // The live region says so too, as it says "recording" while live.
    expect(find.bySemanticsLabel('Paused'), findsOneWidget);
    await tester.tap(key('check-in-recorder-pause'));
    await tester.pump();
    expect(recorder.resumeCalls, 1);
    expect(labelOf(tester, 'check-in-recorder-pause'), 'Pause');
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
      for (final name in ['discard', 'stop', 'pause'])
        tester.getRect(key('check-in-recorder-$name')),
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
      tester.getRect(key('check-in-recorder-stop')).center,
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
