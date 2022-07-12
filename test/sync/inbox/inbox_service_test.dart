import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/connectivity.dart';
import 'package:lotti/sync/fg_bg.dart';
import 'package:lotti/sync/inbox/inbox_service.dart';
import 'package:mocktail/mocktail.dart';

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
    final mockPersistenceLogic = MockPersistenceLogic();

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

      getIt
        ..registerSingleton<SyncDatabase>(
          SyncDatabase(inMemoryDatabase: true),
          dispose: (db) async => db.close(),
        )
        ..registerSingleton<ConnectivityService>(mockConnectivityService)
        ..registerSingleton<FgBgService>(mockFgBgService)
        ..registerSingleton<VectorClockService>(mockVectorClockService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
        ..registerSingleton<SyncConfigService>(syncConfigMock)
        ..registerSingleton<InboxService>(InboxService());
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
      getIt<InboxService>().enqueueNextFetchRequest();
    });
  });
}
