import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/sync/inbox_service.dart';
import 'package:lotti/sync/outbox.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncConfigService extends Mock implements SyncConfigService {
  MockSyncConfigService({
    this.imapConfig,
    this.sharedKey,
    required this.testingSucceeds,
  });

  String? sharedKey;
  ImapConfig? imapConfig;
  bool testingSucceeds;

  @override
  Future<String?> getSharedKey() async {
    return sharedKey;
  }

  @override
  Future<ImapConfig?> getImapConfig() async {
    return imapConfig;
  }

  @override
  Future<void> deleteSharedKey() async {
    sharedKey = null;
  }

  @override
  Future<void> deleteImapConfig() async {
    imapConfig = null;
  }

  @override
  Future<bool> testConnection(SyncConfig syncConfig) async {
    return testingSucceeds;
  }
}

class MockSyncInboxService extends Mock implements SyncInboxService {
  @override
  Future<void> init() async {}
}

class MockOutboxService extends Mock implements OutboxService {
  @override
  Future<void> init() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testKey = 'abc123';
  final testImapConfig = ImapConfig(
    host: 'host',
    folder: 'folder',
    userName: 'userName',
    password: 'password',
    port: 993,
  );

  group('SyncConfigCubit Tests', () {
    group(' -', () {
      setUp(() {
        getIt
          ..registerSingleton<OutboxService>(MockOutboxService())
          ..registerSingleton<SyncInboxService>(MockSyncInboxService());
      });
      tearDown(getIt.reset);

      blocTest<SyncConfigCubit, SyncConfigState>(
        'empty state',
        build: SyncConfigCubit.new,
        setUp: () {
          getIt.registerSingleton<SyncConfigService>(
            MockSyncConfigService(testingSucceeds: true),
          );
        },
        act: (c) => c.emitState(),
        expect: () => <SyncConfigState>[SyncConfigState.empty()],
        tearDown: () async => getIt.reset(),
      );

      blocTest<SyncConfigCubit, SyncConfigState>(
        'configured state',
        build: SyncConfigCubit.new,
        setUp: () {
          getIt.registerSingleton<SyncConfigService>(
            MockSyncConfigService(
              imapConfig: testImapConfig,
              sharedKey: testKey,
              testingSucceeds: true,
            ),
          );
        },
        act: (c) => c.emitState(),
        expect: () => <SyncConfigState>[
          SyncConfigState.empty(),
          SyncConfigState.imapTesting(imapConfig: testImapConfig),
          SyncConfigState.configured(
            imapConfig: testImapConfig,
            sharedSecret: testKey,
          ),
        ],
        tearDown: () async => getIt.reset(),
      );

      blocTest<SyncConfigCubit, SyncConfigState>(
        'configured state, then delete key',
        build: SyncConfigCubit.new,
        setUp: () {
          getIt.registerSingleton<SyncConfigService>(
            MockSyncConfigService(
              imapConfig: testImapConfig,
              sharedKey: testKey,
              testingSucceeds: true,
            ),
          );
        },
        act: (c) => c.deleteSharedKey(),
        expect: () => <SyncConfigState>[
          SyncConfigState.empty(),
          SyncConfigState.imapTesting(imapConfig: testImapConfig),
          SyncConfigState.imapSaved(imapConfig: testImapConfig),
        ],
        tearDown: () async => getIt.reset(),
      );

      blocTest<SyncConfigCubit, SyncConfigState>(
        'configured state, then delete imap config',
        build: SyncConfigCubit.new,
        setUp: () {
          getIt.registerSingleton<SyncConfigService>(
            MockSyncConfigService(
              imapConfig: testImapConfig,
              sharedKey: testKey,
              testingSucceeds: true,
            ),
          );
        },
        act: (c) => c.deleteImapConfig(),
        expect: () => <SyncConfigState>[
          SyncConfigState.empty(),
        ],
        tearDown: () async => getIt.reset(),
      );

      blocTest<SyncConfigCubit, SyncConfigState>(
        'imap config valid state',
        build: SyncConfigCubit.new,
        setUp: () {
          getIt.registerSingleton<SyncConfigService>(
            MockSyncConfigService(
              imapConfig: testImapConfig,
              testingSucceeds: true,
            ),
          );
        },
        act: (c) => c.emitState(),
        expect: () => <SyncConfigState>[
          SyncConfigState.empty(),
          SyncConfigState.imapTesting(imapConfig: testImapConfig),
          SyncConfigState.imapSaved(imapConfig: testImapConfig),
        ],
        tearDown: () async => getIt.reset(),
      );

      blocTest<SyncConfigCubit, SyncConfigState>(
        'imap config is invalid state',
        build: SyncConfigCubit.new,
        setUp: () {
          getIt.registerSingleton<SyncConfigService>(
            MockSyncConfigService(
              imapConfig: testImapConfig,
              testingSucceeds: false,
            ),
          );
        },
        act: (c) => c.emitState(),
        expect: () => <SyncConfigState>[
          SyncConfigState.empty(),
          SyncConfigState.imapTesting(imapConfig: testImapConfig),
          SyncConfigState.imapInvalid(
            imapConfig: testImapConfig,
            errorMessage: 'Error',
          ),
        ],
        tearDown: () async => getIt.reset(),
      );
    });
  });
}
