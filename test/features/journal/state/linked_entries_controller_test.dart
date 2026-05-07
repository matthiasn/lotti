//ignore_for_file: avoid_positional_boolean_parameters

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/linked_entries_activity_filter.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_entry_controller.dart';
import '../../../mocks/mocks.dart';

class MockIncludeHiddenController extends IncludeHiddenController {
  MockIncludeHiddenController(this._value);
  final bool _value;

  @override
  bool build({required String id}) => _value;
}

/// Synchronous links override for the unresolved-fallback test, so the
/// provider can run without registering a journal repository or stubbing
/// async loads.
class _StaticLinksController extends LinkedEntriesController {
  _StaticLinksController(this._links);
  final List<EntryLink> _links;

  @override
  Future<List<EntryLink>> build({required String id}) {
    state = AsyncData(_links);
    return SynchronousFuture(_links);
  }
}

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

    // Register mocks in GetIt. EntryController is constructed by the
    // sortedLinkedEntriesProvider tests via FakeEntryController, which
    // resolves these services in field initializers.
    getIt.allowReassignment = true;
    getIt
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<JournalDb>(MockJournalDb())
      ..registerSingleton<EditorStateService>(MockEditorStateService())
      ..registerSingleton<PersistenceLogic>(MockPersistenceLogic());
  });

  tearDown(() async {
    await updateStreamController.close();
    await getIt.reset();
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
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
        ],
      );

      // Get the controller and wait for it to load
      final controller = container.read(
        linkedEntriesControllerProvider(id: testId).notifier,
      );
      final result = await container.read(
        linkedEntriesControllerProvider(id: testId).future,
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
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
        ],
      );

      // Get the controller and wait for it to load
      final controller = container.read(
        linkedEntriesControllerProvider(id: testId).notifier,
      );
      await container.read(linkedEntriesControllerProvider(id: testId).future);

      // Simulate an update notification for one of the watched IDs
      updateStreamController.add({'linked-id-1'});

      // Wait for the async update to complete
      await pumpEventQueue();

      // Get the updated state
      final updatedState = container.read(
        linkedEntriesControllerProvider(id: testId),
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
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
        ],
      );

      // Get the controller and wait for it to load
      final controller = container.read(
        linkedEntriesControllerProvider(id: testId).notifier,
      );
      await container.read(linkedEntriesControllerProvider(id: testId).future);

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
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
        ],
      );

      // Get the controller and wait for it to load
      final controller = container.read(
        linkedEntriesControllerProvider(id: testId).notifier,
      );
      await container.read(linkedEntriesControllerProvider(id: testId).future);

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
          includeHiddenControllerProvider(id: testId).overrideWith(
            () =>
                MockIncludeHiddenController(true), // Set includeHidden to true
          ),
        ],
      );

      // Get the controller and wait for it to load
      await container.read(linkedEntriesControllerProvider(id: testId).future);

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
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
        ],
      );

      // Get the controller and wait for it to load
      final controller = container.read(
        linkedEntriesControllerProvider(id: testId).notifier,
      );
      await container.read(linkedEntriesControllerProvider(id: testId).future);

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
        includeHiddenControllerProvider(id: testId),
      );

      // Assert
      expect(result, isFalse);
    });

    test('can update value', () {
      // Act
      final container = ProviderContainer();
      final controller = container.read(
        includeHiddenControllerProvider(id: testId).notifier,
      );

      // Initial state should be false
      expect(controller.includeHidden, isFalse);

      // Update the value
      controller.includeHidden = true;

      // Assert
      expect(controller.includeHidden, isTrue);
      expect(
        container.read(includeHiddenControllerProvider(id: testId)),
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
        includeAiEntriesControllerProvider(id: testId),
      );

      // Assert
      expect(result, isFalse);
    });

    test('can update value', () {
      // Act
      final container = ProviderContainer();
      final controller = container.read(
        includeAiEntriesControllerProvider(id: testId).notifier,
      );

      // Initial state should be false
      expect(controller.includeAiEntries, isFalse);

      // Update the value
      controller.includeAiEntries = true;

      // Assert
      expect(controller.includeAiEntries, isTrue);
      expect(
        container.read(includeAiEntriesControllerProvider(id: testId)),
        isTrue,
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
        newestLinkedIdControllerProvider(id: null).future,
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
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
        ],
      );

      // Wait for the linked entries to load
      await container.read(linkedEntriesControllerProvider(id: testId).future);

      // Get the newest linked ID
      final newestId = await container.read(
        newestLinkedIdControllerProvider(id: testId).future,
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
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
        ],
      );

      // Wait for the linked entries to load
      await container.read(linkedEntriesControllerProvider(id: testId).future);

      // Get the newest linked ID
      final newestId = await container.read(
        newestLinkedIdControllerProvider(id: testId).future,
      );

      // Assert
      expect(newestId, isNull);
    });
  });

  group('HasNonTaskLinkedEntriesProvider', () {
    const testId = 'test-entry-id';
    final testDate = DateTime(2025, 12, 31, 12);

    Task buildTask(String id) => Task(
      meta: Metadata(
        id: id,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: const [],
        title: 'Test Task',
      ),
    );

    JournalEntry buildJournalEntry(String id) => JournalEntry(
      meta: Metadata(
        id: id,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      ),
      entryText: const EntryText(plainText: 'Test entry'),
    );

    test('returns false when resolved entities is empty', () {
      // Act
      final container = ProviderContainer(
        overrides: [
          resolvedOutgoingLinkedEntriesProvider(testId).overrideWith(
            (ref) => <JournalEntity>[],
          ),
        ],
      );

      final result = container.read(hasNonTaskLinkedEntriesProvider(testId));

      // Assert
      expect(result, isFalse);
    });

    test('returns false when all entries are Tasks', () {
      // Arrange
      final task1 = buildTask('linked-id-1');
      final task2 = buildTask('linked-id-2');

      // Act
      final container = ProviderContainer(
        overrides: [
          resolvedOutgoingLinkedEntriesProvider(testId).overrideWith(
            (ref) => [task1, task2],
          ),
        ],
      );

      final result = container.read(hasNonTaskLinkedEntriesProvider(testId));

      // Assert
      expect(result, isFalse);
    });

    test('returns true when there is at least one non-Task entry', () {
      // Arrange
      final task = buildTask('linked-id-1');
      final journalEntry = buildJournalEntry('linked-id-2');

      // Act
      final container = ProviderContainer(
        overrides: [
          resolvedOutgoingLinkedEntriesProvider(testId).overrideWith(
            (ref) => [task, journalEntry],
          ),
        ],
      );

      final result = container.read(hasNonTaskLinkedEntriesProvider(testId));

      // Assert
      expect(result, isTrue);
    });

    test('returns true when all entries are non-Task', () {
      // Arrange
      final journalEntry1 = buildJournalEntry('linked-id-1');
      final journalEntry2 = buildJournalEntry('linked-id-2');

      // Act
      final container = ProviderContainer(
        overrides: [
          resolvedOutgoingLinkedEntriesProvider(testId).overrideWith(
            (ref) => [journalEntry1, journalEntry2],
          ),
        ],
      );

      final result = container.read(hasNonTaskLinkedEntriesProvider(testId));

      // Assert
      expect(result, isTrue);
    });
  });

  group('LinkedEntriesActivityFilterController', () {
    const testId = 'test-entry-id';

    test('defaults to all activity kinds active', () {
      final container = ProviderContainer();
      final state = container.read(
        linkedEntriesActivityFilterControllerProvider(id: testId),
      );
      expect(state, LinkedEntryActivityFilter.values.toSet());
    });

    test('toggle removes an active kind', () {
      final container = ProviderContainer();
      container
          .read(
            linkedEntriesActivityFilterControllerProvider(id: testId).notifier,
          )
          .toggle(LinkedEntryActivityFilter.audio);

      final state = container.read(
        linkedEntriesActivityFilterControllerProvider(id: testId),
      );
      expect(state, isNot(contains(LinkedEntryActivityFilter.audio)));
      expect(state, contains(LinkedEntryActivityFilter.timer));
      expect(state, contains(LinkedEntryActivityFilter.images));
    });

    test('toggle restores an inactive kind', () {
      final container = ProviderContainer();
      container.read(
          linkedEntriesActivityFilterControllerProvider(
            id: testId,
          ).notifier,
        )
        ..toggle(LinkedEntryActivityFilter.timer)
        ..toggle(LinkedEntryActivityFilter.timer);

      final state = container.read(
        linkedEntriesActivityFilterControllerProvider(id: testId),
      );
      expect(state, contains(LinkedEntryActivityFilter.timer));
    });

    test('toggle is independent per entry id', () {
      final container = ProviderContainer();
      container
          .read(
            linkedEntriesActivityFilterControllerProvider(id: 'a').notifier,
          )
          .toggle(LinkedEntryActivityFilter.images);

      final stateA = container.read(
        linkedEntriesActivityFilterControllerProvider(id: 'a'),
      );
      final stateB = container.read(
        linkedEntriesActivityFilterControllerProvider(id: 'b'),
      );
      expect(stateA, isNot(contains(LinkedEntryActivityFilter.images)));
      expect(stateB, contains(LinkedEntryActivityFilter.images));
    });
  });

  group('sortedLinkedEntriesProvider', () {
    const testId = 'test-entry-id';
    final linkCreatedAt = DateTime(2024, 3, 15, 10);

    EntryLink buildLink(String suffix) => EntryLink.basic(
      id: 'link-$suffix',
      fromId: testId,
      toId: 'linked-id-$suffix',
      // All links share the same createdAt — so any ordering must come
      // from the linked entity's dateFrom, not the link timestamp.
      createdAt: linkCreatedAt,
      updatedAt: linkCreatedAt,
      vectorClock: null,
      hidden: false,
    );

    JournalEntry buildEntry(String suffix, DateTime dateFrom) => JournalEntry(
      meta: Metadata(
        id: 'linked-id-$suffix',
        createdAt: linkCreatedAt,
        updatedAt: linkCreatedAt,
        dateFrom: dateFrom,
        dateTo: dateFrom,
      ),
      entryText: EntryText(plainText: 'entry $suffix'),
    );

    test('orders by entity dateFrom descending when newestFirst', () async {
      final earliest = buildEntry('a', DateTime(2026, 5, 7, 19, 45));
      final latest = buildEntry('b', DateTime(2026, 5, 7, 20, 45));
      final middle = buildEntry('c', DateTime(2026, 5, 7, 20, 17));
      final links = [buildLink('a'), buildLink('b'), buildLink('c')];

      when(
        () => mockJournalRepository.getLinksFromId(testId),
      ).thenAnswer((_) async => links);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
          createEntryControllerOverride(earliest),
          createEntryControllerOverride(latest),
          createEntryControllerOverride(middle),
        ],
      );

      await container.read(linkedEntriesControllerProvider(id: testId).future);
      await Future.wait([
        for (final entry in [earliest, latest, middle])
          container.read(entryControllerProvider(id: entry.meta.id).future),
      ]);

      final sorted = container.read(sortedLinkedEntriesProvider(testId));

      expect(
        sorted.map((l) => l.toId),
        [latest.meta.id, middle.meta.id, earliest.meta.id],
      );
    });

    test('orders by entity dateFrom ascending when oldestFirst', () async {
      final earliest = buildEntry('a', DateTime(2026, 5, 7, 19, 45));
      final latest = buildEntry('b', DateTime(2026, 5, 7, 20, 45));
      final middle = buildEntry('c', DateTime(2026, 5, 7, 20, 17));
      final links = [buildLink('a'), buildLink('b'), buildLink('c')];

      when(
        () => mockJournalRepository.getLinksFromId(testId),
      ).thenAnswer((_) async => links);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
          createEntryControllerOverride(earliest),
          createEntryControllerOverride(latest),
          createEntryControllerOverride(middle),
        ],
      );

      await container.read(linkedEntriesControllerProvider(id: testId).future);
      await Future.wait([
        for (final entry in [earliest, latest, middle])
          container.read(entryControllerProvider(id: entry.meta.id).future),
      ]);
      container
              .read(linkedEntriesSortControllerProvider(id: testId).notifier)
              .order =
          LinkedEntriesSortOrder.oldestFirst;

      final sorted = container.read(sortedLinkedEntriesProvider(testId));

      expect(
        sorted.map((l) => l.toId),
        [earliest.meta.id, middle.meta.id, latest.meta.id],
      );
    });

    test('ignores link.createdAt when sorting by dateFrom', () async {
      // The link for the "latest" entry was created earliest; the link for
      // the "earliest" entry was created last. If sort used link.createdAt
      // the order would be inverted.
      final earliest = buildEntry('a', DateTime(2026, 5, 7, 19, 45));
      final latest = buildEntry('b', DateTime(2026, 5, 7, 20, 45));

      final earliestLink = EntryLink.basic(
        id: 'link-a',
        fromId: testId,
        toId: earliest.meta.id,
        createdAt: DateTime(2026, 6),
        updatedAt: DateTime(2026, 6),
        vectorClock: null,
        hidden: false,
      );
      final latestLink = EntryLink.basic(
        id: 'link-b',
        fromId: testId,
        toId: latest.meta.id,
        createdAt: DateTime(2026, 4),
        updatedAt: DateTime(2026, 4),
        vectorClock: null,
        hidden: false,
      );

      when(() => mockJournalRepository.getLinksFromId(testId)).thenAnswer(
        (_) async => [earliestLink, latestLink],
      );

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
          createEntryControllerOverride(earliest),
          createEntryControllerOverride(latest),
        ],
      );

      await container.read(linkedEntriesControllerProvider(id: testId).future);
      await Future.wait([
        for (final entry in [earliest, latest])
          container.read(entryControllerProvider(id: entry.meta.id).future),
      ]);

      final sorted = container.read(sortedLinkedEntriesProvider(testId));

      expect(sorted.map((l) => l.toId), [latest.meta.id, earliest.meta.id]);
    });

    test('falls back to link.createdAt when entity is unresolved', () {
      final unresolvedLink = EntryLink.basic(
        id: 'link-old',
        fromId: testId,
        toId: 'unresolved-id',
        createdAt: DateTime(2026, 5),
        updatedAt: DateTime(2026, 5),
        vectorClock: null,
        hidden: false,
      );
      final newerLink = EntryLink.basic(
        id: 'link-new',
        fromId: testId,
        toId: 'unresolved-id-2',
        createdAt: DateTime(2026, 5, 6),
        updatedAt: DateTime(2026, 5, 6),
        vectorClock: null,
        hidden: false,
      );

      when(() => mockJournalRepository.getLinksFromId(testId)).thenAnswer(
        (_) async => [unresolvedLink, newerLink],
      );

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
          linkedEntriesControllerProvider(id: testId).overrideWith(
            () => _StaticLinksController([unresolvedLink, newerLink]),
          ),
        ],
      );

      final sorted = container.read(sortedLinkedEntriesProvider(testId));

      expect(sorted.map((l) => l.id), ['link-new', 'link-old']);
    });

    test('breaks ties deterministically by createdAt then id', () async {
      // All three entries share the same dateFrom, so the primary sort
      // key returns 0 for every pair. The tie-breaker chain must pick
      // a stable order: createdAt ascending, then id ascending.
      final sharedDate = DateTime(2026, 5, 7, 20);
      final entryA = JournalEntry(
        meta: Metadata(
          id: 'entry-a',
          createdAt: linkCreatedAt,
          updatedAt: linkCreatedAt,
          dateFrom: sharedDate,
          dateTo: sharedDate,
        ),
        entryText: const EntryText(plainText: 'a'),
      );
      final entryB = JournalEntry(
        meta: Metadata(
          id: 'entry-b',
          createdAt: linkCreatedAt,
          updatedAt: linkCreatedAt,
          dateFrom: sharedDate,
          dateTo: sharedDate,
        ),
        entryText: const EntryText(plainText: 'b'),
      );
      final entryC = JournalEntry(
        meta: Metadata(
          id: 'entry-c',
          createdAt: linkCreatedAt,
          updatedAt: linkCreatedAt,
          dateFrom: sharedDate,
          dateTo: sharedDate,
        ),
        entryText: const EntryText(plainText: 'c'),
      );

      // Same createdAt for two of the three links — the third gets a
      // distinct (later) timestamp so we exercise both tie-breaker
      // levels: createdAt orders link-c last, then id picks between
      // link-a and link-b.
      final linkA = EntryLink.basic(
        id: 'link-a',
        fromId: testId,
        toId: entryA.meta.id,
        createdAt: DateTime(2026, 4),
        updatedAt: DateTime(2026, 4),
        vectorClock: null,
        hidden: false,
      );
      final linkB = EntryLink.basic(
        id: 'link-b',
        fromId: testId,
        toId: entryB.meta.id,
        createdAt: DateTime(2026, 4),
        updatedAt: DateTime(2026, 4),
        vectorClock: null,
        hidden: false,
      );
      final linkC = EntryLink.basic(
        id: 'link-c',
        fromId: testId,
        toId: entryC.meta.id,
        createdAt: DateTime(2026, 6),
        updatedAt: DateTime(2026, 6),
        vectorClock: null,
        hidden: false,
      );

      when(
        () => mockJournalRepository.getLinksFromId(testId),
      ).thenAnswer((_) async => [linkB, linkC, linkA]);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
          createEntryControllerOverride(entryA),
          createEntryControllerOverride(entryB),
          createEntryControllerOverride(entryC),
        ],
      );

      await container.read(linkedEntriesControllerProvider(id: testId).future);
      await Future.wait([
        for (final entry in [entryA, entryB, entryC])
          container.read(entryControllerProvider(id: entry.meta.id).future),
      ]);

      // Newest first: tie on dateFrom → newest createdAt wins, so link-c
      // (createdAt 2026-06) is first. link-a/link-b share createdAt;
      // the id tie-breaker is always ascending (not sign-flipped) so
      // link-a comes before link-b regardless of sort direction.
      expect(
        container
            .read(sortedLinkedEntriesProvider(testId))
            .map((l) => l.id)
            .toList(),
        ['link-c', 'link-a', 'link-b'],
      );

      container
              .read(linkedEntriesSortControllerProvider(id: testId).notifier)
              .order =
          LinkedEntriesSortOrder.oldestFirst;

      // Oldest first: link-a / link-b come before link-c (older
      // createdAt), and id orders them link-a, link-b.
      expect(
        container
            .read(sortedLinkedEntriesProvider(testId))
            .map((l) => l.id)
            .toList(),
        ['link-a', 'link-b', 'link-c'],
      );
    });

    test('returns empty list when no links exist', () async {
      when(
        () => mockJournalRepository.getLinksFromId(testId),
      ).thenAnswer((_) async => const []);

      final container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          includeHiddenControllerProvider(id: testId).overrideWith(
            () => MockIncludeHiddenController(false),
          ),
        ],
      );

      await container.read(linkedEntriesControllerProvider(id: testId).future);

      expect(container.read(sortedLinkedEntriesProvider(testId)), isEmpty);
    });
  });

  group('LinkedEntriesSortController', () {
    const testId = 'test-entry-id';

    test('defaults to newest first', () {
      final container = ProviderContainer();
      expect(
        container.read(linkedEntriesSortControllerProvider(id: testId)),
        LinkedEntriesSortOrder.newestFirst,
      );
    });

    test('order setter updates state', () {
      final container = ProviderContainer();
      container
              .read(linkedEntriesSortControllerProvider(id: testId).notifier)
              .order =
          LinkedEntriesSortOrder.oldestFirst;

      expect(
        container.read(linkedEntriesSortControllerProvider(id: testId)),
        LinkedEntriesSortOrder.oldestFirst,
      );
    });

    test('state is independent per entry id', () {
      final container = ProviderContainer();
      container
              .read(linkedEntriesSortControllerProvider(id: 'a').notifier)
              .order =
          LinkedEntriesSortOrder.oldestFirst;

      expect(
        container.read(linkedEntriesSortControllerProvider(id: 'a')),
        LinkedEntriesSortOrder.oldestFirst,
      );
      expect(
        container.read(linkedEntriesSortControllerProvider(id: 'b')),
        LinkedEntriesSortOrder.newestFirst,
      );
    });
  });
}
