import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

void main() {
  const take = CheckInTake(
    audioEntryId: 'audio-1',
    length: Duration(seconds: 23),
  );

  group('checkInSaveBlockOf', () {
    test('saving wins over everything', () {
      expect(
        checkInSaveBlockOf(
          phase: const CheckInSpeechRecording(),
          hasWords: true,
          hasTakes: true,
          saving: true,
        ),
        CheckInSaveBlock.saving,
      );
    });

    test('the recorder at work holds Save, whatever there is', () {
      for (final (hasWords, hasTakes) in [
        (true, true),
        (true, false),
        (false, true),
        (false, false),
      ]) {
        expect(
          checkInSaveBlockOf(
            phase: const CheckInSpeechPreparing(),
            hasWords: hasWords,
            hasTakes: hasTakes,
            saving: false,
          ),
          CheckInSaveBlock.preparing,
        );
        expect(
          checkInSaveBlockOf(
            phase: const CheckInSpeechRecording(),
            hasWords: hasWords,
            hasTakes: hasTakes,
            saving: false,
          ),
          CheckInSaveBlock.recording,
        );
      }
    });

    // The point of takes: a recording is enough to save, its words still on
    // their way or not.
    test('at rest, words or a recording are enough', () {
      for (final phase in [
        const CheckInSpeechIdle(),
        const CheckInSpeechFailed(
          CheckInSpeechFailure(CheckInSpeechFailureKind.microphoneDenied),
        ),
      ]) {
        for (final (hasWords, hasTakes, block) in [
          (true, false, CheckInSaveBlock.none),
          (false, true, CheckInSaveBlock.none),
          (true, true, CheckInSaveBlock.none),
          (false, false, CheckInSaveBlock.emptyNarrative),
        ]) {
          expect(
            checkInSaveBlockOf(
              phase: phase,
              hasWords: hasWords,
              hasTakes: hasTakes,
              saving: false,
            ),
            block,
            reason: '$phase words=$hasWords takes=$hasTakes',
          );
        }
      }
    });
  });

  group('CheckInTake', () {
    test('starts transcribing, and moves between words states keeping '
        'what it is', () {
      expect(take.words, CheckInTakeWords.transcribing);

      final routed = take.withRoute('whisper · via Melious');
      final heard = routed.heard('Pip wants the krill memo.');
      expect(
        (heard.words, heard.transcript, heard.route, heard.length),
        (
          CheckInTakeWords.heard,
          'Pip wants the krill memo.',
          'whisper · via Melious',
          const Duration(seconds: 23),
        ),
      );

      final missing = routed.missing('HTTP 503');
      expect(
        (missing.words, missing.transcript, missing.detail),
        (CheckInTakeWords.missing, null, 'HTTP 503'),
      );

      // Try again: back to waiting, the error and any old words gone.
      final retried = missing.transcribing();
      expect(
        (retried.words, retried.detail, retried.route),
        (CheckInTakeWords.transcribing, null, 'whisper · via Melious'),
      );
      expect(missing.withRoute('r').words, CheckInTakeWords.missing);
    });

    test('is a value', () {
      expect(
        take.heard('x'),
        const CheckInTake(
          audioEntryId: 'audio-1',
          length: Duration(seconds: 23),
          words: CheckInTakeWords.heard,
          transcript: 'x',
        ),
      );
      expect(take.heard('x').hashCode, take.heard('x').hashCode);
      expect(take.heard('x'), isNot(take.heard('y')));
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

  group('checkInSpokenClockLabel', () {
    final messages = AppLocalizationsEn();
    test('says the length in words, minutes first, nothing that is zero', () {
      expect(
        checkInSpokenClockLabel(messages, const Duration(seconds: 23)),
        '23 seconds',
      );
      expect(
        checkInSpokenClockLabel(messages, const Duration(seconds: 83)),
        '1 minute 23 seconds',
      );
      expect(
        checkInSpokenClockLabel(messages, const Duration(minutes: 2)),
        '2 minutes',
      );
      expect(checkInSpokenClockLabel(messages, Duration.zero), '0 seconds');
    });
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
        checkInClockLabel(const Duration(hours: 1, seconds: 23)),
        '1:00:23',
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

    test('is a value', () {
      const denied = CheckInSpeechFailure(
        CheckInSpeechFailureKind.microphoneDenied,
      );
      expect(
        denied,
        const CheckInSpeechFailure(CheckInSpeechFailureKind.microphoneDenied),
      );
      expect(denied.hashCode, denied.kind.hashCode);
      expect(
        denied,
        isNot(
          const CheckInSpeechFailure(CheckInSpeechFailureKind.recorderBusy),
        ),
      );
    });
  });

  group('checkInComposerStatusOf', () {
    test('rest reads as idle; the failures name themselves', () {
      expect(
        checkInComposerStatusOf(
          const CheckInSpeechIdle(),
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
      final byKind = {
        CheckInSpeechFailureKind.microphoneDenied:
            CheckInComposerStatus.microphoneDenied,
        CheckInSpeechFailureKind.recordingFailed:
            CheckInComposerStatus.recordingFailed,
        CheckInSpeechFailureKind.recordingNotSaved:
            CheckInComposerStatus.recordingNotSaved,
        CheckInSpeechFailureKind.recorderBusy:
            CheckInComposerStatus.recorderBusy,
        CheckInSpeechFailureKind.transcriptionUnavailable:
            CheckInComposerStatus.transcriptionUnavailable,
      };
      for (final entry in byKind.entries) {
        expect(
          checkInComposerStatusOf(
            CheckInSpeechFailed(CheckInSpeechFailure(entry.key)),
            recorderPaused: false,
            takes: [take],
          ),
          entry.value,
        );
      }
    });

    // At rest the takes speak: one still waiting outranks one whose words
    // never came, and words that arrived say nothing.
    test('at rest, the takes say where the words are', () {
      for (final (takes, status) in [
        (<CheckInTake>[take.heard('x')], CheckInComposerStatus.idle),
        ([take], CheckInComposerStatus.transcribing),
        ([take.missing(null)], CheckInComposerStatus.transcriptMissing),
        (
          [take.missing(null), take],
          CheckInComposerStatus.transcribing,
        ),
      ]) {
        expect(
          checkInComposerStatusOf(
            const CheckInSpeechIdle(),
            recorderPaused: false,
            takes: takes,
          ),
          status,
        );
      }
      // The recorder is what the user is doing now.
      expect(
        checkInComposerStatusOf(
          const CheckInSpeechRecording(),
          recorderPaused: false,
          takes: [take],
        ),
        CheckInComposerStatus.recording,
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
