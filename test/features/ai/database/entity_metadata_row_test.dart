import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/entity_metadata_row.dart';

void main() {
  group('EntityMetadataRow', () {
    test('stores entityId and taskId', () {
      const row = EntityMetadataRow(
        entityId: 'entity-1',
        taskId: 'task-1',
      );

      expect(row.entityId, 'entity-1');
      expect(row.taskId, 'task-1');
    });

    test('supports empty taskId', () {
      const row = EntityMetadataRow(
        entityId: 'entity-2',
        taskId: '',
      );

      expect(row.entityId, 'entity-2');
      expect(row.taskId, isEmpty);
    });
  });
}
