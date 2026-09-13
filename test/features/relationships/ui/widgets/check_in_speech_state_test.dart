import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';

void main() {
  const missing = CheckInSpeechFailure(
    CheckInSpeechFailureKind.transcriptMissing,
    audioEntryId: 'audio-1',
    length: Duration(seconds: 23),
  );

  group('checkInSaveBlockOf', () {
    test('saving wins over everything', () {
      expect(
        checkInSaveBlockOf(
          phase: const CheckInSpeechRecording(),
          hasWords: true,
          saving: true,
        ),
        CheckInSaveBlock.saving,
      );
    });

    test('speech in flight holds Save regardless of words', () {
      for (final hasWords in [true, false]) {
        expect(
          checkInSaveBlockOf(
            phase: const CheckInSpeechPreparing(),
            hasWords: hasWords,
            saving: false,
          ),
          CheckInSaveBlock.preparing,
        );
        expect(
          checkInSaveBlockOf(
            phase: const CheckInSpeechRecording(),
            hasWords: hasWords,
            saving: false,
          ),
          CheckInSaveBlock.recording,
        );
        expect(
          checkInSaveBlockOf(
            phase: const CheckInSpeechTranscribing(
              audioEntryId: 'audio-1',
              length: Duration(seconds: 5),
            ),
            hasWords: hasWords,
            saving: false,
          ),
          CheckInSaveBlock.transcribing,
        );
      }
    });

    test('at rest, words are the only thing Save waits for', () {
      for (final phase in [
        const CheckInSpeechIdle(),
        const CheckInSpeechReady(
          transcript: 'x',
          length: Duration(seconds: 1),
        ),
        const CheckInSpeechFailed(
          CheckInSpeechFailure(CheckInSpeechFailureKind.microphoneDenied),
        ),
        const CheckInSpeechFailed(missing),
      ]) {
        expect(
          checkInSaveBlockOf(phase: phase, hasWords: true, saving: false),
          CheckInSaveBlock.none,
          reason: '$phase with words',
        );
      }
      expect(
        checkInSaveBlockOf(
          phase: const CheckInSpeechIdle(),
          hasWords: false,
          saving: false,
        ),
        CheckInSaveBlock.emptyNarrative,
      );
    });

    test('a missing transcript with no words offers the retry', () {
      expect(
        checkInSaveBlockOf(
          phase: const CheckInSpeechFailed(missing),
          hasWords: false,
          saving: false,
        ),
        CheckInSaveBlock.typeOrRetry,
      );
      expect(
        checkInSaveBlockOf(
          phase: const CheckInSpeechFailed(
            CheckInSpeechFailure(CheckInSpeechFailureKind.recordingFailed),
          ),
          hasWords: false,
          saving: false,
        ),
        CheckInSaveBlock.emptyNarrative,
      );
    });
  });

  group('checkInWordCount', () {
    test('counts whitespace-separated runs', () {
      expect(checkInWordCount(''), 0);
      expect(checkInWordCount('   \n '), 0);
      expect(checkInWordCount('one'), 1);
      expect(checkInWordCount('a  b\n c'), 3);
      expect(checkInWordCount('  leading and trailing  '), 3);
    });

    glados.Glados<List<String>>(glados.any.list(glados.any.letters)).test(
      'joining N non-empty words with any whitespace counts N',
      (words) {
        final nonEmpty = words.where((w) => w.isNotEmpty).toList();
        final joined = nonEmpty.join('  \n ');
        expect(checkInWordCount(joined), nonEmpty.length);
      },
      tags: 'glados',
    );
  });

  group('checkInClockLabel', () {
    test('m:ss under an hour, h:mm:ss beyond or when asked', () {
      expect(checkInClockLabel(const Duration(seconds: 23)), '0:23');
      expect(
        checkInClockLabel(const Duration(minutes: 11, seconds: 5)),
        '11:05',
      );
      expect(
        checkInClockLabel(const Duration(hours: 1, seconds: 2)),
        '1:00:02',
      );
      expect(
        checkInClockLabel(const Duration(seconds: 23), alwaysHours: true),
        '0:00:23',
      );
    });

    test('never goes negative', () {
      expect(checkInClockLabel(const Duration(seconds: -5)), '0:00');
    });
  });

  group('CheckInSpeechFailure', () {
    test('maps the recorder refusals: denied is denied, the rest failed', () {
      expect(
        CheckInSpeechFailure.fromRecorder(
          AudioRecordingFailure.permissionDenied,
        ).kind,
        CheckInSpeechFailureKind.microphoneDenied,
      );
      expect(
        CheckInSpeechFailure.fromRecorder(
          AudioRecordingFailure.startFailed,
        ).kind,
        CheckInSpeechFailureKind.recordingFailed,
      );
      expect(
        CheckInSpeechFailure.fromRecorder(AudioRecordingFailure.busy).kind,
        CheckInSpeechFailureKind.recordingFailed,
      );
    });

    test('only a missing transcript has a recording to point at', () {
      expect(missing.hasRecording, isTrue);
      expect(
        const CheckInSpeechFailure(
          CheckInSpeechFailureKind.microphoneDenied,
        ).hasRecording,
        isFalse,
      );
      expect(
        () => CheckInSpeechFailure(CheckInSpeechFailureKind.transcriptMissing),
        throwsA(isA<AssertionError>()),
      );
    });

    test('is a value', () {
      expect(
        missing,
        const CheckInSpeechFailure(
          CheckInSpeechFailureKind.transcriptMissing,
          audioEntryId: 'audio-1',
          length: Duration(seconds: 23),
        ),
      );
      expect(missing.hashCode, isNot(0));
      expect(
        missing,
        isNot(
          const CheckInSpeechFailure(
            CheckInSpeechFailureKind.transcriptMissing,
            audioEntryId: 'audio-2',
          ),
        ),
      );
    });
  });

  group('checkInComposerStatusOf', () {
    test('rest and ready read as idle; the failures name themselves', () {
      expect(
        checkInComposerStatusOf(
          const CheckInSpeechIdle(),
          recorderPaused: false,
        ),
        CheckInComposerStatus.idle,
      );
      expect(
        checkInComposerStatusOf(
          const CheckInSpeechReady(transcript: 'x', length: Duration.zero),
          recorderPaused: false,
        ),
        CheckInComposerStatus.idle,
      );
      expect(
        checkInComposerStatusOf(
          const CheckInSpeechPreparing(),
          recorderPaused: false,
        ),
        CheckInComposerStatus.preparing,
      );
      expect(
        checkInComposerStatusOf(
          const CheckInSpeechTranscribing(
            audioEntryId: 'a',
            length: Duration.zero,
          ),
          recorderPaused: false,
        ),
        CheckInComposerStatus.transcribing,
      );
      final byKind = {
        CheckInSpeechFailureKind.microphoneDenied:
            CheckInComposerStatus.microphoneDenied,
        CheckInSpeechFailureKind.recordingFailed:
            CheckInComposerStatus.recordingFailed,
        CheckInSpeechFailureKind.transcriptionUnavailable:
            CheckInComposerStatus.transcriptionUnavailable,
      };
      for (final entry in byKind.entries) {
        expect(
          checkInComposerStatusOf(
            CheckInSpeechFailed(CheckInSpeechFailure(entry.key)),
            recorderPaused: false,
          ),
          entry.value,
        );
      }
      expect(
        checkInComposerStatusOf(
          const CheckInSpeechFailed(missing),
          recorderPaused: false,
        ),
        CheckInComposerStatus.transcriptMissing,
      );
    });

    test('recording is paused only while the recorder says so', () {
      expect(
        checkInComposerStatusOf(
          const CheckInSpeechRecording(),
          recorderPaused: false,
        ),
        CheckInComposerStatus.recording,
      );
      expect(
        checkInComposerStatusOf(
          const CheckInSpeechRecording(),
          recorderPaused: true,
        ),
        CheckInComposerStatus.paused,
      );
      // A pause flag outside recording is noise.
      expect(
        checkInComposerStatusOf(
          const CheckInSpeechIdle(),
          recorderPaused: true,
        ),
        CheckInComposerStatus.idle,
      );
    });
  });
}
