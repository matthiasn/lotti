import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_inline_recorder.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../helpers/check_in_speech_fakes.dart';

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
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Finder key(String name) => find.byKey(ValueKey(name));

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
    expect(find.byType(LiveWaveform), findsOneWidget);
    expect(find.text('Audio saved to this device as you go'), findsOneWidget);
  });

  testWidgets("a refused start is reported in the composer's own terms", (
    tester,
  ) async {
    await pump(tester, recordFailure: AudioRecordingFailure.permissionDenied);
    expect(failed, [CheckInSpeechFailureKind.microphoneDenied]);
    expect(recorded, isEmpty);
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
    expect(find.text('Pause'), findsOneWidget);

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
    expect(find.text('0:23'), findsOneWidget);

    await tester.tap(key('check-in-recorder-stop'));
    await tester.pump();
    await tester.pump();

    expect(recorder.stopCalls, 1);
    expect(recorded, [('audio-1', const Duration(seconds: 23))]);
  });

  testWidgets('a stop that saves nothing, or throws, is a recording not '
      'saved — never a start that failed', (tester) async {
    await pump(tester, stopResult: null);
    await tester.tap(key('check-in-recorder-stop'));
    await tester.pump();
    expect(failed, [CheckInSpeechFailureKind.recordingNotSaved]);
    expect(recorded, isEmpty);
    // The controls are usable again for another try.
    expect(
      tester
          .widget<DesignSystemButton>(key('check-in-recorder-stop'))
          .onPressed,
      isNotNull,
    );

    await pump(tester, stopThrows: true);
    await tester.tap(key('check-in-recorder-stop'));
    await tester.pump();
    expect(failed.last, CheckInSpeechFailureKind.recordingNotSaved);
  });

  testWidgets('the controls go quiet while a stop is in flight', (
    tester,
  ) async {
    final gate = Completer<void>();
    await pump(tester, stopGate: gate);
    await tester.tap(key('check-in-recorder-stop'));
    await tester.pump();

    for (final name in [
      'check-in-recorder-stop',
      'check-in-recorder-pause',
      'check-in-recorder-discard',
    ]) {
      expect(
        tester.widget<DesignSystemButton>(key(name)).onPressed,
        isNull,
        reason: name,
      );
    }
    gate.complete();
    await tester.pump();
    expect(recorded, hasLength(1));
  });

  testWidgets('Discard asks first; confirming cancels and says so, backing '
      'out keeps recording', (tester) async {
    await pump(tester);
    await tester.tap(key('check-in-recorder-discard'));
    await tester.pumpAndSettle();
    expect(find.text('Discard recording?'), findsOneWidget);
    // This surface's own words, not the journal recorder's: the audio goes,
    // the check-in stays.
    expect(
      find.text('The audio is deleted. Your check-in stays open.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Keep recording'));
    await tester.pumpAndSettle();
    expect(recorder.cancelCalls, 0);
    expect(discarded, 0);

    await tester.tap(key('check-in-recorder-discard'));
    await tester.pumpAndSettle();
    // The dialog's confirm, not the recorder's own Discard beneath it. Pump
    // by hand: Stop wears its spinner until the parent takes the recorder
    // down, so nothing here ever "settles".
    await tester.tap(find.text('Discard').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(recorder.cancelCalls, 1);
    expect(discarded, 1);
  });

  testWidgets('Pause and Resume toggle the recorder and the label', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(key('check-in-recorder-pause'));
    await tester.pump();
    expect(recorder.pauseCalls, 1);
    expect(find.text('Resume'), findsOneWidget);
    // The live region says so too, as it says "recording" while live.
    expect(find.bySemanticsLabel('Paused'), findsOneWidget);
    await tester.tap(key('check-in-recorder-pause'));
    await tester.pump();
    expect(recorder.resumeCalls, 1);
    expect(find.text('Pause'), findsOneWidget);
  });

  testWidgets('the clock ticks in place: crossing a digit boundary moves '
      'nothing beneath it', (tester) async {
    await pump(tester);
    recorder.tick(progress: const Duration(seconds: 9));
    await tester.pump();
    final stopBefore = tester.getRect(key('check-in-recorder-stop'));
    final clockBefore = tester.getRect(key('check-in-recorder-clock'));

    recorder.tick(progress: const Duration(minutes: 59, seconds: 59));
    await tester.pump();
    expect(find.text('59:59'), findsOneWidget);
    expect(tester.getRect(key('check-in-recorder-stop')), stopBefore);
    expect(tester.getRect(key('check-in-recorder-clock')), clockBefore);
  });

  testWidgets('the level strip keeps a bounded window of samples', (
    tester,
  ) async {
    await pump(tester);
    for (var i = 0; i < CheckInInlineRecorder.amplitudeWindow + 10; i++) {
      recorder.tick(
        progress: Duration(milliseconds: 20 * i),
        dBFS: -30.0 - i,
      );
      await tester.pump();
    }
    final strip = tester.widget<LiveWaveform>(find.byType(LiveWaveform));
    expect(strip.amplitudes.length, CheckInInlineRecorder.amplitudeWindow);
    expect(strip.amplitudes.every((a) => a >= 0 && a <= 1), isTrue);
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

  testWidgets('the controls sit on the trailing rail, where Dictate, Try '
      'again and Add more live in every other phase', (tester) async {
    await pump(tester);
    final wrap = tester.widget<Wrap>(
      find.ancestor(
        of: key('check-in-recorder-discard'),
        matching: find.byType(Wrap),
      ),
    );
    expect(wrap.alignment, WrapAlignment.end);
  });
}
