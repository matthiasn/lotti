import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/demo/seed/demo_entity_factories.dart';

void main() {
  group('TestMetadataFactory', () {
    test('anchors every date on the fixed test clock by default', () {
      final meta = TestMetadataFactory.create();

      expect(meta.createdAt, testFixedDate);
      expect(meta.updatedAt, testFixedDate);
      expect(meta.dateFrom, testFixedDate);
      expect(meta.dateTo, testFixedDate);
      expect(meta.starred, isFalse);
      expect(meta.private, isFalse);
      expect(meta.categoryId, isNull);
    });

    test('createdAt override cascades to the other unset dates', () {
      final created = DateTime(2026, 7, 17, 10, 30);
      final meta = TestMetadataFactory.create(
        id: 'meta-1',
        createdAt: created,
      );

      expect(meta.id, 'meta-1');
      expect(meta.createdAt, created);
      expect(meta.updatedAt, created);
      expect(meta.dateFrom, created);
      expect(meta.dateTo, created);
    });
  });

  group('TestTaskFactory', () {
    test('wires metadata, task data, and entry text into one open task', () {
      final task = TestTaskFactory.create(
        id: 'task-1',
        title: 'Fix bug',
        plainText: 'Repro steps',
        categoryId: 'category-1',
        estimate: const Duration(hours: 1),
      );

      expect(task.meta.id, 'task-1');
      expect(task.meta.categoryId, 'category-1');
      expect(task.data.title, 'Fix bug');
      expect(task.data.status, isA<TaskOpen>());
      expect(task.data.statusHistory, [task.data.status]);
      expect(task.data.estimate, const Duration(hours: 1));
      expect(task.entryText?.plainText, 'Repro steps');
    });

    test('honors an explicit status and keeps it in the history', () {
      final status = TaskStatus.done(
        id: 'status-done',
        createdAt: testFixedDate,
        utcOffset: 0,
      );
      final task = TestTaskFactory.create(status: status);

      expect(task.data.status, status);
      expect(task.data.statusHistory, [status]);
    });
  });

  group('TestImageFactory', () {
    test('derives image file identifiers from the entity id', () {
      final image = TestImageFactory.create(id: 'img-7');

      expect(image.data.imageId, 'image-id-img-7');
      expect(image.data.imageFile, 'img-7.jpg');
      expect(image.data.imageDirectory, '/images/');
      expect(image.data.capturedAt, testFixedDate);
      expect(image.entryText, isNull);
    });

    test('a caption becomes the image entry text', () {
      final image = TestImageFactory.create(
        id: 'img-8',
        plainText: 'Habitat inspection photo',
      );

      expect(image.entryText?.plainText, 'Habitat inspection photo');
    });
  });

  group('TestChecklistItemFactory', () {
    test('builds unchecked, unarchived items unless told otherwise', () {
      final item = TestChecklistItemFactory.create(
        title: 'Buy milk',
        linkedChecklists: const ['checklist-1'],
      );

      expect(item.title, 'Buy milk');
      expect(item.isChecked, isFalse);
      expect(item.isArchived, isFalse);
      expect(item.linkedChecklists, const ['checklist-1']);
    });
  });

  group('TestAiResponseFactory', () {
    test('marks deletion through metadata, not the payload', () {
      final deletedAt = DateTime(2026, 7, 18);
      final response = TestAiResponseFactory.create(
        response: 'OCR text',
        deletedAt: deletedAt,
      );

      expect(response.meta.deletedAt, deletedAt);
      expect(response.data.response, 'OCR text');
    });
  });
}
