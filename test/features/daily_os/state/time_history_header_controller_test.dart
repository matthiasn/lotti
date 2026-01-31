import 'dart:async';

import 'package:clock/clock.dart';
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
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockJournalDb mockDb;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockLoggingService mockLoggingService;
  late StreamController<Set<String>> updateStreamController;

  // Use a fixed date to avoid test flakiness
  final testDate = DateTime(2026, 1, 15, 12);

  // Fixed clock for deterministic tests - controller uses clock.now()
  final fixedClock = Clock.fixed(testDate);

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
    registerFallbackValue(StackTrace.current);
    getIt.allowReassignment = true;
  });

  setUp(() {
    mockDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockLoggingService = MockLoggingService();
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
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<LoggingService>(mockLoggingService);

    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    updateStreamController.close();
    getIt.reset();
  });

  group('TimeHistoryHeaderController', () {
    test('initial load fetches 30 days of data', () async {
      await withClock(fixedClock, () async {
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
    });

    test('aggregates entries by day and category', () async {
      await withClock(fixedClock, () async {
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
    });

    test('handles entries without category links', () async {
      await withClock(fixedClock, () async {
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
    });

    test('computes maxDailyTotal correctly', () async {
      await withClock(fixedClock, () async {
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
    });

    test('precomputes stacked heights', () async {
      await withClock(fixedClock, () async {
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

        when(() => mockDb.linksForEntryIds(any()))
            .thenAnswer((_) async => links);

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
    });

    test('loadMoreDays fetches 14 additional days', () async {
      await withClock(fixedClock, () async {
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

        final result =
            container.read(timeHistoryHeaderControllerProvider).value!;

        // Should have 30 + 14 = 44 days
        expect(result.days.length, equals(44));
      });
    });

    test('loadMoreDays respects history window cap', () async {
      await withClock(fixedClock, () async {
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

        final result =
            container.read(timeHistoryHeaderControllerProvider).value!;

        // Should be capped at 180 days
        expect(result.days.length, lessThanOrEqualTo(180));
      });
    });

    test('does not load more when already loading', () async {
      await withClock(fixedClock, () async {
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
    });

    test('categoryOrder reflects EntitiesCacheService order', () async {
      await withClock(fixedClock, () async {
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
    });

    test('days are sorted newest to oldest', () async {
      await withClock(fixedClock, () async {
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
    });

    test('dayAt helper returns correct day summary', () async {
      await withClock(fixedClock, () async {
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

    test('captures entries at start of day (midnight boundary)', () async {
      await withClock(fixedClock, () async {
        // Entry at 00:30 on Jan 15 should be captured when querying Jan 15
        final jan15Early = DateTime(2026, 1, 15, 0, 30);

        final entry = createJournalEntry(
          id: 'entry-early',
          categoryId: null,
          dateFrom: jan15Early,
          dateTo: jan15Early.add(const Duration(hours: 1)),
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

        // Should have captured the early morning entry
        expect(daySummary.total, equals(const Duration(hours: 1)));
      });
    });

    test('recomputes stacked heights when maxDailyTotal increases on merge',
        () async {
      await withClock(fixedClock, () async {
        // Initial load has 1 hour in cat-work (max = 1 hour)
        final jan15 = DateTime(2026, 1, 15, 10);

        final task1 = createTask(
          id: 'task-1',
          categoryId: 'cat-work',
          dateFrom: jan15,
        );

        final entry1 = createJournalEntry(
          id: 'entry-1',
          categoryId: null,
          dateFrom: jan15,
          dateTo: jan15.add(const Duration(hours: 1)),
        );

        final link1 = createLink(fromId: 'task-1', toId: 'entry-1');

        when(
          () => mockDb.sortedCalendarEntries(
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        ).thenAnswer((_) async => [entry1]);

        when(() => mockDb.linksForEntryIds(any()))
            .thenAnswer((_) async => [link1]);

        when(() => mockDb.getJournalEntitiesForIds(any()))
            .thenAnswer((_) async => [task1]);

        // Initial load
        await container.read(timeHistoryHeaderControllerProvider.future);

        final initialResult =
            container.read(timeHistoryHeaderControllerProvider).value!;
        expect(initialResult.maxDailyTotal, equals(const Duration(hours: 1)));

        // Initial heights: cat-work starts at 0, goes to 1.0 (60/60 = 1.0)
        final jan15Noon = DateTime(2026, 1, 15, 12);
        final initialHeights = initialResult.stackedHeights[jan15Noon];
        expect(initialHeights, isNotNull);
        expect(initialHeights!['cat-work'], equals(0.0));
        // cat-personal starts after cat-work: 60/60 = 1.0
        expect(initialHeights['cat-personal'], closeTo(1.0, 0.01));

        // Now load more with higher max (5 hours in cat-work)
        // With clock at Jan 15, loadMore fetches Dec 3-16, so use Dec 10
        final olderDate = DateTime(2025, 12, 10, 10);

        final task2 = createTask(
          id: 'task-2',
          categoryId: 'cat-work',
          dateFrom: olderDate,
        );

        final bigEntry = createJournalEntry(
          id: 'entry-big',
          categoryId: null,
          dateFrom: olderDate,
          dateTo: olderDate.add(const Duration(hours: 5)),
        );

        final link2 = createLink(fromId: 'task-2', toId: 'entry-big');

        when(
          () => mockDb.sortedCalendarEntries(
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        ).thenAnswer((_) async => [bigEntry]);

        when(() => mockDb.linksForEntryIds(any()))
            .thenAnswer((_) async => [link2]);

        when(() => mockDb.getJournalEntitiesForIds(any()))
            .thenAnswer((_) async => [task2]);

        final notifier =
            container.read(timeHistoryHeaderControllerProvider.notifier);
        await notifier.loadMoreDays();

        final afterMerge =
            container.read(timeHistoryHeaderControllerProvider).value!;

        // Max should have increased
        expect(afterMerge.maxDailyTotal, equals(const Duration(hours: 5)));

        // Stacked heights for Jan 15 should be rescaled
        // With 1 hour out of 5 hours max, cat-personal now starts at 60/300 = 0.2
        final rescaledHeights = afterMerge.stackedHeights[jan15Noon];
        expect(rescaledHeights, isNotNull);
        expect(rescaledHeights!['cat-work'], equals(0.0)); // Still starts at 0
        // cat-personal now starts at 60/300 = 0.2 (was 1.0 before rescale)
        expect(rescaledHeights['cat-personal'], closeTo(0.2, 0.01));
      });
    });

    test('sliding window drops newest days when cap is reached', () async {
      await withClock(fixedClock, () async {
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
        final initialResult =
            await container.read(timeHistoryHeaderControllerProvider.future);
        final initialLatest = initialResult.latestDay;

        final notifier =
            container.read(timeHistoryHeaderControllerProvider.notifier);

        // Load enough to exceed cap (180 days)
        // Initial: 30, then 14 per load, need ~11 loads to exceed
        for (var i = 0; i < 15; i++) {
          await notifier.loadMoreDays();
        }

        final afterCap =
            container.read(timeHistoryHeaderControllerProvider).value!;

        // Should be capped at 180 days
        expect(afterCap.days.length, lessThanOrEqualTo(180));

        // Latest day should have moved back (newest dropped)
        // The newest days are at the front, so latestDay (first in list) changes
        expect(
          afterCap.latestDay.isBefore(initialLatest) ||
              afterCap.latestDay.isAtSameMomentAs(initialLatest),
          isTrue,
          reason: 'Sliding window should drop newest days',
        );

        // Earliest day should have moved further back (we loaded more history)
        expect(
          afterCap.earliestDay.isBefore(initialResult.earliestDay),
          isTrue,
          reason: 'Should have loaded older history',
        );
      });
    });

    test('canLoadMore stays true for infinite scroll (gaps allowed)', () async {
      await withClock(fixedClock, () async {
        // Infinite scroll should not stop on gaps - sliding window handles memory
        when(
          () => mockDb.sortedCalendarEntries(
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        ).thenAnswer((_) async => []); // No entries, but days still generated

        when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);

        when(() => mockDb.getJournalEntitiesForIds(any()))
            .thenAnswer((_) async => []);

        // Initial load
        await container.read(timeHistoryHeaderControllerProvider.future);

        final notifier =
            container.read(timeHistoryHeaderControllerProvider.notifier);

        // Load more several times
        for (var i = 0; i < 5; i++) {
          await notifier.loadMoreDays();
        }

        final result =
            container.read(timeHistoryHeaderControllerProvider).value!;

        // canLoadMore should stay true for infinite scroll
        expect(result.canLoadMore, isTrue);
      });
    });

    test('resetToToday restores initial view after scrolling far back',
        () async {
      await withClock(fixedClock, () async {
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
        final initialResult =
            await container.read(timeHistoryHeaderControllerProvider.future);
        final initialLatest = initialResult.latestDay;

        final notifier =
            container.read(timeHistoryHeaderControllerProvider.notifier);

        // Load more several times
        for (var i = 0; i < 5; i++) {
          await notifier.loadMoreDays();
        }

        // Now reset to today
        await notifier.resetToToday();

        final afterReset =
            container.read(timeHistoryHeaderControllerProvider).value!;

        // Should have same latest day as initial (today)
        expect(afterReset.latestDay, equals(initialLatest));
        expect(afterReset.days.length, equals(30));
        expect(afterReset.canLoadMore, isTrue);
      });
    });

    test('loadMoreDays handles errors gracefully', () async {
      await withClock(fixedClock, () async {
        var callCount = 0;

        when(
          () => mockDb.sortedCalendarEntries(
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount > 1) {
            throw Exception('Database error');
          }
          return [];
        });

        when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);

        when(() => mockDb.getJournalEntitiesForIds(any()))
            .thenAnswer((_) async => []);

        // Initial load succeeds
        await container.read(timeHistoryHeaderControllerProvider.future);

        final notifier =
            container.read(timeHistoryHeaderControllerProvider.notifier);

        // Load more should fail but not crash
        await notifier.loadMoreDays();

        final result =
            container.read(timeHistoryHeaderControllerProvider).value!;

        // Should still have initial data and isLoadingMore reset to false
        expect(result.days.length, equals(30));
        expect(result.isLoadingMore, isFalse);

        // Error should have been logged
        verify(
          () => mockLoggingService.captureException(
            any<Object>(),
            domain: 'TimeHistoryHeaderController.loadMoreDays',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    test('resetToToday handles errors gracefully', () async {
      await withClock(fixedClock, () async {
        var callCount = 0;

        when(
          () => mockDb.sortedCalendarEntries(
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount > 1) {
            throw Exception('Database error');
          }
          return [];
        });

        when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);

        when(() => mockDb.getJournalEntitiesForIds(any()))
            .thenAnswer((_) async => []);

        // Initial load succeeds
        final initialResult =
            await container.read(timeHistoryHeaderControllerProvider.future);

        final notifier =
            container.read(timeHistoryHeaderControllerProvider.notifier);

        // Reset should fail but restore previous state
        await notifier.resetToToday();

        final result =
            container.read(timeHistoryHeaderControllerProvider).value;

        // Should have restored the previous state
        expect(result, isNotNull);
        expect(result!.days.length, equals(initialResult.days.length));

        // Error should have been logged
        verify(
          () => mockLoggingService.captureException(
            any<Object>(),
            domain: 'TimeHistoryHeaderController.resetToToday',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });
  });
}
