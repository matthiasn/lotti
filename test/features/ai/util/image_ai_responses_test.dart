import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/util/image_ai_responses.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../mocks/mocks.dart';

void main() {
  late MockJournalDb mockDb;

  setUp(() {
    mockDb = MockJournalDb();
  });

  group('fetchAiResponsesForImages', () {
    test(
      'returns empty map without querying when no images are linked',
      () async {
        final result = await fetchAiResponsesForImages(
          db: mockDb,
          linkedEntities: [
            TestTaskFactory.create(),
            JournalEntry(
              meta: TestMetadataFactory.create(id: 'text-1'),
            ),
          ],
        );

        expect(result, isEmpty);
        verifyNever(() => mockDb.getBulkLinkedEntities(any()));
      },
    );

    test(
      'bulk-fetches per image, keeps only non-deleted AI responses sorted '
      'oldest-first',
      () async {
        final imageA = TestImageFactory.create(id: 'img-a');
        final imageB = TestImageFactory.create(id: 'img-b');
        final summary = TestAiResponseFactory.create(
          id: 'summary-1',
          model: 'mistral-small',
          response: 'A summary',
          dateFrom: DateTime(2026, 7, 23, 17, 10),
        );
        final ocr = TestAiResponseFactory.create(
          id: 'ocr-1',
          model: 'mistral-ocr-latest',
          response: 'OCR text',
          dateFrom: DateTime(2026, 7, 23, 17, 9),
        );
        final deleted = TestAiResponseFactory.create(
          id: 'deleted-1',
          deletedAt: DateTime(2026, 7, 24),
        );

        when(
          () => mockDb.getBulkLinkedEntities({'img-a', 'img-b'}),
        ).thenAnswer(
          (_) async => {
            // Bulk query returns newest-first; a linked comment and a deleted
            // response must both be dropped.
            'img-a': [
              summary,
              ocr,
              deleted,
              JournalEntry(
                meta: TestMetadataFactory.create(id: 'comment-1'),
              ),
            ],
            'img-b': <JournalEntity>[],
          },
        );

        final result = await fetchAiResponsesForImages(
          db: mockDb,
          linkedEntities: [imageA, imageB, TestTaskFactory.create()],
        );

        expect(result.keys, ['img-a']);
        expect(
          result['img-a']!.map((r) => r.meta.id),
          ['ocr-1', 'summary-1'],
          reason: 'analyses must be chronological (oldest first)',
        );
        verify(
          () => mockDb.getBulkLinkedEntities({'img-a', 'img-b'}),
        ).called(1);
      },
    );

    test('omits images whose only linked responses are deleted', () async {
      final image = TestImageFactory.create(id: 'img-a');
      when(() => mockDb.getBulkLinkedEntities({'img-a'})).thenAnswer(
        (_) async => {
          'img-a': [
            TestAiResponseFactory.create(
              id: 'deleted-1',
              deletedAt: DateTime(2026, 7, 24),
            ),
          ],
        },
      );

      final result = await fetchAiResponsesForImages(
        db: mockDb,
        linkedEntities: [image],
      );

      expect(result, isEmpty);
    });
  });
}
