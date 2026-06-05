import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
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
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockJournalDb mockDb;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockDomainLogger mockDomainLogger;
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
    mockDomainLogger = MockDomainLogger();
    updateStreamController = StreamController<Set<String>>.broadcast();

    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => updateStreamController.stream);

    when(() => mockEntitiesCacheService.sortedCategories).thenReturn([
      createCategory('cat-work', 'Work'),
      createCategory('cat-personal', 'Personal'),
    ]);

    // Default blanket stub for the lean category projection used during
    // time-history aggregation. Individual tests override with the
    // specific id→categoryId map they need.
    when(
      () => mockDb.getCategoryIdsForEntryIds(any()),
    ).thenAnswer((_) async => const <String, String?>{});

    getIt
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<DomainLogger>(mockDomainLogger);

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

        when(
          () => mockDb.getJournalEntitiesForIdsUnordered(any()),
        ).thenAnswer((_) async => []);

        final result = await container.read(
          timeHistoryHeaderControllerProvider.future,
        );

        expect(result.days.length, equals(60));
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

        when(
          () => mockDb.linksForEntryIds(any()),
        ).thenAnswer((_) async => [link]);

        when(
          () => mockDb.getJournalEntitiesForIdsUnordered(any()),
        ).thenAnswer((_) async => [task]);
        when(() => mockDb.getCategoryIdsForEntryIds(any())).thenAnswer(
          (_) async => {'task-1': 'cat-work'},
        );

        final result = await container.read(
          timeHistoryHeaderControllerProvider.future,
        );

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

        when(
          () => mockDb.getJournalEntitiesForIdsUnordered(any()),
        ).thenAnswer((_) async => []);

        final result = await container.read(
          timeHistoryHeaderControllerProvider.future,
        );

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

        when(
          () => mockDb.getJournalEntitiesForIdsUnordered(any()),
        ).thenAnswer((_) async => []);

        final result = await container.read(
          timeHistoryHeaderControllerProvider.future,
        );

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

        when(
          () => mockDb.linksForEntryIds(any()),
        ).thenAnswer((_) async => links);

        when(
          () => mockDb.getJournalEntitiesForIdsUnordered(any()),
        ).thenAnswer((_) async => [task1, task2]);
        when(() => mockDb.getCategoryIdsForEntryIds(any())).thenAnswer(
          (_) async => {'task-1': 'cat-work', 'task-2': 'cat-personal'},
        );

        final result = await container.read(
          timeHistoryHeaderControllerProvider.future,
        );

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

        when(
          () => mockDb.getJournalEntitiesForIdsUnordered(any()),
        ).thenAnswer((_) async => []);

        // Initial load
        await container.read(timeHistoryHeaderControllerProvider.future);

        // Load more
        final notifier = container.read(
          timeHistoryHeaderControllerProvider.notifier,
        );
        await notifier.loadMoreDays();

        final result = container
            .read(timeHistoryHeaderControllerProvider)
            .value!;

        // Initial: 30 past + 30 future = 60 days, plus 14 more = 74 days
        expect(result.days.length, equals(74));
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

        when(
          () => mockDb.getJournalEntitiesForIdsUnordered(any()),
        ).thenAnswer((_) async => []);

        await container.read(timeHistoryHeaderControllerProvider.future);

        final notifier = container.read(
          timeHistoryHeaderControllerProvider.notifier,
        );

        // Start two loads simultaneously and await both deterministically —
        // no zero-duration Timer (fake-time policy). The second call is a
        // no-op because a load is already in flight.
        await Future.wait([
          notifier.loadMoreDays(),
          notifier.loadMoreDays(),
        ]);

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

        when(
          () => mockDb.getJournalEntitiesForIdsUnordered(any()),
        ).thenAnswer((_) async => []);

        final result = await container.read(
          timeHistoryHeaderControllerProvider.future,
        );

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

        when(
          () => mockDb.getJournalEntitiesForIdsUnordered(any()),
        ).thenAnswer((_) async => []);

        final result = await container.read(
          timeHistoryHeaderControllerProvider.future,
        );

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

        when(
          () => mockDb.getJournalEntitiesForIdsUnordered(any()),
        ).thenAnswer((_) async => []);

        final result = await container.read(
          timeHistoryHeaderControllerProvider.future,
        );

        final daySummary = result.days.firstWhere(
          (d) => d.day.day == 15 && d.day.month == 1,
        );

        // Should have captured the early morning entry
        expect(daySummary.total, equals(const Duration(hours: 1)));
      });
    });

    test(
      'recomputes stacked heights when maxDailyTotal increases on merge',
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

          when(
            () => mockDb.linksForEntryIds(any()),
          ).thenAnswer((_) async => [link1]);

          when(
            () => mockDb.getJournalEntitiesForIdsUnordered(any()),
          ).thenAnswer((_) async => [task1]);
          when(() => mockDb.getCategoryIdsForEntryIds(any())).thenAnswer(
            (_) async => {'task-1': 'cat-work'},
          );

          // Initial load
          await container.read(timeHistoryHeaderControllerProvider.future);

          final initialResult = container
              .read(timeHistoryHeaderControllerProvider)
              .value!;
          expect(initialResult.maxDailyTotal, equals(const Duration(hours: 1)));

          // Initial heights: cat-work starts at 0, goes to 1.0 (60/60 = 1.0)
          final jan15Noon = DateTime(2026, 1, 15, 12);
          final initialHeights = initialResult.stackedHeights[jan15Noon];
          expect(initialHeights, isNotNull);
          expect(initialHeights!['cat-work'], equals(0.0));
          // cat-personal starts after cat-work: 60/60 = 1.0
          expect(initialHeights['cat-personal'], closeTo(1.0, 0.01));

          // Now load more with higher max (5 hours in cat-work)
          // With clock at Jan 15 and 30 past days, loadMore fetches Dec 3-16
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

          when(
            () => mockDb.linksForEntryIds(any()),
          ).thenAnswer((_) async => [link2]);

          when(
            () => mockDb.getJournalEntitiesForIdsUnordered(any()),
          ).thenAnswer((_) async => [task2]);
          when(() => mockDb.getCategoryIdsForEntryIds(any())).thenAnswer(
            (_) async => {'task-2': 'cat-work'},
          );

          final notifier = container.read(
            timeHistoryHeaderControllerProvider.notifier,
          );
          await notifier.loadMoreDays();

          final afterMerge = container
              .read(timeHistoryHeaderControllerProvider)
              .value!;

          // Max should have increased
          expect(afterMerge.maxDailyTotal, equals(const Duration(hours: 5)));

          // Stacked heights for Jan 15 should be rescaled
          // With 1 hour out of 5 hours max, cat-personal now starts at 60/300 = 0.2
          final rescaledHeights = afterMerge.stackedHeights[jan15Noon];
          expect(rescaledHeights, isNotNull);
          expect(
            rescaledHeights!['cat-work'],
            equals(0.0),
          ); // Still starts at 0
          // cat-personal now starts at 60/300 = 0.2 (was 1.0 before rescale)
          expect(rescaledHeights['cat-personal'], closeTo(0.2, 0.01));
        });
      },
    );

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

        when(
          () => mockDb.getJournalEntitiesForIdsUnordered(any()),
        ).thenAnswer((_) async => []);

        // Initial load
        await container.read(timeHistoryHeaderControllerProvider.future);

        final notifier = container.read(
          timeHistoryHeaderControllerProvider.notifier,
        );

        // Load more several times
        for (var i = 0; i < 5; i++) {
          await notifier.loadMoreDays();
        }

        final result = container
            .read(timeHistoryHeaderControllerProvider)
            .value!;

        // canLoadMore should stay true for infinite scroll
        expect(result.canLoadMore, isTrue);
      });
    });

    test(
      'resetToToday restores initial view after scrolling far back',
      () async {
        await withClock(fixedClock, () async {
          when(
            () => mockDb.sortedCalendarEntries(
              rangeStart: any(named: 'rangeStart'),
              rangeEnd: any(named: 'rangeEnd'),
            ),
          ).thenAnswer((_) async => []);

          when(
            () => mockDb.linksForEntryIds(any()),
          ).thenAnswer((_) async => []);

          when(
            () => mockDb.getJournalEntitiesForIdsUnordered(any()),
          ).thenAnswer((_) async => []);

          // Initial load
          final initialResult = await container.read(
            timeHistoryHeaderControllerProvider.future,
          );
          final initialLatest = initialResult.latestDay;

          final notifier = container.read(
            timeHistoryHeaderControllerProvider.notifier,
          );

          // Load more several times
          for (var i = 0; i < 5; i++) {
            await notifier.loadMoreDays();
          }

          // Now reset to today
          await notifier.resetToToday();

          final afterReset = container
              .read(timeHistoryHeaderControllerProvider)
              .value!;

          // Should have same latest day as initial (today)
          expect(afterReset.latestDay, equals(initialLatest));
          expect(afterReset.days.length, equals(60));
          expect(afterReset.canLoadMore, isTrue);
        });
      },
    );

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

        when(
          () => mockDb.getJournalEntitiesForIdsUnordered(any()),
        ).thenAnswer((_) async => []);

        // Initial load succeeds
        await container.read(timeHistoryHeaderControllerProvider.future);

        final notifier = container.read(
          timeHistoryHeaderControllerProvider.notifier,
        );

        // Load more should fail but not crash
        await notifier.loadMoreDays();

        final result = container
            .read(timeHistoryHeaderControllerProvider)
            .value!;

        // Should still have initial data and isLoadingMore reset to false
        expect(result.days.length, equals(60));
        expect(result.isLoadingMore, isFalse);

        // Error should have been logged
        verify(
          () => mockDomainLogger.error(
            LogDomain.calendar,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'TimeHistoryHeaderController.loadMoreDays',
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

        when(
          () => mockDb.getJournalEntitiesForIdsUnordered(any()),
        ).thenAnswer((_) async => []);

        // Initial load succeeds
        final initialResult = await container.read(
          timeHistoryHeaderControllerProvider.future,
        );

        final notifier = container.read(
          timeHistoryHeaderControllerProvider.notifier,
        );

        // Reset should fail but restore previous state
        await notifier.resetToToday();

        final result = container
            .read(timeHistoryHeaderControllerProvider)
            .value;

        // Should have restored the previous state
        expect(result, isNotNull);
        expect(result!.days.length, equals(initialResult.days.length));

        // Error should have been logged
        verify(
          () => mockDomainLogger.error(
            LogDomain.calendar,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'TimeHistoryHeaderController.resetToToday',
          ),
        ).called(1);
      });
    });
  });

  // DST boundary tests verify that calendar arithmetic produces correct unique days
  // regardless of timezone. The calendar arithmetic approach (DateTime(y, m, d - n))
  // and UTC-based day counting are inherently DST-safe because they operate on
  // date components, not durations.
  //
  // These tests verify the controller produces correct calendar days. The separate
  // "Timezone-explicit DST verification" group below uses the timezone package
  // to prove that Duration-based math fails across DST transitions while our
  // calendar arithmetic and UTC-based approaches succeed.
  group('DST boundary tests', () {
    late ProviderContainer container;
    late MockJournalDb mockDb;
    late MockUpdateNotifications mockUpdateNotifications;
    late MockEntitiesCacheService mockEntitiesCacheService;
    late MockDomainLogger mockDomainLogger;
    late StreamController<Set<String>> updateStreamController;

    setUp(() {
      mockDb = MockJournalDb();
      mockUpdateNotifications = MockUpdateNotifications();
      mockEntitiesCacheService = MockEntitiesCacheService();
      mockDomainLogger = MockDomainLogger();
      updateStreamController = StreamController<Set<String>>.broadcast();

      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => updateStreamController.stream);

      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

      getIt
        ..registerSingleton<JournalDb>(mockDb)
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<DomainLogger>(mockDomainLogger);

      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
      updateStreamController.close();
      getIt.reset();
    });

    test(
      'generates correct days across US DST spring forward (March 8, 2026)',
      () async {
        // US DST spring forward: clocks jump 2:00 AM -> 3:00 AM on March 8, 2026
        // Testing from March 10 to ensure the DST day (March 8) is within range.
        // With 30 days back from March 10, we cover Feb 9 - March 10, including
        // the March 8 DST transition.
        final dstDay = DateTime(2026, 3, 10, 12);
        final fixedClock = Clock.fixed(dstDay);

        await withClock(fixedClock, () async {
          when(
            () => mockDb.sortedCalendarEntries(
              rangeStart: any(named: 'rangeStart'),
              rangeEnd: any(named: 'rangeEnd'),
            ),
          ).thenAnswer((_) async => []);

          when(
            () => mockDb.linksForEntryIds(any()),
          ).thenAnswer((_) async => []);

          when(
            () => mockDb.getJournalEntitiesForIdsUnordered(any()),
          ).thenAnswer((_) async => []);

          final result = await container.read(
            timeHistoryHeaderControllerProvider.future,
          );

          // Should have exactly 30 unique days
          expect(result.days.length, equals(60));

          // Extract day numbers to verify uniqueness
          final dayDates = result.days.map(
            (d) => DateTime(d.day.year, d.day.month, d.day.day),
          );
          final uniqueDates = dayDates.toSet();
          expect(
            uniqueDates.length,
            equals(60),
            reason: 'All 60 days should be unique (no duplicates from DST)',
          );

          // Verify March 8 (DST day) is present exactly once
          final march8Count = result.days
              .where((d) => d.day.month == 3 && d.day.day == 8)
              .length;
          expect(
            march8Count,
            equals(1),
            reason:
                'March 8 (DST spring forward day) should appear exactly once',
          );

          // Verify all days are at noon
          for (final day in result.days) {
            expect(
              day.day.hour,
              equals(12),
              reason: 'All days should be at noon',
            );
          }
        });
      },
    );

    test(
      'generates correct days across US DST fall back (November 1, 2026)',
      () async {
        // US DST fall back: clocks fall 2:00 AM -> 1:00 AM on November 1, 2026
        // Testing from November 3 to ensure the DST day (November 1) is within range.
        final dstDay = DateTime(2026, 11, 3, 12);
        final fixedClock = Clock.fixed(dstDay);

        await withClock(fixedClock, () async {
          when(
            () => mockDb.sortedCalendarEntries(
              rangeStart: any(named: 'rangeStart'),
              rangeEnd: any(named: 'rangeEnd'),
            ),
          ).thenAnswer((_) async => []);

          when(
            () => mockDb.linksForEntryIds(any()),
          ).thenAnswer((_) async => []);

          when(
            () => mockDb.getJournalEntitiesForIdsUnordered(any()),
          ).thenAnswer((_) async => []);

          final result = await container.read(
            timeHistoryHeaderControllerProvider.future,
          );

          // Should have exactly 30 unique days
          expect(result.days.length, equals(60));

          // Extract day numbers to verify uniqueness
          final dayDates = result.days.map(
            (d) => DateTime(d.day.year, d.day.month, d.day.day),
          );
          final uniqueDates = dayDates.toSet();
          expect(
            uniqueDates.length,
            equals(60),
            reason: 'All 60 days should be unique (no duplicates from DST)',
          );

          // Verify November 1 (DST day) is present exactly once
          final nov1Count = result.days
              .where((d) => d.day.month == 11 && d.day.day == 1)
              .length;
          expect(
            nov1Count,
            equals(1),
            reason: 'November 1 (DST fall back day) should appear exactly once',
          );

          // Verify all days are at noon
          for (final day in result.days) {
            expect(
              day.day.hour,
              equals(12),
              reason: 'All days should be at noon',
            );
          }
        });
      },
    );

    test(
      'loadMoreDays produces exact day count near US DST transition',
      () async {
        // Test that loadMoreDays produces exactly 44 days (30 initial + 14 more)
        // even when crossing US DST boundary.
        final dstDay = DateTime(2026, 3, 10, 12);
        final fixedClock = Clock.fixed(dstDay);

        await withClock(fixedClock, () async {
          when(
            () => mockDb.sortedCalendarEntries(
              rangeStart: any(named: 'rangeStart'),
              rangeEnd: any(named: 'rangeEnd'),
            ),
          ).thenAnswer((_) async => []);

          when(
            () => mockDb.linksForEntryIds(any()),
          ).thenAnswer((_) async => []);

          when(
            () => mockDb.getJournalEntitiesForIdsUnordered(any()),
          ).thenAnswer((_) async => []);

          // Initial load
          await container.read(timeHistoryHeaderControllerProvider.future);

          // Load more days
          final notifier = container.read(
            timeHistoryHeaderControllerProvider.notifier,
          );
          await notifier.loadMoreDays();

          final result = container
              .read(timeHistoryHeaderControllerProvider)
              .value!;

          // Should have exactly 74 unique days (60 initial + 14 more)
          expect(result.days.length, equals(74));

          // Verify all days are unique
          final dayDates = result.days.map(
            (d) => DateTime(d.day.year, d.day.month, d.day.day),
          );
          final uniqueDates = dayDates.toSet();
          expect(
            uniqueDates.length,
            equals(74),
            reason: 'All 74 days should be unique after loadMoreDays',
          );

          // Verify days are properly ordered (newest to oldest)
          for (var i = 0; i < result.days.length - 1; i++) {
            expect(
              result.days[i].day.isAfter(result.days[i + 1].day),
              isTrue,
              reason: 'Days should be sorted newest to oldest',
            );
          }
        });
      },
    );

    test(
      'generates correct days across EU DST spring forward (March 29, 2026)',
      () async {
        // EU DST spring forward: clocks jump 2:00 AM -> 3:00 AM on last Sunday
        // in March (March 29, 2026).
        // Testing from March 31 to ensure the DST day is within range.
        final dstDay = DateTime(2026, 3, 31, 12);
        final fixedClock = Clock.fixed(dstDay);

        await withClock(fixedClock, () async {
          when(
            () => mockDb.sortedCalendarEntries(
              rangeStart: any(named: 'rangeStart'),
              rangeEnd: any(named: 'rangeEnd'),
            ),
          ).thenAnswer((_) async => []);

          when(
            () => mockDb.linksForEntryIds(any()),
          ).thenAnswer((_) async => []);

          when(
            () => mockDb.getJournalEntitiesForIdsUnordered(any()),
          ).thenAnswer((_) async => []);

          final result = await container.read(
            timeHistoryHeaderControllerProvider.future,
          );

          // Should have exactly 30 unique days
          expect(result.days.length, equals(60));

          // Extract day numbers to verify uniqueness
          final dayDates = result.days.map(
            (d) => DateTime(d.day.year, d.day.month, d.day.day),
          );
          final uniqueDates = dayDates.toSet();
          expect(
            uniqueDates.length,
            equals(60),
            reason: 'All 60 days should be unique (no duplicates from EU DST)',
          );

          // Verify March 29 (EU DST day) is present exactly once
          final march29Count = result.days
              .where((d) => d.day.month == 3 && d.day.day == 29)
              .length;
          expect(
            march29Count,
            equals(1),
            reason:
                'March 29 (EU DST spring forward day) should appear exactly once',
          );

          // Verify all days are at noon
          for (final day in result.days) {
            expect(
              day.day.hour,
              equals(12),
              reason: 'All days should be at noon',
            );
          }
        });
      },
    );

    test(
      'generates correct days across EU DST fall back (October 25, 2026)',
      () async {
        // EU DST fall back: clocks fall 3:00 AM -> 2:00 AM on last Sunday
        // in October (October 25, 2026).
        // Testing from October 27 to ensure the DST day is within range.
        final dstDay = DateTime(2026, 10, 27, 12);
        final fixedClock = Clock.fixed(dstDay);

        await withClock(fixedClock, () async {
          when(
            () => mockDb.sortedCalendarEntries(
              rangeStart: any(named: 'rangeStart'),
              rangeEnd: any(named: 'rangeEnd'),
            ),
          ).thenAnswer((_) async => []);

          when(
            () => mockDb.linksForEntryIds(any()),
          ).thenAnswer((_) async => []);

          when(
            () => mockDb.getJournalEntitiesForIdsUnordered(any()),
          ).thenAnswer((_) async => []);

          final result = await container.read(
            timeHistoryHeaderControllerProvider.future,
          );

          // Should have exactly 30 unique days
          expect(result.days.length, equals(60));

          // Extract day numbers to verify uniqueness
          final dayDates = result.days.map(
            (d) => DateTime(d.day.year, d.day.month, d.day.day),
          );
          final uniqueDates = dayDates.toSet();
          expect(
            uniqueDates.length,
            equals(60),
            reason: 'All 60 days should be unique (no duplicates from EU DST)',
          );

          // Verify October 25 (EU DST day) is present exactly once
          final oct25Count = result.days
              .where((d) => d.day.month == 10 && d.day.day == 25)
              .length;
          expect(
            oct25Count,
            equals(1),
            reason:
                'October 25 (EU DST fall back day) should appear exactly once',
          );

          // Verify all days are at noon
          for (final day in result.days) {
            expect(
              day.day.hour,
              equals(12),
              reason: 'All days should be at noon',
            );
          }
        });
      },
    );
  });

  // Timezone-explicit tests that don't depend on system TZ environment variable.
  // These use the timezone package to verify DST behavior directly.
  group('Timezone-explicit DST verification', () {
    setUpAll(tz.initializeTimeZones);

    test(
      'Duration subtraction gives wrong day count across US DST spring forward',
      () {
        // US Eastern: March 8, 2026 springs forward (loses 1 hour)
        final eastern = tz.getLocation('America/New_York');

        // March 10 at noon Eastern
        final march10 = tz.TZDateTime(eastern, 2026, 3, 10, 12);
        // March 2 at noon Eastern (8 days earlier, crossing DST)
        final march2 = tz.TZDateTime(eastern, 2026, 3, 2, 12);

        // Duration between them: should be 8 calendar days
        final duration = march10.difference(march2);

        // Because March 8 only has 23 hours, Duration gives < 8 days worth of hours
        // 8 days = 192 hours normally, but with DST it's 191 hours
        expect(duration.inHours, equals(191)); // Not 192!
        expect(duration.inDays, equals(7)); // Wrong! Should be 8 calendar days

        // Calendar arithmetic gives correct answer
        final calendarDays =
            march10.day -
            march2.day +
            (march10.month - march2.month) * 31; // Simplified for same month
        expect(calendarDays, equals(8)); // Correct!

        // UTC-based calculation also gives correct answer
        final march10Utc = DateTime.utc(2026, 3, 10);
        final march2Utc = DateTime.utc(2026, 3, 2);
        expect(march10Utc.difference(march2Utc).inDays, equals(8)); // Correct!
      },
    );

    test(
      'Duration subtraction gives wrong day count across EU DST spring forward',
      () {
        // EU Berlin: March 29, 2026 springs forward (loses 1 hour)
        final berlin = tz.getLocation('Europe/Berlin');

        // March 31 at noon Berlin
        final march31 = tz.TZDateTime(berlin, 2026, 3, 31, 12);
        // March 27 at noon Berlin (4 days earlier, crossing DST)
        final march27 = tz.TZDateTime(berlin, 2026, 3, 27, 12);

        // Duration between them: should be 4 calendar days
        final duration = march31.difference(march27);

        // Because March 29 only has 23 hours, Duration gives < 4 days worth of hours
        // 4 days = 96 hours normally, but with DST it's 95 hours
        expect(duration.inHours, equals(95)); // Not 96!
        expect(duration.inDays, equals(3)); // Wrong! Should be 4 calendar days

        // UTC-based calculation gives correct answer
        final march31Utc = DateTime.utc(2026, 3, 31);
        final march27Utc = DateTime.utc(2026, 3, 27);
        expect(march31Utc.difference(march27Utc).inDays, equals(4)); // Correct!
      },
    );

    test(
      'Duration subtraction gives wrong day count across US DST fall back',
      () {
        // US Eastern: November 1, 2026 falls back (gains 1 hour)
        final eastern = tz.getLocation('America/New_York');

        // November 3 at noon Eastern
        final nov3 = tz.TZDateTime(eastern, 2026, 11, 3, 12);
        // October 31 at noon Eastern (3 days earlier, crossing DST)
        final oct31 = tz.TZDateTime(eastern, 2026, 10, 31, 12);

        // Duration between them: should be 3 calendar days
        final duration = nov3.difference(oct31);

        // Because November 1 has 25 hours, Duration gives > 3 days worth of hours
        // 3 days = 72 hours normally, but with DST it's 73 hours
        expect(duration.inHours, equals(73)); // Not 72!
        // inDays truncates, so this still gives 3, but the hours are wrong
        expect(
          duration.inDays,
          equals(3),
        ); // Happens to be correct due to truncation

        // UTC-based calculation is always correct
        final nov3Utc = DateTime.utc(2026, 11, 3);
        final oct31Utc = DateTime.utc(2026, 10, 31);
        expect(nov3Utc.difference(oct31Utc).inDays, equals(3)); // Correct!
      },
    );

    test('Calendar arithmetic generates correct days regardless of DST', () {
      // This is the pattern used in the controller
      // DateTime(year, month, day - n, 12) uses calendar arithmetic

      // Generate 10 days back from March 31, 2026 (crossing EU DST on March 29)
      final days = List<DateTime>.generate(
        10,
        (i) => DateTime(2026, 3, 31 - i, 12),
      );

      // Should get exactly 10 unique calendar dates
      expect(days.length, equals(10));

      // Verify all dates are unique and at noon
      final uniqueDates = days
          .map((d) => '${d.year}-${d.month}-${d.day}')
          .toSet();
      expect(uniqueDates.length, equals(10));

      // Verify March 29 (EU DST) is present exactly once
      final march29Count = days
          .where((d) => d.month == 3 && d.day == 29)
          .length;
      expect(march29Count, equals(1));

      // Verify all are at noon
      for (final day in days) {
        expect(day.hour, equals(12));
      }
    });

    test('UTC day count calculation is DST-safe', () {
      // This is the pattern used in _aggregateEntries for dayCount

      // Count days from March 2 to March 31, 2026 (crossing both US and EU DST)
      final startUtc = DateTime.utc(2026, 3, 2);
      final endUtc = DateTime.utc(2026, 3, 31);

      final dayCount = endUtc.difference(startUtc).inDays + 1;

      // Should be exactly 30 days (March 2-31 inclusive)
      expect(dayCount, equals(30));

      // Verify by counting manually
      var manualCount = 0;
      for (var d = 2; d <= 31; d++) {
        manualCount++;
      }
      expect(dayCount, equals(manualCount));
    });
  });

  // ---------------------------------------------------------------------------
  // Notification-driven refresh tests (lines 106-107, 112-113, 117, 121-131,
  // 136): covers the _listenToUpdates → _refresh path.
  // ---------------------------------------------------------------------------
  group('notification-driven refresh', () {
    // Each test creates its own ProviderContainer INSIDE fakeAsync so that
    // Riverpod's scheduler Timers and RxDart's throttle Timer are all
    // registered in the fake-async zone.  flushMicrotasks() settles async
    // Futures; elapse(6s) fires the 5-second throttleTime window timer.

    test(
      '_refresh updates state when relevant notification arrives after throttle',
      () {
        fakeAsync((fa) {
          withClock(fa.getClock(testDate), () {
            // Create container INSIDE fakeAsync so the Riverpod scheduler
            // Timer and the RxDart throttle Timer are both in this zone.
            final c = ProviderContainer();
            var fetchCount = 0;
            when(
              () => mockDb.sortedCalendarEntries(
                rangeStart: any(named: 'rangeStart'),
                rangeEnd: any(named: 'rangeEnd'),
              ),
            ).thenAnswer((_) async {
              fetchCount++;
              return <JournalEntity>[];
            });
            when(
              () => mockDb.linksForEntryIds(any()),
            ).thenAnswer((_) async => []);

            // Use listen() to keep a continuous subscription so that Riverpod
            // does NOT auto-dispose the provider (which would cancel the update
            // subscription and invalidate the throttle timer).
            c.listen(
              timeHistoryHeaderControllerProvider,
              (_, _) {},
              fireImmediately: true,
            );
            fa.flushMicrotasks();
            expect(fetchCount, equals(1));

            // Push a notification with a subscribed ID.  Flush microtasks
            // first to deliver the broadcast event to the throttle transformer
            // (which creates the 5s Timer in this fakeAsync zone), then
            // elapse 6s to fire it.
            updateStreamController.add({textEntryNotification});
            fa
              ..flushMicrotasks() // deliver event → Timer(5s) created
              ..elapse(const Duration(seconds: 6)); // fire the throttle timer
            // Drain the nested async chain from _fetchDataForRange.
            for (var i = 0; i < 30; i++) {
              fa.flushMicrotasks();
            }

            // A second DB fetch should have been triggered by _refresh.
            expect(fetchCount, greaterThanOrEqualTo(2));
            c.dispose();
          });
        });
      },
    );

    test(
      '_refresh is skipped when notification IDs do not intersect subscribed set',
      () {
        fakeAsync((fa) {
          withClock(fa.getClock(testDate), () {
            final c = ProviderContainer();
            var fetchCount = 0;
            when(
              () => mockDb.sortedCalendarEntries(
                rangeStart: any(named: 'rangeStart'),
                rangeEnd: any(named: 'rangeEnd'),
              ),
            ).thenAnswer((_) async {
              fetchCount++;
              return <JournalEntity>[];
            });
            when(
              () => mockDb.linksForEntryIds(any()),
            ).thenAnswer((_) async => []);

            // Keep a listener so the provider is not auto-disposed.
            c.listen(
              timeHistoryHeaderControllerProvider,
              (_, _) {},
              fireImmediately: true,
            );
            fa.flushMicrotasks();
            expect(fetchCount, equals(1));

            // Notification ID is NOT in {textEntry, audio, task}.
            updateStreamController.add({'SOME_OTHER_NOTIFICATION'});
            fa
              ..flushMicrotasks()
              ..elapse(const Duration(seconds: 6))
              ..flushMicrotasks();

            // No additional fetch — _refresh was never invoked.
            expect(fetchCount, equals(1));
            c.dispose();
          });
        });
      },
    );

    test('_refresh is skipped when state has no value (null state)', () {
      fakeAsync((fa) {
        withClock(fa.getClock(testDate), () {
          final c = ProviderContainer();
          // Use a completer so the build future never resolves, leaving the
          // provider in AsyncLoading (state.value == null).
          final buildCompleter = Completer<List<JournalEntity>>();
          when(
            () => mockDb.sortedCalendarEntries(
              rangeStart: any(named: 'rangeStart'),
              rangeEnd: any(named: 'rangeEnd'),
            ),
          ).thenAnswer((_) => buildCompleter.future);
          when(
            () => mockDb.linksForEntryIds(any()),
          ).thenAnswer((_) async => []);

          // Keep a listener so the provider is not auto-disposed while loading.
          c.listen(
            timeHistoryHeaderControllerProvider,
            (_, _) {},
            fireImmediately: true,
          );
          fa.flushMicrotasks();

          final before = c.read(timeHistoryHeaderControllerProvider);
          expect(before.isLoading, isTrue);

          // Emit a notification while state.value == null.
          // _refresh must return early without throwing.
          updateStreamController.add({taskNotification});
          fa
            ..flushMicrotasks()
            ..elapse(const Duration(seconds: 6))
            ..flushMicrotasks();

          // Provider must still be in loading state — no crash.
          final after = c.read(timeHistoryHeaderControllerProvider);
          expect(after.isLoading, isTrue);

          // Resolve the build so the container disposes cleanly.
          buildCompleter.complete([]);
          fa.flushMicrotasks();
          c.dispose();
        });
      });
    });

    test(
      '_refresh is skipped while isLoadingMore is true (line 117)',
      () {
        fakeAsync((fa) {
          withClock(fa.getClock(testDate), () {
            final c = ProviderContainer();
            var fetchCount = 0;
            // Second call blocks via a completer to keep isLoadingMore = true.
            final slowCompleter = Completer<List<JournalEntity>>();
            when(
              () => mockDb.sortedCalendarEntries(
                rangeStart: any(named: 'rangeStart'),
                rangeEnd: any(named: 'rangeEnd'),
              ),
            ).thenAnswer((_) async {
              fetchCount++;
              if (fetchCount == 1) return <JournalEntity>[];
              return slowCompleter.future;
            });
            when(
              () => mockDb.linksForEntryIds(any()),
            ).thenAnswer((_) async => []);

            // Keep a listener so the provider is not auto-disposed.
            c.listen(
              timeHistoryHeaderControllerProvider,
              (_, _) {},
              fireImmediately: true,
            );
            fa.flushMicrotasks();
            expect(fetchCount, equals(1));

            // Kick off loadMoreDays — fetch #2 blocks, isLoadingMore becomes
            // true immediately via copyWith before the await.
            c.read(timeHistoryHeaderControllerProvider.notifier).loadMoreDays();
            fa.flushMicrotasks();

            final duringLoad = c
                .read(timeHistoryHeaderControllerProvider)
                .value!;
            expect(duringLoad.isLoadingMore, isTrue);

            final countSnapshot = fetchCount;

            // Emit a notification — _refresh detects isLoadingMore and bails.
            updateStreamController.add({textEntryNotification});
            fa
              ..flushMicrotasks()
              ..elapse(const Duration(seconds: 6));
            for (var i = 0; i < 10; i++) {
              fa.flushMicrotasks();
            }

            // fetchCount must not have grown from the notification.
            expect(fetchCount, equals(countSnapshot));

            // Resolve the slow future for clean teardown.
            slowCompleter.complete([]);
            fa.flushMicrotasks();
            c.dispose();
          });
        });
      },
    );

    test(
      '_refresh logs error and keeps current state on exception (line 136)',
      () {
        fakeAsync((fa) {
          withClock(fa.getClock(testDate), () {
            final c = ProviderContainer();
            var fetchCount = 0;
            when(
              () => mockDb.sortedCalendarEntries(
                rangeStart: any(named: 'rangeStart'),
                rangeEnd: any(named: 'rangeEnd'),
              ),
            ).thenAnswer((_) async {
              fetchCount++;
              if (fetchCount == 1) return <JournalEntity>[];
              throw Exception('refresh DB error');
            });
            when(
              () => mockDb.linksForEntryIds(any()),
            ).thenAnswer((_) async => []);

            // Keep a listener so the provider is not auto-disposed.
            c.listen(
              timeHistoryHeaderControllerProvider,
              (_, _) {},
              fireImmediately: true,
            );
            fa.flushMicrotasks();
            expect(fetchCount, equals(1));

            final before = c.read(timeHistoryHeaderControllerProvider).value!;
            expect(before.days.length, equals(60));

            // Trigger refresh that throws.
            updateStreamController.add({audioNotification});
            fa
              ..flushMicrotasks()
              ..elapse(const Duration(seconds: 6));
            // Drain the nested async chain.
            for (var i = 0; i < 20; i++) {
              fa.flushMicrotasks();
            }

            // State preserved — data not disrupted by error in refresh.
            final afterError = c
                .read(timeHistoryHeaderControllerProvider)
                .value;
            expect(afterError, isNotNull);
            expect(afterError!.days.length, equals(60));

            // DomainLogger.error must have been called for _refresh.
            verify(
              () => mockDomainLogger.error(
                LogDomain.calendar,
                any<Object>(),
                stackTrace: any<StackTrace>(named: 'stackTrace'),
                subDomain: 'TimeHistoryHeaderController._refresh',
              ),
            ).called(1);
            c.dispose();
          });
        });
      },
    );
  });

  // ---------------------------------------------------------------------------
  // loadMoreDays edge cases: lines 195, 200, 221
  // ---------------------------------------------------------------------------
  group('loadMoreDays — max and empty-list branches', () {
    test(
      'keeps current maxDailyTotal when additional data has a lower max '
      '(line 200 — current max >= additional max branch)',
      () async {
        await withClock(fixedClock, () async {
          // Initial load with a 3-hour entry so maxDailyTotal == 3h.
          final jan15 = DateTime(2026, 1, 15, 10);
          final entry = createJournalEntry(
            id: 'entry-big',
            categoryId: null,
            dateFrom: jan15,
            dateTo: jan15.add(const Duration(hours: 3)),
          );

          var callIndex = 0;
          when(
            () => mockDb.sortedCalendarEntries(
              rangeStart: any(named: 'rangeStart'),
              rangeEnd: any(named: 'rangeEnd'),
            ),
          ).thenAnswer((_) async {
            callIndex++;
            // First call: initial load — return the big entry.
            // Second call (loadMoreDays): return empty list.
            return callIndex == 1 ? [entry] : <JournalEntity>[];
          });
          when(
            () => mockDb.linksForEntryIds(any()),
          ).thenAnswer((_) async => []);

          await container.read(timeHistoryHeaderControllerProvider.future);

          final initialState = container
              .read(timeHistoryHeaderControllerProvider)
              .value!;
          expect(
            initialState.maxDailyTotal,
            equals(const Duration(hours: 3)),
          );

          final notifier = container.read(
            timeHistoryHeaderControllerProvider.notifier,
          );
          await notifier.loadMoreDays();

          final afterLoad = container
              .read(timeHistoryHeaderControllerProvider)
              .value!;

          // Additional data has no entries (max = 0), so the current max (3h)
          // must be preserved.
          expect(
            afterLoad.maxDailyTotal,
            equals(const Duration(hours: 3)),
          );
          // Heights for older days (zero entries) should be merged via the
          // spread path, not via a full recompute.
          expect(afterLoad.days.length, equals(74));
        });
      },
    );
  });

  // ---------------------------------------------------------------------------
  // resetToToday error path without prior value — line 264 (AsyncError branch)
  // ---------------------------------------------------------------------------
  group('resetToToday — AsyncError fallback when no prior value', () {
    test(
      'sets AsyncError when _fetchInitialData throws and previousState has no '
      'value (line 264)',
      () async {
        await withClock(fixedClock, () async {
          when(
            () => mockDb.sortedCalendarEntries(
              rangeStart: any(named: 'rangeStart'),
              rangeEnd: any(named: 'rangeEnd'),
            ),
          ).thenAnswer((_) async => throw Exception('forced failure'));
          when(
            () => mockDb.linksForEntryIds(any()),
          ).thenAnswer((_) async => []);

          // Collect state emissions so we can observe AsyncError without using
          // .future (which throws a StateError when Riverpod disposes during load).
          final states = <AsyncValue<TimeHistoryData>>[];
          container.listen<AsyncValue<TimeHistoryData>>(
            timeHistoryHeaderControllerProvider,
            (previous, next) => states.add(next),
            fireImmediately: true,
          );

          // Wait for the initial build to settle into AsyncError.
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          final stateAfterBuild = container.read(
            timeHistoryHeaderControllerProvider,
          );
          expect(stateAfterBuild.hasError, isTrue);
          expect(stateAfterBuild.hasValue, isFalse);

          // Call resetToToday — previousState has no value, so the catch block
          // must emit AsyncError(e, stackTrace) — line 264.
          final notifier = container.read(
            timeHistoryHeaderControllerProvider.notifier,
          );
          await notifier.resetToToday();

          final afterReset = container.read(
            timeHistoryHeaderControllerProvider,
          );
          expect(afterReset.hasError, isTrue);

          // DomainLogger must have been called for resetToToday.
          verify(
            () => mockDomainLogger.error(
              LogDomain.calendar,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: 'TimeHistoryHeaderController.resetToToday',
            ),
          ).called(greaterThanOrEqualTo(1));
        });
      },
    );
  });
}
