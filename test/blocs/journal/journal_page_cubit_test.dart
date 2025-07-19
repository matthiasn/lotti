import 'package:bloc_test/bloc_test.dart';
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

import '../../mocks/mocks.dart';
import '../../test_data/sync_config_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mockUpdateNotifications = MockUpdateNotifications();

  group('JournalPageCubit Tests - ', () {
    var vcMockNext = '1';
    late MockEntitiesCacheService mockEntitiesCacheService;

    setUpAll(() {
      final secureStorageMock = MockSecureStorage();
      final settingsDb = SettingsDb(inMemoryDatabase: true);
      final mockTimeService = MockTimeService();
      mockEntitiesCacheService = MockEntitiesCacheService();

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

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<SyncDatabase>(SyncDatabase(inMemoryDatabase: true))
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
        ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
        ..registerSingleton<LoggingService>(LoggingService())
        ..registerSingleton<Fts5Db>(Fts5Db(inMemoryDatabase: true))
        ..registerSingleton<SecureStorage>(secureStorageMock)
        ..registerSingleton<OutboxService>(OutboxService())
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<VectorClockService>(VectorClockService())
        ..registerSingleton<PersistenceLogic>(PersistenceLogic())
        ..registerSingleton<EditorDb>(EditorDb(inMemoryDatabase: true))
        ..registerSingleton<EditorStateService>(EditorStateService())
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
    });
    tearDownAll(getIt.reset);

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
  });
}
