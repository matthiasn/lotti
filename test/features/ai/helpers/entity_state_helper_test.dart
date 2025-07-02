import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/helpers/entity_state_helper.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAiInputRepository extends Mock implements AiInputRepository {}

void main() {
  late MockAiInputRepository mockAiInputRepo;

  setUp(() {
    mockAiInputRepo = MockAiInputRepository();
  });

  group('EntityStateHelper', () {
    group('getCurrentEntityState', () {
      test('returns typed entity when fetch succeeds and type matches',
          () async {
        // Arrange
        const entityId = 'test-image-id';
        final expectedImage = JournalImage(
          meta: Metadata(
            id: entityId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          data: ImageData(
            capturedAt: DateTime.now(),
            imageId: 'img-123',
            imageFile: 'test.jpg',
            imageDirectory: '/images/',
          ),
        );

        when(() => mockAiInputRepo.getEntity(entityId))
            .thenAnswer((_) async => expectedImage);

        // Act
        final result =
            await EntityStateHelper.getCurrentEntityState<JournalImage>(
          entityId: entityId,
          aiInputRepo: mockAiInputRepo,
          entityTypeName: 'image',
        );

        // Assert
        expect(result, equals(expectedImage));
        expect(result, isA<JournalImage>());
        verify(() => mockAiInputRepo.getEntity(entityId)).called(1);
      });

      test('returns null when entity is not found', () async {
        // Arrange
        const entityId = 'non-existent-id';

        when(() => mockAiInputRepo.getEntity(entityId))
            .thenAnswer((_) async => null);

        // Act
        final result =
            await EntityStateHelper.getCurrentEntityState<JournalImage>(
          entityId: entityId,
          aiInputRepo: mockAiInputRepo,
          entityTypeName: 'image',
        );

        // Assert
        expect(result, isNull);
        verify(() => mockAiInputRepo.getEntity(entityId)).called(1);
      });

      test('returns null when entity type does not match expected type',
          () async {
        // Arrange
        const entityId = 'task-id';
        final task = Task(
          meta: Metadata(
            id: entityId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          data: TaskData(
            title: 'Test Task',
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            statusHistory: [],
          ),
        );

        when(() => mockAiInputRepo.getEntity(entityId))
            .thenAnswer((_) async => task);

        // Act
        // Expecting JournalImage but getting Task
        final result =
            await EntityStateHelper.getCurrentEntityState<JournalImage>(
          entityId: entityId,
          aiInputRepo: mockAiInputRepo,
          entityTypeName: 'image',
        );

        // Assert
        expect(result, isNull);
        verify(() => mockAiInputRepo.getEntity(entityId)).called(1);
      });

      test('returns null when repository throws exception', () async {
        // Arrange
        const entityId = 'error-id';

        when(() => mockAiInputRepo.getEntity(entityId))
            .thenThrow(Exception('Repository error'));

        // Act
        final result =
            await EntityStateHelper.getCurrentEntityState<JournalImage>(
          entityId: entityId,
          aiInputRepo: mockAiInputRepo,
          entityTypeName: 'image',
        );

        // Assert
        expect(result, isNull);
        verify(() => mockAiInputRepo.getEntity(entityId)).called(1);
      });

      test('works correctly with different entity types', () async {
        // Test with JournalAudio
        const audioId = 'audio-id';
        final audio = JournalAudio(
          meta: Metadata(
            id: audioId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          data: AudioData(
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            duration: const Duration(seconds: 30),
            audioDirectory: '/audio/',
            audioFile: 'test.aac',
          ),
        );

        when(() => mockAiInputRepo.getEntity(audioId))
            .thenAnswer((_) async => audio);

        final audioResult =
            await EntityStateHelper.getCurrentEntityState<JournalAudio>(
          entityId: audioId,
          aiInputRepo: mockAiInputRepo,
          entityTypeName: 'audio',
        );

        expect(audioResult, equals(audio));
        expect(audioResult, isA<JournalAudio>());

        // Test with Task
        const taskId = 'task-id';
        final task = Task(
          meta: Metadata(
            id: taskId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          data: TaskData(
            title: 'Test Task',
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            status: TaskStatus.done(
              id: 'status-1',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            statusHistory: [],
          ),
        );

        when(() => mockAiInputRepo.getEntity(taskId))
            .thenAnswer((_) async => task);

        final taskResult = await EntityStateHelper.getCurrentEntityState<Task>(
          entityId: taskId,
          aiInputRepo: mockAiInputRepo,
          entityTypeName: 'task',
        );

        expect(taskResult, equals(task));
        expect(taskResult, isA<Task>());
      });

      test('handles complex inheritance correctly', () async {
        // Arrange
        const entityId = 'journal-entity-id';
        final journalEntity = JournalEntry(
          meta: Metadata(
            id: entityId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          entryText: const EntryText(
            plainText: 'Test entry',
            markdown: 'Test entry',
          ),
        );

        when(() => mockAiInputRepo.getEntity(entityId))
            .thenAnswer((_) async => journalEntity);

        // Act - Request base type, should work since JournalEntry extends JournalEntity
        final result =
            await EntityStateHelper.getCurrentEntityState<JournalEntity>(
          entityId: entityId,
          aiInputRepo: mockAiInputRepo,
          entityTypeName: 'entity',
        );

        // Assert
        expect(result, equals(journalEntity));
        expect(result, isA<JournalEntry>());
        expect(result, isA<JournalEntity>());
      });
    });
  });
}
