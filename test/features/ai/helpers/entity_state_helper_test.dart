import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/helpers/entity_state_helper.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockAiInputRepository mockAiInputRepo;

  setUp(() {
    mockAiInputRepo = MockAiInputRepository();
  });

  group('EntityStateHelper', () {
    group('getCurrentEntityState', () {
      final testImage = JournalImage(
        meta: Metadata(
          id: 'entity-id',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          updatedAt: DateTime(2024, 3, 15, 10, 30),
          dateFrom: DateTime(2024, 3, 15, 10, 30),
          dateTo: DateTime(2024, 3, 15, 10, 30),
        ),
        data: ImageData(
          capturedAt: DateTime(2024, 3, 15, 10, 30),
          imageId: 'img-123',
          imageFile: 'test.jpg',
          imageDirectory: '/images/',
        ),
      );
      final testTask = Task(
        meta: Metadata(
          id: 'entity-id',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          updatedAt: DateTime(2024, 3, 15, 10, 30),
          dateFrom: DateTime(2024, 3, 15, 10, 30),
          dateTo: DateTime(2024, 3, 15, 10, 30),
        ),
        data: TaskData(
          title: 'Test Task',
          dateFrom: DateTime(2024, 3, 15, 10, 30),
          dateTo: DateTime(2024, 3, 15, 10, 30),
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            utcOffset: 0,
          ),
          statusHistory: [],
        ),
      );

      /// Drives one fetch-as-JournalImage case: [stubbed] is what the
      /// repository returns ([throws] overrides it with an exception);
      /// [expected] is the helper's result.
      Future<void> runImageCase({
        required JournalImage? expected,
        JournalEntity? stubbed,
        bool throws = false,
      }) async {
        const entityId = 'entity-id';
        if (throws) {
          when(
            () => mockAiInputRepo.getEntity(entityId),
          ).thenThrow(Exception('Repository error'));
        } else {
          when(
            () => mockAiInputRepo.getEntity(entityId),
          ).thenAnswer((_) async => stubbed);
        }

        final result =
            await EntityStateHelper.getCurrentEntityState<JournalImage>(
              entityId: entityId,
              aiInputRepo: mockAiInputRepo,
              entityTypeName: 'image',
            );

        expect(result, expected);
        verify(() => mockAiInputRepo.getEntity(entityId)).called(1);
      }

      test('returns typed entity when fetch succeeds and type matches', () {
        return runImageCase(stubbed: testImage, expected: testImage);
      });

      test('returns null when entity is not found', () {
        return runImageCase(expected: null);
      });

      test('returns null when entity type does not match expected type', () {
        // Expecting JournalImage but getting Task.
        return runImageCase(stubbed: testTask, expected: null);
      });

      test(
        'returns null on type mismatch for a second concrete type '
        '(expecting JournalAudio but fetch yields JournalImage)',
        () async {
          // Exercises the generic `<T>` mismatch branch for a different
          // requested type than JournalImage, so the type guard is covered
          // for both realistic entity types rather than only one.
          const audioId = 'audio-id';
          when(
            () => mockAiInputRepo.getEntity(audioId),
          ).thenAnswer((_) async => testImage);

          final result =
              await EntityStateHelper.getCurrentEntityState<JournalAudio>(
                entityId: audioId,
                aiInputRepo: mockAiInputRepo,
                entityTypeName: 'audio',
              );

          expect(result, isNull);
          verify(() => mockAiInputRepo.getEntity(audioId)).called(1);
        },
      );

      test('returns null when repository throws exception', () {
        return runImageCase(throws: true, expected: null);
      });

      test('works correctly with different entity types', () async {
        // Test with JournalAudio
        const audioId = 'audio-id';
        final audio = JournalAudio(
          meta: Metadata(
            id: audioId,
            createdAt: DateTime(2024, 3, 15, 10, 30),
            updatedAt: DateTime(2024, 3, 15, 10, 30),
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
          ),
          data: AudioData(
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
            duration: const Duration(seconds: 30),
            audioDirectory: '/audio/',
            audioFile: 'test.aac',
          ),
        );

        when(
          () => mockAiInputRepo.getEntity(audioId),
        ).thenAnswer((_) async => audio);

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
            createdAt: DateTime(2024, 3, 15, 11),
            updatedAt: DateTime(2024, 3, 15, 11),
            dateFrom: DateTime(2024, 3, 15, 11),
            dateTo: DateTime(2024, 3, 15, 11),
          ),
          data: TaskData(
            title: 'Test Task',
            dateFrom: DateTime(2024, 3, 15, 11),
            dateTo: DateTime(2024, 3, 15, 11),
            status: TaskStatus.done(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15, 11),
              utcOffset: 0,
            ),
            statusHistory: [],
          ),
        );

        when(
          () => mockAiInputRepo.getEntity(taskId),
        ).thenAnswer((_) async => task);

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
            createdAt: DateTime(2024, 3, 15, 12),
            updatedAt: DateTime(2024, 3, 15, 12),
            dateFrom: DateTime(2024, 3, 15, 12),
            dateTo: DateTime(2024, 3, 15, 12),
          ),
          entryText: const EntryText(
            plainText: 'Test entry',
            markdown: 'Test entry',
          ),
        );

        when(
          () => mockAiInputRepo.getEntity(entityId),
        ).thenAnswer((_) async => journalEntity);

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
