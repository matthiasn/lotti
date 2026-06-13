import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'embedding_content_extractor_test_helpers.dart';

void main() {
  group('EmbeddingContentExtractor.extractText', () {
    group('JournalEntry', () {
      test('extracts plainText when long enough', () {
        final entry = JournalEntry(
          meta: hMeta(),
          entryText: const EntryText(plainText: hLongText),
        );

        expect(EmbeddingContentExtractor.extractText(entry), hLongText);
      });

      test('returns null when text is too short', () {
        final entry = JournalEntry(
          meta: hMeta(),
          entryText: const EntryText(plainText: hShortText),
        );

        expect(EmbeddingContentExtractor.extractText(entry), isNull);
      });

      test('returns null when entryText is null', () {
        final entry = JournalEntry(meta: hMeta());

        expect(EmbeddingContentExtractor.extractText(entry), isNull);
      });

      test('returns null when plainText is empty', () {
        final entry = JournalEntry(
          meta: hMeta(),
          entryText: const EntryText(plainText: ''),
        );

        expect(EmbeddingContentExtractor.extractText(entry), isNull);
      });

      test('trims whitespace from extracted text', () {
        final entry = JournalEntry(
          meta: hMeta(),
          entryText: const EntryText(plainText: '  $hLongText  '),
        );

        expect(EmbeddingContentExtractor.extractText(entry), hLongText);
      });
    });

    group('Task', () {
      TaskData taskData({String title = 'Test Task Title'}) => TaskData(
        status: TaskStatus.open(
          id: 'status-id',
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 0,
        ),
        title: title,
        statusHistory: [],
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15),
      );

      test('combines title and body text', () {
        final task = Task(
          meta: hMeta(),
          data: taskData(title: 'My Important Task'),
          entryText: const EntryText(plainText: hLongText),
        );

        expect(
          EmbeddingContentExtractor.extractText(task),
          'My Important Task\n$hLongText',
        );
      });

      test('uses title only when body is empty', () {
        final task = Task(
          meta: hMeta(),
          data: taskData(
            title: 'A task title that is long enough for embedding',
          ),
          entryText: const EntryText(plainText: ''),
        );

        expect(
          EmbeddingContentExtractor.extractText(task),
          'A task title that is long enough for embedding',
        );
      });

      test('uses title only when entryText is null', () {
        final task = Task(
          meta: hMeta(),
          data: taskData(
            title: 'A task title that is long enough for embedding',
          ),
        );

        expect(
          EmbeddingContentExtractor.extractText(task),
          'A task title that is long enough for embedding',
        );
      });

      test('returns null when title is too short and no body', () {
        final task = Task(
          meta: hMeta(),
          data: taskData(title: 'Short'),
        );

        expect(EmbeddingContentExtractor.extractText(task), isNull);
      });
    });

    group('JournalAudio', () {
      AudioData audioData({List<AudioTranscript>? transcripts}) => AudioData(
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15),
        duration: const Duration(minutes: 5),
        audioFile: 'test.m4a',
        audioDirectory: '/audio',
        transcripts: transcripts,
      );

      test('prefers entryText over transcript', () {
        final audio = JournalAudio(
          meta: hMeta(),
          data: audioData(
            transcripts: [
              AudioTranscript(
                created: DateTime(2024, 3, 15),
                library: 'whisper',
                model: 'small',
                detectedLanguage: 'en',
                transcript: 'This is the transcript text that is long enough.',
              ),
            ],
          ),
          entryText: const EntryText(plainText: hLongText),
        );

        expect(EmbeddingContentExtractor.extractText(audio), hLongText);
      });

      test('falls back to first transcript when entryText is null', () {
        const transcriptText =
            'This is a transcript that is long enough for embedding.';
        final audio = JournalAudio(
          meta: hMeta(),
          data: audioData(
            transcripts: [
              AudioTranscript(
                created: DateTime(2024, 3, 15),
                library: 'whisper',
                model: 'small',
                detectedLanguage: 'en',
                transcript: transcriptText,
              ),
            ],
          ),
        );

        expect(
          EmbeddingContentExtractor.extractText(audio),
          transcriptText,
        );
      });

      test(
        'uses the FIRST transcript (index 0), not the most recent — this '
        'deliberately differs from SkillInferenceRunner._resolveEntryContent '
        'which picks the latest by created',
        () {
          const firstText =
              'The very first transcript, long enough for embedding.';
          const newerText =
              'A newer transcript that must NOT be selected here.';
          final audio = JournalAudio(
            meta: hMeta(),
            data: audioData(
              transcripts: [
                AudioTranscript(
                  created: DateTime(2024, 3, 15),
                  library: 'whisper',
                  model: 'small',
                  detectedLanguage: 'en',
                  transcript: firstText,
                ),
                AudioTranscript(
                  created: DateTime(2024, 3, 16),
                  library: 'whisper',
                  model: 'large',
                  detectedLanguage: 'en',
                  transcript: newerText,
                ),
              ],
            ),
          );

          expect(EmbeddingContentExtractor.extractText(audio), firstText);
        },
      );

      test('returns null when no text and no transcripts', () {
        final audio = JournalAudio(
          meta: hMeta(),
          data: audioData(),
        );

        expect(EmbeddingContentExtractor.extractText(audio), isNull);
      });

      test('returns null when transcripts list is empty', () {
        final audio = JournalAudio(
          meta: hMeta(),
          data: audioData(transcripts: []),
        );

        expect(EmbeddingContentExtractor.extractText(audio), isNull);
      });
    });

    group('AiResponseEntry', () {
      test('extracts plainText when long enough', () {
        final aiResponse = AiResponseEntry(
          meta: hMeta(),
          data: const AiResponseData(
            model: 'test-model',
            systemMessage: '',
            prompt: '',
            thoughts: '',
            response: '',
          ),
          entryText: const EntryText(plainText: hLongText),
        );

        expect(EmbeddingContentExtractor.extractText(aiResponse), hLongText);
      });

      test('returns null when entryText is null', () {
        final aiResponse = AiResponseEntry(
          meta: hMeta(),
          data: const AiResponseData(
            model: 'test-model',
            systemMessage: '',
            prompt: '',
            thoughts: '',
            response: '',
          ),
        );

        expect(EmbeddingContentExtractor.extractText(aiResponse), isNull);
      });
    });

    group('unsupported entity types', () {
      test('returns null for JournalImage', () {
        final image = JournalImage(
          meta: hMeta(),
          data: ImageData(
            imageId: 'img-1',
            imageFile: 'test.jpg',
            imageDirectory: '/images',
            capturedAt: DateTime(2024, 3, 15),
          ),
          entryText: const EntryText(plainText: hLongText),
        );

        expect(EmbeddingContentExtractor.extractText(image), isNull);
      });

      test('returns null for QuantitativeEntry', () {
        final entry = QuantitativeEntry(
          meta: hMeta(),
          data: QuantitativeData.discreteQuantityData(
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            value: 70,
            dataType: 'WEIGHT',
            unit: 'KG',
          ),
        );

        expect(EmbeddingContentExtractor.extractText(entry), isNull);
      });
    });
  });
}
