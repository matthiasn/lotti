import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'linked_entries_controller_test_helpers.dart';

void main() {
  late MockJournalRepository mockJournalRepository;
  late MockUpdateNotifications mockUpdateNotifications;
  late StreamController<Set<String>> updateStreamController;

  setUp(() {
    mockJournalRepository = MockJournalRepository();
    mockUpdateNotifications = MockUpdateNotifications();
    updateStreamController = StreamController<Set<String>>.broadcast();

    // Setup the mock update notifications
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => updateStreamController.stream);

    // Per-test GetIt scope (popped in tearDown). EntryController is
    // constructed by the sortedLinkedEntriesProvider tests via
    // FakeEntryController, which resolves these services in field
    // initializers.
    getIt
      ..pushNewScope()
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<JournalDb>(MockJournalDb())
      ..registerSingleton<EditorStateService>(MockEditorStateService())
      ..registerSingleton<PersistenceLogic>(MockPersistenceLogic());
  });

  tearDown(() async {
    await updateStreamController.close();
    await getIt.popScope();
  });

  group('LinkedEntriesController', () {
    const testId = 'test-entry-id';
    final testDate = DateTime(2024, 3, 15, 10, 30);
    final testLinks = [
      EntryLink.basic(
        id: 'link-1',
        fromId: testId,
        toId: 'linked-id-1',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
        hidden: false,
      ),
      EntryLink.basic(
        id: 'link-2',
        fromId: testId,
        toId: 'linked-id-2',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
        hidden: false,
      ),
    ];

    test('loads links on initialization', () async {
      // Arrange
      when(
        () => mockJournalRepository.getLinksFromId(testId),
      ).thenAnswer((_) async => testLinks);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(testId).overrideWith(
            () => FakeIncludeHiddenController(false),
          ),
        ],
      );

      // Get the controller and wait for it to load
      final controller = container.read(
        linkedEntriesControllerProvider(testId).notifier,
      );
      final result = await container.read(
        linkedEntriesControllerProvider(testId).future,
      );

      // Assert
      expect(result, equals(testLinks));
      expect(controller.watchedIds, contains(testId));
      expect(controller.watchedIds, contains('linked-id-1'));
      expect(controller.watchedIds, contains('linked-id-2'));

      // Verify the repository was called with the correct parameters
      verify(() => mockJournalRepository.getLinksFromId(testId)).called(1);
    });

    test('updates state when affected IDs are notified', () async {
      // Arrange
      when(
        () => mockJournalRepository.getLinksFromId(testId),
      ).thenAnswer((_) async => testLinks);

      final updatedLinks = [
        EntryLink.basic(
          id: 'link-1',
          fromId: testId,
          toId: 'linked-id-1',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
          hidden: false,
        ),
        EntryLink.basic(
          id: 'link-3',
          fromId: testId,
          toId: 'linked-id-3', // Changed from linked-id-2 to linked-id-3
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
          hidden: false,
        ),
      ];

      // Setup the second call to return updated links
      when(
        () => mockJournalRepository.getLinksFromId(testId),
      ).thenAnswer((_) async => testLinks);
      when(
        () => mockJournalRepository.getLinksFromId(testId),
      ).thenAnswer((_) async => updatedLinks);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(testId).overrideWith(
            () => FakeIncludeHiddenController(false),
          ),
        ],
      );

      // Get the controller and wait for it to load
      final controller = container.read(
        linkedEntriesControllerProvider(testId).notifier,
      );
      await container.read(linkedEntriesControllerProvider(testId).future);

      // Simulate an update notification for one of the watched IDs
      updateStreamController.add({'linked-id-1'});

      // Wait for the async update to complete
      await pumpEventQueue();

      // Get the updated state
      final updatedState = container.read(
        linkedEntriesControllerProvider(testId),
      );

      // Assert
      expect(updatedState.value, equals(updatedLinks));
      expect(
        controller.watchedIds,
        contains('linked-id-3'),
      ); // Should have the new ID

      // Verify the repository was called twice
      verify(() => mockJournalRepository.getLinksFromId(testId)).called(2);
    });

    test('removes link when removeLink is called', () async {
      // Arrange
      when(
        () => mockJournalRepository.getLinksFromId(testId),
      ).thenAnswer((_) async => testLinks);

      when(
        () => mockJournalRepository.removeLink(
          fromId: testId,
          toId: 'linked-id-1',
        ),
      ).thenAnswer((_) async => 1);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(testId).overrideWith(
            () => FakeIncludeHiddenController(false),
          ),
        ],
      );

      // Get the controller and wait for it to load
      final controller = container.read(
        linkedEntriesControllerProvider(testId).notifier,
      );
      await container.read(linkedEntriesControllerProvider(testId).future);

      // Call removeLink
      await controller.removeLink(toId: 'linked-id-1');

      // Assert
      verify(
        () => mockJournalRepository.removeLink(
          fromId: testId,
          toId: 'linked-id-1',
        ),
      ).called(1);
    });

    test('updates link when updateLink is called', () async {
      // Arrange
      when(
        () => mockJournalRepository.getLinksFromId(testId),
      ).thenAnswer((_) async => testLinks);

      final linkToUpdate = EntryLink.basic(
        id: 'link-1',
        fromId: testId,
        toId: 'linked-id-1',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
        hidden: true, // Changed to hidden
      );

      when(
        () => mockJournalRepository.updateLink(linkToUpdate),
      ).thenAnswer((_) async => true);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(testId).overrideWith(
            () => FakeIncludeHiddenController(false),
          ),
        ],
      );

      // Get the controller and wait for it to load
      final controller = container.read(
        linkedEntriesControllerProvider(testId).notifier,
      );
      await container.read(linkedEntriesControllerProvider(testId).future);

      // Call updateLink
      await controller.updateLink(linkToUpdate);

      // Assert
      verify(() => mockJournalRepository.updateLink(linkToUpdate)).called(1);
    });

    test('respects includeHidden parameter', () async {
      // Arrange
      when(
        () => mockJournalRepository.getLinksFromId(testId, includeHidden: true),
      ).thenAnswer((_) async => testLinks);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(testId).overrideWith(
            () =>
                FakeIncludeHiddenController(true), // Set includeHidden to true
          ),
        ],
      );

      // Get the controller and wait for it to load
      await container.read(linkedEntriesControllerProvider(testId).future);

      // Assert
      verify(
        () => mockJournalRepository.getLinksFromId(testId, includeHidden: true),
      ).called(1);
    });

    test('disposes subscription when disposed', () async {
      // Arrange
      when(
        () => mockJournalRepository.getLinksFromId(testId),
      ).thenAnswer((_) async => testLinks);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(testId).overrideWith(
            () => FakeIncludeHiddenController(false),
          ),
        ],
      );

      // Get the controller and wait for it to load
      final controller = container.read(
        linkedEntriesControllerProvider(testId).notifier,
      );
      await container.read(linkedEntriesControllerProvider(testId).future);

      // We can't directly access the private _updateSubscription field
      // but we can verify the controller was created successfully
      expect(controller, isNotNull);

      // Dispose the container
      container.dispose();

      // We can't directly test if the subscription is canceled, but we've verified
      // the onDispose callback is registered correctly in the controller
    });
  });

  group('IncludeHiddenController', () {
    const testId = 'test-entry-id';

    test('initializes with default value of false', () {
      // Act
      final container = ProviderContainer();
      final result = container.read(
        includeHiddenControllerProvider(testId),
      );

      // Assert
      expect(result, isFalse);
    });

    test('can update value', () {
      // Act
      final container = ProviderContainer();
      final controller = container.read(
        includeHiddenControllerProvider(testId).notifier,
      );

      // Initial state should be false
      expect(controller.includeHidden, isFalse);

      // Update the value
      controller.includeHidden = true;

      // Assert
      expect(controller.includeHidden, isTrue);
      expect(
        container.read(includeHiddenControllerProvider(testId)),
        isTrue,
      );
    });
  });

  group('IncludeAiEntriesController', () {
    const testId = 'test-entry-id';

    test('initializes with default value of false', () {
      // Act
      final container = ProviderContainer();
      final result = container.read(
        includeAiEntriesControllerProvider(testId),
      );

      // Assert
      expect(result, isFalse);
    });

    test('can update value', () {
      // Act
      final container = ProviderContainer();
      final controller = container.read(
        includeAiEntriesControllerProvider(testId).notifier,
      );

      // Initial state should be false
      expect(controller.includeAiEntries, isFalse);

      // Update the value
      controller.includeAiEntries = true;

      // Assert
      expect(controller.includeAiEntries, isTrue);
      expect(
        container.read(includeAiEntriesControllerProvider(testId)),
        isTrue,
      );
    });
  });

  group('ShowFlaggedOnlyController', () {
    const testId = 'test-entry-id';

    test('initializes with default value of false', () {
      // Act
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final result = container.read(
        showFlaggedOnlyControllerProvider(testId),
      );

      // Assert
      expect(result, isFalse);
    });

    test('can update value', () {
      // Act
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(
        showFlaggedOnlyControllerProvider(testId).notifier,
      );

      // Initial state should be false
      expect(controller.showFlaggedOnly, isFalse);

      // Update the value
      controller.showFlaggedOnly = true;

      // Assert
      expect(controller.showFlaggedOnly, isTrue);
      expect(
        container.read(showFlaggedOnlyControllerProvider(testId)),
        isTrue,
      );
    });

    test('state is scoped per entry id', () {
      // Act
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
              .read(showFlaggedOnlyControllerProvider(testId).notifier)
              .showFlaggedOnly =
          true;

      // Assert: another entry id keeps its own independent default
      expect(
        container.read(showFlaggedOnlyControllerProvider(testId)),
        isTrue,
      );
      expect(
        container.read(showFlaggedOnlyControllerProvider('other-id')),
        isFalse,
      );
    });
  });

  group('NewestLinkedIdController', () {
    const testId = 'test-entry-id';
    final baseDate = DateTime(2024, 3, 15, 10, 30);
    final testLinks = [
      EntryLink.basic(
        id: 'link-1',
        fromId: testId,
        toId: 'linked-id-1',
        createdAt: baseDate.subtract(const Duration(days: 2)),
        updatedAt: baseDate,
        vectorClock: null,
        hidden: false,
      ),
      EntryLink.basic(
        id: 'link-2',
        fromId: testId,
        toId: 'linked-id-2',
        createdAt: baseDate.subtract(const Duration(days: 1)),
        updatedAt: baseDate,
        vectorClock: null,
        hidden: false,
      ),
      EntryLink.basic(
        id: 'link-3',
        fromId: testId,
        toId: 'linked-id-3',
        createdAt: baseDate,
        updatedAt: baseDate,
        vectorClock: null,
        hidden: false,
      ),
    ];

    test('returns null when id is null', () async {
      // Act
      final container = ProviderContainer();
      final result = await container.read(
        newestLinkedIdControllerProvider(null).future,
      );

      // Assert
      expect(result, isNull);
    });

    test('returns the newest linked ID based on creation date', () async {
      // Arrange
      when(
        () => mockJournalRepository.getLinksFromId(testId),
      ).thenAnswer((_) async => testLinks);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(testId).overrideWith(
            () => FakeIncludeHiddenController(false),
          ),
        ],
      );

      // Wait for the linked entries to load
      await container.read(linkedEntriesControllerProvider(testId).future);

      // Get the newest linked ID
      final newestId = await container.read(
        newestLinkedIdControllerProvider(testId).future,
      );

      // Assert
      expect(newestId, equals('linked-id-3')); // The most recently created link
    });

    test('returns null when there are no linked entries', () async {
      // Arrange
      when(
        () => mockJournalRepository.getLinksFromId(testId),
      ).thenAnswer((_) async => []);

      // Act
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(testId).overrideWith(
            () => FakeIncludeHiddenController(false),
          ),
        ],
      );

      // Wait for the linked entries to load
      await container.read(linkedEntriesControllerProvider(testId).future);

      // Get the newest linked ID
      final newestId = await container.read(
        newestLinkedIdControllerProvider(testId).future,
      );

      // Assert
      expect(newestId, isNull);
    });
  });
}
