import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/connectivity.dart';
import 'package:lotti/sync/fg_bg.dart';
import 'package:lotti/sync/outbox/outbox_service.dart';
import 'package:lotti/sync/secure_storage.dart';
import 'package:lotti/sync/utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../mocks/sync_config_test_mocks.dart';
import '../../test_data/sync_config_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JournalPageCubit Tests - ', () {
    var vcMockNext = '1';

    setUpAll(() {
      final secureStorageMock = MockSecureStorage();
      final settingsDb = SettingsDb(inMemoryDatabase: true);
      final mockConnectivityService = MockConnectivityService();
      final mockFgBgService = MockFgBgService();
      final mockTimeService = MockTimeService();

      final syncConfigMock = MockSyncConfigService();
      when(syncConfigMock.getSyncConfig)
          .thenAnswer((_) async => testSyncConfigConfigured);

      when(() => mockConnectivityService.connectedStream).thenAnswer(
        (_) => Stream<bool>.fromIterable([true]),
      );

      when(() => mockFgBgService.fgBgStream).thenAnswer(
        (_) => Stream<bool>.fromIterable([true]),
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
        ..registerSingleton<ConnectivityService>(mockConnectivityService)
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<FgBgService>(mockFgBgService)
        ..registerSingleton<SyncConfigService>(syncConfigMock)
        ..registerSingleton<SyncDatabase>(SyncDatabase(inMemoryDatabase: true))
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
        ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
        ..registerSingleton<Fts5Db>(Fts5Db(inMemoryDatabase: true))
        ..registerSingleton<SecureStorage>(secureStorageMock)
        ..registerSingleton<OutboxService>(OutboxService())
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<VectorClockService>(VectorClockService())
        ..registerSingleton<PersistenceLogic>(PersistenceLogic())
        ..registerSingleton<EditorDb>(EditorDb(inMemoryDatabase: true))
        ..registerSingleton<EditorStateService>(EditorStateService());
    });
    tearDownAll(getIt.reset);

    Matcher isJournalPageState() {
      return isA<JournalPageState>();
    }

    blocTest<JournalPageCubit, JournalPageState>(
      'toggle starred entries changes state',
      build: JournalPageCubit.new,
      setUp: () {},
      act: (c) async {
        c.toggleStarredEntriesOnly();
      },
      wait: defaultWait,
      expect: () => [isJournalPageState()],
      verify: (c) => c.state.starredEntriesOnly,
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'toggle starred entries twice disables flag again',
      build: JournalPageCubit.new,
      setUp: () {},
      act: (c) async {
        c
          ..toggleStarredEntriesOnly()
          ..toggleStarredEntriesOnly();
      },
      wait: defaultWait,
      expect: () => [
        isJournalPageState(),
        isJournalPageState(),
      ],
      verify: (c) => !c.state.starredEntriesOnly,
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'toggle private entries changes state',
      build: JournalPageCubit.new,
      setUp: () {},
      act: (c) async {
        c.togglePrivateEntriesOnly();
      },
      wait: defaultWait,
      expect: () => [isJournalPageState()],
      verify: (c) => c.state.privateEntriesOnly,
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'toggle private entries twice disables flag again',
      build: JournalPageCubit.new,
      setUp: () {},
      act: (c) async {
        c
          ..togglePrivateEntriesOnly()
          ..togglePrivateEntriesOnly();
      },
      wait: defaultWait,
      expect: () => [
        isJournalPageState(),
        isJournalPageState(),
      ],
      verify: (c) => !c.state.privateEntriesOnly,
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'toggle flagged entries changes state',
      build: JournalPageCubit.new,
      setUp: () {},
      act: (c) async {
        c.toggleFlaggedEntriesOnly();
      },
      wait: defaultWait,
      expect: () => [isJournalPageState()],
      verify: (c) => c.state.flaggedEntriesOnly,
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'toggle flagged entries twice disables flag again',
      build: JournalPageCubit.new,
      setUp: () {},
      act: (c) async {
        c
          ..toggleFlaggedEntriesOnly()
          ..toggleFlaggedEntriesOnly();
      },
      wait: defaultWait,
      expect: () => [
        isJournalPageState(),
        isJournalPageState(),
      ],
      verify: (c) => !c.state.flaggedEntriesOnly,
    );

    blocTest<JournalPageCubit, JournalPageState>(
      'toggle flagged entries changes state',
      build: JournalPageCubit.new,
      setUp: () {},
      act: (c) async {
        await c.setSearchString('query');
      },
      wait: defaultWait,
      expect: () => [isJournalPageState()],
      verify: (c) => c.state.match == 'query',
    );
  });
}
