import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/verification_glare.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/secure_storage.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/mocks/mocks.dart';
import '../test/widget_test_utils.dart';
import 'helpers/sync_test_helpers.dart';
import 'matrix_test_room.dart';

/// Two devices that start the emoji ceremony at each other, against a real
/// homeserver.
///
/// `matrix_service_test.dart` only ever has one side start. This drives the
/// crossing that `specs/tla/VerificationLaunch.tla` (`AutoVerifies`) found:
/// both launchers open a sheet at the other device at once. Each simulated
/// device follows the app's rules through the production helpers — the
/// launcher answers a request the target already sent instead of starting
/// its own, and while its own request is unanswered the incoming-request
/// wrapper yields to a smaller identity (`shouldYieldTo`,
/// `handOffOutgoingVerification`) and otherwise defers. The model takes a
/// handoff as one step; here it is a timer stop, a cancel round trip and an
/// accept, racing the peer's own traffic.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const timeout = Duration(minutes: 2);
  const keyStep = 'm.key.verification.key';

  group('Crossing emoji verification', () {
    final secureStorageMock = MockSecureStorage();
    final mockUpdateNotifications = MockUpdateNotifications();

    // Scripts use Dart defines; IDE runners can supply process environment.
    final user1 = const String.fromEnvironment('TEST_USER1').isNotEmpty
        ? const String.fromEnvironment('TEST_USER1')
        : Platform.environment['TEST_USER1'] ?? '';
    final user2 = const String.fromEnvironment('TEST_USER2').isNotEmpty
        ? const String.fromEnvironment('TEST_USER2')
        : Platform.environment['TEST_USER2'] ?? '';
    final skipReason = user1.isEmpty || user2.isEmpty
        ? 'Missing TEST_USER1/TEST_USER2. Run via run_matrix_tests.sh'
        : null;

    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    late LoggingService sharedLoggingService;
    late UserActivityService sharedUserActivityService;
    late Directory sharedDocumentsDirectory;
    late AiConfigDb aiConfigDb;
    late AiConfigRepository sharedAiConfigRepository;

    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());
    when(() => mockUpdateNotifications.notify(any())).thenAnswer((_) {});
    when(
      () => secureStorageMock.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => secureStorageMock.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => secureStorageMock.delete(key: any(named: 'key')),
    ).thenAnswer((_) async {});

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      await vod.init();
      sharedDocumentsDirectory = await Directory.systemTemp.createTemp(
        'lotti-crossing-',
      );
      aiConfigDb = AiConfigDb(inMemoryDatabase: true);
      sharedAiConfigRepository = AiConfigRepository(aiConfigDb);
      sharedUserActivityService = UserActivityService();
      final harness = await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<Directory>(sharedDocumentsDirectory)
            ..unregister<UpdateNotifications>()
            ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
            ..registerSingleton<UserActivityService>(sharedUserActivityService)
            ..unregister<JournalDb>()
            ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
            ..unregister<SettingsDb>()
            ..registerSingleton<SettingsDb>(SettingsDb(inMemoryDatabase: true))
            ..registerSingleton<SecureStorage>(secureStorageMock)
            ..registerSingleton<AiConfigDb>(aiConfigDb)
            ..registerSingleton<AiConfigRepository>(sharedAiConfigRepository);
        },
      );
      sharedLoggingService = harness.loggingService;
    });

    tearDownAll(() async {
      await getIt<JournalDb>().close();
      await getIt<SettingsDb>().close();
      await aiConfigDb.close();
      await sharedUserActivityService.dispose();
      await sharedLoggingService.flush();
      await sharedLoggingService.dispose();
      await tearDownTestGetIt();
      await sharedDocumentsDirectory.delete(recursive: true);
    });

    Future<MatrixService> startDevice(String name, String user) async {
      final documents = await Directory(
        '${sharedDocumentsDirectory.path}/$name-${uuid.v1()}',
      ).create();
      final client = await createMatrixClient(
        documentsDirectory: documents,
        dbName: '${name}_${uuid.v1()}',
      );
      addTearDown(client.dispose);
      final registry = SentEventRegistry();
      final journalDb = JournalDb(
        overriddenFilename: '${name}_${uuid.v1()}.sqlite',
        inMemoryDatabase: true,
      );
      addTearDown(journalDb.close);
      final settingsDb = SettingsDb(inMemoryDatabase: true);
      addTearDown(settingsDb.close);
      final syncDb = SyncDatabase(inMemoryDatabase: true);
      addTearDown(syncDb.close);
      final clock = MockVectorClockService();
      when(() => clock.initialized).thenAnswer((_) async {});
      when(clock.getHost).thenAnswer((_) async => name);
      when(clock.getHostHash).thenAnswer((_) async => '$name-hash');
      final device = await createSyncTestDevice(
        config: MatrixConfig(
          homeServer: TestConfig.testHomeServer,
          user: user,
          password: TestConfig.testPassword,
        ),
        gateway: MatrixSdkGateway(client: client, sentEventRegistry: registry),
        loggingService: getIt<DomainLogger>(),
        journalDb: journalDb,
        settingsDb: settingsDb,
        secureStorage: secureStorageMock,
        deviceName: name,
        activityService: sharedUserActivityService,
        documentsDirectory: documents,
        updateNotifications: mockUpdateNotifications,
        aiConfigRepository: sharedAiConfigRepository,
        sentEventRegistry: registry,
        syncDb: syncDb,
        vectorClockService: clock,
      );
      addTearDown(device.dispose);
      final service = device.matrixService;
      await service.init();
      await service.login();
      debugPrint('$name - deviceId: ${service.client.deviceID}');
      return service;
    }

    test(
      'two devices starting the ceremony at each other both end up verified',
      () async {
        final alice = await startDevice('CrossingAlice', user1);
        final roomId = await createTestSyncRoom(
          MatrixSdkGateway(
            client: alice.client,
            sentEventRegistry: SentEventRegistry(),
          ),
        );
        await alice.joinRoom(roomId);
        final bob = await startDevice('CrossingBob', user2);
        await inviteToTestSyncRoom(alice, userId: user2);
        await waitSeconds(5);
        await bob.joinRoom(roomId);

        await waitUntil(
          () => alice.getUnverifiedDevices().isNotEmpty,
          timeout: timeout,
        );
        await waitUntil(
          () => bob.getUnverifiedDevices().isNotEmpty,
          timeout: timeout,
        );

        final emojis = <String, String>{};
        final withdrawn = <String, KeyVerification>{};
        final deferred = <String, KeyVerification>{};
        final logger = getIt<DomainLogger>();

        // The app's rules, one device at a time.
        void follow(String name, MatrixService me) {
          // IncomingVerificationWrapper while the launcher's sheet holds the
          // lock: yield to a smaller identity, else keep the request.
          final incoming = me.getIncomingKeyVerificationStream().listen((
            request,
          ) async {
            final outgoing = me.keyVerificationRunner;
            final yields = shouldYieldTo(
              incoming: request,
              outgoing: outgoing,
              ownUserId: me.ownUserId,
              ownDeviceId: me.ownDeviceId,
            );
            debugPrint(
              '$name - request from ${request.deviceId}: '
              '${yields ? 'yields' : 'defers'} '
              '(own step: ${outgoing?.lastStep})',
            );
            if (yields) {
              withdrawn[name] = outgoing!.keyVerification;
              await handOffOutgoingVerification(
                service: me,
                incoming: request,
                domainLogger: logger,
              );
            } else {
              deferred[name] = request;
            }
          });
          addTearDown(incoming.cancel);

          // Both sheets confirm the emoji once both users have seen them,
          // as people comparing two screens do: the outgoing sheet (own
          // ceremony or a handed-off one) and the incoming one. Confirming
          // the moment they appear lets this side's MAC overtake the peer's
          // 100 ms poll, which then never sees the key step.
          Future<void> confirm(KeyVerificationRunner runner) async {
            if (runner.lastStep != keyStep || emojis.containsKey(name)) return;
            emojis[name] = extractEmojiString(runner.emojis);
            debugPrint('$name - emojis: ${emojis[name]}');
            await waitUntil(() => emojis.length == 2, timeout: timeout);
            await runner.acceptEmojiVerification();
          }

          final outgoingSheet = me.keyVerificationStream.listen(confirm);
          addTearDown(outgoingSheet.cancel);
          final incomingSheet = me.incomingKeyVerificationRunnerStream.listen(
            confirm,
          );
          addTearDown(incomingSheet.cancel);
        }

        follow('alice', alice);
        follow('bob', bob);

        // AutoVerificationLauncher: answer a request the target already sent
        // (IncomingVerificationModal auto-accepts it), else start one.
        Future<void> launch(String name, MatrixService me) async {
          final target = me.getUnverifiedDevices().first;
          final waiting = me.incomingKeyVerificationRunner;
          if (waiting != null &&
              waiting.outcome == KeyVerificationOutcome.pending &&
              waiting.keyVerification.deviceId == target.deviceId) {
            debugPrint('$name - answers the waiting request');
            await waiting.acceptVerification();
            return;
          }
          debugPrint('$name - starts toward ${target.deviceId}');
          await me.verifyDevice(target);
        }

        await Future.wait([launch('alice', alice), launch('bob', bob)]);

        await waitUntil(
          () =>
              alice.getUnverifiedDevices().isEmpty &&
              bob.getUnverifiedDevices().isEmpty,
          timeout: timeout,
          message: 'the crossing ceremony never finished',
        );

        expect(emojis.keys, unorderedEquals(['alice', 'bob']));
        expect(emojis['alice'], isNotEmpty);
        expect(emojis['alice'], emojis['bob']);

        // Exactly one side withdrew its request, and it is the larger
        // identity: the SDK's order, applied one step earlier.
        expect(withdrawn, hasLength(1));
        final yielder = withdrawn.keys.single;
        final (larger, smaller) = yielder == 'alice'
            ? (alice, bob)
            : (bob, alice);
        expect(
          verificationIdentity(
            userId: smaller.ownUserId,
            deviceId: smaller.ownDeviceId,
          ).compareTo(
            verificationIdentity(
              userId: larger.ownUserId,
              deviceId: larger.ownDeviceId,
            ),
          ),
          lessThan(0),
        );
        expect(withdrawn[yielder]!.canceled, isTrue);

        // The peer sees the withdrawn request cancelled too, so nothing is
        // left waiting on it once its sheet would show it.
        final keptBack = deferred.values.where(
          (request) =>
              request.transactionId == withdrawn[yielder]!.transactionId,
        );
        for (final request in keptBack) {
          await waitUntil(() => request.canceled, timeout: timeout);
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
      skip: skipReason,
    );
  });
}
