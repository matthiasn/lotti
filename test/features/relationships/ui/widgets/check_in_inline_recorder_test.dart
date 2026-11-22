import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_inline_recorder.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/inline_recorder.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../helpers/check_in_speech_fakes.dart';

/// The recorder's own behaviour is pinned in `inline_recorder_test.dart`;
/// these pin what the People wrapper adds: the composer's failure kinds and
/// the pass-through of what the host asked for.
void main() {
  final failed = <CheckInSpeechFailureKind>[];
  final recorded = <(String, Duration)>[];
  setUp(() {
    failed.clear();
    recorded.clear();
  });

  Future<FakeAudioRecorderController> pump(
    WidgetTester tester, {
    AudioRecordingFailure? recordFailure,
    String? stopResult = 'audio-1',
    String? runningFor,
    bool compact = false,
    bool showStatus = false,
  }) async {
    final recorder = FakeAudioRecorderController(
      recordFailure: recordFailure,
      stopResult: stopResult,
      runningFor: runningFor,
    );
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        CheckInInlineRecorder(
          linkedId: 'person-1',
          categoryId: 'category-7',
          compact: compact,
          showStatus: showStatus,
          onRecorded: (id, length) => recorded.add((id, length)),
          onDiscarded: () {},
          onFailed: failed.add,
        ),
        overrides: [
          audioRecorderControllerProvider.overrideWith(() => recorder),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    return recorder;
  }

  testWidgets('records for the person, the host transcribing, and hands the '
      'take back', (tester) async {
    final recorder = await pump(tester, compact: true, showStatus: true);

    expect(recorder.recordCalls, [
      (linkedId: 'person-1', handledByCaller: true),
    ]);
    expect(recorder.categoryIds, ['category-7']);
    final inner = tester.widget<InlineRecorder>(find.byType(InlineRecorder));
    expect(inner.compact, isTrue);
    expect(inner.showStatus, isTrue);

    await tester.tap(find.byKey(const ValueKey('check-in-recorder-stop')));
    await tester.pump();
    expect(recorded, [('audio-1', Duration.zero)]);
  });

  for (final (name, failure, kind) in [
    (
      'a refused microphone',
      AudioRecordingFailure.permissionDenied,
      CheckInSpeechFailureKind.microphoneDenied,
    ),
    (
      'a failed start',
      AudioRecordingFailure.startFailed,
      CheckInSpeechFailureKind.recordingFailed,
    ),
  ]) {
    testWidgets("$name arrives in the composer's own kind", (tester) async {
      await pump(tester, recordFailure: failure);
      expect(failed, [kind]);
    });
  }

  testWidgets("someone else's running take is the recorder-busy card, and is "
      'left running', (tester) async {
    final recorder = await pump(tester, runningFor: 'person-2');

    expect(failed, [CheckInSpeechFailureKind.recorderBusy]);
    expect(recorder.recordCalls, isEmpty);
    expect(recorder.stopCalls, 0);
  });

  testWidgets('a take that could not be saved says so', (tester) async {
    await pump(tester, stopResult: null);
    await tester.tap(find.byKey(const ValueKey('check-in-recorder-stop')));
    await tester.pump();

    expect(failed, [CheckInSpeechFailureKind.recordingNotSaved]);
  });
}
