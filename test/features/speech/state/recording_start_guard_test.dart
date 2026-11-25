import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_start_guard.dart';

AudioRecorderState _running(AudioRecorderStatus status, {String? linkedId}) =>
    AudioRecorderState(
      status: status,
      progress: Duration.zero,
      dBFS: -160,
      inlineHostVisible: false,
      linkedId: linkedId,
    );

void main() {
  group('decideRecordingStart', () {
    test('nothing recording: start, whatever the subject', () {
      final idle = _running(AudioRecorderStatus.stopped, linkedId: 'task-1');
      expect(
        decideRecordingStart(idle, linkedId: 'task-2'),
        RecordingStartDecision.start,
      );
      expect(
        decideRecordingStart(idle, linkedId: null),
        RecordingStartDecision.start,
      );
    });

    for (final status in [
      AudioRecorderStatus.recording,
      AudioRecorderStatus.paused,
    ]) {
      group('a take ${status.name}', () {
        test('for this subject: attach', () {
          expect(
            decideRecordingStart(
              _running(status, linkedId: 'task-1'),
              linkedId: 'task-1',
            ),
            RecordingStartDecision.attach,
          );
        });

        test('for another subject: busy', () {
          expect(
            decideRecordingStart(
              _running(status, linkedId: 'task-1'),
              linkedId: 'task-2',
            ),
            RecordingStartDecision.busy,
          );
        });

        test('for a subject, asked for a voice note: busy', () {
          expect(
            decideRecordingStart(
              _running(status, linkedId: 'task-1'),
              linkedId: null,
            ),
            RecordingStartDecision.busy,
          );
        });

        test('as a voice note, asked for a voice note: attach', () {
          expect(
            decideRecordingStart(_running(status), linkedId: null),
            RecordingStartDecision.attach,
          );
        });
      });
    }
  });

  group('failureOfStart', () {
    test('a refused microphone reads as microphoneDenied', () {
      expect(
        failureOfStart(AudioRecordingFailure.permissionDenied),
        InlineRecordingFailure.microphoneDenied,
      );
    });

    test('a failed start reads as startFailed', () {
      expect(
        failureOfStart(AudioRecordingFailure.startFailed),
        InlineRecordingFailure.startFailed,
      );
    });

    test('a start or stop still in flight reads as a failed start', () {
      expect(
        failureOfStart(AudioRecordingFailure.busy),
        InlineRecordingFailure.startFailed,
      );
    });
  });
}
