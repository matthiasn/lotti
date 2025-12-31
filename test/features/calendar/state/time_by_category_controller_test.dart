import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/calendar/state/time_by_category_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Mock classes
class MockJournalDb extends Mock implements JournalDb {}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockVisibilityInfo extends Mock implements VisibilityInfo {}

// Listener for state changes
class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockJournalDb mockDb;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockUpdateNotifications mockUpdateNotifications;
  late Listener<AsyncValue<Map<DateTime, Map<CategoryDefinition?, Duration>>>>
      listener;
  late StreamController<Set<String>> updateStreamController;

  setUpAll(() {
    // Register fallback values for Mocktail
    registerFallbackValue(
      const AsyncValue<
          Map<DateTime, Map<CategoryDefinition?, Duration>>>.loading(),
    );

    // Initialize GetIt for testing
    getIt.allowReassignment = true;
  });

  setUp(() {
    mockDb = MockJournalDb();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockUpdateNotifications = MockUpdateNotifications();
    listener = Listener<
        AsyncValue<Map<DateTime, Map<CategoryDefinition?, Duration>>>>();

    updateStreamController = StreamController<Set<String>>.broadcast();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);

    // Register mocks in GetIt
    getIt
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);

    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    updateStreamController.close();
  });

  test('initial state loads time by category data', () async {
    // Arrange
    final now = DateTime.now();
    final dateFrom = DateTime(now.year, now.month, now.day);
    final dateTo = dateFrom.add(const Duration(hours: 2));

    final testEntry = JournalEntity.journalEntry(
      meta: Metadata(
        id: 'test-entry-id',
        dateFrom: dateFrom,
        dateTo: dateTo,
        createdAt: now,
        updatedAt: now,
        categoryId: 'test-category-id',
      ),
      entryText: const EntryText(plainText: 'Test entry'),
    );

    final category = CategoryDefinition(
      id: 'test-category-id',
      createdAt: now,
      updatedAt: now,
      name: 'Test Category',
      color: '#FF0000',
      vectorClock: null,
      private: false,
      active: true,
    );

    // Setup mock responses
    when(
      () => mockDb.sortedCalendarEntries(
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((_) async => [testEntry]);

    when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);

    when(() => mockDb.getJournalEntitiesForIds(any()))
        .thenAnswer((_) async => []);

    when(() => mockEntitiesCacheService.getCategoryById(any()))
        .thenReturn(category);

    when(() => mockEntitiesCacheService.sortedCategories)
        .thenReturn([category]);

    // Act
    container.listen(
      timeByCategoryControllerProvider,
      listener.call,
      fireImmediately: true,
    );

    // Wait for the future to complete
    await container.read(timeByCategoryControllerProvider.notifier).future;

    // Assert
    verify(
      () => mockDb.sortedCalendarEntries(
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).called(1);

    verify(
      () => listener.call(
        any(
          that: isA<
                  AsyncValue<
                      Map<DateTime, Map<CategoryDefinition?, Duration>>>>()
              .having((p0) => p0.isLoading, 'isLoading', true),
        ),
        any(
          that: isA<
                  AsyncValue<
                      Map<DateTime, Map<CategoryDefinition?, Duration>>>>()
              .having((p0) => p0.hasValue, 'hasValue', true),
        ),
      ),
    ).called(1);
  });

  test('updates state when relevant update notifications are received',
      () async {
    // Arrange
    final now = DateTime.now();
    final dateFrom = DateTime(now.year, now.month, now.day);
    final dateTo = dateFrom.add(const Duration(hours: 2));

    final testEntry = JournalEntity.journalEntry(
      meta: Metadata(
        id: 'test-entry-id',
        dateFrom: dateFrom,
        dateTo: dateTo,
        createdAt: now,
        updatedAt: now,
        categoryId: 'test-category-id',
      ),
      entryText: const EntryText(plainText: 'Test entry'),
    );

    final category = CategoryDefinition(
      id: 'test-category-id',
      createdAt: now,
      updatedAt: now,
      name: 'Test Category',
      color: '#FF0000',
      vectorClock: null,
      private: false,
      active: true,
    );

    // Setup mock responses for initial load
    when(
      () => mockDb.sortedCalendarEntries(
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((_) async => [testEntry]);

    when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);

    when(() => mockDb.getJournalEntitiesForIds(any()))
        .thenAnswer((_) async => []);

    when(() => mockEntitiesCacheService.getCategoryById(any()))
        .thenReturn(category);

    when(() => mockEntitiesCacheService.sortedCategories)
        .thenReturn([category]);

    // Act - initial load and update under fake time to drive throttling deterministically
    fakeAsync((async) {
      container
        ..listen(
          timeByCategoryControllerProvider,
          listener.call,
          fireImmediately: true,
        )

        // Wait for initial state - trigger the read to start loading
        ..read(timeByCategoryControllerProvider.notifier);

      // Reset mocks for update
      final updatedEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'updated-entry-id',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: now,
          updatedAt: now,
          categoryId: 'test-category-id',
        ),
        entryText: const EntryText(plainText: 'Updated test entry'),
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [updatedEntry]);

      // Simulate visibility change to true (immediate fetch)
      final controller =
          container.read(timeByCategoryControllerProvider.notifier);
      final mockVisibilityInfo = MockVisibilityInfo();
      when(() => mockVisibilityInfo.visibleFraction).thenReturn(1);
      controller.onVisibilityChanged(mockVisibilityInfo);

      // Trigger notification update and advance fake time past throttle window
      updateStreamController.add({textEntryNotification});
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 6))
        ..flushMicrotasks();

      // Verify update was called (initial + visibility + throttled notification)
      verify(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).called(greaterThan(1));
    });
  });

  test('TimeFrameController updates timeSpanDays correctly', () {
    // Arrange
    final controller = container.read(timeFrameControllerProvider.notifier);
    final initialTimeFrame = container.read(timeFrameControllerProvider);

    // Initial value should be 30
    expect(initialTimeFrame, equals(30));

    // Act - change the time frame
    controller.onValueChanged(60);

    // Get updated state
    final updatedTimeFrame = container.read(timeFrameControllerProvider);

    // Assert
    expect(updatedTimeFrame, equals(60));
  });

  test('getDaysAtNoon returns correct dates', () {
    // Arrange
    final today = DateTime.now();
    const rangeDays = 5;

    // Act
    final days = getDaysAtNoon(rangeDays, today);

    // Assert
    expect(days.length, equals(rangeDays));

    // All dates should be at noon
    for (final day in days) {
      expect(day.hour, equals(12));
      expect(day.minute, equals(0));
      expect(day.second, equals(0));
    }

    // Dates should be in reverse order (today first, then past days)
    for (var i = 0; i < days.length - 1; i++) {
      expect(days[i].isAfter(days[i + 1]), isTrue);
    }
  });

  test('timeByDayChart provider transforms time data correctly', () async {
    // Arrange
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);

    final category = CategoryDefinition(
      id: 'test-category-id',
      createdAt: now,
      updatedAt: now,
      name: 'Test Category',
      color: '#FF0000',
      vectorClock: null,
      private: false,
      active: true,
    );

    // Initial setup for the category
    when(() => mockEntitiesCacheService.sortedCategories)
        .thenReturn([category]);

    // Prepare a sample entry that will create the time data we want
    final testEntry = JournalEntity.journalEntry(
      meta: Metadata(
        id: 'test-entry-id',
        dateFrom: today,
        dateTo: today.add(const Duration(hours: 2)),
        createdAt: now,
        updatedAt: now,
        categoryId: 'test-category-id',
      ),
      entryText: const EntryText(plainText: 'Test entry'),
    );

    final uncategorizedEntry = JournalEntity.journalEntry(
      meta: Metadata(
        id: 'uncategorized-id',
        dateFrom: today,
        dateTo: today.add(const Duration(hours: 1)),
        createdAt: now,
        updatedAt: now,
      ),
      entryText: const EntryText(plainText: 'Uncategorized entry'),
    );

    // Setup mock responses to generate time data
    when(
      () => mockDb.sortedCalendarEntries(
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((_) async => [testEntry, uncategorizedEntry]);

    when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);

    when(() => mockDb.getJournalEntitiesForIds(any()))
        .thenAnswer((_) async => []);

    when(() => mockEntitiesCacheService.getCategoryById(any()))
        .thenReturn(category);

    // First, load the time data
    await container.read(timeByCategoryControllerProvider.notifier).future;

    // Act - now read the chart data
    final result = await container.read(timeByDayChartProvider.future);

    // Assert
    expect(result, isNotEmpty);

    // There should be entries for both the category and unassigned
    final categoryEntries = result.where(
      (item) => item.categoryId == 'test-category-id',
    );
    expect(categoryEntries.isNotEmpty, isTrue);

    final unassignedEntries = result.where(
      (item) => item.categoryId == 'unassigned',
    );
    expect(unassignedEntries.isNotEmpty, isTrue);
  });
}
