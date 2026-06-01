import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/workflow/task_source_renderer.dart';

import '../../../helpers/entity_factories.dart';

Metadata _meta(String id, DateTime dateFrom) => Metadata(
  id: id,
  createdAt: dateFrom,
  dateFrom: dateFrom,
  dateTo: dateFrom,
  updatedAt: dateFrom,
);

JournalEntry _text(String id, String text, {DateTime? dateFrom}) =>
    JournalEntry(
      meta: _meta(id, dateFrom ?? DateTime(2024, 3, 10)),
      entryText: EntryText(plainText: text),
    );

JournalAudio _audio(
  String id, {
  String? editedText,
  String? transcript,
  String language = 'en',
  DateTime? dateFrom,
}) => JournalAudio(
  meta: _meta(id, dateFrom ?? DateTime(2024, 3, 11)),
  entryText: editedText == null ? null : EntryText(plainText: editedText),
  data: AudioData(
    dateFrom: dateFrom ?? DateTime(2024, 3, 11),
    dateTo: dateFrom ?? DateTime(2024, 3, 11),
    duration: const Duration(minutes: 1),
    audioFile: 'a.m4a',
    audioDirectory: '/audio',
    transcripts: transcript == null
        ? null
        : [
            AudioTranscript(
              created: DateTime(2024, 3, 11),
              library: 'whisper',
              model: 'small',
              detectedLanguage: language,
              transcript: transcript,
            ),
          ],
  ),
);

void main() {
  group('renderTaskSources', () {
    test('renders a text entry with provenance and source timestamp', () {
      final sources = renderTaskSources([
        _text('e1', 'a note', dateFrom: DateTime(2024, 3, 10)),
      ]);

      expect(sources, hasLength(1));
      expect(sources.single.contentEntryId, 'e1');
      expect(sources.single.sourceCreatedAt, DateTime(2024, 3, 10));
      expect(sources.single.content, {'entryType': 'text', 'text': 'a note'});
    });

    test('renders an audio transcript when the entry is not hand-edited', () {
      final sources = renderTaskSources([
        _audio('e1', transcript: 'spoken words', language: 'de'),
      ]);

      expect(sources.single.content, {
        'entryType': 'audio',
        'text': '',
        'audioTranscript': 'spoken words',
        'transcriptLanguage': 'de',
      });
    });

    test('prefers edited text over the transcript for an audio entry', () {
      final sources = renderTaskSources([
        _audio(
          'e1',
          editedText: 'corrected text',
          transcript: 'raw transcript',
        ),
      ]);

      // The transcript is dropped once the user has edited the text.
      expect(sources.single.content, {
        'entryType': 'audio',
        'text': 'corrected text',
      });
    });

    test('renders an image entry as its (possibly empty) text', () {
      final image = JournalImage(
        meta: _meta('e1', DateTime(2024, 3, 12)),
        data: ImageData(
          capturedAt: DateTime(2024, 3, 12),
          imageId: 'img-1',
          imageFile: 'img.jpg',
          imageDirectory: '/images',
        ),
        entryText: const EntryText(plainText: 'caption'),
      );

      final sources = renderTaskSources([image]);

      expect(sources.single.content, {'entryType': 'image', 'text': 'caption'});
    });

    test('skips non-log linked entities', () {
      final sources = renderTaskSources([
        TestTaskFactory.create(id: 'task-1'),
        _text('e1', 'kept'),
      ]);

      expect(sources.map((s) => s.contentEntryId), ['e1']);
    });

    test(
      'digests differ across content but match generate-style precedence',
      () {
        // Two distinct entries with the same text share a content digest;
        // editing changes it.
        final shared = renderTaskSources([
          _text('e1', 'same'),
          _text('e2', 'same'),
        ]);
        expect(
          ContentDigest.of(shared[0].content),
          ContentDigest.of(shared[1].content),
        );

        final edited = renderTaskSources([_text('e1', 'changed')]);
        expect(
          ContentDigest.of(edited.single.content),
          isNot(ContentDigest.of(shared[0].content)),
        );
      },
    );
  });
}
