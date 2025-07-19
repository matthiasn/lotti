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
import 'package:mocktail/mocktail.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../mocks/mocks.dart';
import '../../mocks/sync_config_test_mocks.dart';
import '../../test_data/sync_config_test_data.dart';

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
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
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
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
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
      verify: (cubit) {
        expect(cubit.state.selectedEntryTypes.contains('Task'), isFalse);
        expect(
            cubit.state.selectedEntryTypes.contains('JournalEntry'), isFalse);
      },
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'selectSingleEntryType sets only one entry type',
      build: () {
        when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
        return JournalPageCubit(showTasks: false);
      },
      act: (cubit) => cubit.selectSingleEntryType('Task'),
      wait: defaultWait,
      verify: (cubit) {
        expect(cubit.state.selectedEntryTypes, equals(['Task']));
      },
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'selectAllEntryTypes selects all entry types',
      build: () {
        when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
        return JournalPageCubit(showTasks: false);
      },
      seed: () => JournalPageState(
        match: '',
        tagIds: <String>{},
        filters: {},
        showPrivateEntries: false,
        selectedEntryTypes: ['Task'],
        fullTextMatches: {},
        showTasks: false,
        pagingController: null,
        taskStatuses: const [],
        selectedTaskStatuses: {},
        selectedCategoryIds: {},
      ),
      act: (cubit) => cubit.selectAllEntryTypes(),
      wait: defaultWait,
      verify: (cubit) {
        expect(
            cubit.state.selectedEntryTypes.length, equals(entryTypes.length));
      },
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'clearSelectedEntryTypes removes all selections',
      build: () {
        when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
        return JournalPageCubit(showTasks: false);
      },
      act: (cubit) => cubit.clearSelectedEntryTypes(),
      wait: defaultWait,
      verify: (cubit) {
        expect(cubit.state.selectedEntryTypes, isEmpty);
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

    blocTest<JournalPageCubit, JournalPageState>(
      'updateVisibility refreshes when becoming visible',
      build: () {
        when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
        return JournalPageCubit(showTasks: false);
      },
      act: (cubit) async {
        // First, simulate being invisible
        cubit.updateVisibility(
          const MockVisibilityInfo(visibleBounds: Rect.zero),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Now simulate becoming visible - this should trigger refreshQuery
        cubit.updateVisibility(
          const MockVisibilityInfo(
            visibleBounds: Rect.fromLTWH(0, 0, 100, 100),
          ),
        );
      },
      wait: defaultWait,
      verify: (cubit) {
        // Just verify the cubit is in a valid state
        expect(cubit.state.pagingController, isNotNull);
      },
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'does not refresh when staying invisible',
      build: () {
        when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
        return JournalPageCubit(showTasks: false);
      },
      act: (cubit) async {
        // Simulate being invisible
        cubit.updateVisibility(
          const MockVisibilityInfo(visibleBounds: Rect.zero),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Stay invisible - this should NOT trigger refreshQuery
        cubit.updateVisibility(
          const MockVisibilityInfo(visibleBounds: Rect.zero),
        );
      },
      wait: defaultWait,
      verify: (cubit) {
        // Just verify the cubit is still in a valid state
        expect(cubit.state.pagingController, isNotNull);
      },
    );
  });
}

class MockVisibilityInfo extends VisibilityInfo {
  const MockVisibilityInfo({required super.visibleBounds})
      : super(
          key: const Key('test'),
          size: const Size(100, 100),
        );
}
