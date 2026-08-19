import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/util/audio_entry_one_liner.dart';

JournalAudio _audio({String? plainText, List<String> transcripts = const []}) {
  final ts = DateTime(2026, 4, 20, 12);
  return JournalAudio(
    meta: Metadata(
      id: 'audio-1',
      createdAt: ts,
      updatedAt: ts,
      dateFrom: ts,
      dateTo: ts,
    ),
    entryText: plainText == null ? null : EntryText(plainText: plainText),
    data: AudioData(
      dateFrom: ts,
      dateTo: ts,
      duration: const Duration(minutes: 1),
      audioFile: '',
      audioDirectory: '',
      transcripts: transcripts.isEmpty
          ? null
          : [
              for (final (i, transcript) in transcripts.indexed)
                AudioTranscript(
                  created: ts.add(Duration(minutes: i)),
                  library: 'lib',
                  model: 'model',
                  detectedLanguage: 'en',
                  transcript: transcript,
                ),
            ],
    ),
  );
}

void main() {
  group('audioEntryOneLiner', () {
    test('prefers the entry text over transcripts', () {
      final audio = _audio(
        plainText: 'Cleaned-up note',
        transcripts: ['raw transcript'],
      );
      expect(audioEntryOneLiner(audio), 'Cleaned-up note');
    });

    test('falls back to the LATEST transcript when entry text is empty', () {
      final audio = _audio(
        plainText: '   ',
        transcripts: ['first pass', 'second pass'],
      );
      expect(audioEntryOneLiner(audio), 'second pass');
    });

    test('returns null when nothing was transcribed yet', () {
      expect(audioEntryOneLiner(_audio()), isNull);
      expect(audioEntryOneLiner(_audio(plainText: '  \n ')), isNull);
    });

    test('collapses newlines and whitespace runs into single spaces', () {
      final audio = _audio(
        plainText: 'line one\nline two\n\n  line   three ',
      );
      expect(
        audioEntryOneLiner(audio),
        'line one line two line three',
      );
    });

    // Property: for ANY input text the result is either null or a single
    // line with no doubled whitespace — the invariant the collapsed card's
    // one-line rendering depends on.
    glados.Glados(glados.any.stringOf('abc \n\t')).test(
      'never returns an empty string, a newline, or a doubled space',
      (text) {
        final result = audioEntryOneLiner(_audio(plainText: text));
        if (result == null) {
          expect(text.trim(), isEmpty);
        } else {
          expect(result, isNotEmpty);
          expect(result.contains('\n'), isFalse);
          expect(result.contains('\t'), isFalse);
          expect(result.contains('  '), isFalse);
          expect(result.trim(), result);
        }
      },
      tags: 'glados',
    );
  });
}
