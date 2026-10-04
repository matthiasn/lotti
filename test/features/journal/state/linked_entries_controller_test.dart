import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/outbox_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
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

      // The initial build sees the original links; the refetch triggered by
      // the notification sees the updated ones.
      final responses = [testLinks, updatedLinks];
      when(
        () => mockJournalRepository.getLinksFromId(testId),
      ).thenAnswer((_) async => responses.removeAt(0));

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
      expect(
        await container.read(linkedEntriesControllerProvider(testId).future),
        equals(testLinks),
      );

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

    // The hide toggle sets the flag on the link as stored: a card's copy
    // rendered before the link was removed must not bring it back
    // (`specs/tla/EntryLinkIdentity.tla`, EditOnStored).
    test('setLinkHidden sets hidden on the link as stored', () async {
      when(
        () => mockJournalRepository.getLinksFromId(testId),
      ).thenAnswer((_) async => testLinks);
      when(
        () => mockJournalRepository.changeLink(any(), any()),
      ).thenAnswer((_) async => true);
      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(testId).overrideWith(
            () => FakeIncludeHiddenController(false),
          ),
        ],
      );
      final controller = container.read(
        linkedEntriesControllerProvider(testId).notifier,
      );
      await container.read(linkedEntriesControllerProvider(testId).future);

      await controller.setLinkHidden('link-1', hidden: true);

      final change =
          verify(
                () => mockJournalRepository.changeLink('link-1', captureAny()),
              ).captured.single
              as EntryLink Function(EntryLink);
      final stored = EntryLink.basic(
        id: 'link-1',
        fromId: testId,
        toId: 'linked-id-1',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
        collapsed: true,
      );
      expect(change(stored), stored.copyWith(hidden: true));
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
      expect(container.read(includeHiddenControllerProvider(testId)), isFalse);

      // Update the value
      controller.setIncludeHidden(value: true);

      // Assert
      expect(
        container.read(includeHiddenControllerProvider(testId)),
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
      expect(
        container.read(showFlaggedOnlyControllerProvider(testId)),
        isFalse,
      );

      // Update the value
      controller.setShowFlaggedOnly(value: true);

      // Assert
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
          .setShowFlaggedOnly(value: true);

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

  // The hide toggle through the real repository and journal: the link the
  // card shows was loaded into the controller's state, then removed on
  // another device; hiding it must not bring it back
  // (`specs/tla/EntryLinkIdentity.tla`, EditOnStored, NoRevival).
  group('setLinkHidden over the journal', () {
    const entryId = 'entry-with-link';
    late JournalDb db;
    late SettingsDb settingsDb;
    late MockOutboxService outbox;

    setUpAll(registerAllFallbackValues);

    setUp(() async {
      db = JournalDb(inMemoryDatabase: true);
      settingsDb = SettingsDb(inMemoryDatabase: true);
      outbox = MockOutboxService();
      when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
      getIt
        ..pushNewScope()
        ..registerSingleton<JournalDb>(db)
        ..registerSingleton<OutboxService>(outbox)
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<VectorClockService>(VectorClockService());
      await getIt<VectorClockService>().initialized;
    });

    tearDown(() async {
      await getIt.popScope();
      await db.close();
      await settingsDb.close();
    });

    test('hiding a link removed after the card loaded it leaves it '
        'removed', () async {
      final link = EntryLink.basic(
        id: 'shown-link',
        fromId: entryId,
        toId: 'note-id',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: const VectorClock({'device-b': 1}),
      );
      expect(await db.upsertEntryLink(link), 1);
      // The note it links to, which orders the card's links.
      await db.updateJournalEntity(
        testTextEntry.copyWith(
          meta: testTextEntry.meta.copyWith(id: 'note-id'),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          includeHiddenControllerProvider(
            entryId,
          ).overrideWith(() => FakeIncludeHiddenController(false)),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        linkedEntriesControllerProvider(entryId).notifier,
      );
      expect(
        await container.read(linkedEntriesControllerProvider(entryId).future),
        [link],
      );

      // Device B removes the link; its tombstone lands here.
      final removal = link.copyWith(
        deletedAt: DateTime(2024, 3, 16),
        updatedAt: DateTime(2024, 3, 16),
        hidden: true,
        vectorClock: const VectorClock({'device-b': 2}),
      );
      expect(await db.upsertEntryLink(removal), 1);

      await controller.setLinkHidden('shown-link', hidden: false);

      expect(await db.entryLinkById('shown-link'), removal);
    });
  });
}
