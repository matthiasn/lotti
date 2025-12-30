import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/calendar/state/day_view_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockSettingsDb extends Mock implements SettingsDb {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockJournalDb mockDb;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockSettingsDb mockSettingsDb;
  late StreamController<Set<String>> updateStreamController;
  late StreamController<List<SettingsItem>> settingsStreamController;

  setUpAll(() {
    getIt.allowReassignment = true;
  });

  setUp(() {
    mockDb = MockJournalDb();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockUpdateNotifications = MockUpdateNotifications();
    mockSettingsDb = MockSettingsDb();

    updateStreamController = StreamController<Set<String>>.broadcast();
    settingsStreamController = StreamController<List<SettingsItem>>.broadcast();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);

    when(() => mockSettingsDb.watchSettingsItemByKey(any()))
        .thenAnswer((_) => settingsStreamController.stream);

    getIt
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<SettingsDb>(mockSettingsDb);

    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    updateStreamController.close();
    settingsStreamController.close();
  });

  group('Privacy filtering for calendar events', () {
    test('shows text when category is visible (empty filter = show all)',
        () async {
      // Arrange
      final dateFrom = DateTime(2024, 1, 15, 10);
      final dateTo = dateFrom.add(const Duration(hours: 2));

      final testEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'entry-1',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: dateFrom,
          updatedAt: dateFrom,
          categoryId: 'visible-category',
        ),
        entryText: const EntryText(plainText: 'Test notes'),
      );

      final category = CategoryDefinition(
        id: 'visible-category',
        createdAt: dateFrom,
        updatedAt: dateFrom,
        name: 'Work',
        color: '#FF0000',
        vectorClock: null,
        private: false,
        active: true,
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [testEntry]);

      when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);
      when(() => mockDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => []);
      when(() => mockEntitiesCacheService.getCategoryById('visible-category'))
          .thenReturn(category);
      when(() => mockEntitiesCacheService.getCategoryById(null))
          .thenReturn(null);

      // Act - with empty filter (show all)
      final events = await container.read(dayViewControllerProvider.future);

      // Assert - text should be visible (description is the entry text)
      expect(events, isNotEmpty);
      final event = events.first;
      expect(event.description, contains('Test notes'));
      expect(event.color, isNotNull);
    });

    test('hides text when category is hidden but shows colored box', () async {
      // Arrange
      final dateFrom = DateTime(2024, 1, 15, 10);
      final dateTo = dateFrom.add(const Duration(hours: 2));

      final testEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'entry-1',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: dateFrom,
          updatedAt: dateFrom,
        ),
        entryText: const EntryText(plainText: 'Secret notes'),
      );

      // Create linked task with hidden category
      final linkedTask = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'task-1',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: dateFrom,
          updatedAt: dateFrom,
          categoryId: 'hidden-category',
        ),
        entryText: const EntryText(plainText: 'Task'),
      );

      final category = CategoryDefinition(
        id: 'hidden-category',
        createdAt: dateFrom,
        updatedAt: dateFrom,
        name: 'Secret Client',
        color: '#0000FF',
        vectorClock: null,
        private: false,
        active: true,
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [testEntry]);

      when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => [
            EntryLink.basic(
              id: 'link-1',
              fromId: 'task-1',
              toId: 'entry-1',
              createdAt: dateFrom,
              updatedAt: dateFrom,
              vectorClock: null,
            ),
          ]);
      when(() => mockDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => [linkedTask]);
      when(() => mockEntitiesCacheService.getCategoryById('hidden-category'))
          .thenReturn(category);
      when(() => mockEntitiesCacheService.getCategoryById(null))
          .thenReturn(null);

      // First, trigger the provider to start listening to the stream
      container.listen(
        dayViewControllerProvider,
        (_, __) {},
        fireImmediately: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Now set visibility filter - only 'visible-category' selected
      const filter = TasksFilter(
        selectedCategoryIds: {'visible-category'},
      );
      settingsStreamController.add([
        SettingsItem(
          configKey: 'TASKS_CATEGORY_FILTERS',
          value: jsonEncode(filter),
          updatedAt: DateTime(2024),
        ),
      ]);
      // Wait for stream to propagate and provider to rebuild
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Act - read fresh state after filter change
      final events = await container.read(dayViewControllerProvider.future);

      // Assert - event exists but text is hidden
      expect(events, isNotEmpty);
      final event = events.first;
      // Title should be empty (hidden)
      expect(event.title, isEmpty);
      // Description should be null (hidden)
      expect(event.description, isNull);
      // But color should still be present (colored box visible)
      expect(event.color, isNotNull);
    });

    test('stores categoryId in CalendarEvent for filtering', () async {
      // Arrange
      final dateFrom = DateTime(2024, 1, 15, 10);
      final dateTo = dateFrom.add(const Duration(hours: 2));

      final testEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'entry-1',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: dateFrom,
          updatedAt: dateFrom,
        ),
        entryText: const EntryText(plainText: 'Notes'),
      );

      // Create linked task with categoryId
      final linkedTask = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'task-1',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: dateFrom,
          updatedAt: dateFrom,
          categoryId: 'my-category-id',
        ),
        entryText: const EntryText(plainText: 'Task'),
      );

      final category = CategoryDefinition(
        id: 'my-category-id',
        createdAt: dateFrom,
        updatedAt: dateFrom,
        name: 'My Category',
        color: '#00FF00',
        vectorClock: null,
        private: false,
        active: true,
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [testEntry]);

      when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => [
            EntryLink.basic(
              id: 'link-1',
              fromId: 'task-1',
              toId: 'entry-1',
              createdAt: dateFrom,
              updatedAt: dateFrom,
              vectorClock: null,
            ),
          ]);
      when(() => mockDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => [linkedTask]);
      when(() => mockEntitiesCacheService.getCategoryById('my-category-id'))
          .thenReturn(category);
      when(() => mockEntitiesCacheService.getCategoryById(null))
          .thenReturn(null);

      // Act
      final events = await container.read(dayViewControllerProvider.future);

      // Assert - CalendarEvent should have categoryId from linked entry
      expect(events, isNotEmpty);
      final calendarEvent = events.first.event!;
      expect(calendarEvent.categoryId, equals('my-category-id'));
    });

    test('handles unassigned entries visibility', () async {
      // Arrange
      final dateFrom = DateTime(2024, 1, 15, 10);
      final dateTo = dateFrom.add(const Duration(hours: 2));

      // Entry with no category (unassigned)
      final unassignedEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'unassigned-entry',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: dateFrom,
          updatedAt: dateFrom,
        ),
        entryText: const EntryText(plainText: 'Unassigned notes'),
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [unassignedEntry]);

      when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);
      when(() => mockDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => []);
      when(() => mockEntitiesCacheService.getCategoryById(any()))
          .thenReturn(null);

      // First, trigger the provider to start listening to the stream
      container.listen(
        dayViewControllerProvider,
        (_, __) {},
        fireImmediately: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Set visibility filter - only specific category selected (not unassigned)
      const filter = TasksFilter(
        selectedCategoryIds: {'some-category'},
      );
      settingsStreamController.add([
        SettingsItem(
          configKey: 'TASKS_CATEGORY_FILTERS',
          value: jsonEncode(filter),
          updatedAt: DateTime(2024),
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Act
      final events = await container.read(dayViewControllerProvider.future);

      // Assert - unassigned entry text should be hidden
      expect(events, isNotEmpty);
      final event = events.first;
      expect(event.title, isEmpty);
      expect(event.color, isNotNull); // Color still visible
    });

    test('unassigned entries visible when unassigned marker is selected',
        () async {
      // Arrange
      final dateFrom = DateTime(2024, 1, 15, 10);
      final dateTo = dateFrom.add(const Duration(hours: 2));

      final unassignedEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'unassigned-entry',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: dateFrom,
          updatedAt: dateFrom,
        ),
        entryText: const EntryText(plainText: 'Unassigned notes'),
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [unassignedEntry]);

      when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);
      when(() => mockDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => []);
      when(() => mockEntitiesCacheService.getCategoryById(any()))
          .thenReturn(null);

      // First, trigger the provider to start listening to the stream
      container.listen(
        dayViewControllerProvider,
        (_, __) {},
        fireImmediately: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Set visibility filter - include unassigned marker ''
      const filter = TasksFilter(
        selectedCategoryIds: {'some-category', ''},
      );
      settingsStreamController.add([
        SettingsItem(
          configKey: 'TASKS_CATEGORY_FILTERS',
          value: jsonEncode(filter),
          updatedAt: DateTime(2024),
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Act
      final events = await container.read(dayViewControllerProvider.future);

      // Assert - unassigned entry should have description (the plain text)
      expect(events, isNotEmpty);
      final event = events.first;
      // Description should be visible
      expect(event.description, isNotNull);
      expect(event.color, isNotNull);
    });

    test('WorkoutEntry shows workout type as title and formatted description',
        () async {
      // Arrange
      final dateFrom = DateTime(2024, 1, 15, 10);
      final dateTo = dateFrom.add(const Duration(hours: 2));

      final workoutEntry = JournalEntity.workout(
        meta: Metadata(
          id: 'workout-1',
          dateFrom: dateFrom,
          dateTo: dateTo,
          createdAt: dateFrom,
          updatedAt: dateFrom,
        ),
        data: WorkoutData(
          id: 'workout-data-1',
          dateFrom: dateFrom,
          dateTo: dateTo,
          workoutType: 'Running',
          energy: 500,
          distance: 5000,
          source: 'test',
        ),
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [workoutEntry]);

      when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);
      when(() => mockDb.getJournalEntitiesForIds(any()))
          .thenAnswer((_) async => []);
      when(() => mockEntitiesCacheService.getCategoryById(any()))
          .thenReturn(null);

      // Act - with empty filter (show all)
      final events = await container.read(dayViewControllerProvider.future);

      // Assert - workout entry should show workout type as title
      expect(events, isNotEmpty);
      final event = events.first;
      // Title should contain the workout type
      expect(event.title, contains('Running'));
      // Description should contain workout details (distance, energy)
      expect(event.description, isNotNull);
      // Workout entries have a specific green color (#A8CD66)
      expect(event.color, isNotNull);
    });
  });
}
