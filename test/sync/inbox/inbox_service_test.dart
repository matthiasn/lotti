import 'dart:io';

import 'package:drift/isolate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/connectivity.dart';
import 'package:lotti/sync/fg_bg.dart';
import 'package:lotti/sync/imap_client.dart';
import 'package:lotti/sync/inbox/inbox_service.dart';
import 'package:lotti/sync/secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../helpers/path_provider.dart';
import '../../mocks/mocks.dart';
import '../../mocks/sync_config_test_mocks.dart';
import '../../test_data/sync_config_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InboxService Tests', () {
    final syncConfigMock = MockSyncConfigService();
    final mockVectorClockService = MockVectorClockService();
    final mockJournalDb = MockJournalDb();
    final mockImapClientManager = MockImapClientManager();
    final mockPersistenceLogic = MockPersistenceLogic();
    final secureStorageMock = MockSecureStorage();

    final mockConnectivityService = MockConnectivityService();
    when(() => mockConnectivityService.connectedStream).thenAnswer(
      (_) => Stream<bool>.fromIterable([true]),
    );
    when(mockConnectivityService.isConnected).thenAnswer((_) async => true);

    final mockFgBgService = MockFgBgService();
    when(() => mockFgBgService.fgBgStream).thenAnswer(
      (_) => Stream<bool>.fromIterable([true]),
    );

    setUpAll(() async {
      setFakeDocumentsPath();

      when(syncConfigMock.getSyncConfig)
          .thenAnswer((_) async => testSyncConfigConfigured);

      when(() => mockJournalDb.getConfigFlag(any()))
          .thenAnswer((_) async => true);

      when(
        () => mockImapClientManager.imapAction(
          any(),
          syncConfig: any(named: 'syncConfig'),
          allowInvalidCert: any(named: 'allowInvalidCert'),
        ),
      ).thenAnswer((_) async => true);

      getIt.registerSingleton<Directory>(
        await getApplicationDocumentsDirectory(),
      );

      await getIt.registerSingleton<Future<DriftIsolate>>(
        createDriftIsolate(loggingDbFileName, inMemory: true),
        instanceName: loggingDbFileName,
      );

      await getIt.registerSingleton<Future<DriftIsolate>>(
        createDriftIsolate(settingsDbFileName, inMemory: true),
        instanceName: settingsDbFileName,
      );

      await getIt.registerSingleton<Future<DriftIsolate>>(
        createDriftIsolate(journalDbFileName, inMemory: true),
        instanceName: journalDbFileName,
      );

      getIt
        ..registerSingleton<LoggingDb>(getLoggingDb())
        ..registerSingleton<SettingsDb>(getSettingsDb())
        ..registerSingleton<SecureStorage>(secureStorageMock)
        ..registerSingleton<SyncConfigService>(syncConfigMock)
        ..registerSingleton<ConnectivityService>(mockConnectivityService)
        ..registerSingleton<FgBgService>(mockFgBgService)
        ..registerSingleton<ImapClientManager>(mockImapClientManager)
        ..registerSingleton<VectorClockService>(mockVectorClockService)
        ..registerSingleton<JournalDb>(getJournalDb())
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<InboxService>(InboxService());

      await initConfigFlags(getIt<JournalDb>(), inMemoryDatabase: true);
    });

    setUp(() {
      when(mockVectorClockService.getHostHash)
          .thenAnswer((_) async => 'some_host_hash');
      when(mockVectorClockService.getHost)
          .thenAnswer((_) async => 'some_host_id');
    });

    tearDownAll(() async {
      await getIt.reset();
    });

    tearDown(() async {
      reset(mockVectorClockService);
    });

    test('', () async {
      await getIt<InboxService>().init();
    });
  });
}
