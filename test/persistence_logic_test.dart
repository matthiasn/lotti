import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/logic/persistence_logic.dart';

void main() {
  test(
    'Add tags',
    () async {
      DateTime now = DateTime.now();

      Metadata meta = Metadata(
        createdAt: now,
        id: 'test-id',
        dateTo: now,
        dateFrom: now,
        updatedAt: now,
        tagIds: [
          'tag1',
          'tag2',
          'tag3',
        ],
      );

      expect(
        addTagsToMeta(
          meta,
          [
            'tag4',
            'tag5',
          ],
        ).tagIds,
        [
          'tag1',
          'tag2',
          'tag3',
          'tag4',
          'tag5',
        ],
      );
    },
  );

  test(
    'Does nothing for existing tags',
    () async {
      DateTime now = DateTime.now();

      Metadata meta = Metadata(
        createdAt: now,
        id: 'test-id',
        dateTo: now,
        dateFrom: now,
        updatedAt: now,
        tagIds: [
          'tag1',
          'tag2',
          'tag3',
        ],
      );

      expect(
        addTagsToMeta(
          meta,
          [
            'tag3',
            'tag2',
            'tag1',
          ],
        ).tagIds,
        [
          'tag1',
          'tag2',
          'tag3',
        ],
      );
    },
  );

  test(
    'Removes tag',
    () async {
      DateTime now = DateTime.now();

      Metadata meta = Metadata(
        createdAt: now,
        id: 'test-id',
        dateTo: now,
        dateFrom: now,
        updatedAt: now,
        tagIds: [
          'tag1',
          'tag2',
          'tag3',
        ],
      );

      expect(
        removeTagFromMeta(meta, 'tag1').tagIds,
        ['tag2', 'tag3'],
      );
    },
  );

  test(
    'Removing non-existing tag does nothing',
    () async {
      DateTime now = DateTime.now();

      Metadata meta = Metadata(
        createdAt: now,
        id: 'test-id',
        dateTo: now,
        dateFrom: now,
        updatedAt: now,
        tagIds: [
          'tag1',
          'tag2',
          'tag3',
        ],
      );

      expect(
        removeTagFromMeta(meta, 'tag4').tagIds,
        ['tag1', 'tag2', 'tag3'],
      );
    },
  );
}
