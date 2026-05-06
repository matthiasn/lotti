import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

/// Default nav-index values used by [JournalControllerTestSetup]. The
/// controller compares the stream's emitted index against these to
/// decide whether its tab is active.
const int testTasksIndex = 0;
const int testJournalIndex = 5;
const int testOtherIndex = 99;

/// Shared test infrastructure for journal page controller and related tests.
///
/// Creates all mocks, stream controllers, and default stubs. Call [setUp]
/// inside a test `setUp` callback and [tearDown] inside `tearDown`.
class JournalControllerTestSetup {
  late MockJournalDb mockJournalDb;
  late MockSettingsDb mockSettingsDb;
  late MockFts5Db mockFts5Db;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockNavService mockNavService;
  late StreamController<Set<String>> updateStreamController;
  late StreamController<Set<String>> configFlagsController;
  late StreamController<bool> privateFlagController;
  late StreamController<int> navIndexController;
  late ProviderContainer container;

  void setUp({int initialNavIndex = testTasksIndex}) {
    mockJournalDb = MockJournalDb();
    mockSettingsDb = MockSettingsDb();
    mockFts5Db = MockFts5Db();
    mockUpdateNotifications = MockUpdateNotifications();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockNavService = MockNavService();

    updateStreamController = StreamController<Set<String>>.broadcast();
    configFlagsController = StreamController<Set<String>>.broadcast();
    privateFlagController = StreamController<bool>.broadcast();
    navIndexController = StreamController<int>.broadcast();

    // Default mock behaviors
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => updateStreamController.stream);

    when(() => mockJournalDb.watchConfigFlag(any())).thenAnswer((invocation) {
      final flagName = invocation.positionalArguments.first as String;
      if (flagName == privateFlag) {
        return privateFlagController.stream;
      }
      return configFlagsController.stream.map(
        (flags) => flags.contains(flagName),
      );
    });

    when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);

    when(
      () => mockSettingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);

    when(
      () => mockFts5Db.watchFullTextMatches(any()),
    ).thenAnswer((_) => Stream.value(<String>[]));

    when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

    when(
      () => mockJournalDb.getTasks(
        ids: any(named: 'ids'),
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
        sortByDate: any(named: 'sortByDate'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => <JournalEntity>[]);

    when(
      () => mockJournalDb.getTasksSortedByDueDate(
        ids: any(named: 'ids'),
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => <JournalEntity>[]);

    when(
      () => mockJournalDb.getJournalEntities(
        types: any(named: 'types'),
        starredStatuses: any(named: 'starredStatuses'),
        privateStatuses: any(named: 'privateStatuses'),
        flaggedStatuses: any(named: 'flaggedStatuses'),
        ids: any(named: 'ids'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        categoryIds: any(named: 'categoryIds'),
      ),
    ).thenAnswer((_) async => <JournalEntity>[]);

    when(
      () => mockJournalDb.getTaskIdsForProjects(any()),
    ).thenAnswer((_) async => <String>{});

    when(() => mockNavService.tasksIndex).thenReturn(testTasksIndex);
    when(() => mockNavService.journalIndex).thenReturn(testJournalIndex);
    when(() => mockNavService.index).thenReturn(initialNavIndex);
    when(
      mockNavService.getIndexStream,
    ).thenAnswer((_) => navIndexController.stream);

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<SettingsDb>(mockSettingsDb)
      ..registerSingleton<Fts5Db>(mockFts5Db)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<NavService>(mockNavService);

    container = ProviderContainer();
  }

  /// Convenience for tests: drives a nav-index emission on the same
  /// channel `JournalPageController` listens to. Use this instead of
  /// adding to `navIndexController` directly so callers don't have to
  /// know which controller consumes which stream.
  void emitNavIndex(int index) {
    when(() => mockNavService.index).thenReturn(index);
    navIndexController.add(index);
  }

  Future<void> tearDown() async {
    await updateStreamController.close();
    await configFlagsController.close();
    await privateFlagController.close();
    await navIndexController.close();
    container.dispose();
    await getIt.reset();
  }
}
