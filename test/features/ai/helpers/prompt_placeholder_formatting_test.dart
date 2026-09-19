import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/helpers/prompt_placeholder_formatting.dart';

Metadata _meta(String id) => Metadata(
  id: id,
  createdAt: DateTime(2024, 3, 15),
  dateFrom: DateTime(2024, 3, 15),
  dateTo: DateTime(2024, 3, 15),
  updatedAt: DateTime(2024, 3, 15),
);

JournalAudio _audio({
  String id = 'audio-1',
  String? editedText,
  List<AudioTranscript>? transcripts,
}) => JournalAudio(
  data: AudioData(
    audioFile: 'audio.m4a',
    audioDirectory: '/test',
    duration: const Duration(minutes: 1),
    dateFrom: DateTime(2024, 3, 15),
    dateTo: DateTime(2024, 3, 15),
    transcripts: transcripts,
  ),
  meta: _meta(id),
  entryText: editedText == null ? null : EntryText(plainText: editedText),
);

JournalEntry _entry({String id = 'entry-1', String? text}) => JournalEntry(
  meta: _meta(id),
  entryText: text == null ? null : EntryText(plainText: text),
);

/// Printable text mixed with every character JSON must escape.
const _awkwardChars = 'ab Z9"\\\n\r\t\b\f\u0000\u0001\u001b\u001fé→';

final _awkwardText = glados.any.stringOf(_awkwardChars);

AudioTranscript _transcript(String text, DateTime created) => AudioTranscript(
  created: created,
  library: 'lib',
  model: 'm',
  detectedLanguage: 'en',
  transcript: text,
);

void main() {
  group('resolveEntryText', () {
    test('prefers user-edited plain text over transcripts', () {
      final audio = _audio(
        editedText: 'edited wins',
        transcripts: [_transcript('transcript loses', DateTime(2024, 3, 16))],
      );
      expect(resolveEntryText(audio), 'edited wins');
    });

    test('falls back to the most recent transcript when no edited text', () {
      final audio = _audio(
        transcripts: [
          _transcript('older', DateTime(2024, 3, 15)),
          _transcript('newest', DateTime(2024, 3, 17)),
          _transcript('middle', DateTime(2024, 3, 16)),
        ],
      );
      expect(resolveEntryText(audio), 'newest');
    });

    test(
      'returns empty string when audio has no edited text or transcript',
      () {
        expect(resolveEntryText(_audio()), '');
      },
    );

    test('skips a blank latest transcript and yields empty', () {
      final audio = _audio(
        transcripts: [_transcript('   ', DateTime(2024, 3, 17))],
      );
      expect(resolveEntryText(audio), '');
    });

    test('uses edited text for a non-audio entry', () {
      expect(resolveEntryText(_entry(text: 'typed note')), 'typed note');
    });

    test('returns empty string for a non-audio entry without text', () {
      expect(resolveEntryText(_entry()), '');
    });
  });

  group('resolveAudioTranscript', () {
    test('returns the resolved text for an audio entry', () {
      final audio = _audio(
        transcripts: [_transcript('hello there', DateTime(2024, 3, 17))],
      );
      expect(resolveAudioTranscript(audio), 'hello there');
    });

    test('returns a no-transcription placeholder for empty audio', () {
      expect(resolveAudioTranscript(_audio()), '[No transcription available]');
    });

    test('returns a type-mismatch placeholder for non-audio entities', () {
      expect(
        resolveAudioTranscript(_entry()),
        '[Audio entry expected but received JournalEntry]',
      );
    });
  });

  group('escapeForJsonToken', () {
    test('escapes backslashes, quotes, and newlines', () {
      expect(
        escapeForJsonToken('a\\b"c\nd'),
        r'a\\b\"c\nd',
      );
    });

    test('leaves plain text unchanged', () {
      expect(escapeForJsonToken('macOS'), 'macOS');
    });
  });

  group('formatSpeechDictionaryPrompt', () {
    test('returns empty string for no terms', () {
      expect(formatSpeechDictionaryPrompt(const []), '');
    });

    test('injects the bracketed, quoted, escaped terms into the template', () {
      final out = formatSpeechDictionaryPrompt(['macOS', 'iPhone']);
      expect(out, contains('Required spellings: ["macOS", "iPhone"]'));
      expect(out, startsWith('IMPORTANT - SPEECH DICTIONARY'));
    });

    test('escapes special characters inside terms', () {
      final out = formatSpeechDictionaryPrompt([r'a"b\c']);
      expect(out, contains(r'["a\"b\\c"]'));
    });
  });

  group('formatCorrectionExamplesPrompt', () {
    test('returns empty string for no examples', () {
      expect(formatCorrectionExamplesPrompt(const []), '');
    });

    test('orders examples by capturedAt descending and formats arrows', () {
      final out = formatCorrectionExamplesPrompt([
        ChecklistCorrectionExample(
          before: 'old before',
          after: 'old after',
          capturedAt: DateTime(2024, 3, 15),
        ),
        ChecklistCorrectionExample(
          before: 'new before',
          after: 'new after',
          capturedAt: DateTime(2024, 3, 17),
        ),
      ]);
      final newIdx = out.indexOf('new before');
      final oldIdx = out.indexOf('old before');
      expect(newIdx, lessThan(oldIdx), reason: 'most recent must come first');
      expect(out, contains('- "new before" → "new after"'));
      expect(out, startsWith('USER-PROVIDED CORRECTION EXAMPLES'));
    });

    test('caps the number of injected examples at kMaxCorrectionExamples', () {
      final examples = List.generate(
        kMaxCorrectionExamples + 10,
        (i) => ChecklistCorrectionExample(
          before: 'b$i',
          after: 'a$i',
          capturedAt: DateTime(2024, 3, 15).add(Duration(seconds: i)),
        ),
      );
      final out = formatCorrectionExamplesPrompt(examples);
      final arrowCount = '→'.allMatches(out).length;
      expect(arrowCount, kMaxCorrectionExamples);
    });

    test('treats a null capturedAt as the epoch (sorts last)', () {
      final out = formatCorrectionExamplesPrompt([
        const ChecklistCorrectionExample(before: 'no time', after: 'x'),
        ChecklistCorrectionExample(
          before: 'has time',
          after: 'y',
          capturedAt: DateTime(2024, 3, 17),
        ),
      ]);
      expect(
        out.indexOf('has time'),
        lessThan(out.indexOf('no time')),
      );
    });

    test('escapes double quotes in before/after text', () {
      final out = formatCorrectionExamplesPrompt([
        ChecklistCorrectionExample(
          before: 'say "hi"',
          after: 'say "bye"',
          capturedAt: DateTime(2024, 3, 17),
        ),
      ]);
      expect(out, contains(r'- "say \"hi\"" → "say \"bye\""'));
    });
  });
  group('properties', () {
    glados.Glados(_awkwardText, glados.ExploreConfig(numRuns: 300)).test(
      'escapeForJsonToken decodes back to the original on a single line',
      (text) {
        final escaped = escapeForJsonToken(text);
        expect(jsonDecode('"$escaped"'), text);
        expect(escaped.codeUnits.every((u) => u >= 0x20), isTrue);
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.listWithLengthInRange(
        0,
        12,
        glados.any.combine2(
          _awkwardText,
          _awkwardText,
          (String before, String after) => (before, after),
        ),
      ),
      glados.any.intInRange(0, 1000),
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'correction examples render one line each, most recent first',
      (texts, seed) {
        // Distinct timestamps, handed over in a shuffled order.
        final examples = [
          for (final (i, (before, after)) in texts.indexed)
            ChecklistCorrectionExample(
              before: before,
              after: after,
              capturedAt: DateTime(2024, 3, 15).add(Duration(minutes: i)),
            ),
        ];
        final shuffled = [...examples]..shuffle(Random(seed));

        final out = formatCorrectionExamplesPrompt(shuffled);
        if (examples.isEmpty) {
          expect(out, isEmpty);
          return;
        }

        const lead = 'apply these corrections when you see matching patterns.';
        final block = out.substring(out.indexOf(lead) + lead.length + 2);
        final lines = block.substring(0, block.length - 1).split('\n');
        expect(lines, hasLength(min(examples.length, kMaxCorrectionExamples)));

        final linePattern = RegExp(r'^- "(.*)" → "(.*)"$');
        for (final (i, line) in lines.indexed) {
          final expected = examples[examples.length - 1 - i];
          final match = linePattern.firstMatch(line);
          expect(match, isNotNull, reason: line);
          expect(jsonDecode('"${match!.group(1)}"'), expected.before);
          expect(jsonDecode('"${match.group(2)}"'), expected.after);
        }
      },
      tags: 'glados',
    );
  });
}
