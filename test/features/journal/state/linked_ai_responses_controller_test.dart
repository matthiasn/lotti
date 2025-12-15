import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/linked_ai_responses_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalRepository extends Mock implements JournalRepository {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

// Test data
const testAudioEntryId = 'audio-entry-123';

final testAiResponseEntry1 = AiResponseEntry(
  meta: Metadata(
    id: 'ai-response-1',
    createdAt: DateTime(2024, 1, 15, 10),
    dateFrom: DateTime(2024, 1, 15, 10),
    dateTo: DateTime(2024, 1, 15, 10, 5),
    updatedAt: DateTime(2024, 1, 15, 10, 5),
  ),
  data: const AiResponseData(
    model: 'test-model',
    systemMessage: 'System message',
    prompt: 'Test prompt',
    thoughts: 'Test thoughts',
    response: '## Summary\nTest summary\n\n## Prompt\nTest prompt content',
    type: AiResponseType.promptGeneration,
  ),
);

final testAiResponseEntry2 = AiResponseEntry(
  meta: Metadata(
    id: 'ai-response-2',
    createdAt: DateTime(2024, 1, 15, 11),
    dateFrom: DateTime(2024, 1, 15, 11),
    dateTo: DateTime(2024, 1, 15, 11, 5),
    updatedAt: DateTime(2024, 1, 15, 11, 5),
  ),
  data: const AiResponseData(
    model: 'test-model',
    systemMessage: 'System message 2',
    prompt: 'Test prompt 2',
    thoughts: 'Test thoughts 2',
    response: 'Audio transcription result',
    type: AiResponseType.audioTranscription,
  ),
);

final testDeletedAiResponseEntry = AiResponseEntry(
  meta: Metadata(
    id: 'ai-response-deleted',
    createdAt: DateTime(2024, 1, 15, 9),
    dateFrom: DateTime(2024, 1, 15, 9),
    dateTo: DateTime(2024, 1, 15, 9, 5),
    updatedAt: DateTime(2024, 1, 15, 9, 5),
    deletedAt: DateTime(2024, 1, 15, 12), // Deleted
  ),
  data: const AiResponseData(
    model: 'test-model',
    systemMessage: 'Deleted system message',
    prompt: 'Deleted prompt',
    thoughts: 'Deleted thoughts',
    response: 'Deleted response',
    type: AiResponseType.taskSummary,
  ),
);

final testNonAiEntry = JournalEntry(
  meta: Metadata(
    id: 'text-entry-1',
    createdAt: DateTime(2024, 1, 15, 8),
    dateFrom: DateTime(2024, 1, 15, 8),
    dateTo: DateTime(2024, 1, 15, 8, 5),
    updatedAt: DateTime(2024, 1, 15, 8, 5),
  ),
);

final testLinks = [
  EntryLink.basic(
    id: 'link-1',
    fromId: testAudioEntryId,
    toId: testAiResponseEntry1.meta.id,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    vectorClock: null,
  ),
  EntryLink.basic(
    id: 'link-2',
    fromId: testAudioEntryId,
    toId: testAiResponseEntry2.meta.id,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    vectorClock: null,
  ),
  EntryLink.basic(
    id: 'link-3',
    fromId: testAudioEntryId,
    toId: testDeletedAiResponseEntry.meta.id,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    vectorClock: null,
  ),
  EntryLink.basic(
    id: 'link-4',
    fromId: testAudioEntryId,
    toId: testNonAiEntry.meta.id,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    vectorClock: null,
  ),
];

void main() {
  late MockJournalRepository mockJournalRepository;
  late MockUpdateNotifications mockUpdateNotifications;
  late StreamController<Set<String>> updateStreamController;

  setUp(() {
    mockJournalRepository = MockJournalRepository();
    mockUpdateNotifications = MockUpdateNotifications();
    updateStreamController = StreamController<Set<String>>.broadcast();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);

    getIt.allowReassignment = true;
    getIt.registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  tearDown(() {
    updateStreamController.close();
    getIt.unregister<UpdateNotifications>();
  });

  group('LinkedAiResponsesController', () {
    test('loads AI responses linked to an entry on initialization', () async {
      // Arrange
      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async => testLinks);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry2.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry2);
      when(() => mockJournalRepository.getJournalEntityById(
            testDeletedAiResponseEntry.meta.id,
          )).thenAnswer((_) async => testDeletedAiResponseEntry);
      when(() => mockJournalRepository.getJournalEntityById(
            testNonAiEntry.meta.id,
          )).thenAnswer((_) async => testNonAiEntry);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      final result = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );

      // Assert - should only have non-deleted AI responses
      expect(result.length, equals(2));
      expect(result[0].meta.id, equals(testAiResponseEntry2.meta.id));
      expect(result[1].meta.id, equals(testAiResponseEntry1.meta.id));

      // Verify repository calls
      verify(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .called(1);

      container.dispose();
    });

    test('filters out deleted AI responses', () async {
      // Arrange
      final linksWithDeleted = [
        EntryLink.basic(
          id: 'link-deleted',
          fromId: testAudioEntryId,
          toId: testDeletedAiResponseEntry.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async => linksWithDeleted);
      when(() => mockJournalRepository.getJournalEntityById(
            testDeletedAiResponseEntry.meta.id,
          )).thenAnswer((_) async => testDeletedAiResponseEntry);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      final result = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );

      // Assert - deleted entries should be filtered out
      expect(result, isEmpty);

      container.dispose();
    });

    test('filters out non-AI response entries', () async {
      // Arrange
      final linksWithNonAi = [
        EntryLink.basic(
          id: 'link-non-ai',
          fromId: testAudioEntryId,
          toId: testNonAiEntry.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async => linksWithNonAi);
      when(() => mockJournalRepository.getJournalEntityById(
            testNonAiEntry.meta.id,
          )).thenAnswer((_) async => testNonAiEntry);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      final result = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );

      // Assert - non-AI entries should be filtered out
      expect(result, isEmpty);

      container.dispose();
    });

    test('returns empty list when no links exist', () async {
      // Arrange
      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async => []);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      final result = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );

      // Assert
      expect(result, isEmpty);

      container.dispose();
    });

    test('sorts AI responses by date (newest first)', () async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry1.meta.id, // Older (10:00)
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
        EntryLink.basic(
          id: 'link-2',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry2.meta.id, // Newer (11:00)
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry2.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry2);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      final result = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );

      // Assert - newest should be first
      expect(result.length, equals(2));
      expect(result[0].meta.id, equals(testAiResponseEntry2.meta.id));
      expect(result[1].meta.id, equals(testAiResponseEntry1.meta.id));

      container.dispose();
    });

    test('updates state when affected IDs are notified', () async {
      // Arrange
      final initialLinks = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      final updatedLinks = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
        EntryLink.basic(
          id: 'link-2',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry2.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      var callCount = 0;
      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? initialLinks : updatedLinks;
      });
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry2.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry2);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Initial load
      final initialResult = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );
      expect(initialResult.length, equals(1));

      // Simulate update notification
      updateStreamController.add({testAudioEntryId});

      // Wait for async update
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Get updated state
      final updatedResult = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );

      // Assert
      expect(updatedResult.length, equals(2));

      container.dispose();
    });

    test('handles null entity gracefully', () async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: 'non-existent-id',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById('non-existent-id'))
          .thenAnswer((_) async => null);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      final result = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );

      // Assert - should handle null gracefully
      expect(result, isEmpty);

      container.dispose();
    });

    test('updates state when watched AI response ID is notified', () async {
      // Arrange - test the intersection path in _listen()
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      // First call returns original, second call returns updated
      final updatedEntry = AiResponseEntry(
        meta: Metadata(
          id: testAiResponseEntry1.meta.id,
          createdAt: DateTime(2024, 1, 15, 10),
          dateFrom: DateTime(2024, 1, 15, 10),
          dateTo: DateTime(2024, 1, 15, 10, 5),
          updatedAt: DateTime(2024, 1, 15, 12), // Updated timestamp
        ),
        data: const AiResponseData(
          model: 'test-model',
          systemMessage: 'Updated system message',
          prompt: 'Updated prompt',
          thoughts: 'Updated thoughts',
          response: 'Updated response content',
          type: AiResponseType.promptGeneration,
        ),
      );

      var fetchCount = 0;
      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async {
        fetchCount++;
        return fetchCount == 1 ? testAiResponseEntry1 : updatedEntry;
      });

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Initial load - adds AI response ID to watched IDs
      final initialResult = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );
      expect(initialResult.length, equals(1));
      expect(
        initialResult[0].meta.updatedAt,
        equals(testAiResponseEntry1.meta.updatedAt),
      );

      // Notify with AI response ID (tests intersection path)
      updateStreamController.add({testAiResponseEntry1.meta.id});

      // Wait for async update
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Get updated state
      final updatedResult = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );

      // Assert - should have updated entry
      expect(updatedResult.length, equals(1));
      expect(
          updatedResult[0].meta.updatedAt, equals(updatedEntry.meta.updatedAt));

      container.dispose();
    });

    test('does not update state when fetched data is identical', () async {
      // Arrange - test the _listEquals optimization path
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      var fetchCount = 0;
      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async {
        fetchCount++;
        return links;
      });
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Initial load
      await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );
      expect(fetchCount, equals(1));

      // Notify - should fetch but not update state since data is identical
      updateStreamController.add({testAudioEntryId});

      // Wait for async fetch
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify fetch was called again
      expect(fetchCount, equals(2));

      // State should still be valid (no error from identical comparison)
      final result = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );
      expect(result.length, equals(1));

      container.dispose();
    });

    test('ignores notifications for unrelated IDs', () async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      var fetchCount = 0;
      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async {
        fetchCount++;
        return links;
      });
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Initial load
      await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );
      expect(fetchCount, equals(1));

      // Notify with unrelated ID - should be ignored
      updateStreamController.add({'unrelated-id-123'});

      // Wait briefly
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify fetch was NOT called again
      expect(fetchCount, equals(1));

      container.dispose();
    });

    test('handles multiple AI responses with same date correctly', () async {
      // Arrange - test sorting stability
      final sameTimeEntry1 = AiResponseEntry(
        meta: Metadata(
          id: 'same-time-1',
          createdAt: DateTime(2024, 1, 15, 10),
          dateFrom: DateTime(2024, 1, 15, 10),
          dateTo: DateTime(2024, 1, 15, 10, 5),
          updatedAt: DateTime(2024, 1, 15, 10, 5),
        ),
        data: const AiResponseData(
          model: 'test-model',
          systemMessage: 'System 1',
          prompt: 'Prompt 1',
          thoughts: 'Thoughts 1',
          response: 'Response 1',
          type: AiResponseType.promptGeneration,
        ),
      );

      final sameTimeEntry2 = AiResponseEntry(
        meta: Metadata(
          id: 'same-time-2',
          createdAt: DateTime(2024, 1, 15, 10),
          dateFrom: DateTime(2024, 1, 15, 10), // Same dateFrom
          dateTo: DateTime(2024, 1, 15, 10, 5),
          updatedAt: DateTime(2024, 1, 15, 10, 5),
        ),
        data: const AiResponseData(
          model: 'test-model',
          systemMessage: 'System 2',
          prompt: 'Prompt 2',
          thoughts: 'Thoughts 2',
          response: 'Response 2',
          type: AiResponseType.audioTranscription,
        ),
      );

      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: sameTimeEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
        EntryLink.basic(
          id: 'link-2',
          fromId: testAudioEntryId,
          toId: sameTimeEntry2.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
          sameTimeEntry1.meta.id)).thenAnswer((_) async => sameTimeEntry1);
      when(() => mockJournalRepository.getJournalEntityById(
          sameTimeEntry2.meta.id)).thenAnswer((_) async => sameTimeEntry2);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      final result = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );

      // Assert - both entries should be present
      expect(result.length, equals(2));

      container.dispose();
    });

    test('cleans up subscription on dispose', () async {
      // Arrange
      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async => []);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );

      // Dispose should not throw
      container.dispose();

      // Sending notification after dispose should not cause issues
      updateStreamController.add({testAudioEntryId});

      // No assertion needed - test passes if no exception is thrown
    });

    test('handles rapid successive notifications', () async {
      // Arrange
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      var fetchCount = 0;
      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async {
        fetchCount++;
        // Simulate some async delay
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return links;
      });
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Initial load
      await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );

      // Send rapid notifications
      updateStreamController
        ..add({testAudioEntryId})
        ..add({testAudioEntryId})
        ..add({testAudioEntryId});

      // Wait for all fetches
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Verify multiple fetches were triggered (exact count depends on timing)
      expect(fetchCount, greaterThan(1));

      // State should still be valid
      final result = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );
      expect(result.length, equals(1));

      container.dispose();
    });

    test('updates state when list length changes', () async {
      // Arrange - tests _listEquals different length branch (line 39)
      final initialLinks = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      final updatedLinks = <EntryLink>[]; // Empty list - different length

      var callCount = 0;
      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? initialLinks : updatedLinks;
      });
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Initial load - should have 1 item
      final initialResult = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );
      expect(initialResult.length, equals(1));

      // Notify update
      updateStreamController.add({testAudioEntryId});

      // Wait for async update
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Get updated state - should have 0 items (different length triggers update)
      final updatedResult = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );
      expect(updatedResult.length, equals(0));

      container.dispose();
    });

    test('updates state when entry ID changes in list', () async {
      // Arrange - tests _listEquals different ID branch (line 41)
      final entry1Link = EntryLink.basic(
        id: 'link-1',
        fromId: testAudioEntryId,
        toId: testAiResponseEntry1.meta.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
      );

      final entry2Link = EntryLink.basic(
        id: 'link-2',
        fromId: testAudioEntryId,
        toId: testAiResponseEntry2.meta.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
      );

      var callCount = 0;
      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async {
        callCount++;
        // First call returns entry1, second call returns entry2 (same length, different ID)
        return callCount == 1 ? [entry1Link] : [entry2Link];
      });
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry2.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry2);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Initial load
      final initialResult = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );
      expect(initialResult[0].meta.id, equals(testAiResponseEntry1.meta.id));

      // Notify update
      updateStreamController.add({testAudioEntryId});

      // Wait for async update
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Get updated state - should have different entry (ID change triggers update)
      final updatedResult = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );
      expect(updatedResult[0].meta.id, equals(testAiResponseEntry2.meta.id));

      container.dispose();
    });

    test('handles empty initial state transitioning to data', () async {
      // Arrange - tests state.value being null initially
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      var callCount = 0;
      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async {
        callCount++;
        // First call returns empty, second returns data
        return callCount == 1 ? [] : links;
      });
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Initial load - empty
      final initialResult = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );
      expect(initialResult, isEmpty);

      // Notify update
      updateStreamController.add({testAudioEntryId});

      // Wait for async update
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Get updated state - should have data now
      final updatedResult = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );
      expect(updatedResult.length, equals(1));

      container.dispose();
    });

    test('correctly compares two empty lists as equal', () async {
      // Arrange - tests _listEquals when both lists are empty (line 46)
      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async => []);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Initial load - empty list
      final initialResult = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );
      expect(initialResult, isEmpty);

      // Notify update - should fetch but not update state since [] equals []
      updateStreamController.add({testAudioEntryId});

      // Wait for async update
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // State should still be empty (two empty lists are equal)
      final result = await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );
      expect(result, isEmpty);

      container.dispose();
    });

    test('tracks state transitions from loading to data', () async {
      // Arrange - verifies proper state transitions including null -> data
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Track state changes
      final states = <AsyncValue<List<AiResponseEntry>>>[];
      container.listen(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId),
        (_, next) => states.add(next),
        fireImmediately: true,
      );

      // Wait for initial load
      await container.read(
        linkedAiResponsesControllerProvider(entryId: testAudioEntryId).future,
      );

      // Verify we got loading then data states
      expect(states.any((s) => s.isLoading), isTrue);
      expect(states.any((s) => s.hasValue && s.value!.isNotEmpty), isTrue);

      container.dispose();
    });
  });
}
