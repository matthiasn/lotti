import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_input_shader.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_inline_recorder.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recording_style.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../helpers/check_in_speech_fakes.dart';

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
  final failed = <CheckInSpeechFailureKind>[];
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
    bool adoptRunning = false,
    String style = 'modern',
  }) async {
    recorder = FakeAudioRecorderController(
      recordFailure: recordFailure,
      stopResult: stopResult,
      stopThrows: stopThrows,
      runningFor: runningFor,
    )..stopGate = stopGate;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        CheckInInlineRecorder(
          linkedId: 'person-1',
          categoryId: 'category-7',
          adoptRunning: adoptRunning,
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
    expect(find.text('Audio saved to this device as you go'), findsOneWidget);
  });

  group("the recording sheet's anatomy", () {
    testWidgets('the shared visualizer, clock and transport row, in that '
        'order, with no orb doubling as Stop', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);

      expect(find.byType(RecordingLevelVisualizer), findsOneWidget);
      expect(find.byType(RecordingTransportControls), findsOneWidget);
      final visualizer = tester.getRect(find.byType(RecordingLevelVisualizer));
      final clock = tester.getRect(key('check-in-recorder-clock'));
      final controls = tester.getRect(find.byType(RecordingTransportControls));
      expect(visualizer.bottom, lessThanOrEqualTo(clock.top + 0.5));
      expect(clock.bottom, lessThan(controls.top));
      // Discard, Pause, Stop: the sheet's order, left to right.
      final discard = tester.getRect(key('check-in-recorder-discard'));
      final pause = tester.getRect(key('check-in-recorder-pause'));
      final stop = tester.getRect(key('check-in-recorder-stop'));
      expect(discard.right, lessThan(pause.left));
      expect(pause.right, lessThan(stop.left));
      // The Stop pill carries its word; the discard is this surface's own.
      expect(find.text('Stop'), findsOneWidget);
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

    testWidgets("the clock is the sheet's and reads in words", (
      tester,
    ) async {
      await pump(tester);
      recorder.tick(progress: const Duration(seconds: 83));
      await tester.pump();
      final clock = tester.widget<RecordingClock>(
        key('check-in-recorder-clock'),
      );
      expect(clock.progress, const Duration(seconds: 83));
      expect(clock.semanticsLabel, '1 minute 23 seconds');
      expect(find.text('0:01:23'), findsOneWidget);
    });
  });

  testWidgets("a refused start is reported in the composer's own terms, "
      'and leaves nothing to pause or stop', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, recordFailure: AudioRecordingFailure.permissionDenied);
    expect(failed, [CheckInSpeechFailureKind.microphoneDenied]);
    expect(recorded, isEmpty);
    expect(enabled(tester, 'check-in-recorder-stop'), isFalse);
    expect(enabled(tester, 'check-in-recorder-pause'), isFalse);
    semantics.dispose();
  });

  testWidgets('a start the recorder refuses as busy or failed is a failed '
      'start', (tester) async {
    await pump(tester, recordFailure: AudioRecordingFailure.busy);
    expect(failed, [CheckInSpeechFailureKind.recordingFailed]);
  });

  // `record()` on a running recorder toggles it off; adopting attaches to
  // the take instead, and only hides the indicator.
  testWidgets('adopting a running take never calls record', (tester) async {
    await pump(tester, runningFor: 'person-1', adoptRunning: true);
    expect(recorder.recordCalls, isEmpty);
    expect(recorder.categoryIds, isEmpty);
    expect(recorder.modalVisibleLog, [true]);

    await tester.tap(key('check-in-recorder-stop'));
    await tester.pump();
    expect(recorded, [('audio-1', Duration.zero)]);
  });

  testWidgets('Stop hands back the entry and the length the clock stood at', (
    tester,
  ) async {
    await pump(tester);
    recorder.tick(progress: const Duration(seconds: 23), dBFS: -20);
    await tester.pump();
    expect(find.text('0:00:23'), findsOneWidget);

    await tester.tap(key('check-in-recorder-stop'));
    await tester.pump();
    await tester.pump();

    expect(recorder.stopCalls, 1);
    expect(recorded, [('audio-1', const Duration(seconds: 23))]);
  });

  testWidgets('a stop that saves nothing, or throws, is a recording not '
      'saved — never a start that failed', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, stopResult: null);
    await tester.tap(key('check-in-recorder-stop'));
    await tester.pump();
    expect(failed, [CheckInSpeechFailureKind.recordingNotSaved]);
    expect(recorded, isEmpty);

    await pump(tester, stopThrows: true);
    await tester.tap(key('check-in-recorder-stop'));
    await tester.pump();
    expect(failed.last, CheckInSpeechFailureKind.recordingNotSaved);
    semantics.dispose();
  });

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

  testWidgets('the clock ticks in place: crossing a digit boundary moves '
      'nothing beneath it', (tester) async {
    await pump(tester);
    recorder.tick(progress: const Duration(seconds: 9));
    await tester.pump();
    final stopBefore = tester.getRect(key('check-in-recorder-stop'));

    recorder.tick(progress: const Duration(minutes: 59, seconds: 59));
    await tester.pump();
    expect(find.text('0:59:59'), findsOneWidget);
    expect(tester.getRect(key('check-in-recorder-stop')), stopBefore);
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
