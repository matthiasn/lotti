import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockJournalDb mockDb;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late StreamController<Set<String>> updateStreamController;

  // Use a fixed date to avoid test flakiness
  final testDate = DateTime(2026, 1, 15, 12);

  CategoryDefinition createCategory(String id, String name) {
    return CategoryDefinition(
      id: id,
      name: name,
      createdAt: testDate,
      updatedAt: testDate,
      vectorClock: null,
      private: false,
      active: true,
    );
  }

  JournalEntity createJournalEntry({
    required String id,
    required String? categoryId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) {
    return JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: dateFrom,
        updatedAt: dateFrom,
        dateFrom: dateFrom,
        dateTo: dateTo,
        categoryId: categoryId,
      ),
    );
  }

  JournalEntity createTask({
    required String id,
    required String? categoryId,
    required DateTime dateFrom,
  }) {
    return JournalEntity.task(
      meta: Metadata(
        id: id,
        createdAt: dateFrom,
        updatedAt: dateFrom,
        dateFrom: dateFrom,
        dateTo: dateFrom,
        categoryId: categoryId,
      ),
      data: TaskData(
        title: 'Task $id',
        dateFrom: dateFrom,
        dateTo: dateFrom,
        statusHistory: [],
        status: TaskStatus.open(
          id: 'status-$id',
          createdAt: dateFrom,
          utcOffset: 0,
        ),
      ),
    );
  }

  EntryLink createLink({
    required String fromId,
    required String toId,
  }) {
    return EntryLink.basic(
      id: 'link-$fromId-$toId',
      fromId: fromId,
      toId: toId,
      createdAt: testDate,
      updatedAt: testDate,
      vectorClock: null,
    );
  }

  setUpAll(() {
    registerFallbackValue(<String>{});
    getIt.allowReassignment = true;
  });

  setUp(() {
    mockDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();
    mockEntitiesCacheService = MockEntitiesCacheService();
    updateStreamController = StreamController<Set<String>>.broadcast();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);

    when(() => mockEntitiesCacheService.sortedCategories).thenReturn([
      createCategory('cat-work', 'Work'),
      createCategory('cat-personal', 'Personal'),
    ]);

    getIt
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);

    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    updateStreamController.close();
    getIt.reset();
  });

  group('TimeHistoryHeaderController', () {
    test('initial load fetches 30 days of data', () async {
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);

      when(() => mockDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => []);

      final result =
          await container.read(timeHistoryHeaderControllerProvider.future);

      expect(result.days.length, equals(30));
      expect(result.isLoadingMore, isFalse);
      expect(result.canLoadMore, isTrue);
    });

    test('aggregates entries by day and category', () async {
      final jan15 = DateTime(2026, 1, 15, 10);

      // Task linked to journal entry
      final task = createTask(
        id: 'task-1',
        categoryId: 'cat-work',
        dateFrom: jan15,
      );

      // Journal entry with 1 hour duration
      final entry = createJournalEntry(
        id: 'entry-1',
        categoryId: null, // No direct category
        dateFrom: jan15,
        dateTo: jan15.add(const Duration(hours: 1)),
      );

      final link = createLink(fromId: 'task-1', toId: 'entry-1');

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [entry]);

      when(() => mockDb.linksForEntryIds(any()))
          .thenAnswer((_) async => [link]);

      when(() => mockDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => [task]);

      final result =
          await container.read(timeHistoryHeaderControllerProvider.future);

      // Find the day summary for Jan 15
      final daySummary = result.days.firstWhere(
        (d) => d.day.day == 15 && d.day.month == 1,
      );

      // Should have 1 hour in cat-work category
      expect(
        daySummary.durationByCategoryId['cat-work'],
        equals(const Duration(hours: 1)),
      );
      expect(daySummary.total, equals(const Duration(hours: 1)));
    });

    test('handles entries without category links', () async {
      final jan15 = DateTime(2026, 1, 15, 10);

      // Journal entry with no linked task (uncategorized)
      final entry = createJournalEntry(
        id: 'entry-1',
        categoryId: null,
        dateFrom: jan15,
        dateTo: jan15.add(const Duration(minutes: 30)),
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [entry]);

      when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);

      when(() => mockDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => []);

      final result =
          await container.read(timeHistoryHeaderControllerProvider.future);

      final daySummary = result.days.firstWhere(
        (d) => d.day.day == 15 && d.day.month == 1,
      );

      // Should have 30 minutes in null category (uncategorized)
      expect(
        daySummary.durationByCategoryId[null],
        equals(const Duration(minutes: 30)),
      );
    });

    test('computes maxDailyTotal correctly', () async {
      final jan15 = DateTime(2026, 1, 15, 10);
      final jan14 = DateTime(2026, 1, 14, 10);

      final entry1 = createJournalEntry(
        id: 'entry-1',
        categoryId: null,
        dateFrom: jan15,
        dateTo: jan15.add(const Duration(hours: 2)),
      );

      final entry2 = createJournalEntry(
        id: 'entry-2',
        categoryId: null,
        dateFrom: jan14,
        dateTo: jan14.add(const Duration(hours: 3)),
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [entry1, entry2]);

      when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);

      when(() => mockDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => []);

      final result =
          await container.read(timeHistoryHeaderControllerProvider.future);

      // Max should be 3 hours (from Jan 14)
      expect(result.maxDailyTotal, equals(const Duration(hours: 3)));
    });

    test('precomputes stacked heights', () async {
      final jan15 = DateTime(2026, 1, 15, 10);

      final task1 = createTask(
        id: 'task-1',
        categoryId: 'cat-work',
        dateFrom: jan15,
      );

      final task2 = createTask(
        id: 'task-2',
        categoryId: 'cat-personal',
        dateFrom: jan15,
      );

      final entry1 = createJournalEntry(
        id: 'entry-1',
        categoryId: null,
        dateFrom: jan15,
        dateTo: jan15.add(const Duration(hours: 1)),
      );

      final entry2 = createJournalEntry(
        id: 'entry-2',
        categoryId: null,
        dateFrom: jan15.add(const Duration(hours: 2)),
        dateTo: jan15.add(const Duration(hours: 3)),
      );

      final links = [
        createLink(fromId: 'task-1', toId: 'entry-1'),
        createLink(fromId: 'task-2', toId: 'entry-2'),
      ];

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [entry1, entry2]);

      when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => links);

      when(() => mockDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => [task1, task2]);

      final result =
          await container.read(timeHistoryHeaderControllerProvider.future);

      final jan15Noon = DateTime(2026, 1, 15, 12);
      final heights = result.stackedHeights[jan15Noon];

      expect(heights, isNotNull);
      // cat-work should start at 0 (first in stack)
      expect(heights!['cat-work'], equals(0.0));
      // cat-personal should start after cat-work
      expect(heights['cat-personal'], greaterThan(0.0));
    });

    test('loadMoreDays fetches 14 additional days', () async {
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);

      when(() => mockDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => []);

      // Initial load
      await container.read(timeHistoryHeaderControllerProvider.future);

      // Load more
      final notifier =
          container.read(timeHistoryHeaderControllerProvider.notifier);
      await notifier.loadMoreDays();

      final result = container.read(timeHistoryHeaderControllerProvider).value!;

      // Should have 30 + 14 = 44 days
      expect(result.days.length, equals(44));
    });

    test('loadMoreDays respects history window cap', () async {
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);

      when(() => mockDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => []);

      // Initial load
      await container.read(timeHistoryHeaderControllerProvider.future);

      final notifier =
          container.read(timeHistoryHeaderControllerProvider.notifier);

      // Load many times to exceed cap (180 days)
      for (var i = 0; i < 15; i++) {
        await notifier.loadMoreDays();
      }

      final result = container.read(timeHistoryHeaderControllerProvider).value!;

      // Should be capped at 180 days
      expect(result.days.length, lessThanOrEqualTo(180));
    });

    test('does not load more when already loading', () async {
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);

      when(() => mockDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => []);

      await container.read(timeHistoryHeaderControllerProvider.future);

      final notifier =
          container.read(timeHistoryHeaderControllerProvider.notifier);

      // Start two loads simultaneously
      unawaited(notifier.loadMoreDays());
      unawaited(notifier.loadMoreDays());

      await Future<void>.delayed(Duration.zero);

      // Only one additional query should have been made
      // Initial (1) + loadMore (1) = 2 total
      verify(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).called(2);
    });

    test('categoryOrder reflects EntitiesCacheService order', () async {
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);

      when(() => mockDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => []);

      final result =
          await container.read(timeHistoryHeaderControllerProvider.future);

      expect(result.categoryOrder, equals(['cat-work', 'cat-personal']));
    });

    test('days are sorted newest to oldest', () async {
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);

      when(() => mockDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => []);

      final result =
          await container.read(timeHistoryHeaderControllerProvider.future);

      // Verify days are sorted descending (newest first)
      for (var i = 0; i < result.days.length - 1; i++) {
        expect(
          result.days[i].day.isAfter(result.days[i + 1].day),
          isTrue,
          reason: 'Days should be sorted newest to oldest',
        );
      }
    });

    test('dayAt helper returns correct day summary', () async {
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);

      when(() => mockDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => []);

      final result =
          await container.read(timeHistoryHeaderControllerProvider.future);

      // Should find day regardless of time component
      final found = result.dayAt(DateTime(2026, 1, 15, 8, 30));
      expect(found, isNotNull);
      expect(found!.day.day, equals(15));

      // Should return null for date outside range
      final notFound = result.dayAt(DateTime(2025));
      expect(notFound, isNull);
    });
  });
}
