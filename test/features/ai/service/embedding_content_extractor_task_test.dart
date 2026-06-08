import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'embedding_content_extractor_test_helpers.dart';

void main() {
  group('EmbeddingContentExtractor.entityType', () {
    // One parameterized loop over the switch arms: supported types map to
    // their store discriminator constant, unsupported types map to null.
    final cases = <String, (JournalEntity, String?)>{
      'JournalEntry -> journal_text': (
        JournalEntry(meta: hMeta()),
        kEntityTypeJournalText,
      ),
      'Task -> task': (
        Task(
          meta: hMeta(),
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
        ),
        kEntityTypeTask,
      ),
      'JournalAudio -> audio': (
        JournalAudio(
          meta: hMeta(),
          data: AudioData(
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            duration: Duration.zero,
            audioFile: '',
            audioDirectory: '',
          ),
        ),
        kEntityTypeAudio,
      ),
      'AiResponseEntry -> ai_response': (
        AiResponseEntry(
          meta: hMeta(),
          data: const AiResponseData(
            model: 'test-model',
            systemMessage: '',
            prompt: '',
            thoughts: '',
            response: '',
          ),
        ),
        kEntityTypeAiResponse,
      ),
      'JournalImage -> null (unsupported)': (
        JournalImage(
          meta: hMeta(),
          data: ImageData(
            imageId: '',
            imageFile: '',
            imageDirectory: '',
            capturedAt: DateTime(2024, 3, 15),
          ),
        ),
        null,
      ),
    };

    for (final entry in cases.entries) {
      test(entry.key, () {
        expect(
          EmbeddingContentExtractor.entityType(entry.value.$1),
          entry.value.$2,
        );
      });
    }
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

  group('EmbeddingContentExtractor.extractTaskText', () {
    test('combines title and labels', () {
      final result = EmbeddingContentExtractor.extractTaskText(
        title: 'Fix login bug',
        labelNames: ['authentication', 'security', 'backend'],
      );

      expect(
        result,
        'Fix login bug\nLabels: authentication, security, backend',
      );
    });

    test('includes body text after labels', () {
      final result = EmbeddingContentExtractor.extractTaskText(
        title: 'Fix login bug',
        labelNames: ['security'],
        bodyText: 'The JWT token validation is failing.',
      );

      expect(
        result,
        'Fix login bug\nLabels: security\nThe JWT token validation is failing.',
      );
    });

    test('omits labels line when labelNames is empty', () {
      final result = EmbeddingContentExtractor.extractTaskText(
        title: 'A task title that is long enough for embedding',
        labelNames: [],
      );

      expect(result, 'A task title that is long enough for embedding');
    });

    test('returns null when total text is below minimum length', () {
      final result = EmbeddingContentExtractor.extractTaskText(
        title: 'Short',
        labelNames: [],
      );

      expect(result, isNull);
    });

    test('labels push short titles over minimum length threshold', () {
      final result = EmbeddingContentExtractor.extractTaskText(
        title: 'Fix auth',
        labelNames: ['security', 'backend'],
      );

      // "Fix auth\nLabels: security, backend" = 34 chars, > 20
      expect(result, isNotNull);
      expect(result, contains('Labels: security, backend'));
    });

    test('handles empty body text same as null', () {
      final result = EmbeddingContentExtractor.extractTaskText(
        title: 'A task title that is long enough for embedding',
        labelNames: ['label-one'],
        bodyText: '',
      );

      expect(result, isNot(contains('\n\n')));
      expect(result, endsWith('Labels: label-one'));
    });

    test('trims whitespace from result', () {
      final result = EmbeddingContentExtractor.extractTaskText(
        title: '  A padded title that is long enough  ',
        labelNames: [],
      );

      expect(result, startsWith('A padded'));
      expect(result, endsWith('enough'));
    });
  });

  group('kMinEmbeddingTextLength boundary', () {
    test('text at exactly threshold is accepted', () {
      // 20 characters exactly
      const exactText = '12345678901234567890';
      expect(exactText.length, kMinEmbeddingTextLength);

      final entry = JournalEntry(
        meta: hMeta(),
        entryText: const EntryText(plainText: exactText),
      );
      expect(EmbeddingContentExtractor.extractText(entry), exactText);
    });

    test('text one below threshold is rejected', () {
      // 19 characters
      const belowText = '1234567890123456789';
      expect(belowText.length, kMinEmbeddingTextLength - 1);

      final entry = JournalEntry(
        meta: hMeta(),
        entryText: const EntryText(plainText: belowText),
      );
      expect(EmbeddingContentExtractor.extractText(entry), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Glados properties for extractTaskText threshold and composition.
  // -------------------------------------------------------------------------
  group('extractTaskText — Glados properties', () {
    glados.Glados2(
      glados.any.taskTitle,
      glados.any.labelNameList,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'returns null iff assembled text is below kMinEmbeddingTextLength',
      (title, labels) {
        final result = EmbeddingContentExtractor.extractTaskText(
          title: title,
          labelNames: labels,
        );
        final assembled = StringBuffer(title);
        if (labels.isNotEmpty) {
          assembled
            ..write('\n')
            ..write('Labels: ')
            ..write(labels.join(', '));
        }
        final trimmed = assembled.toString().trim();
        if (trimmed.length < kMinEmbeddingTextLength) {
          expect(
            result,
            isNull,
            reason: 'Short text ("$trimmed") should yield null',
          );
        } else {
          expect(
            result,
            isNotNull,
            reason: 'Long-enough text ("$trimmed") should not be null',
          );
          expect(result, trimmed);
        }
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.taskTitle,
      glados.any.labelNameList,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'non-null result always contains the title',
      (title, labels) {
        final result = EmbeddingContentExtractor.extractTaskText(
          title: title,
          labelNames: labels,
        );
        if (result != null) {
          expect(
            result,
            startsWith(title.trim()),
            reason: 'Result must start with the trimmed title',
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.taskTitle,
      glados.any.labelNameList,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'non-null result contains each label when labels are non-empty',
      (title, labels) {
        final result = EmbeddingContentExtractor.extractTaskText(
          title: title,
          labelNames: labels,
        );
        if (result != null && labels.isNotEmpty) {
          for (final label in labels) {
            expect(
              result,
              contains(label),
              reason: 'Result must contain label "$label"',
            );
          }
        }
      },
      tags: 'glados',
    );

    glados.Glados3(
      glados.any.taskTitle,
      glados.any.labelNameList,
      glados.any.taskBody,
      glados.ExploreConfig(numRuns: 110),
    ).test(
      'body text is appended last, after the Labels line when labels exist',
      (title, labels, bodyText) {
        // taskBody is always non-empty with no trailing whitespace, so the
        // body survives the final trim() intact and sits at the very end.
        final result = EmbeddingContentExtractor.extractTaskText(
          title: title,
          labelNames: labels,
          bodyText: bodyText,
        );
        if (result == null) return;

        // The body is appended last and has no trailing whitespace, so the
        // output always ends with it (regardless of title/label presence).
        expect(
          result,
          endsWith(bodyText),
          reason: 'Body ("$bodyText") must be the trailing segment',
        );

        // When labels are present, the Labels line must precede the body. The
        // distinctive BODY_ prefix cannot collide with the title/label
        // alphabet, so indexOf locates the body unambiguously.
        if (labels.isNotEmpty) {
          final labelsLine = 'Labels: ${labels.join(', ')}';
          expect(
            result.indexOf(labelsLine),
            allOf(
              greaterThanOrEqualTo(0),
              lessThan(result.indexOf(bodyText)),
            ),
            reason: 'Labels line must appear before the body',
          );
        }
      },
      tags: 'glados',
    );
  });
}
