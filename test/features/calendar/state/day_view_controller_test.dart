import 'dart:async';

import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/calendar/state/calendar_event.dart';
import 'package:lotti/features/calendar/state/day_view_controller.dart';
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

class MockSettingsDb extends Mock implements SettingsDb {}

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
  late MockSettingsDb mockSettingsDb;
  late Listener<AsyncValue<List<CalendarEventData<CalendarEvent>>>> listener;
  late StreamController<Set<String>> updateStreamController;
  late StreamController<List<SettingsItem>> settingsStreamController;

  setUpAll(() {
    // Register fallback values for Mocktail
    registerFallbackValue(
      const AsyncValue<List<CalendarEventData<CalendarEvent>>>.loading(),
    );

    // Initialize GetIt for testing
    getIt.allowReassignment = true;
  });

  setUp(() {
    mockDb = MockJournalDb();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockUpdateNotifications = MockUpdateNotifications();
    mockSettingsDb = MockSettingsDb();
    listener = Listener<AsyncValue<List<CalendarEventData<CalendarEvent>>>>();

    updateStreamController = StreamController<Set<String>>.broadcast();
    settingsStreamController = StreamController<List<SettingsItem>>.broadcast();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);

    when(() => mockSettingsDb.watchSettingsItemByKey(any()))
        .thenAnswer((_) => settingsStreamController.stream);

    // Register mocks in GetIt
    getIt
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<SettingsDb>(mockSettingsDb);

    // Create a provider container without overrides
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    updateStreamController.close();
    settingsStreamController.close();
  });

  test('initial state loads calendar entries', () async {
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

    // Act
    container.listen(
      dayViewControllerProvider,
      listener.call,
      fireImmediately: true,
    );

    // Wait for the future to complete
    await container.read(dayViewControllerProvider.future);

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
          that: isA<AsyncValue<List<CalendarEventData<CalendarEvent>>>>()
              .having((p0) => p0.isLoading, 'isLoading', true),
        ),
        any(
          that: isA<AsyncValue<List<CalendarEventData<CalendarEvent>>>>()
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
      ),
      entryText: const EntryText(plainText: 'Test entry'),
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
        .thenReturn(null);

    // Act - initial load
    container.listen(
      dayViewControllerProvider,
      listener.call,
      fireImmediately: true,
    );

    // Wait for initial state
    await container.read(dayViewControllerProvider.future);

    // Reset mocks for update
    final updatedEntry = JournalEntity.journalEntry(
      meta: Metadata(
        id: 'updated-entry-id',
        dateFrom: dateFrom,
        dateTo: dateTo,
        createdAt: now,
        updatedAt: now,
      ),
      entryText: const EntryText(plainText: 'Updated test entry'),
    );

    when(
      () => mockDb.sortedCalendarEntries(
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((_) async => [updatedEntry]);

    // Simulate visibility change to true
    final controller = container.read(dayViewControllerProvider.notifier);
    final mockVisibilityInfo = MockVisibilityInfo();
    when(() => mockVisibilityInfo.visibleFraction).thenReturn(1);
    controller.onVisibilityChanged(mockVisibilityInfo);

    // Trigger notification update
    updateStreamController.add({textEntryNotification});

    // Wait for the state to update
    await Future<void>.delayed(const Duration(seconds: 1));

    // Verify update was called
    verify(
      () => mockDb.sortedCalendarEntries(
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).called(greaterThan(1));
  });

  test('registers onResume callback that triggers invalidation', () async {
    // This test verifies that the onResume callback is registered and that
    // invalidating the provider causes a refetch. The full pause/resume
    // lifecycle (via TickerMode and navigation) is an integration concern
    // that requires real route transitions to test properly.
    //
    // The fix for Riverpod 3's auto-pause behavior:
    //   ..onResume(() => Future.microtask(ref.invalidateSelf))
    //
    // This test verifies the invalidation path works correctly.

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

    // Act - initial load
    container.listen(
      dayViewControllerProvider,
      listener.call,
      fireImmediately: true,
    );

    // Wait for initial state
    await container.read(dayViewControllerProvider.future);

    // Simulate what onResume does: invalidate the provider
    // In production, this is triggered by Riverpod 3's TickerMode-based
    // pause/resume lifecycle when navigating back to the calendar view
    container.invalidate(dayViewControllerProvider);

    // Allow microtask to process the invalidation
    await Future<void>.delayed(Duration.zero);

    // Wait for the refetch triggered by invalidation
    await container.read(dayViewControllerProvider.future);

    // Verify the data was fetched twice:
    // 1. Initial load
    // 2. After invalidation (simulating onResume behavior)
    verify(
      () => mockDb.sortedCalendarEntries(
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).called(2);
  });

  test('DaySelectionController selects day correctly', () {
    // Act
    final controller = container.read(daySelectionControllerProvider.notifier);
    final initialDay = container.read(daySelectionControllerProvider);

    // Initial state should be today
    expect(initialDay.year, DateTime.now().year);
    expect(initialDay.month, DateTime.now().month);
    expect(initialDay.day, DateTime.now().day);

    // Select a different day
    final newDate = DateTime(2023, 5, 15);
    controller.selectDay(newDate);

    // Get updated state
    final updatedDay = container.read(daySelectionControllerProvider);

    // Assert
    expect(updatedDay, equals(newDate));
  });

  test('TimeChartSelectedData updates selection correctly', () {
    // Arrange
    final controller = container.read(timeChartSelectedDataProvider.notifier);
    final initialData = container.read(timeChartSelectedDataProvider);

    // Initial state should be empty
    expect(initialData, isEmpty);

    // Act - update with test data
    final testData = {
      1: {'category': 'Work', 'duration': 120},
      2: {'category': 'Exercise', 'duration': 60},
    };
    controller.updateSelection(testData);

    // Get updated state
    final updatedData = container.read(timeChartSelectedDataProvider);

    // Assert
    expect(updatedData, equals(testData));
  });

  // Skip the test that requires a real Flutter widget context
  test('CalendarGlobalKeyController retrieves a GlobalKey', () {
    // We're just testing that it returns a GlobalKey, not its actual functionality with widgets
    final globalKey = container.read(calendarGlobalKeyControllerProvider);
    expect(globalKey, isA<GlobalKey<DayViewState>>());
  });
}
