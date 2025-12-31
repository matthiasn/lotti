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
    createdAt: DateTime(2024, 1, 15, 10),
    updatedAt: DateTime(2024, 1, 15, 10),
    vectorClock: null,
  ),
  EntryLink.basic(
    id: 'link-2',
    fromId: testAudioEntryId,
    toId: testAiResponseEntry2.meta.id,
    createdAt: DateTime(2024, 1, 15, 10),
    updatedAt: DateTime(2024, 1, 15, 10),
    vectorClock: null,
  ),
  EntryLink.basic(
    id: 'link-3',
    fromId: testAudioEntryId,
    toId: testDeletedAiResponseEntry.meta.id,
    createdAt: DateTime(2024, 1, 15, 10),
    updatedAt: DateTime(2024, 1, 15, 10),
    vectorClock: null,
  ),
  EntryLink.basic(
    id: 'link-4',
    fromId: testAudioEntryId,
    toId: testNonAiEntry.meta.id,
    createdAt: DateTime(2024, 1, 15, 10),
    updatedAt: DateTime(2024, 1, 15, 10),
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

  /// Waits for the provider state to change to a value that satisfies the predicate.
  /// Uses completer to avoid timing-based delays.
  Future<List<AiResponseEntry>> waitForState(
    ProviderContainer container,
    bool Function(List<AiResponseEntry>) predicate, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final completer = Completer<List<AiResponseEntry>>();
    final sub = container.listen(
      linkedAiResponsesControllerProvider(testAudioEntryId),
      (_, next) {
        if (!completer.isCompleted && next.hasValue && predicate(next.value!)) {
          completer.complete(next.value);
        }
      },
    );

    try {
      return await completer.future.timeout(timeout);
    } finally {
      sub.close();
    }
  }

  group('LinkedAiResponsesController', () {
    test('loads AI responses linked to an entry on initialization', () async {
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

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      final result = await container
          .read(
            linkedAiResponsesControllerProvider(testAudioEntryId).notifier,
          )
          .future;

      // Should only have non-deleted AI responses
      expect(result.length, equals(2));
      expect(result[0].meta.id, equals(testAiResponseEntry2.meta.id));
      expect(result[1].meta.id, equals(testAiResponseEntry1.meta.id));

      verify(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .called(1);

      container.dispose();
    });

    test('filters out deleted AI responses', () async {
      final linksWithDeleted = [
        EntryLink.basic(
          id: 'link-deleted',
          fromId: testAudioEntryId,
          toId: testDeletedAiResponseEntry.meta.id,
          createdAt: DateTime(2024, 1, 15, 10),
          updatedAt: DateTime(2024, 1, 15, 10),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async => linksWithDeleted);
      when(() => mockJournalRepository.getJournalEntityById(
            testDeletedAiResponseEntry.meta.id,
          )).thenAnswer((_) async => testDeletedAiResponseEntry);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      final result = await container
          .read(
            linkedAiResponsesControllerProvider(testAudioEntryId).notifier,
          )
          .future;

      expect(result, isEmpty);

      container.dispose();
    });

    test('filters out non-AI response entries', () async {
      final linksWithNonAi = [
        EntryLink.basic(
          id: 'link-non-ai',
          fromId: testAudioEntryId,
          toId: testNonAiEntry.meta.id,
          createdAt: DateTime(2024, 1, 15, 10),
          updatedAt: DateTime(2024, 1, 15, 10),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async => linksWithNonAi);
      when(() => mockJournalRepository.getJournalEntityById(
            testNonAiEntry.meta.id,
          )).thenAnswer((_) async => testNonAiEntry);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      final result = await container
          .read(
            linkedAiResponsesControllerProvider(testAudioEntryId).notifier,
          )
          .future;

      expect(result, isEmpty);

      container.dispose();
    });

    test('returns empty list when no links exist', () async {
      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async => []);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      final result = await container
          .read(
            linkedAiResponsesControllerProvider(testAudioEntryId).notifier,
          )
          .future;

      expect(result, isEmpty);

      container.dispose();
    });

    test('sorts AI responses by date (newest first)', () async {
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry1.meta.id, // Older (10:00)
          createdAt: DateTime(2024, 1, 15, 10),
          updatedAt: DateTime(2024, 1, 15, 10),
          vectorClock: null,
        ),
        EntryLink.basic(
          id: 'link-2',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry2.meta.id, // Newer (11:00)
          createdAt: DateTime(2024, 1, 15, 10),
          updatedAt: DateTime(2024, 1, 15, 10),
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

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      final result = await container
          .read(
            linkedAiResponsesControllerProvider(testAudioEntryId).notifier,
          )
          .future;

      // Newest should be first
      expect(result.length, equals(2));
      expect(result[0].meta.id, equals(testAiResponseEntry2.meta.id));
      expect(result[1].meta.id, equals(testAiResponseEntry1.meta.id));

      container.dispose();
    });

    test('updates state when affected IDs are notified', () async {
      final initialLinks = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime(2024, 1, 15, 10),
          updatedAt: DateTime(2024, 1, 15, 10),
          vectorClock: null,
        ),
      ];

      final updatedLinks = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime(2024, 1, 15, 10),
          updatedAt: DateTime(2024, 1, 15, 10),
          vectorClock: null,
        ),
        EntryLink.basic(
          id: 'link-2',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry2.meta.id,
          createdAt: DateTime(2024, 1, 15, 10),
          updatedAt: DateTime(2024, 1, 15, 10),
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

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Initial load
      final initialResult = await container
          .read(
            linkedAiResponsesControllerProvider(testAudioEntryId).notifier,
          )
          .future;
      expect(initialResult.length, equals(1));

      // Simulate update notification and wait for state change
      updateStreamController.add({testAudioEntryId});

      final updatedResult = await waitForState(
        container,
        (list) => list.length == 2,
      );

      expect(updatedResult.length, equals(2));

      container.dispose();
    });

    test('handles null entity gracefully', () async {
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: 'non-existent-id',
          createdAt: DateTime(2024, 1, 15, 10),
          updatedAt: DateTime(2024, 1, 15, 10),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById('non-existent-id'))
          .thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      final result = await container
          .read(
            linkedAiResponsesControllerProvider(testAudioEntryId).notifier,
          )
          .future;

      expect(result, isEmpty);

      container.dispose();
    });

    test('updates state when watched AI response ID is notified', () async {
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime(2024, 1, 15, 10),
          updatedAt: DateTime(2024, 1, 15, 10),
          vectorClock: null,
        ),
      ];

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

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Initial load
      final initialResult = await container
          .read(
            linkedAiResponsesControllerProvider(testAudioEntryId).notifier,
          )
          .future;
      expect(initialResult.length, equals(1));
      expect(
        initialResult[0].meta.updatedAt,
        equals(testAiResponseEntry1.meta.updatedAt),
      );

      // Notify with AI response ID and wait for state change
      updateStreamController.add({testAiResponseEntry1.meta.id});

      final updatedResult = await waitForState(
        container,
        (list) =>
            list.isNotEmpty &&
            list[0].meta.updatedAt == updatedEntry.meta.updatedAt,
      );

      expect(
          updatedResult[0].meta.updatedAt, equals(updatedEntry.meta.updatedAt));

      container.dispose();
    });

    test('ignores notifications for unrelated IDs', () async {
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime(2024, 1, 15, 10),
          updatedAt: DateTime(2024, 1, 15, 10),
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

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Initial load
      await container
          .read(
            linkedAiResponsesControllerProvider(testAudioEntryId).notifier,
          )
          .future;
      expect(fetchCount, equals(1));

      // Notify with unrelated ID
      updateStreamController.add({'unrelated-id-123'});

      // Allow time for any potential handler to run
      await Future.microtask(() {});
      await Future.microtask(() {});

      // Fetch count should not have increased
      expect(fetchCount, equals(1));

      container.dispose();
    });

    test('handles multiple AI responses with same date correctly', () async {
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
          createdAt: DateTime(2024, 1, 15, 10),
          updatedAt: DateTime(2024, 1, 15, 10),
          vectorClock: null,
        ),
        EntryLink.basic(
          id: 'link-2',
          fromId: testAudioEntryId,
          toId: sameTimeEntry2.meta.id,
          createdAt: DateTime(2024, 1, 15, 10),
          updatedAt: DateTime(2024, 1, 15, 10),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
          sameTimeEntry1.meta.id)).thenAnswer((_) async => sameTimeEntry1);
      when(() => mockJournalRepository.getJournalEntityById(
          sameTimeEntry2.meta.id)).thenAnswer((_) async => sameTimeEntry2);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      final result = await container
          .read(
            linkedAiResponsesControllerProvider(testAudioEntryId).notifier,
          )
          .future;

      expect(result.length, equals(2));

      container.dispose();
    });

    test('cleans up subscription on dispose', () async {
      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async => []);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      await container
          .read(
            linkedAiResponsesControllerProvider(testAudioEntryId).notifier,
          )
          .future;

      // Dispose should not throw
      container.dispose();

      // Sending notification after dispose should not cause issues
      updateStreamController.add({testAudioEntryId});

      // No assertion needed - test passes if no exception is thrown
    });

    test('updates state when list length changes', () async {
      final initialLinks = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime(2024, 1, 15, 10),
          updatedAt: DateTime(2024, 1, 15, 10),
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

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Initial load - should have 1 item
      final initialResult = await container
          .read(
            linkedAiResponsesControllerProvider(testAudioEntryId).notifier,
          )
          .future;
      expect(initialResult.length, equals(1));

      // Notify update and wait for state change
      updateStreamController.add({testAudioEntryId});

      final updatedResult = await waitForState(
        container,
        (list) => list.isEmpty,
      );

      expect(updatedResult.length, equals(0));

      container.dispose();
    });

    test('updates state when entry ID changes in list', () async {
      final entry1Link = EntryLink.basic(
        id: 'link-1',
        fromId: testAudioEntryId,
        toId: testAiResponseEntry1.meta.id,
        createdAt: DateTime(2024, 1, 15, 10),
        updatedAt: DateTime(2024, 1, 15, 10),
        vectorClock: null,
      );

      final entry2Link = EntryLink.basic(
        id: 'link-2',
        fromId: testAudioEntryId,
        toId: testAiResponseEntry2.meta.id,
        createdAt: DateTime(2024, 1, 15, 10),
        updatedAt: DateTime(2024, 1, 15, 10),
        vectorClock: null,
      );

      var callCount = 0;
      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? [entry1Link] : [entry2Link];
      });
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry2.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry2);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Initial load
      final initialResult = await container
          .read(
            linkedAiResponsesControllerProvider(testAudioEntryId).notifier,
          )
          .future;
      expect(initialResult[0].meta.id, equals(testAiResponseEntry1.meta.id));

      // Notify update and wait for state change
      updateStreamController.add({testAudioEntryId});

      final updatedResult = await waitForState(
        container,
        (list) =>
            list.isNotEmpty && list[0].meta.id == testAiResponseEntry2.meta.id,
      );

      expect(updatedResult[0].meta.id, equals(testAiResponseEntry2.meta.id));

      container.dispose();
    });

    test('handles empty initial state transitioning to data', () async {
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime(2024, 1, 15, 10),
          updatedAt: DateTime(2024, 1, 15, 10),
          vectorClock: null,
        ),
      ];

      var callCount = 0;
      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? [] : links;
      });
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Initial load - empty
      final initialResult = await container
          .read(
            linkedAiResponsesControllerProvider(testAudioEntryId).notifier,
          )
          .future;
      expect(initialResult, isEmpty);

      // Notify update and wait for state change
      updateStreamController.add({testAudioEntryId});

      final updatedResult = await waitForState(
        container,
        (list) => list.length == 1,
      );

      expect(updatedResult.length, equals(1));

      container.dispose();
    });

    test('tracks state transitions from loading to data', () async {
      final links = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testAudioEntryId,
          toId: testAiResponseEntry1.meta.id,
          createdAt: DateTime(2024, 1, 15, 10),
          updatedAt: DateTime(2024, 1, 15, 10),
          vectorClock: null,
        ),
      ];

      when(() => mockJournalRepository.getLinksFromId(testAudioEntryId))
          .thenAnswer((_) async => links);
      when(() => mockJournalRepository.getJournalEntityById(
            testAiResponseEntry1.meta.id,
          )).thenAnswer((_) async => testAiResponseEntry1);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      // Track state changes
      final states = <AsyncValue<List<AiResponseEntry>>>[];
      container.listen(
        linkedAiResponsesControllerProvider(testAudioEntryId),
        (_, next) => states.add(next),
        fireImmediately: true,
      );

      // Wait for initial load
      await container
          .read(
            linkedAiResponsesControllerProvider(testAudioEntryId).notifier,
          )
          .future;

      // Verify we got loading then data states
      expect(states.any((s) => s.isLoading), isTrue);
      expect(states.any((s) => s.hasValue && s.value!.isNotEmpty), isTrue);

      container.dispose();
    });
  });
}
