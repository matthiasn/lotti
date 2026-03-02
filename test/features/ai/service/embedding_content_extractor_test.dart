import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';

/// Builds a minimal [Metadata] for test entities.
Metadata _meta({String id = 'test-id'}) => Metadata(
      id: id,
      createdAt: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
      dateFrom: DateTime(2024, 3, 15),
      dateTo: DateTime(2024, 3, 15),
    );

/// Text that is long enough to pass the minimum length threshold.
const _longText = 'This is a sufficiently long text for embedding generation.';

/// Text that is too short to embed.
const _shortText = 'Too short';

void main() {
  group('EmbeddingContentExtractor.extractText', () {
    group('JournalEntry', () {
      test('extracts plainText when long enough', () {
        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _longText),
        );

        expect(EmbeddingContentExtractor.extractText(entry), _longText);
      });

      test('returns null when text is too short', () {
        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: _shortText),
        );

        expect(EmbeddingContentExtractor.extractText(entry), isNull);
      });

      test('returns null when entryText is null', () {
        final entry = JournalEntry(meta: _meta());

        expect(EmbeddingContentExtractor.extractText(entry), isNull);
      });

      test('returns null when plainText is empty', () {
        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: ''),
        );

        expect(EmbeddingContentExtractor.extractText(entry), isNull);
      });

      test('trims whitespace from extracted text', () {
        final entry = JournalEntry(
          meta: _meta(),
          entryText: const EntryText(plainText: '  $_longText  '),
        );

        expect(EmbeddingContentExtractor.extractText(entry), _longText);
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
          meta: _meta(),
          data: taskData(title: 'My Important Task'),
          entryText: const EntryText(plainText: _longText),
        );

        expect(
          EmbeddingContentExtractor.extractText(task),
          'My Important Task\n$_longText',
        );
      });

      test('uses title only when body is empty', () {
        final task = Task(
          meta: _meta(),
          data:
              taskData(title: 'A task title that is long enough for embedding'),
          entryText: const EntryText(plainText: ''),
        );

        expect(
          EmbeddingContentExtractor.extractText(task),
          'A task title that is long enough for embedding',
        );
      });

      test('uses title only when entryText is null', () {
        final task = Task(
          meta: _meta(),
          data:
              taskData(title: 'A task title that is long enough for embedding'),
        );

        expect(
          EmbeddingContentExtractor.extractText(task),
          'A task title that is long enough for embedding',
        );
      });

      test('returns null when title is too short and no body', () {
        final task = Task(
          meta: _meta(),
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
          meta: _meta(),
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
          entryText: const EntryText(plainText: _longText),
        );

        expect(EmbeddingContentExtractor.extractText(audio), _longText);
      });

      test('falls back to first transcript when entryText is null', () {
        const transcriptText =
            'This is a transcript that is long enough for embedding.';
        final audio = JournalAudio(
          meta: _meta(),
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

      test('returns null when no text and no transcripts', () {
        final audio = JournalAudio(
          meta: _meta(),
          data: audioData(),
        );

        expect(EmbeddingContentExtractor.extractText(audio), isNull);
      });

      test('returns null when transcripts list is empty', () {
        final audio = JournalAudio(
          meta: _meta(),
          data: audioData(transcripts: []),
        );

        expect(EmbeddingContentExtractor.extractText(audio), isNull);
      });
    });

    group('AiResponseEntry', () {
      test('extracts plainText when long enough', () {
        final aiResponse = AiResponseEntry(
          meta: _meta(),
          data: const AiResponseData(
            model: 'test-model',
            systemMessage: '',
            prompt: '',
            thoughts: '',
            response: '',
          ),
          entryText: const EntryText(plainText: _longText),
        );

        expect(EmbeddingContentExtractor.extractText(aiResponse), _longText);
      });

      test('returns null when entryText is null', () {
        final aiResponse = AiResponseEntry(
          meta: _meta(),
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
          meta: _meta(),
          data: ImageData(
            imageId: 'img-1',
            imageFile: 'test.jpg',
            imageDirectory: '/images',
            capturedAt: DateTime(2024, 3, 15),
          ),
          entryText: const EntryText(plainText: _longText),
        );

        expect(EmbeddingContentExtractor.extractText(image), isNull);
      });

      test('returns null for QuantitativeEntry', () {
        final entry = QuantitativeEntry(
          meta: _meta(),
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

  group('EmbeddingContentExtractor.entityType', () {
    test('returns journal_text for JournalEntry', () {
      final entry = JournalEntry(meta: _meta());
      expect(
        EmbeddingContentExtractor.entityType(entry),
        kEntityTypeJournalText,
      );
    });

    test('returns task for Task', () {
      final task = Task(
        meta: _meta(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'id',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
          ),
          title: 'test',
          statusHistory: [],
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
      );
      expect(EmbeddingContentExtractor.entityType(task), kEntityTypeTask);
    });

    test('returns audio for JournalAudio', () {
      final audio = JournalAudio(
        meta: _meta(),
        data: AudioData(
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          duration: Duration.zero,
          audioFile: '',
          audioDirectory: '',
        ),
      );
      expect(EmbeddingContentExtractor.entityType(audio), kEntityTypeAudio);
    });

    test('returns ai_response for AiResponseEntry', () {
      final ai = AiResponseEntry(
        meta: _meta(),
        data: const AiResponseData(
          model: 'test-model',
          systemMessage: '',
          prompt: '',
          thoughts: '',
          response: '',
        ),
      );
      expect(
        EmbeddingContentExtractor.entityType(ai),
        kEntityTypeAiResponse,
      );
    });

    test('returns null for JournalImage', () {
      final image = JournalImage(
        meta: _meta(),
        data: ImageData(
          imageId: '',
          imageFile: '',
          imageDirectory: '',
          capturedAt: DateTime(2024, 3, 15),
        ),
      );
      expect(EmbeddingContentExtractor.entityType(image), isNull);
    });
  });

  group('EmbeddingContentExtractor.contentHash', () {
    test('returns deterministic SHA-256 hash', () {
      const text = 'hello world';
      final expected = sha256.convert(utf8.encode(text)).toString();

      expect(EmbeddingContentExtractor.contentHash(text), expected);
    });

    test('same input produces same hash', () {
      const text = 'consistent hashing test input text';
      final hash1 = EmbeddingContentExtractor.contentHash(text);
      final hash2 = EmbeddingContentExtractor.contentHash(text);

      expect(hash1, hash2);
    });

    test('different input produces different hash', () {
      final hash1 = EmbeddingContentExtractor.contentHash('text one');
      final hash2 = EmbeddingContentExtractor.contentHash('text two');

      expect(hash1, isNot(hash2));
    });
  });

  group('kMinEmbeddingTextLength', () {
    test('is 20', () {
      expect(kMinEmbeddingTextLength, 20);
    });

    test('text at exactly threshold is accepted', () {
      // 20 characters exactly
      const exactText = '12345678901234567890';
      expect(exactText.length, kMinEmbeddingTextLength);

      final entry = JournalEntry(
        meta: _meta(),
        entryText: const EntryText(plainText: exactText),
      );
      expect(EmbeddingContentExtractor.extractText(entry), exactText);
    });

    test('text one below threshold is rejected', () {
      // 19 characters
      const belowText = '1234567890123456789';
      expect(belowText.length, kMinEmbeddingTextLength - 1);

      final entry = JournalEntry(
        meta: _meta(),
        entryText: const EntryText(plainText: belowText),
      );
      expect(EmbeddingContentExtractor.extractText(entry), isNull);
    });
  });
}
