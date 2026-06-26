import 'dart:async';

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
        linkedEntriesActivityFilterControllerProvider(testId),
      );
      expect(state, LinkedEntryActivityFilter.values.toSet());
    });

    test('toggle removes an active kind', () {
      final container = ProviderContainer();
      container
          .read(
            linkedEntriesActivityFilterControllerProvider(testId).notifier,
          )
          .toggle(LinkedEntryActivityFilter.audio);

      final state = container.read(
        linkedEntriesActivityFilterControllerProvider(testId),
      );
      expect(state, isNot(contains(LinkedEntryActivityFilter.audio)));
      expect(state, contains(LinkedEntryActivityFilter.timer));
      expect(state, contains(LinkedEntryActivityFilter.images));
    });

    test('toggle restores an inactive kind', () {
      final container = ProviderContainer();
      container.read(
          linkedEntriesActivityFilterControllerProvider(testId).notifier,
        )
        ..toggle(LinkedEntryActivityFilter.timer)
        ..toggle(LinkedEntryActivityFilter.timer);

      final state = container.read(
        linkedEntriesActivityFilterControllerProvider(testId),
      );
      expect(state, contains(LinkedEntryActivityFilter.timer));
    });

    test('toggle is independent per entry id', () {
      final container = ProviderContainer();
      container
          .read(
            linkedEntriesActivityFilterControllerProvider('a').notifier,
          )
          .toggle(LinkedEntryActivityFilter.images);

      final stateA = container.read(
        linkedEntriesActivityFilterControllerProvider('a'),
      );
      final stateB = container.read(
        linkedEntriesActivityFilterControllerProvider('b'),
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
          includeHiddenControllerProvider(testId).overrideWith(
            () => FakeIncludeHiddenController(false),
          ),
          createEntryControllerOverride(earliest),
          createEntryControllerOverride(latest),
          createEntryControllerOverride(middle),
        ],
      );

      await container.read(linkedEntriesControllerProvider(testId).future);
      await Future.wait([
        for (final entry in [earliest, latest, middle])
          container.read(entryControllerProvider(entry.meta.id).future),
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
          includeHiddenControllerProvider(testId).overrideWith(
            () => FakeIncludeHiddenController(false),
          ),
          createEntryControllerOverride(earliest),
          createEntryControllerOverride(latest),
          createEntryControllerOverride(middle),
        ],
      );

      await container.read(linkedEntriesControllerProvider(testId).future);
      await Future.wait([
        for (final entry in [earliest, latest, middle])
          container.read(entryControllerProvider(entry.meta.id).future),
      ]);
      container
              .read(linkedEntriesSortControllerProvider(testId).notifier)
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
          includeHiddenControllerProvider(testId).overrideWith(
            () => FakeIncludeHiddenController(false),
          ),
          createEntryControllerOverride(earliest),
          createEntryControllerOverride(latest),
        ],
      );

      await container.read(linkedEntriesControllerProvider(testId).future);
      await Future.wait([
        for (final entry in [earliest, latest])
          container.read(entryControllerProvider(entry.meta.id).future),
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
          includeHiddenControllerProvider(testId).overrideWith(
            () => FakeIncludeHiddenController(false),
          ),
          linkedEntriesControllerProvider(testId).overrideWith(
            () => StaticLinksController([unresolvedLink, newerLink]),
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
          includeHiddenControllerProvider(testId).overrideWith(
            () => FakeIncludeHiddenController(false),
          ),
          createEntryControllerOverride(entryA),
          createEntryControllerOverride(entryB),
          createEntryControllerOverride(entryC),
        ],
      );

      await container.read(linkedEntriesControllerProvider(testId).future);
      await Future.wait([
        for (final entry in [entryA, entryB, entryC])
          container.read(entryControllerProvider(entry.meta.id).future),
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
              .read(linkedEntriesSortControllerProvider(testId).notifier)
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
          includeHiddenControllerProvider(testId).overrideWith(
            () => FakeIncludeHiddenController(false),
          ),
        ],
      );

      await container.read(linkedEntriesControllerProvider(testId).future);

      expect(container.read(sortedLinkedEntriesProvider(testId)), isEmpty);
    });
  });

  group('LinkedEntriesSortController', () {
    const testId = 'test-entry-id';

    test('defaults to newest first', () {
      final container = ProviderContainer();
      expect(
        container.read(linkedEntriesSortControllerProvider(testId)),
        LinkedEntriesSortOrder.newestFirst,
      );
    });

    test('order setter updates state', () {
      final container = ProviderContainer();
      container
              .read(linkedEntriesSortControllerProvider(testId).notifier)
              .order =
          LinkedEntriesSortOrder.oldestFirst;

      expect(
        container.read(linkedEntriesSortControllerProvider(testId)),
        LinkedEntriesSortOrder.oldestFirst,
      );
    });

    test('state is independent per entry id', () {
      final container = ProviderContainer();
      container.read(linkedEntriesSortControllerProvider('a').notifier).order =
          LinkedEntriesSortOrder.oldestFirst;

      expect(
        container.read(linkedEntriesSortControllerProvider('a')),
        LinkedEntriesSortOrder.oldestFirst,
      );
      expect(
        container.read(linkedEntriesSortControllerProvider('b')),
        LinkedEntriesSortOrder.newestFirst,
      );
    });
  });
}
