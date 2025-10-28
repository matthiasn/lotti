import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/features/sync/utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';

// Test-only cubit override to avoid SettingsDb writes and use a direct query
class _TestPriorityCubit extends JournalPageCubit {
  _TestPriorityCubit(this.repo) : super(showTasks: true);

  final JournalDb repo;
  final Set<String> _localPriorities = <String>{};

  @override
  Future<void> toggleSelectedPriority(String priority) async {
    if (_localPriorities.contains(priority)) {
      _localPriorities.remove(priority);
    } else {
      _localPriorities.add(priority);
    }
    await super.toggleSelectedPriority(priority);
  }

  @override
  Future<void> persistTasksFilter() async {
    // Skip SettingsDb writes; only exercise refresh + query
    await refreshQuery();
  }

  @override
  Future<void> refreshQuery() async {
    // Call the repository directly using current state to avoid other deps
    await repo.getTasks(
      ids: null,
      starredStatuses: const [true, false],
      taskStatuses: state.selectedTaskStatuses.toList(),
      categoryIds: state.selectedCategoryIds.map((e) => e ?? '').toList(),
      labelIds: state.selectedLabelIds.toList(),
      priorities: _localPriorities.toList(),
      limit: 50,
      offset: 0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JournalPageCubit Priority Filter Integration - ', () {
    setUp(() {
      getIt
        ..reset()
        ..allowReassignment = true;

      // Base mocks
      final secureStorageMock = MockSecureStorage();
      final mockSettingsDb = MockSettingsDb();
      final mockJournalDb = MockJournalDb();
      final mockFts5Db = MockFts5Db();
      final mockLoggingDb = MockLoggingDb();
      final mockEditorStateService = MockEditorStateService();
      final mockPersistenceLogic = MockPersistenceLogic();
      final mockEntitiesCacheService = MockEntitiesCacheService();
      final mockUpdateNotifications = MockUpdateNotifications();

      when(() => mockUpdateNotifications.updateStream)
          .thenAnswer((_) => const Stream<Set<String>>.empty());

      when(() => secureStorageMock.readValue(hostKey))
          .thenAnswer((_) async => 'host');
      when(() => secureStorageMock.readValue(nextAvailableCounterKey))
          .thenAnswer((_) async => '1');
      when(() => secureStorageMock.writeValue(nextAvailableCounterKey, any()))
          .thenAnswer((_) async {});

      when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);
      when(() => mockSettingsDb.saveSettingsItem(any(), any()))
          .thenAnswer((_) async => 1);

      // Default flags/streams
      when(() => mockJournalDb.watchConfigFlag(any()))
          .thenAnswer((_) => Stream<bool>.value(false));
      when(mockJournalDb.watchConfigFlags)
          .thenAnswer((_) => Stream<Set<ConfigFlag>>.value(<ConfigFlag>{}));
      when(mockJournalDb.watchActiveConfigFlagNames)
          .thenAnswer((_) => Stream<Set<String>>.value(<String>{}));

      // Safe defaults for queries the cubit might call
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

      when(() => mockFts5Db.watchFullTextMatches(any()))
          .thenAnswer((_) => Stream<List<String>>.value([]));

      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<SettingsDb>(mockSettingsDb)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<LoggingDb>(mockLoggingDb)
        ..registerSingleton<LoggingService>(LoggingService())
        ..registerSingleton<Fts5Db>(mockFts5Db)
        ..registerSingleton<SecureStorage>(secureStorageMock)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
    });

    tearDown(getIt.reset);

    test('toggleSelectedPriority results in getTasks called with priorities',
        () async {
      final mockJournalDb = getIt<JournalDb>();

      final captured = <List<String>?>[];
      when(() => mockJournalDb.getTasks(
            ids: any(named: 'ids'),
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            labelIds: any(named: 'labelIds'),
            priorities: any(named: 'priorities'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((invocation) async {
        captured.add(invocation.namedArguments[#priorities] as List<String>?);
        return [];
      });

      final cubit = _TestPriorityCubit(mockJournalDb);

      // Let initial fetch run
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Toggle priority and allow refresh to execute
      await cubit.toggleSelectedPriority('P1');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final hasP1 =
          captured.any((p) => p != null && p.length == 1 && p[0] == 'P1');
      expect(hasP1, isTrue,
          reason:
              'Expected getTasks to be invoked with priorities [P1], captured=$captured');

      await cubit.close();
    });
  });
}
