import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../mocks/mocks.dart';
import '../../mocks/sync_config_test_mocks.dart';

const defaultWait = Duration(milliseconds: 100);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JournalPageCubit Tests - ', () {
    var vcMockNext = '1';
    late MockEntitiesCacheService mockEntitiesCacheService;
    late MockUpdateNotifications mockUpdateNotifications;

    setUp(() {
      // Reset getIt and allow reassignment
      getIt
        ..reset()
        ..allowReassignment = true;

      final secureStorageMock = MockSecureStorage();
      final mockSettingsDb = MockSettingsDb();
      final mockJournalDb = MockJournalDb();
      final mockFts5Db = MockFts5Db();
      final mockSyncDatabase = MockSyncDatabase();
      final mockLoggingDb = MockLoggingDb();
      final mockEditorDb = MockEditorDb();
      final mockEditorStateService = MockEditorStateService();
      final mockPersistenceLogic = MockPersistenceLogic();
      final mockOutboxService = MockOutboxService();
      final mockTimeService = MockTimeService();
      final mockVectorClockService = MockVectorClockService();
      mockEntitiesCacheService = MockEntitiesCacheService();
      mockUpdateNotifications = MockUpdateNotifications();

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(() => secureStorageMock.readValue(hostKey))
          .thenAnswer((_) async => 'some_host');

      when(() => secureStorageMock.readValue(nextAvailableCounterKey))
          .thenAnswer((_) async {
        return vcMockNext;
      });

      when(() => secureStorageMock.writeValue(nextAvailableCounterKey, any()))
          .thenAnswer((invocation) async {
        vcMockNext = invocation.positionalArguments[1] as String;
      });

      // Mock SettingsDb to return null for saved settings
      when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);
      when(() => mockSettingsDb.saveSettingsItem(any(), any()))
          .thenAnswer((_) async => 1);

      // Mock JournalDb
      when(() => mockJournalDb.watchConfigFlag(any())).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );
      when(mockJournalDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
      );
      when(mockJournalDb.watchActiveConfigFlagNames).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([<String>{}]),
      );
      when(() => mockJournalDb.getTasks(
            ids: any(named: 'ids'),
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []);
      when(() => mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            categoryIds: any(named: 'categoryIds'),
          )).thenAnswer((_) async => []);

      // Mock Fts5Db
      when(() => mockFts5Db.watchFullTextMatches(any())).thenAnswer(
        (_) => Stream<List<String>>.fromIterable([[]]),
      );

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<SettingsDb>(mockSettingsDb)
        ..registerSingleton<SyncDatabase>(mockSyncDatabase)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<LoggingDb>(mockLoggingDb)
        ..registerSingleton<LoggingService>(LoggingService())
        ..registerSingleton<Fts5Db>(mockFts5Db)
        ..registerSingleton<SecureStorage>(secureStorageMock)
        ..registerSingleton<OutboxService>(mockOutboxService)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<VectorClockService>(mockVectorClockService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<EditorDb>(mockEditorDb)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
    });
    tearDown(getIt.reset);

    Matcher isJournalPageState() {
      return isA<JournalPageState>();
    }

    blocTest<JournalPageCubit, JournalPageState>(
      'toggle starred entries changes state',
      build: () => JournalPageCubit(showTasks: false),
      setUp: () {},
      act: (c) async {
        c.setFilters({DisplayFilter.starredEntriesOnly});
      },
      wait: defaultWait,
      skip: 1, // Skip the initial state emission from flag sanitization
      expect: () => [isJournalPageState()],
      verify: (c) => c.state.filters == {DisplayFilter.starredEntriesOnly},
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'toggle flagged entries changes state',
      build: () => JournalPageCubit(showTasks: false),
      setUp: () {},
      act: (c) async {
        await c.setSearchString('query');
      },
      wait: defaultWait,
      skip: 1,
      expect: () => [isJournalPageState()],
      verify: (c) => c.state.match == 'query',
    );

    test(
        'initializes with unassigned category selected when showTasks=true and no categories exist',
        () async {
      // Mock no categories
      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

      final cubit = JournalPageCubit(showTasks: true);

      // Verify immediately after construction
      expect(cubit.state.selectedCategoryIds, equals(<String>{''}));

      // Wait a bit before closing to avoid async errors
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await cubit.close();
    });

    test('does not initialize with unassigned when showTasks=false', () async {
      // Mock no categories
      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

      final cubit = JournalPageCubit(showTasks: false);

      // Verify state does not have unassigned selected
      expect(cubit.state.selectedCategoryIds, equals(<String>{}));

      // Wait a bit before closing to avoid async errors
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await cubit.close();
    });

    test('does not default to unassigned when categories exist', () async {
      // Mock some categories
      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([
        CategoryDefinition(
          id: 'cat1',
          name: 'Work',
          color: '#FF0000',
          createdAt: DateTime(2024, 1, 1, 10),
          updatedAt: DateTime(2024, 1, 1, 10),
          active: true,
          private: false,
          vectorClock: null,
        ),
      ]);

      final cubit = JournalPageCubit(showTasks: true);

      // Verify state does not have unassigned selected
      expect(cubit.state.selectedCategoryIds, equals(<String>{}));

      // Wait a bit before closing to avoid async errors
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await cubit.close();
    });

    test('query returns unassigned tasks when no categories exist', () async {
      // Mock no categories
      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

      final cubit = JournalPageCubit(showTasks: true);

      // Wait for initialization
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify the state has unassigned selected
      expect(cubit.state.selectedCategoryIds, equals(<String>{''}));

      await cubit.close();
    });

    blocTest<JournalPageCubit, JournalPageState>(
      'toggleSelectedTaskStatus adds and removes task status',
      build: () {
        when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
        return JournalPageCubit(showTasks: true);
      },
      act: (cubit) {
        cubit
          // Add a new status
          ..toggleSelectedTaskStatus('BLOCKED')
          // Remove an existing status
          ..toggleSelectedTaskStatus('OPEN');
      },
      wait: defaultWait,
      skip: 1,
      verify: (cubit) {
        expect(cubit.state.selectedTaskStatuses.contains('BLOCKED'), isTrue);
        expect(cubit.state.selectedTaskStatuses.contains('OPEN'), isFalse);
        expect(cubit.state.selectedTaskStatuses.contains('GROOMED'), isTrue);
        expect(
            cubit.state.selectedTaskStatuses.contains('IN PROGRESS'), isTrue);
      },
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'toggleSelectedCategoryIds adds and removes categories',
      build: () {
        when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
        return JournalPageCubit(showTasks: true);
      },
      act: (cubit) {
        cubit
          ..toggleSelectedCategoryIds('cat1')
          ..toggleSelectedCategoryIds('cat2')
          ..toggleSelectedCategoryIds('cat1'); // Remove cat1
      },
      wait: defaultWait,
      skip: 1,
      verify: (cubit) {
        expect(cubit.state.selectedCategoryIds, equals({'', 'cat2'}));
      },
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'selectedAllCategories clears all selected categories',
      build: () {
        when(() => mockEntitiesCacheService.sortedCategories).thenReturn([
          CategoryDefinition(
            id: 'cat1',
            name: 'Work',
            color: '#FF0000',
            createdAt: DateTime(2024, 1, 1, 10),
            updatedAt: DateTime(2024, 1, 1, 10),
            active: true,
            private: false,
            vectorClock: null,
          ),
        ]);
        return JournalPageCubit(showTasks: true);
      },
      seed: () => JournalPageState(
        match: '',
        tagIds: <String>{},
        filters: {},
        showPrivateEntries: false,
        selectedEntryTypes: const [],
        fullTextMatches: {},
        showTasks: true,
        pagingController: null,
        taskStatuses: const ['OPEN', 'GROOMED', 'IN PROGRESS'],
        selectedTaskStatuses: {'OPEN'},
        selectedCategoryIds: {'cat1', 'cat2'},
      ),
      act: (cubit) => cubit.selectedAllCategories(),
      wait: defaultWait,
      skip: 1,
      verify: (cubit) {
        expect(cubit.state.selectedCategoryIds, isEmpty);
      },
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'toggleSelectedEntryTypes adds and removes entry types',
      build: () {
        when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
        return JournalPageCubit(showTasks: false);
      },
      act: (cubit) {
        cubit
          ..toggleSelectedEntryTypes('Task')
          ..toggleSelectedEntryTypes('JournalEntry');
      },
      wait: defaultWait,
      skip: 1,
      verify: (cubit) {
        expect(cubit.state.selectedEntryTypes.contains('Task'), isFalse);
        expect(
            cubit.state.selectedEntryTypes.contains('JournalEntry'), isFalse);
      },
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'selectSingleEntryType sets only one entry type and preserves it',
      build: () {
        when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
        return JournalPageCubit(showTasks: false);
      },
      act: (cubit) => cubit.selectSingleEntryType('Task'),
      wait: defaultWait,
      skip: 1, // Skip initial sanitization emission
      verify: (cubit) {
        // User's partial selection is now preserved correctly
        expect(cubit.state.selectedEntryTypes, equals(['Task']));
      },
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'selectAllEntryTypes selects all allowed types based on feature flags',
      build: () {
        when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
        return JournalPageCubit(showTasks: false);
      },
      act: (cubit) => cubit.selectAllEntryTypes(),
      wait: defaultWait,
      skip: 1, // Skip initial sanitization emission
      verify: (cubit) {
        // With no feature flags enabled, expects 7 non-feature-gated types
        expect(cubit.state.selectedEntryTypes.length, equals(7));
        expect(cubit.state.selectedEntryTypes.contains('Task'), isTrue);
        expect(cubit.state.selectedEntryTypes.contains('JournalEntry'), isTrue);
      },
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'clearSelectedEntryTypes clears then sanitization restores all allowed types',
      build: () {
        when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
        return JournalPageCubit(showTasks: false);
      },
      act: (cubit) => cubit.clearSelectedEntryTypes(),
      wait: defaultWait,
      skip: 1, // Skip initial sanitization emission
      verify: (cubit) {
        // Empty selection triggers "select all" behavior - restores all 7 allowed types
        expect(cubit.state.selectedEntryTypes.length, equals(7));
      },
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'selectSingleTaskStatus sets only one task status',
      build: () {
        when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
        return JournalPageCubit(showTasks: true);
      },
      act: (cubit) => cubit.selectSingleTaskStatus('DONE'),
      wait: defaultWait,
      skip: 1,
      verify: (cubit) {
        expect(cubit.state.selectedTaskStatuses, equals({'DONE'}));
      },
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'selectAllTaskStatuses selects all task statuses',
      build: () {
        when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
        return JournalPageCubit(showTasks: true);
      },
      act: (cubit) => cubit.selectAllTaskStatuses(),
      wait: defaultWait,
      skip: 1,
      verify: (cubit) {
        expect(
          cubit.state.selectedTaskStatuses,
          equals(cubit.state.taskStatuses.toSet()),
        );
      },
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'clearSelectedTaskStatuses removes all selections',
      build: () {
        when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
        return JournalPageCubit(showTasks: true);
      },
      act: (cubit) => cubit.clearSelectedTaskStatuses(),
      wait: defaultWait,
      skip: 1,
      verify: (cubit) {
        expect(cubit.state.selectedTaskStatuses, isEmpty);
      },
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'setFilters updates display filters',
      build: () {
        when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
        return JournalPageCubit(showTasks: false);
      },
      act: (cubit) => cubit.setFilters({
        DisplayFilter.starredEntriesOnly,
        DisplayFilter.privateEntriesOnly,
      }),
      wait: defaultWait,
      skip: 1,
      verify: (cubit) {
        expect(
          cubit.state.filters,
          equals({
            DisplayFilter.starredEntriesOnly,
            DisplayFilter.privateEntriesOnly,
          }),
        );
      },
    );

    test('updateVisibility refreshes when becoming visible', () async {
      // Track refresh calls
      var refreshCallCount = 0;

      // Mock the getJournalEntities to track calls
      final mockJournalDb = getIt<JournalDb>();
      when(() => mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            categoryIds: any(named: 'categoryIds'),
          )).thenAnswer((_) async {
        refreshCallCount++;
        return [];
      });

      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

      final cubit = JournalPageCubit(showTasks: false);

      // Wait for initialization
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final initialCount = refreshCallCount; // may perform >1 initial fetches

      // First, simulate being invisible
      cubit.updateVisibility(
        const MockVisibilityInfo(visibleBounds: Rect.zero),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Count should remain unchanged (no refresh when invisible)
      expect(refreshCallCount, equals(initialCount));

      // Now simulate becoming visible - this should trigger refreshQuery
      cubit.updateVisibility(
        const MockVisibilityInfo(
          visibleBounds: Rect.fromLTWH(0, 0, 100, 100),
        ),
      );

      // Wait for the refresh to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Should have increased by exactly 1 due to visibility change
      expect(refreshCallCount, equals(initialCount + 1));

      await cubit.close();
    });

    test('does not refresh when staying invisible', () async {
      // Track refresh calls
      var refreshCallCount = 0;

      // Mock the getJournalEntities to track calls
      final mockJournalDb = getIt<JournalDb>();
      when(() => mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            categoryIds: any(named: 'categoryIds'),
          )).thenAnswer((_) async {
        refreshCallCount++;
        return [];
      });

      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

      final cubit = JournalPageCubit(showTasks: false);

      // Wait for initialization
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final initialCount = refreshCallCount;

      // Simulate being invisible
      cubit.updateVisibility(
        const MockVisibilityInfo(visibleBounds: Rect.zero),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Count should still be unchanged
      expect(refreshCallCount, equals(initialCount));

      // Stay invisible - this should NOT trigger refreshQuery
      cubit.updateVisibility(
        const MockVisibilityInfo(visibleBounds: Rect.zero),
      );

      // Wait to ensure no refresh happens
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Should still be unchanged (no refresh while invisible)
      expect(refreshCallCount, equals(initialCount));

      await cubit.close();
    });

    test('intersects selected types with allowed feature-gated types',
        () async {
      // Arrange: enableEvents=true, enableDashboards=false, enableHabits=true
      final mockJournalDb = getIt<JournalDb>();
      when(mockJournalDb.watchActiveConfigFlagNames).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([
          {enableEventsFlag, enableHabitsPageFlag},
        ]),
      );

      // Capture the types passed into getJournalEntities
      List<String>? capturedTypes;
      when(() => mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            categoryIds: any(named: 'categoryIds'),
          )).thenAnswer((invocation) async {
        capturedTypes = invocation.namedArguments[#types] as List<String>;
        return [];
      });

      // Act
      final cubit = JournalPageCubit(showTasks: false);
      // Select all types intentionally
      // ignore: cascade_invocations
      cubit.selectAllEntryTypes(entryTypes);

      // Wait briefly for stream + refresh to propagate
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Assert: 'MeasurementEntry' and 'QuantitativeEntry' are removed when dashboards disabled
      expect(capturedTypes, isNotNull);
      expect(capturedTypes!.contains('MeasurementEntry'), isFalse);
      expect(capturedTypes!.contains('QuantitativeEntry'), isFalse);
      // Assert: 'HabitCompletionEntry' remains when habits enabled
      expect(capturedTypes!.contains('HabitCompletionEntry'), isTrue);
      // Assert: 'JournalEvent' remains when events enabled
      expect(capturedTypes!.contains('JournalEvent'), isTrue);

      await cubit.close();
    });
  });
}

class MockVisibilityInfo extends VisibilityInfo {
  const MockVisibilityInfo({required super.visibleBounds})
      : super(
          key: const Key('test'),
          size: const Size(100, 100),
        );
}

/* TODO: Add these tests once GetIt mock timing is resolved
  // New test group with isolated setup for flag sanitization tests
  group('JournalPageCubit Flag Sanitization Tests - ', () {
    late MockEntitiesCacheService mockEntitiesCacheService;
    late MockUpdateNotifications mockUpdateNotifications;
    var vcMockNext = '1';

    setUp(() {
      getIt
        ..reset()
        ..allowReassignment = true;

      final secureStorageMock = MockSecureStorage();
      final mockSettingsDb = MockSettingsDb();
      final mockJournalDb = MockJournalDb();
      final mockFts5Db = MockFts5Db();
      final mockSyncDatabase = MockSyncDatabase();
      final mockLoggingDb = MockLoggingDb();
      final mockEditorDb = MockEditorDb();
      final mockEditorStateService = MockEditorStateService();
      final mockPersistenceLogic = MockPersistenceLogic();
      final mockOutboxService = MockOutboxService();
      final mockTimeService = MockTimeService();
      final mockVectorClockService = MockVectorClockService();
      mockEntitiesCacheService = MockEntitiesCacheService();
      mockUpdateNotifications = MockUpdateNotifications();

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(() => secureStorageMock.readValue(hostKey))
          .thenAnswer((_) async => 'some_host');
      when(() => secureStorageMock.readValue(nextAvailableCounterKey))
          .thenAnswer((_) async => vcMockNext);
      when(() => secureStorageMock.writeValue(nextAvailableCounterKey, any()))
          .thenAnswer((invocation) async {
        vcMockNext = invocation.positionalArguments[1] as String;
      });

      when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);
      when(() => mockSettingsDb.saveSettingsItem(any(), any()))
          .thenAnswer((_) async => 1);

      when(() => mockJournalDb.watchConfigFlag(any())).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );
      when(mockJournalDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
      );
      // Default: no flags enabled
      when(mockJournalDb.watchActiveConfigFlagNames).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([<String>{}]),
      );
      when(() => mockJournalDb.getTasks(
            ids: any(named: 'ids'),
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => []);
      when(() => mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            categoryIds: any(named: 'categoryIds'),
          )).thenAnswer((_) async => []);

      when(() => mockFts5Db.watchFullTextMatches(any())).thenAnswer(
        (_) => Stream<List<String>>.fromIterable([[]]),
      );

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<SettingsDb>(mockSettingsDb)
        ..registerSingleton<SyncDatabase>(mockSyncDatabase)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<LoggingDb>(mockLoggingDb)
        ..registerSingleton<LoggingService>(LoggingService())
        ..registerSingleton<Fts5Db>(mockFts5Db)
        ..registerSingleton<SecureStorage>(secureStorageMock)
        ..registerSingleton<OutboxService>(mockOutboxService)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<VectorClockService>(mockVectorClockService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<EditorDb>(mockEditorDb)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
    });
    tearDown(getIt.reset);

    test('removes disallowed types when Events flag toggled OFF with partial selection',
        () async {
      final mockJournalDb = getIt<JournalDb>();
      final flagController = StreamController<Set<String>>();

      // Initial: Events enabled
      when(mockJournalDb.watchActiveConfigFlagNames).thenAnswer(
        (_) => flagController.stream,
      );

      when(() => mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            categoryIds: any(named: 'categoryIds'),
          )).thenAnswer((_) async => []);

      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

      final cubit = JournalPageCubit(showTasks: false);

      // Emit initial flags with Events enabled
      flagController.add({enableEventsFlag, enableHabitsPageFlag});
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // User selects partial types: Task, JournalEvent, JournalAudio
      cubit
        ..clearSelectedEntryTypes()
        ..toggleSelectedEntryTypes('Task')
        ..toggleSelectedEntryTypes('JournalEvent')
        ..toggleSelectedEntryTypes('JournalAudio');

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify partial selection
      expect(cubit.state.selectedEntryTypes.contains('Task'), isTrue);
      expect(cubit.state.selectedEntryTypes.contains('JournalEvent'), isTrue);
      expect(cubit.state.selectedEntryTypes.contains('JournalAudio'), isTrue);
      expect(cubit.state.selectedEntryTypes.length, equals(3));

      // Toggle Events flag OFF
      flagController.add({enableHabitsPageFlag});
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Assert: JournalEvent removed, Task and JournalAudio remain
      expect(cubit.state.selectedEntryTypes.contains('JournalEvent'), isFalse);
      expect(cubit.state.selectedEntryTypes.contains('Task'), isTrue);
      expect(cubit.state.selectedEntryTypes.contains('JournalAudio'), isTrue);
      expect(cubit.state.selectedEntryTypes.length, equals(2));

      // Verify persistEntryTypes was called
      final mockSettingsDb = getIt<SettingsDb>();
      verify(() => mockSettingsDb.saveSettingsItem(any(), any())).called(greaterThan(0));

      await flagController.close();
      await cubit.close();
    });

    test('keeps all remaining types selected when flag toggled OFF with full selection',
        () async {
      final mockJournalDb = getIt<JournalDb>();
      final flagController = StreamController<Set<String>>();

      when(mockJournalDb.watchActiveConfigFlagNames).thenAnswer(
        (_) => flagController.stream,
      );

      when(() => mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            categoryIds: any(named: 'categoryIds'),
          )).thenAnswer((_) async => []);

      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

      final cubit = JournalPageCubit(showTasks: false);

      // Initial: All flags enabled
      flagController.add({enableEventsFlag, enableHabitsPageFlag, enableDashboardsPageFlag});
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // User selects all available types
      cubit.selectAllEntryTypes(entryTypes);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final initialCount = cubit.state.selectedEntryTypes.length;
      expect(initialCount, greaterThan(0));
      expect(cubit.state.selectedEntryTypes.contains('JournalEvent'), isTrue);
      expect(cubit.state.selectedEntryTypes.contains('MeasurementEntry'), isTrue);

      // Toggle Dashboards flag OFF (removes MeasurementEntry, QuantitativeEntry)
      flagController.add({enableEventsFlag, enableHabitsPageFlag});
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Assert: User had everything selected, so keep everything that's still allowed
      expect(cubit.state.selectedEntryTypes.contains('MeasurementEntry'), isFalse);
      expect(cubit.state.selectedEntryTypes.contains('QuantitativeEntry'), isFalse);
      expect(cubit.state.selectedEntryTypes.contains('JournalEvent'), isTrue);
      expect(cubit.state.selectedEntryTypes.contains('Task'), isTrue);
      expect(cubit.state.selectedEntryTypes.contains('HabitCompletionEntry'), isTrue);

      // All remaining allowed types should be selected
      expect(cubit.state.selectedEntryTypes.length, equals(initialCount - 2));

      await flagController.close();
      await cubit.close();
    });

    test('selects all available types when flag toggled ON with empty selection',
        () async {
      final mockJournalDb = getIt<JournalDb>();
      final flagController = StreamController<Set<String>>();

      when(mockJournalDb.watchActiveConfigFlagNames).thenAnswer(
        (_) => flagController.stream,
      );

      when(() => mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            categoryIds: any(named: 'categoryIds'),
          )).thenAnswer((_) async => []);

      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

      final cubit = JournalPageCubit(showTasks: false);

      // Initial: No flags enabled, empty selection
      flagController.add(<String>{});
      await Future<void>.delayed(const Duration(milliseconds: 100));

      cubit.clearSelectedEntryTypes();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(cubit.state.selectedEntryTypes, isEmpty);

      // Toggle Events flag ON
      flagController.add({enableEventsFlag});
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Assert: Empty selection means select all newly allowed types
      expect(cubit.state.selectedEntryTypes.isNotEmpty, isTrue);
      expect(cubit.state.selectedEntryTypes.contains('JournalEvent'), isTrue);
      expect(cubit.state.selectedEntryTypes.contains('Task'), isTrue);

      await flagController.close();
      await cubit.close();
    });

    test('handles multiple flags toggling simultaneously',
        () async {
      final mockJournalDb = getIt<JournalDb>();
      final flagController = StreamController<Set<String>>();

      when(mockJournalDb.watchActiveConfigFlagNames).thenAnswer(
        (_) => flagController.stream,
      );

      when(() => mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            categoryIds: any(named: 'categoryIds'),
          )).thenAnswer((_) async => []);

      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

      final cubit = JournalPageCubit(showTasks: false);

      // Initial: All flags enabled
      flagController.add({enableEventsFlag, enableHabitsPageFlag, enableDashboardsPageFlag});
      await Future<void>.delayed(const Duration(milliseconds: 100));

      cubit.selectAllEntryTypes(entryTypes);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(cubit.state.selectedEntryTypes.contains('JournalEvent'), isTrue);
      expect(cubit.state.selectedEntryTypes.contains('HabitCompletionEntry'), isTrue);
      expect(cubit.state.selectedEntryTypes.contains('MeasurementEntry'), isTrue);

      // Multiple flags toggle: Events OFF, Habits ON, Dashboards OFF
      flagController.add({enableHabitsPageFlag});
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Assert: JournalEvent and MeasurementEntry removed
      expect(cubit.state.selectedEntryTypes.contains('JournalEvent'), isFalse);
      expect(cubit.state.selectedEntryTypes.contains('MeasurementEntry'), isFalse);
      expect(cubit.state.selectedEntryTypes.contains('QuantitativeEntry'), isFalse);
      // Assert: HabitCompletionEntry remains
      expect(cubit.state.selectedEntryTypes.contains('HabitCompletionEntry'), isTrue);
      // Assert: Non-gated types remain
      expect(cubit.state.selectedEntryTypes.contains('Task'), isTrue);

      await flagController.close();
      await cubit.close();
    });

    test('persists entry types after flag change',
        () async {
      final mockJournalDb = getIt<JournalDb>();
      final flagController = StreamController<Set<String>>();

      when(mockJournalDb.watchActiveConfigFlagNames).thenAnswer(
        (_) => flagController.stream,
      );

      when(() => mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            categoryIds: any(named: 'categoryIds'),
          )).thenAnswer((_) async => []);

      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

      // Track persistence calls
      final mockSettingsDb = getIt<SettingsDb>();
      var persistCallCount = 0;
      when(() => mockSettingsDb.saveSettingsItem(any(), any()))
          .thenAnswer((_) async {
        persistCallCount++;
        return 1;
      });

      final cubit = JournalPageCubit(showTasks: false);

      // Initial flags
      flagController.add({enableEventsFlag});
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final initialPersistCalls = persistCallCount;

      // Toggle flag
      flagController.add(<String>{});
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Assert: persistEntryTypes was called after flag change
      expect(persistCallCount, greaterThan(initialPersistCalls));

      await flagController.close();
      await cubit.close();
    });
  });
*/
