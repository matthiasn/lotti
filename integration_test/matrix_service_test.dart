import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_ingestor.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_persistence.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_repository.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import '../test/mocks/mocks.dart';
import '../test/test_resources/test_audio_data.dart';
import '../test/utils/utils.dart';
import 'matrix_test_room.dart';

const _uuid = Uuid();

int _messageEntryCount(SyncMessage message) =>
    message is SyncOutboxBundle ? message.children.length : 1;

/// Observes the production outbox sender without changing its send semantics.
///
/// The mid-rejoin scenario uses [beforeSend] to pause *between* bundles. There
/// is still one [OutboxProcessor], one Matrix client, and one awaited send at a
/// time, matching the application path.
class _ObservedOutboxMessageSender implements OutboxMessageSender {
  _ObservedOutboxMessageSender(MatrixService matrixService)
    : _delegate = MatrixOutboxMessageSender(matrixService);

  final MatrixOutboxMessageSender _delegate;

  Future<void> Function(int sentEvents, int sentEntries, SyncMessage message)?
  beforeSend;

  int sentEvents = 0;
  int sentEntries = 0;
  final List<int> bundleSizes = [];

  @override
  Future<bool> send(SyncMessage message) async {
    await beforeSend?.call(sentEvents, sentEntries, message);
    final sent = await _delegate.send(message);
    if (sent) {
      sentEvents++;
      final entryCount = _messageEntryCount(message);
      sentEntries += entryCount;
      bundleSizes.add(entryCount);
    }
    return sent;
  }
}

/// Gives each simulated device a stable host identity while both devices run
/// inside the same test isolate and therefore share GetIt's SettingsDb.
class _DeviceVectorClockService extends VectorClockService {
  _DeviceVectorClockService(this._host);

  final String _host;

  @override
  Future<String?> getHost() async => _host;

  @override
  Future<String?> getHostHash() async => 'test-hash-$_host';
}

class _DeviceOutbox {
  _DeviceOutbox({
    required this.service,
    required this.sender,
    required this.journalDb,
    required this.syncDb,
    required this.documentsDirectory,
    required this.deviceName,
  });

  final OutboxService service;
  final _ObservedOutboxMessageSender sender;
  final JournalDb journalDb;
  final SyncDatabase syncDb;
  final Directory documentsDirectory;
  final String deviceName;
  int nextCounter = 1;

  static Future<_DeviceOutbox> create({
    required MatrixService matrixService,
    required JournalDb journalDb,
    required SyncDatabase syncDb,
    required Directory documentsDirectory,
    required UserActivityService userActivityService,
    required DomainLogger loggingService,
    required VectorClockService vectorClockService,
    required String deviceName,
  }) async {
    final sequenceLogService = SyncSequenceLogService(
      syncDatabase: syncDb,
      vectorClockService: vectorClockService,
      loggingService: loggingService,
    );
    final sender = _ObservedOutboxMessageSender(matrixService);
    final service = OutboxService(
      syncDatabase: syncDb,
      loggingService: loggingService,
      vectorClockService: vectorClockService,
      journalDb: journalDb,
      documentsDirectory: documentsDirectory,
      userActivityService: userActivityService,
      messageSender: sender,
      matrixService: matrixService,
      connectivityStream: const Stream<List<ConnectivityResult>>.empty(),
      sequenceLogService: sequenceLogService,
      postDrainSettle: Duration.zero,
      domainLogger: loggingService,
    );
    return _DeviceOutbox(
      service: service,
      sender: sender,
      journalDb: journalDb,
      syncDb: syncDb,
      documentsDirectory: documentsDirectory,
      deviceName: deviceName,
    );
  }
}

Future<MatrixService> _createMatrixService({
  required MatrixConfig config,
  required MatrixSyncGateway gateway,
  required DomainLogger loggingService,
  required JournalDb journalDb,
  required SettingsDb settingsDb,
  required SecureStorage secureStorage,
  required String deviceName,
  required UserActivityService activityService,
  required Directory documentsDirectory,
  required UpdateNotifications updateNotifications,
  required AiConfigRepository aiConfigRepository,
  required SentEventRegistry sentEventRegistry,
  required SyncDatabase syncDb,
  required VectorClockService vectorClockService,
  AttachmentIndex? attachmentIndex,
  QueuePipelineCoordinator Function(QueuePipelineCoordinator coord)?
  onCoordinatorBuilt,
}) async {
  final activityGate = UserActivityGate(
    activityService: activityService,
  );
  final messageSender = MatrixMessageSender(
    loggingService: loggingService,
    journalDb: journalDb,
    documentsDirectory: documentsDirectory,
    sentEventRegistry: sentEventRegistry,
    vectorClockService: vectorClockService,
    domainLogger: loggingService,
  );

  // Shared AttachmentIndex so the queue coordinator subscribes to
  // the same broadcast stream that `AttachmentIndex.record(event)`
  // fires. Without sharing, the coordinator listens to a freshly
  // constructed index and never hears the test-simulated path.
  final sharedAttachmentIndex =
      attachmentIndex ?? AttachmentIndex(logging: loggingService);
  // Ingestor that runs attachment descriptor events through
  // AttachmentIndex + disk-save on the queue pipeline's live +
  // bootstrap paths — the same plumbing `get_it.dart` uses in
  // production so the integration test exercises the real chain.
  final queueAttachmentIngestor = AttachmentIngestor(
    documentsDirectory: documentsDirectory,
    verboseLogging: false,
  );

  final sequenceLogService = SyncSequenceLogService(
    syncDatabase: syncDb,
    vectorClockService: vectorClockService,
    loggingService: loggingService,
  );
  final eventProcessor = SyncEventProcessor(
    loggingService: loggingService,
    domainLogger: loggingService,
    updateNotifications: updateNotifications,
    aiConfigRepository: aiConfigRepository,
    settingsDb: settingsDb,
    savedTaskFiltersRepository: SavedTaskFiltersRepository(
      SavedTaskFiltersPersistence(settingsDb),
      updateNotifications,
    ),
    journalEntityLoader: SmartJournalEntityLoader(
      attachmentIndex: sharedAttachmentIndex,
      loggingService: loggingService,
      documentsDirectory: documentsDirectory,
    ),
    documentsDirectory: documentsDirectory,
    attachmentIndex: sharedAttachmentIndex,
    sequenceLogService: sequenceLogService,
    journalDb: journalDb,
    vectorClockService: vectorClockService,
  );
  final roomManager = SyncRoomManager(
    gateway: gateway,
    settingsDb: settingsDb,
    loggingService: loggingService,
  );
  final sessionManager =
      MatrixSessionManager(
          gateway: gateway,
          roomManager: roomManager,
          loggingService: loggingService,
        )
        ..matrixConfig = config
        ..deviceDisplayName = deviceName;
  var queueCoordinator = QueuePipelineCoordinator(
    syncDb: syncDb,
    settingsDb: settingsDb,
    journalDb: journalDb,
    sessionManager: sessionManager,
    roomManager: roomManager,
    eventProcessor: eventProcessor,
    sequenceLogService: sequenceLogService,
    activityGate: activityGate,
    logging: loggingService,
    attachmentIndex: sharedAttachmentIndex,
    updateNotifications: updateNotifications,
    attachmentIngestor: queueAttachmentIngestor,
  );
  if (onCoordinatorBuilt != null) {
    queueCoordinator = onCoordinatorBuilt(queueCoordinator);
  }

  return MatrixService(
    matrixConfig: config,
    gateway: gateway,
    loggingService: loggingService,
    activityGate: activityGate,
    messageSender: messageSender,
    settingsDb: settingsDb,
    eventProcessor: eventProcessor,
    secureStorage: secureStorage,
    deviceDisplayName: deviceName,
    ownsActivityGate: true,
    collectSyncMetrics: true,
    roomManager: roomManager,
    sessionManager: sessionManager,
    queueCoordinator: queueCoordinator,
  );
}

/// Domain logger that echoes sync-pipeline lines to test stdout.
///
/// The pipeline is silent under test for two independent reasons, and both
/// have to be defeated to see anything:
///
///  * `DomainLogger.enabledDomains` starts empty, so every
///    `log(LogDomain.sync, ...)` is a no-op unless a domain is added;
///  * `LoggingService._enableLogging` is `!isTestEnv`, so `captureEvent`
///    returns early under `FLUTTER_TEST` even when a domain is enabled.
///
/// The consequence is that the catch-up bridge — its mode, its page counts,
/// its give-up ladder, and the exceptions `saveRoom.bootstrap` swallows —
/// leaves no trace in an integration run. A failing test then shows only that
/// nothing arrived, with no way to tell "never ran" from "ran and found
/// nothing" from "threw". This class closes that gap without touching
/// production logging.
class _EchoDomainLogger extends DomainLogger {
  _EchoDomainLogger({required super.loggingService}) {
    enabledDomains.add(LogDomain.sync);
  }

  /// Sub-domains worth echoing. Everything in the sync domain would drown the
  /// per-message traffic of a 250-event burst.
  static const _interesting = <String>[
    'queue.bridge',
    'queue.bootstrap',
    'queue.coordinator',
    'bootstrap',
    'saveRoom',
  ];

  bool _wanted(String? subDomain) =>
      subDomain != null && _interesting.any(subDomain.startsWith);

  @override
  void log(
    LogDomain domain,
    String message, {
    String? subDomain,
    InsightLevel level = InsightLevel.info,
  }) {
    if (domain == LogDomain.sync && _wanted(subDomain)) {
      debugPrint('[sync] $subDomain :: $message');
    }
    super.log(domain, message, subDomain: subDomain, level: level);
  }

  @override
  void error(
    LogDomain domain,
    Object error, {
    StackTrace? stackTrace,
    String? subDomain,
    String? message,
  }) {
    // Errors always echo. `saveRoom.bootstrap` and `queue.bridge.*` swallow
    // exceptions into this method, so a silenced logger turns a thrown
    // bootstrap into an indistinguishable no-op.
    debugPrint('[sync][ERROR] ${subDomain ?? '-'} :: $error');
    super.error(
      domain,
      error,
      stackTrace: stackTrace,
      subDomain: subDomain,
      message: message,
    );
  }
}

/// Thrown when a convergence wait detects that nothing can still be in
/// progress, so waiting out the full timeout would only burn CI time.
class _SyncStalledException implements Exception {
  _SyncStalledException(this.message);
  final String message;
  @override
  String toString() => 'SyncStalled: $message';
}

/// Fails fast when sync has demonstrably stopped rather than merely being slow.
///
/// A device that is catching up always has *something* outstanding: rows in
/// the inbound queue, or a bridge walk in flight. When the journal count has
/// not moved for [stallWindow] AND the queue is empty AND no bridge is
/// running, nothing is going to arrive — the remaining wait is dead time.
///
/// The degraded-network job used to spend the full 15-minute convergence
/// timeout in exactly that state, on every branch, turning a ~6 minute suite
/// into a ~21 minute one. Detecting the stall keeps the failure (it is a real
/// bug) while returning the diagnosis in seconds.
Future<void> throwIfStalled({
  required MatrixService device,
  required int currentCount,
  required int lastCount,
  required Stopwatch sinceLastProgress,
  Duration stallWindow = const Duration(seconds: 90),
  Duration warnWindow = const Duration(seconds: 20),
}) async {
  if (currentCount != lastCount) {
    sinceLastProgress
      ..reset()
      ..start();
    return;
  }
  if (sinceLastProgress.elapsed < warnWindow) return;

  final coord = device.queueCoordinator;
  final stats = await coord.queue.stats();
  // Still-encrypted events have no queue row. Their durable resume floor is
  // therefore part of "outstanding work": a later room key or cold-start
  // bridge can still revisit them even while queue depth is zero.
  final roomId = device.syncRoomId;
  final resumeFloorTs = roomId == null
      ? null
      : await coord.queue.resumeFloorTs(roomId);
  final quiet =
      stats.total == 0 && resumeFloorTs == null && !coord.isBridgeInFlight;

  // Below the failing threshold, report rather than fail. Healthy degraded
  // runs have been measured going 62s without the journal count moving, so
  // the window cannot be tightened on elapsed time alone — what decides it is
  // whether the queue is also empty during those gaps. These lines answer
  // that from real runs, so the threshold can be lowered on evidence.
  if (sinceLastProgress.elapsed < stallWindow) {
    debugPrint(
      '[stall-probe] no progress for '
      '${sinceLastProgress.elapsed.inSeconds}s at $currentCount entries; '
      'quiet=$quiet queue[total=${stats.total} ready=${stats.readyNow}] '
      'resumeFloorTs=$resumeFloorTs '
      'bridgeInFlight=${coord.isBridgeInFlight}',
    );
    return;
  }

  if (!quiet) return;

  throw _SyncStalledException(
    'no progress for ${sinceLastProgress.elapsed.inSeconds}s at '
    '$currentCount entries, with an empty inbound queue and no bridge in '
    'flight, and no ciphertext awaiting a key. Nothing is outstanding, so the '
    'remaining wait cannot help. '
    'queue[total=${stats.total} ready=${stats.readyNow} '
    'byProducer=${stats.byProducer}] '
    'resumeFloorTs=$resumeFloorTs '
    'bridgeInFlight=${coord.isBridgeInFlight} '
    'currentRoomId=${device.syncRoomId}',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const timeout = Duration(minutes: 1);

  // description and how to run in https://github.com/matthiasn/lotti/pull/1695
  group('MatrixService V2 Tests', () {
    final secureStorageMock = MockSecureStorage();
    const testUserEnv1 = 'TEST_USER1';
    const testUserEnv2 = 'TEST_USER2';
    const testServerEnv = 'TEST_SERVER';
    const testPasswordEnv = 'TEST_PASSWORD';
    const testSlowNetworkEnv = 'SLOW_NETWORK';

    // create separate databases for each simulated device & suppress warning
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    final mockUpdateNotifications = MockUpdateNotifications();
    late LoggingService sharedLoggingService;
    late UserActivityService sharedUserActivityService;
    late Directory harnessDocumentsRoot;
    late Directory aliceDocumentsDirectory;
    late Directory bobDocumentsDirectory;
    late AiConfigRepository sharedAiConfigRepository;

    when(() => mockUpdateNotifications.updateStream).thenAnswer(
      (_) => Stream<Set<String>>.fromIterable([]),
    );

    when(
      () => mockUpdateNotifications.notify(any()),
    ).thenAnswer((_) {});
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

    final aliceDb = JournalDb(
      overriddenFilename: 'alice_db.sqlite',
      inMemoryDatabase: true,
    );
    final bobDb = JournalDb(
      overriddenFilename: 'bob_db.sqlite',
      inMemoryDatabase: true,
    );
    final aliceSyncDb = SyncDatabase(
      overriddenFilename: 'alice_sync.sqlite',
      inMemoryDatabase: true,
    );
    final bobSyncDb = SyncDatabase(
      overriddenFilename: 'bob_sync.sqlite',
      inMemoryDatabase: true,
    );
    late AiConfigDb aiConfigDb;

    const testSlowNetwork = bool.fromEnvironment(testSlowNetworkEnv);

    if (testSlowNetwork) {
      debugPrint('Testing with degraded network.');
    }

    final missingEnv = <String>[
      if (!const bool.hasEnvironment(testUserEnv1)) testUserEnv1,
      if (!const bool.hasEnvironment(testUserEnv2)) testUserEnv2,
    ];
    final skipReason = missingEnv.isEmpty
        ? null
        : 'Missing: ${missingEnv.join(', ')}. Run via run_matrix_tests.sh';

    const aliceUserName = String.fromEnvironment(testUserEnv1);
    const bobUserName = String.fromEnvironment(testUserEnv2);

    const testHomeServer = bool.hasEnvironment(testServerEnv)
        ? String.fromEnvironment(testServerEnv)
        : testSlowNetwork
        ? 'http://localhost:18008'
        : 'http://localhost:8008';
    const testPassword = bool.hasEnvironment(testPasswordEnv)
        ? String.fromEnvironment(testPasswordEnv)
        : '?Secret123@';

    const config1 = MatrixConfig(
      homeServer: testHomeServer,
      user: aliceUserName,
      password: testPassword,
    );

    const config2 = MatrixConfig(
      homeServer: testHomeServer,
      user: bobUserName,
      password: testPassword,
    );

    const defaultDelay = 5;

    // Shared services that persist across tests so the second test can
    // reuse the already-verified Alice & Bob from the first test.
    late MatrixService alice;
    late MatrixService bob;
    var aliceInitialized = false;
    var bobInitialized = false;
    late _DeviceOutbox aliceOutbox;
    late _DeviceOutbox bobOutbox;
    var aliceOutboxInitialized = false;
    var bobOutboxInitialized = false;
    late _DeviceVectorClockService aliceVectorClockService;
    late _DeviceVectorClockService bobVectorClockService;
    late String roomId;
    // Bob's settings and queue databases must persist across service
    // reconstruction so test 2 models a real app restart. Production keeps
    // both on disk; creating a random in-memory SyncDatabase per service
    // silently discarded the queue marker and turned the cold restart into a
    // fresh-client bootstrap against the SDK's sparse cached timeline.
    late SettingsDb bobSettingsDb;

    setUpAll(() async {
      await vod.init();
      final docDir = await Directory.systemTemp.createTemp(
        'lotti_matrix_${_uuid.v1()}_',
      );
      debugPrint('Created temporary docDir ${docDir.path}');
      harnessDocumentsRoot = docDir;
      aliceDocumentsDirectory = await Directory(
        '${docDir.path}/alice',
      ).create();
      bobDocumentsDirectory = await Directory(
        '${docDir.path}/bob',
      ).create();

      aiConfigDb = AiConfigDb(inMemoryDatabase: true);
      sharedAiConfigRepository = AiConfigRepository(aiConfigDb);
      sharedLoggingService = LoggingService();
      sharedUserActivityService = UserActivityService();
      bobSettingsDb = SettingsDb(inMemoryDatabase: true);

      // Register essential dependencies
      getIt
        ..registerSingleton<Directory>(harnessDocumentsRoot)
        ..registerSingleton<LoggingService>(sharedLoggingService)
        ..registerSingleton<DomainLogger>(
          _EchoDomainLogger(loggingService: sharedLoggingService),
        )
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<UserActivityService>(sharedUserActivityService)
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
        ..registerSingleton<SettingsDb>(SettingsDb(inMemoryDatabase: true))
        ..registerSingleton<SecureStorage>(secureStorageMock)
        ..registerSingleton<AiConfigDb>(aiConfigDb)
        ..registerSingleton<AiConfigRepository>(sharedAiConfigRepository);

      // Ensure all GetIt instances are properly initialized
      // Give time for any async initializations to complete
      await Future<void>.delayed(const Duration(seconds: 2));
    });

    setUp(() {});

    tearDownAll(() async {
      // Ensure proper cleanup before resetting GetIt
      if (aliceOutboxInitialized) {
        await aliceOutbox.service.dispose();
      }
      if (bobOutboxInitialized) {
        await bobOutbox.service.dispose();
      }
      if (aliceInitialized) {
        try {
          await alice.dispose();
        } catch (e) {
          debugPrint('Error disposing Alice: $e');
        }
      }
      if (bobInitialized) {
        try {
          await bob.dispose();
        } catch (e) {
          debugPrint('Error disposing Bob: $e');
        }
      }
      try {
        await aliceDb.close();
        await bobDb.close();
        await aliceSyncDb.close();
        await bobSyncDb.close();
        await bobSettingsDb.close();
        await aiConfigDb.close();
      } catch (e) {
        debugPrint('Error during database cleanup: $e');
      }
      try {
        await harnessDocumentsRoot.delete(recursive: true);
      } catch (e) {
        debugPrint('Error deleting temporary documents: $e');
      }
    });

    tearDown(() async {
      // Perform any per-test cleanup here
    });

    test(
      'Create room & join (sync v2)',
      () async {
        debugPrint('\n--- Alice goes live');

        // Make sure the GetIt dependencies are ready before creating MatrixService
        await Future<void>.delayed(const Duration(seconds: 1));

        aliceVectorClockService = _DeviceVectorClockService('aliceDeviceV2');
        bobVectorClockService = _DeviceVectorClockService('bobDeviceV2');
        await Future.wait([
          aliceVectorClockService.initialized,
          bobVectorClockService.initialized,
        ]);

        final aliceClient = await createMatrixClient(
          documentsDirectory: aliceDocumentsDirectory,
          dbName: 'AliceV2',
        );
        final aliceRegistry = SentEventRegistry();
        final aliceGateway = MatrixSdkGateway(
          client: aliceClient,
          sentEventRegistry: aliceRegistry,
        );
        final loggingService = getIt<DomainLogger>();
        final aliceSettingsDb = SettingsDb(inMemoryDatabase: true);
        alice = await _createMatrixService(
          config: config1,
          gateway: aliceGateway,
          loggingService: loggingService,
          journalDb: aliceDb,
          settingsDb: aliceSettingsDb,
          secureStorage: secureStorageMock,
          deviceName: 'AliceV2',
          activityService: sharedUserActivityService,
          documentsDirectory: aliceDocumentsDirectory,
          updateNotifications: mockUpdateNotifications,
          aiConfigRepository: sharedAiConfigRepository,
          sentEventRegistry: aliceRegistry,
          syncDb: aliceSyncDb,
          vectorClockService: aliceVectorClockService,
        );
        aliceInitialized = true;

        await alice.init();
        expect(alice.debugPipeline, isNotNull);

        // Allow time for constructor initialization to complete
        await Future<void>.delayed(const Duration(seconds: 1));

        await alice.login();
        debugPrint('Alice - deviceId: ${alice.client.deviceID}');

        roomId = await createTestSyncRoom(aliceGateway);

        debugPrint('Alice - room created: $roomId');

        expect(roomId, isNotEmpty);

        final joinRes = await alice.joinRoom(roomId);
        debugPrint('Alice - room joined: $joinRes');
        debugPrint(
          'Alice - room encrypted: ${alice.syncRoom?.encrypted}',
        );

        debugPrint('\n--- Bob goes live');
        bob = await _createBobService(
          documentsDirectory: bobDocumentsDirectory,
          config: config2,
          loggingService: getIt<DomainLogger>(),
          journalDb: bobDb,
          settingsDb: bobSettingsDb,
          secureStorage: secureStorageMock,
          activityService: sharedUserActivityService,
          updateNotifications: mockUpdateNotifications,
          aiConfigRepository: sharedAiConfigRepository,
          syncDb: bobSyncDb,
          vectorClockService: bobVectorClockService,
        );
        bobInitialized = true;

        await bob.init();
        expect(bob.debugPipeline, isNotNull);

        // Allow time for constructor initialization to complete
        await Future<void>.delayed(const Duration(seconds: 1));

        await bob.login();
        debugPrint('Bob - deviceId: ${bob.client.deviceID}');

        debugPrint('\n--- Alice invites Bob into room $roomId');
        await inviteToTestSyncRoom(alice, userId: bobUserName);
        // Allow invite to propagate to Bob's homeserver before joining
        await waitSeconds(defaultDelay);

        final joinRes2 = await bob.joinRoom(roomId);
        debugPrint('Bob - room joined: $joinRes2');

        await _performSasVerification(
          alice: alice,
          bob: bob,
          timeout: timeout,
          defaultDelay: defaultDelay,
          addTearDown: addTearDown,
        );

        aliceOutbox = await _DeviceOutbox.create(
          matrixService: alice,
          journalDb: aliceDb,
          syncDb: aliceSyncDb,
          documentsDirectory: aliceDocumentsDirectory,
          userActivityService: sharedUserActivityService,
          loggingService: getIt<DomainLogger>(),
          vectorClockService: aliceVectorClockService,
          deviceName: 'aliceDeviceV2',
        );
        aliceOutboxInitialized = true;
        bobOutbox = await _DeviceOutbox.create(
          matrixService: bob,
          journalDb: bobDb,
          syncDb: bobSyncDb,
          documentsDirectory: bobDocumentsDirectory,
          userActivityService: sharedUserActivityService,
          loggingService: getIt<DomainLogger>(),
          vectorClockService: bobVectorClockService,
          deviceName: 'bobDeviceV2',
        );
        bobOutboxInitialized = true;

        const n = testSlowNetwork ? 10 : 100;
        // Each device now persists its own entries at send time (matching
        // production behavior) plus receives the other device's entries via
        // sync. Self-sent events are deduplicated by vector clock comparison.
        const expectedEntriesPerDb = 2 * n;

        debugPrint('\n--- Alice sends $n message');
        await _sendTestMessages(
          n,
          device: aliceOutbox,
          timeout: timeout,
        );

        debugPrint('\n--- Bob sends $n message');
        await _sendTestMessages(
          n,
          device: bobOutbox,
          timeout: timeout,
        );

        await alice.forceRescan();
        debugPrint(
          'Alice V2 metrics after rescan: '
          '${alice.debugPipeline?.metricsSnapshot()}',
        );
        await bob.forceRescan();
        debugPrint(
          'Bob V2 metrics after rescan: '
          '${bob.debugPipeline?.metricsSnapshot()}',
        );

        var lastAliceCount = -1;
        await waitUntilAsync(
          () async {
            final currentCount = await aliceDb.getJournalCount();
            if (currentCount != lastAliceCount) {
              debugPrint('Alice journal count: $currentCount');
              lastAliceCount = currentCount;
            }
            if (currentCount < expectedEntriesPerDb) {
              // Under degraded network, proactively drive catch-up and retries
              // while we wait to avoid long hangs on CI.
              await alice.forceRescan();
              await alice.retryNow();
              // Allow the homeserver to settle before the next fetch.
              await Future<void>.delayed(const Duration(milliseconds: 200));
            }
            return currentCount >= expectedEntriesPerDb;
          },
          timeout: timeout,
        );
        debugPrint('\n--- Alice finished receiving messages');
        final aliceEntriesCount = await aliceDb.getJournalCount();
        expect(aliceEntriesCount, expectedEntriesPerDb);
        debugPrint('Alice persisted $aliceEntriesCount entries');

        var lastBobCount = -1;
        await waitUntilAsync(
          () async {
            final currentCount = await bobDb.getJournalCount();
            if (currentCount != lastBobCount) {
              debugPrint('Bob journal count: $currentCount');
              lastBobCount = currentCount;
            }
            if (currentCount < expectedEntriesPerDb) {
              await bob.forceRescan();
              await bob.retryNow();
              // Allow the homeserver to settle before the next fetch.
              await Future<void>.delayed(const Duration(milliseconds: 200));
            }
            return currentCount >= expectedEntriesPerDb;
          },
          timeout: timeout,
        );
        debugPrint('\n--- Bob finished receiving messages');
        final bobEntriesCount = await bobDb.getJournalCount();
        expect(bobEntriesCount, expectedEntriesPerDb);
        debugPrint('Bob persisted $bobEntriesCount entries');
      },
      timeout: const Timeout(Duration(minutes: 15)),
      skip: skipReason ?? false,
    );

    test(
      'Image sync transfers metadata and exact file bytes to Bob',
      () async {
        const mediaTimeout = Duration(minutes: 3);
        final id = const Uuid().v1();
        final timestamp = DateTime.utc(2025, 2, 1, 12);
        final image = JournalImage(
          meta: _nextMediaMetadata(
            device: aliceOutbox,
            id: id,
            timestamp: timestamp,
          ),
          data: ImageData(
            capturedAt: timestamp,
            imageId: id,
            imageFile: '$id.png',
            imageDirectory: '/images/2025-02-01/',
          ),
          entryText: const EntryText(plainText: 'Matrix image fixture'),
        );
        final bytes = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
          'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        );

        final received = await _sendMediaEntity(
          entity: image,
          bytes: bytes,
          sender: aliceOutbox,
          receiver: bobOutbox,
          receiverService: bob,
          timeout: mediaTimeout,
        );

        expect(received, isA<JournalImage>());
        final receivedImage = received as JournalImage;
        expect(receivedImage.meta, image.meta);
        expect(receivedImage.data, image.data);
        expect(receivedImage.entryText, image.entryText);
      },
      timeout: const Timeout(Duration(minutes: 5)),
      skip: skipReason ?? false,
    );

    test(
      'Audio sync transfers metadata and exact file bytes to Alice',
      () async {
        const mediaTimeout = Duration(minutes: 3);
        final id = const Uuid().v1();
        final timestamp = DateTime.utc(2025, 2, 1, 13);
        final audio = JournalAudio(
          meta: _nextMediaMetadata(
            device: bobOutbox,
            id: id,
            timestamp: timestamp,
          ),
          data: AudioData(
            dateFrom: timestamp,
            dateTo: timestamp.add(const Duration(seconds: 1)),
            audioFile: '$id.wav',
            audioDirectory: '/audio/2025-02-01/',
            duration: const Duration(seconds: 1),
            language: 'en',
          ),
          entryText: const EntryText(plainText: 'Matrix audio fixture'),
        );
        final bytes = base64Decode(TestAudioData.shortSilenceWav);

        final received = await _sendMediaEntity(
          entity: audio,
          bytes: bytes,
          sender: bobOutbox,
          receiver: aliceOutbox,
          receiverService: alice,
          timeout: mediaTimeout,
        );

        expect(received, isA<JournalAudio>());
        final receivedAudio = received as JournalAudio;
        expect(receivedAudio.meta, audio.meta);
        expect(receivedAudio.data, audio.data);
        expect(receivedAudio.entryText, audio.entryText);
      },
      timeout: const Timeout(Duration(minutes: 5)),
      skip: skipReason ?? false,
    );

    test(
      'Late Megolm key survives Bob restart and clears the durable floor',
      () async {
        const lateKeyTimeout = Duration(minutes: 3);
        final bobCountBefore = await bobDb.getJournalCount();
        final bobDeviceId = bob.client.deviceID;
        expect(bobDeviceId, isNotNull);

        final bobDevice =
            alice.client.userDeviceKeys[bobUserName]?.deviceKeys[bobDeviceId];
        expect(
          bobDevice,
          isNotNull,
          reason: 'Alice must know Bob’s verified device after SAS setup',
        );
        expect(bobDevice!.directVerified, isTrue);

        try {
          // Exclude Bob from a freshly-created outbound Megolm session. Bob
          // still receives the room event, but Alice does not send its session
          // key until this test makes Bob eligible again.
          await bobDevice.setVerified(false, false);
          await alice.client.encryption!.keyManager
              .clearOrUseOutboundGroupSession(roomId, wipe: true);

          await _sendTestMessages(
            1,
            device: aliceOutbox,
            timeout: lateKeyTimeout,
          );

          int? floorBeforeRestart;
          await waitUntilAsync(
            () async {
              floorBeforeRestart = await bob.queueCoordinator.queue
                  .resumeFloorTs(roomId);
              return floorBeforeRestart != null;
            },
            timeout: lateKeyTimeout,
          );
          expect(await bobDb.getJournalCount(), bobCountBefore);

          // Tear down the whole receiving app while the ciphertext has no
          // queue row. The resume floor is the only Lotti-owned recovery
          // state that survives this point.
          await bobOutbox.service.dispose();
          bobOutboxInitialized = false;
          await bob.dispose();
          bobInitialized = false;
          final persistedMarker = await (bobSyncDb.select(
            bobSyncDb.queueMarkers,
          )..where((table) => table.roomId.equals(roomId))).getSingle();
          expect(persistedMarker.resumeFloorTs, floorBeforeRestart);

          bob = await _createBobService(
            documentsDirectory: bobDocumentsDirectory,
            config: config2,
            loggingService: getIt<DomainLogger>(),
            journalDb: bobDb,
            settingsDb: bobSettingsDb,
            secureStorage: secureStorageMock,
            activityService: sharedUserActivityService,
            updateNotifications: mockUpdateNotifications,
            aiConfigRepository: sharedAiConfigRepository,
            singleInstance: false,
            syncDb: bobSyncDb,
            vectorClockService: bobVectorClockService,
          );
          bobInitialized = true;
          await bob.init();
          expect(bob.debugPipeline, isNotNull);

          // Prove that restart alone cannot silently discard the unresolved
          // boundary: a real production bridge still sees ciphertext and must
          // leave the persisted floor in place.
          await bob.queueCoordinator.triggerBridge();
          expect(await bobDb.getJournalCount(), bobCountBefore);
          expect(
            await bob.queueCoordinator.queue.resumeFloorTs(roomId),
            floorBeforeRestart,
          );

          await bobDevice.setVerified(true, false);
          final outboundSession = alice.client.encryption!.keyManager
              .getOutboundGroupSession(roomId)
              ?.outboundGroupSession;
          expect(outboundSession, isNotNull);
          final aliceInboundSession = await alice.client.encryption!.keyManager
              .loadInboundGroupSession(roomId, outboundSession!.sessionId);
          final originalSessionKey =
              aliceInboundSession?.content['session_key'];
          expect(originalSessionKey, isA<String>());
          final roomKeyReceived = Completer<void>();
          final roomKeySub = bob.client.onToDeviceEvent.stream.listen((event) {
            if (!roomKeyReceived.isCompleted &&
                event.type == EventTypes.RoomKey &&
                event.content['session_id'] == outboundSession.sessionId) {
              roomKeyReceived.complete();
            }
          });
          // Send the exact current Megolm session through the SDK's real
          // encrypted to-device transport. Its next sync must store the key
          try {
            await alice.client.sendToDeviceEncrypted(
              [bobDevice],
              EventTypes.RoomKey,
              <String, Object?>{
                'algorithm': AlgorithmTypes.megolmV1AesSha2,
                'room_id': roomId,
                'session_id': outboundSession.sessionId,
                'session_key': originalSessionKey,
              },
            );
            // Make the restarted test client poll deterministically instead of
            // waiting for its background long-poll cadence.
            bob.client.backgroundSync = false;
            await bob.client.abortSync();
            await bob.client.oneShotSync(timeout: Duration.zero);
            await roomKeyReceived.future.timeout(lateKeyTimeout);
          } finally {
            await roomKeySub.cancel();
            bob.client.backgroundSync = true;
          }
          expect(
            await bob.client.encryption!.keyManager.loadInboundGroupSession(
              roomId,
              outboundSession.sessionId,
            ),
            isNotNull,
            reason: 'the restarted SDK must persist the real room key',
          );
          await bob.queueCoordinator.triggerBridge();

          await waitUntilAsync(
            () async =>
                await bobDb.getJournalCount() == bobCountBefore + 1 &&
                await bob.queueCoordinator.queue.resumeFloorTs(roomId) == null,
            timeout: lateKeyTimeout,
          );
          expect(
            await bob.queueCoordinator.queue.resumeFloorTs(roomId),
            isNull,
            reason: 'a completed post-key walk must clear the covered floor',
          );

          // Rewalking the same server history must dedupe by event id/vector
          // clock rather than apply the recovered bundle twice.
          await bob.queueCoordinator.triggerBridge();
          expect(await bobDb.getJournalCount(), bobCountBefore + 1);

          bobOutbox = await _DeviceOutbox.create(
            matrixService: bob,
            journalDb: bobDb,
            syncDb: bobSyncDb,
            documentsDirectory: bobDocumentsDirectory,
            userActivityService: sharedUserActivityService,
            loggingService: getIt<DomainLogger>(),
            vectorClockService: bobVectorClockService,
            deviceName: 'bobDeviceV2',
          );
          bobOutboxInitialized = true;
        } finally {
          if (!bobDevice.directVerified) {
            await bobDevice.setVerified(true, false);
          }
          await alice.client.encryption!.keyManager
              .clearOrUseOutboundGroupSession(roomId, wipe: true);
        }
      },
      // Four sequential operations use lateKeyTimeout. Keep the harness
      // budget above their combined diagnostic budgets so waitUntilAsync (or
      // the room-key timeout) reports the actual stalled phase.
      timeout: const Timeout(Duration(minutes: 15)),
      skip: skipReason ?? false,
    );

    test(
      'Bundled outbox convergence: Bob catches up after cold restart',
      () async {
        // Bob's app is closed while Alice accumulates local changes. Alice's
        // production outbox then drains them in bundles of up to 50 before Bob
        // reopens with the same persisted sync token, queue marker, and journal.
        const convergenceTimeout = Duration(minutes: 15);
        const n = testSlowNetwork ? 250 : 1000;

        // Snapshot Bob's DB count before this test's messages
        final bobCountBefore = await bobDb.getJournalCount();
        debugPrint('Bob DB count before convergence test: $bobCountBefore');

        // Phase 1: Dispose Bob entirely (simulates closing the app)
        debugPrint('\n--- Phase 1: Bob goes offline (full dispose)');
        await bobOutbox.service.dispose();
        bobOutboxInitialized = false;
        await bob.dispose();
        bobInitialized = false;
        debugPrint('Bob disposed');

        final bobCountWhileOffline = await bobDb.getJournalCount();
        debugPrint('Bob DB count while offline: $bobCountWhileOffline');
        expect(
          bobCountWhileOffline,
          bobCountBefore,
          reason: 'Bob count should not change while offline',
        );

        // Phase 2: Alice stages n entries, then the production outbox drains
        // them into ceil(n / 50) Matrix events while Bob is offline.
        debugPrint(
          '\n--- Phase 2: Alice drains $n outbox entries (Bob offline)',
        );
        final sendStopwatch = Stopwatch()..start();
        await _sendTestMessages(
          n,
          device: aliceOutbox,
          timeout: convergenceTimeout,
        );
        sendStopwatch.stop();
        debugPrint(
          'Alice finished sending $n outbox entries '
          'in ${sendStopwatch.elapsed.inSeconds}s',
        );

        // Verify Bob hasn't received anything while offline
        final bobCountAfterSend = await bobDb.getJournalCount();
        debugPrint(
          'Bob DB count after Alice sent (still offline): '
          '$bobCountAfterSend',
        );
        expect(
          bobCountAfterSend,
          bobCountBefore,
          reason: 'Bob should not have received messages while offline',
        );

        // Phase 3: Alice goes offline after sending
        debugPrint('\n--- Phase 3: Alice goes offline');
        alice.client.backgroundSync = false;
        await alice.client.abortSync();
        debugPrint('Alice is now offline (sync stopped)');

        // Phase 4: Bob cold-starts (fresh client + pipeline, same DB)
        debugPrint(
          '\n--- Phase 4: Bob cold-starts, catching up $n messages',
        );
        final expectedTotal = bobCountBefore + n;
        final catchupStopwatch = Stopwatch()..start();

        // Create a brand-new client that picks up the stored sync token
        // from the same DB path (simulates app relaunch).
        // Use singleInstance: false to avoid sqflite connection-cache
        // contention with the disposed first client's cached handle.
        bob = await _createBobService(
          documentsDirectory: bobDocumentsDirectory,
          config: config2,
          loggingService: getIt<DomainLogger>(),
          journalDb: bobDb,
          settingsDb: bobSettingsDb,
          secureStorage: secureStorageMock,
          activityService: sharedUserActivityService,
          updateNotifications: mockUpdateNotifications,
          aiConfigRepository: sharedAiConfigRepository,
          singleInstance: false,
          syncDb: bobSyncDb,
          vectorClockService: bobVectorClockService,
        );
        bobInitialized = true;

        await bob.init();
        expect(bob.debugPipeline, isNotNull);
        await Future<void>.delayed(const Duration(seconds: 1));

        await bob.login();
        debugPrint('Bob cold-started - deviceId: ${bob.client.deviceID}');

        // Do NOT set skipSyncWait — the production code path waits for the
        // SDK to complete a sync before running catch-up, which is essential
        // for populating the timeline with gap events.

        // Join the existing room (the new client needs to re-join)
        await bob.joinRoom(roomId);

        // Attach BEFORE saveRoom. saveRoom kicks the bootstrap asynchronously,
        // so a probe installed afterwards can miss a bridge that has already
        // finished — leaving a zero count that reads exactly like the "never
        // ran" diagnosis this instrumentation exists to disprove. (It did, on
        // the first instrumented run.)
        //
        // The metrics block printed later is not a substitute:
        // `catchupBatches`, `processed`, `skipped`, `failures`, `flushes`,
        // `retriesScheduled` and `circuitOpens` have zero call sites in lib/,
        // so they are structurally zero whatever sync does. Only `dbApplied`
        // is wired. Reading one of them as evidence is how this bug was first
        // misdiagnosed.
        var bridgeCompletions = 0;
        final priorOnBridgeCompleted = bob.queueCoordinator.onBridgeCompleted;
        bob.queueCoordinator.onBridgeCompleted = () {
          bridgeCompletions++;
          debugPrint('[probe] bridge completed #$bridgeCompletions');
          priorOnBridgeCompleted?.call();
        };

        // Save room so pipeline attaches to it (triggers start + forceRescan)
        await bob.saveRoom(roomId);
        debugPrint('Bob re-joined room $roomId');

        // Allow startup catch-up to run (sync wait is up to 30s, plus
        // catch-up pagination time for the backlog)
        await Future<void>.delayed(const Duration(seconds: 5));

        Future<String> queueSnapshot() async {
          final coord = bob.queueCoordinator;
          final stats = await coord.queue.stats();
          return 'queue[total=${stats.total} ready=${stats.readyNow} '
              'byProducer=${stats.byProducer} '
              'oldestEnqueuedAt=${stats.oldestEnqueuedAt}] '
              'coord.running=${coord.isRunning} '
              'bridgeInFlight=${coord.isBridgeInFlight} '
              'bridgeCompletions=$bridgeCompletions '
              'currentRoomId=${bob.syncRoomId} '
              'syncRoom=${bob.syncRoom != null}';
        }

        debugPrint(
          'Bob metrics after startup: '
          '${bob.debugPipeline?.metricsSnapshot()}',
        );
        debugPrint('Bob ${await queueSnapshot()}');

        var lastBobCount = -1;
        var stallProbeLastCount = -1;
        final sinceLastProgress = Stopwatch()..start();
        await waitUntilAsync(
          () async {
            final currentCount = await bobDb.getJournalCount();
            if (currentCount != lastBobCount) {
              final delta = currentCount - bobCountBefore;
              debugPrint(
                'Bob journal count: $currentCount '
                '(+$delta/$n new, '
                '${catchupStopwatch.elapsed.inSeconds}s elapsed)',
              );
              lastBobCount = currentCount;
            }
            // No manual forceRescan/retryNow — the pipeline must
            // self-drive catch-up through its signal-driven architecture.
            await throwIfStalled(
              device: bob,
              currentCount: currentCount,
              lastCount: stallProbeLastCount,
              sinceLastProgress: sinceLastProgress,
            );
            stallProbeLastCount = currentCount;
            if (currentCount < expectedTotal) {
              // Log metrics every ~30s to diagnose stalls
              final elapsed = catchupStopwatch.elapsed.inSeconds;
              if (elapsed > 0 && elapsed % 30 == 0) {
                debugPrint(
                  'Bob metrics @ ${elapsed}s: '
                  '${bob.debugPipeline?.metricsSnapshot()}',
                );
                debugPrint('Bob ${await queueSnapshot()}');
              }
              await Future<void>.delayed(const Duration(seconds: 1));
            }
            return currentCount >= expectedTotal;
          },
          timeout: convergenceTimeout,
        );
        catchupStopwatch.stop();

        // Phase 5: Assertions
        debugPrint('\n--- Phase 5: Assertions');
        final bobEntriesCount = await bobDb.getJournalCount();
        final newEntries = bobEntriesCount - bobCountBefore;
        final metricsMap = bob.debugPipeline?.metricsSnapshot();
        final metrics = metricsMap != null
            ? SyncMetrics.fromMap(Map<String, dynamic>.from(metricsMap))
            : null;

        debugPrint(
          'Bob converged $newEntries new entries '
          'in ${catchupStopwatch.elapsed.inSeconds}s '
          '(total: $bobEntriesCount)',
        );
        debugPrint('Bob final metrics: $metricsMap');

        // With sender-side DB persistence, the pre-context overlap window
        // events from test 1 are deduplicated by vector clock comparison,
        // so Bob should receive exactly n new entries.
        expect(newEntries, n);

        // Diagnostics only — deliberately not asserted on.
        //
        // The assertions that used to live here read `failures == 0` and
        // `circuitOpens == 0` on counters nothing ever incremented, so they
        // passed unconditionally. Replacing them with `dbApplied >= n` looked
        // right and was equally wrong: this harness leaves
        // `SyncEventProcessor.applyObserver` unwired, so every counter in the
        // snapshot reads 0 here even on a run that converges correctly.
        // Production wires the observer in `MatrixService`; see `get_it`.
        //
        // The real convergence check is `expect(newEntries, n)` above, which
        // counts rows in Bob's database rather than trusting a counter.
        if (metrics != null) {
          debugPrint('  dbApplied: ${metrics.dbApplied}');
          debugPrint(
            '  dbIgnoredByVectorClock: ${metrics.dbIgnoredByVectorClock}',
          );
          debugPrint('  conflictsCreated: ${metrics.conflictsCreated}');
          debugPrint('  queueAbandoned: ${metrics.queueAbandoned}');
        }

        // Bring Alice back online for clean teardown
        alice.client.backgroundSync = true;
      },
      timeout: const Timeout(Duration(minutes: 30)),
      skip: skipReason ?? false,
    );

    test(
      'Mid-drain rejoin: startup bridge overlaps production outbox bundles '
      'without duplicates or drops',
      () async {
        // Unlike the cold-start test above, Bob rejoins while Alice's single
        // production OutboxProcessor is paused mid-drain, so:
        //  - The startup bridge's `/messages` pagination backfills every
        //    bundle Alice sent while Bob was offline.
        //  - The outbox resumes as soon as Bob's room is saved, allowing live
        //    delivery while startup catch-up is active.
        //  - A deterministic full-history sweep collects anything sent after
        //    the startup bridge reached the server's then-current end.
        //  - Events near the bridge boundary are visited more than once;
        //    `event_id UNIQUE` in
        //    `inbound_event_queue` is the only primitive that keeps
        //    each event from applying twice.
        const convergenceTimeout = Duration(minutes: 15);
        const n = testSlowNetwork ? 150 : 600;
        const expectedMatrixEvents =
            (n + SyncTuning.outboxBundleMaxSize - 1) ~/
            SyncTuning.outboxBundleMaxSize;
        const bobRejoinAtPercent = 40;
        const calculatedRejoinEvents =
            (expectedMatrixEvents * bobRejoinAtPercent) ~/ 100;
        const rejoinAfterEvents = calculatedRejoinEvents == 0
            ? 1
            : calculatedRejoinEvents;
        final resumeDrain = Completer<void>();
        final sentEventsBefore = aliceOutbox.sender.sentEvents;
        final sentEntriesBefore = aliceOutbox.sender.sentEntries;
        var drainStarted = false;

        final bobCountBefore = await bobDb.getJournalCount();
        debugPrint(
          'Bob DB count before mid-burst test: $bobCountBefore',
        );

        // Phase 1: Dispose Bob so his client is offline for the first
        // half of Alice's burst. Keep his DB + settings intact so the
        // cold restart still has the last-applied marker.
        debugPrint('\n--- Phase 1: Bob goes offline (full dispose)');
        if (bobOutboxInitialized) {
          await bobOutbox.service.dispose();
          bobOutboxInitialized = false;
        }
        await bob.dispose();
        bobInitialized = false;

        // Phase 2: stage the full local backlog while sync is disabled, then
        // let the normal outbox runner drain it. The probe pauses before the
        // next bundle once 40% of Matrix events have been acknowledged.
        debugPrint(
          '\n--- Phase 2: Alice stages and drains $n outbox entries',
        );
        final aliceStopwatch = Stopwatch()..start();
        await _stageTestMessages(n, device: aliceOutbox);
        aliceOutbox.sender.beforeSend =
            (
              sentEvents,
              sentEntries,
              message,
            ) async {
              if (sentEvents - sentEventsBefore >= rejoinAfterEvents) {
                await resumeDrain.future;
              }
            };
        addTearDown(() async {
          if (!resumeDrain.isCompleted) {
            resumeDrain.complete();
          }
          aliceOutbox.sender.beforeSend = null;
          if (drainStarted) {
            await _waitForOutboxDrain(
              aliceOutbox,
              timeout: convergenceTimeout,
            );
          }
        });
        await _startStagedMessages(aliceOutbox);
        drainStarted = true;

        // Phase 3: Wait until the configured number of complete bundles has
        // landed, then cold-start Bob. The remaining drain resumes only after
        // Bob's startup bridge is in flight.
        debugPrint(
          '\n--- Phase 3: waiting for Alice to send '
          '$rejoinAfterEvents/$expectedMatrixEvents Matrix events',
        );
        await waitUntilAsync(
          () async =>
              aliceOutbox.sender.sentEvents - sentEventsBefore >=
              rejoinAfterEvents,
          timeout: convergenceTimeout,
        );
        final entriesSentWhileBobOffline =
            aliceOutbox.sender.sentEntries - sentEntriesBefore;
        debugPrint(
          'Alice sent $entriesSentWhileBobOffline/$n entries in '
          '$rejoinAfterEvents Matrix events before Bob starts',
        );

        // Phase 4: Bob cold-starts. Live timeline fires concurrently
        // with Alice's ongoing sends; the startup bridge runs a
        // `/messages` pass to backfill everything below its marker.
        debugPrint('\n--- Phase 4: Bob cold-starts mid-burst');
        final catchupStopwatch = Stopwatch()..start();
        bob = await _createBobService(
          documentsDirectory: bobDocumentsDirectory,
          config: config2,
          loggingService: getIt<DomainLogger>(),
          journalDb: bobDb,
          settingsDb: bobSettingsDb,
          secureStorage: secureStorageMock,
          activityService: sharedUserActivityService,
          updateNotifications: mockUpdateNotifications,
          aiConfigRepository: sharedAiConfigRepository,
          singleInstance: false,
          syncDb: bobSyncDb,
          vectorClockService: bobVectorClockService,
        );
        bobInitialized = true;

        await bob.init();
        expect(bob.debugPipeline, isNotNull);
        await Future<void>.delayed(const Duration(seconds: 1));
        await bob.login();
        debugPrint('Bob cold-started - deviceId: ${bob.client.deviceID}');

        await bob.joinRoom(roomId);
        var bridgeCompletions = 0;
        final priorOnBridgeCompleted = bob.queueCoordinator.onBridgeCompleted;
        bob.queueCoordinator.onBridgeCompleted = () {
          bridgeCompletions++;
          priorOnBridgeCompleted?.call();
        };
        await bob.saveRoom(roomId);
        debugPrint('Bob re-joined room $roomId mid-burst');

        expect(
          aliceOutbox.sender.sentEvents - sentEventsBefore,
          rejoinAfterEvents,
        );
        resumeDrain.complete();
        debugPrint(
          'Bob room is saved; Alice resumes the outbox drain',
        );
        await waitUntilAsync(
          () async => bridgeCompletions > 0,
          timeout: convergenceTimeout,
        );

        // Phase 5: wait for Alice's production outbox to drain so the target
        // count is stable.
        debugPrint('\n--- Phase 5: waiting for Alice outbox to drain');
        await _waitForOutboxDrain(
          aliceOutbox,
          timeout: convergenceTimeout,
        );
        aliceOutbox.sender.beforeSend = null;
        aliceStopwatch.stop();
        expect(aliceOutbox.sender.sentEntries - sentEntriesBefore, n);
        expect(
          aliceOutbox.sender.sentEvents - sentEventsBefore,
          expectedMatrixEvents,
        );
        debugPrint(
          'Alice sent $n entries as $expectedMatrixEvents Matrix events in '
          '${aliceStopwatch.elapsed.inSeconds}s',
        );

        // The startup bridge can finish before a polling interval now that the
        // offline prefix is a handful of real bundles rather than hundreds of
        // synthetic single-entry events. Its completion callback is durable;
        // sampling `isBridgeInFlight` could miss the whole pass. Verify that
        // completed pass covered the offline prefix, then run the production
        // full-history sweep for events sent after Bob rejoined.
        final coordinator = bob.queueCoordinator;
        await waitUntilAsync(
          () async =>
              await bobDb.getJournalCount() >=
              bobCountBefore + entriesSentWhileBobOffline,
          timeout: convergenceTimeout,
        );
        final countBeforeTailBridge = await bobDb.getJournalCount();
        debugPrint(
          'Startup bridge applied '
          '${countBeforeTailBridge - bobCountBefore}/$n new entries; '
          'running full-history sweep',
        );
        final historyResult = await coordinator.collectHistory(
          overallTimeout: convergenceTimeout,
        );
        expect(
          historyResult.stopReason,
          BootstrapStopReason.serverExhausted,
        );
        expect(
          historyResult.totalEvents,
          greaterThanOrEqualTo(expectedMatrixEvents),
        );

        // Phase 6: wait for Bob to converge after the overlapping startup
        // bridge and the full-history sweep.
        debugPrint('\n--- Phase 6: waiting for Bob to converge to $n new');
        final expectedTotal = bobCountBefore + n;
        var lastBobCount = -1;
        var stallProbeLastCount = -1;
        final sinceLastProgress = Stopwatch()..start();
        await waitUntilAsync(
          () async {
            final currentCount = await bobDb.getJournalCount();
            if (currentCount != lastBobCount) {
              final delta = currentCount - bobCountBefore;
              debugPrint(
                'Bob journal count: $currentCount (+$delta/$n, '
                '${catchupStopwatch.elapsed.inSeconds}s)',
              );
              lastBobCount = currentCount;
            }
            await throwIfStalled(
              device: bob,
              currentCount: currentCount,
              lastCount: stallProbeLastCount,
              sinceLastProgress: sinceLastProgress,
            );
            stallProbeLastCount = currentCount;
            if (currentCount < expectedTotal) {
              final elapsed = catchupStopwatch.elapsed.inSeconds;
              if (elapsed > 0 && elapsed % 30 == 0) {
                final coord = bob.queueCoordinator;
                final stats = await coord.queue.stats();
                debugPrint(
                  'Bob queue @ ${elapsed}s: total=${stats.total} '
                  'applied=${stats.applied} abandoned=${stats.abandoned} '
                  'retrying=${stats.retrying} '
                  'byProducer=${stats.byProducer}',
                );
              }
              await Future<void>.delayed(const Duration(seconds: 1));
            }
            return currentCount >= expectedTotal;
          },
          timeout: convergenceTimeout,
        );
        catchupStopwatch.stop();

        // The only thing we care about here is convergence: Bob
        // eventually sees every message Alice sent. No dropped events,
        // no duplicates. Internals (which producer delivered which
        // event, queue stats, pipeline metrics) are implementation
        // detail — this test does not pin them down.
        debugPrint('\n--- Phase 7: convergence check');
        final bobEntriesCount = await bobDb.getJournalCount();
        final newEntries = bobEntriesCount - bobCountBefore;
        expect(newEntries, n);
        debugPrint(
          'Bob converged $newEntries entries in '
          '${catchupStopwatch.elapsed.inSeconds}s',
        );
      },
      timeout: const Timeout(Duration(minutes: 30)),
      skip: skipReason ?? false,
    );
  });
}

/// Creates a fresh Bob [MatrixService] instance with a new Matrix client and
/// gateway. Used both for initial setup and cold-restart simulation.
Future<MatrixService> _createBobService({
  required Directory documentsDirectory,
  required MatrixConfig config,
  required DomainLogger loggingService,
  required JournalDb journalDb,
  required SettingsDb settingsDb,
  required SecureStorage secureStorage,
  required UserActivityService activityService,
  required MockUpdateNotifications updateNotifications,
  required AiConfigRepository aiConfigRepository,
  required SyncDatabase syncDb,
  required VectorClockService vectorClockService,
  bool? singleInstance,
}) async {
  final client = await createMatrixClient(
    documentsDirectory: documentsDirectory,
    dbName: 'BobV2',
    singleInstance: singleInstance,
  );
  final registry = SentEventRegistry();
  final gateway = MatrixSdkGateway(
    client: client,
    sentEventRegistry: registry,
  );
  return _createMatrixService(
    config: config,
    gateway: gateway,
    loggingService: loggingService,
    journalDb: journalDb,
    settingsDb: settingsDb,
    secureStorage: secureStorage,
    deviceName: 'BobV2',
    activityService: activityService,
    documentsDirectory: documentsDirectory,
    updateNotifications: updateNotifications,
    aiConfigRepository: aiConfigRepository,
    sentEventRegistry: registry,
    syncDb: syncDb,
    vectorClockService: vectorClockService,
  );
}

Future<void> _setMatrixSyncEnabled(JournalDb db, {required bool enabled}) {
  return db.upsertConfigFlag(
    ConfigFlag(
      name: enableMatrixFlag,
      description: 'Enable Matrix Sync',
      status: enabled,
    ),
  );
}

Metadata _nextMediaMetadata({
  required _DeviceOutbox device,
  required String id,
  required DateTime timestamp,
}) {
  final counter = device.nextCounter++;
  return Metadata(
    id: id,
    createdAt: timestamp,
    dateFrom: timestamp,
    dateTo: timestamp,
    updatedAt: timestamp,
    starred: true,
    vectorClock: VectorClock({device.deviceName: counter}),
  );
}

String _relativeMediaPath(JournalEntity entity) {
  return switch (entity) {
    JournalImage() => getRelativeImagePath(entity),
    JournalAudio() => AudioUtils.getRelativeAudioPath(entity),
    _ => throw ArgumentError.value(
      entity,
      'entity',
      'Expected JournalImage or JournalAudio',
    ),
  };
}

File _mediaFileFor(_DeviceOutbox device, JournalEntity entity) {
  return File('${device.documentsDirectory.path}${_relativeMediaPath(entity)}');
}

Future<JournalEntity> _sendMediaEntity({
  required JournalEntity entity,
  required List<int> bytes,
  required _DeviceOutbox sender,
  required _DeviceOutbox receiver,
  required MatrixService receiverService,
  required Duration timeout,
}) async {
  final sourceFile = _mediaFileFor(sender, entity);
  final receiverFile = _mediaFileFor(receiver, entity);
  expect(
    sourceFile.absolute.path,
    isNot(receiverFile.absolute.path),
    reason: 'simulated devices must use independent app sandboxes',
  );
  expect(
    receiverFile.existsSync(),
    isFalse,
    reason: 'the receiver must not start with the sender media file',
  );

  await _setMatrixSyncEnabled(sender.journalDb, enabled: false);
  try {
    final actionableBefore = await sender.syncDb.getOutboxItems(
      limit: 2,
      statuses: const [
        OutboxStatus.pending,
        OutboxStatus.sending,
        OutboxStatus.error,
      ],
    );
    expect(
      actionableBefore,
      isEmpty,
      reason: '${sender.deviceName} outbox must start drained',
    );

    await sourceFile.parent.create(recursive: true);
    await sourceFile.writeAsBytes(bytes, flush: true);
    await saveJournalEntityJson(
      entity,
      documentsDirectory: sender.documentsDirectory,
    );
    await sender.journalDb.updateJournalEntity(entity);
    await sender.service.enqueueMessage(
      SyncMessage.journalEntity(
        id: entity.meta.id,
        status: SyncEntryStatus.initial,
        vectorClock: entity.meta.vectorClock,
        jsonPath: relativeEntityPath(entity),
        originatingHostId: sender.deviceName,
      ),
    );

    final pending = await sender.syncDb.getOutboxItems(
      limit: 2,
      statuses: const [OutboxStatus.pending],
    );
    expect(pending, hasLength(1));
    expect(
      pending.single.filePath,
      isNotNull,
      reason: 'production outbox must classify media as an attachment row',
    );
  } finally {
    await _setMatrixSyncEnabled(sender.journalDb, enabled: true);
  }

  final sentEventsBefore = sender.sender.sentEvents;
  final sentEntriesBefore = sender.sender.sentEntries;
  final bundleCountBefore = sender.sender.bundleSizes.length;
  await sender.service.enqueueNextSendRequest(delay: Duration.zero);
  await _waitForOutboxDrain(sender, timeout: timeout);

  expect(sender.sender.sentEvents - sentEventsBefore, 1);
  expect(sender.sender.sentEntries - sentEntriesBefore, 1);
  expect(
    sender.sender.bundleSizes.sublist(bundleCountBefore),
    [1],
    reason: 'media rows must travel alone rather than in an outbox bundle',
  );

  JournalEntity? received;
  await waitUntilAsync(
    () async {
      received = await receiver.journalDb.journalEntityById(entity.meta.id);
      if (received != null &&
          receiverFile.existsSync() &&
          receiverFile.lengthSync() == bytes.length) {
        return true;
      }
      await receiverService.forceRescan();
      await receiverService.retryNow();
      return false;
    },
    timeout: timeout,
  );

  expect(received, isNotNull);
  expect(
    await receiverFile.readAsBytes(),
    orderedEquals(bytes),
    reason: 'Matrix must transfer the exact media payload between sandboxes',
  );
  return received!;
}

Future<void> _stageTestMessages(int n, {required _DeviceOutbox device}) async {
  await _setMatrixSyncEnabled(device.journalDb, enabled: false);

  final actionableBefore = await device.syncDb.getOutboxItems(
    limit: n + 1,
    statuses: const [
      OutboxStatus.pending,
      OutboxStatus.sending,
      OutboxStatus.error,
    ],
  );
  expect(
    actionableBefore,
    isEmpty,
    reason: '${device.deviceName} outbox must start each burst drained',
  );

  for (var index = 0; index < n; index++) {
    final counter = device.nextCounter++;
    final id = const Uuid().v1();
    final timestamp = DateTime.utc(
      2025,
    ).add(Duration(milliseconds: counter));
    final vectorClock = VectorClock({device.deviceName: counter});

    final entity = JournalEntry(
      meta: Metadata(
        id: id,
        createdAt: timestamp,
        dateFrom: timestamp,
        dateTo: timestamp,
        updatedAt: timestamp,
        starred: true,
        vectorClock: vectorClock,
      ),
      entryText: EntryText(
        plainText:
            'Test from ${device.deviceName} #$counter - '
            '${timestamp.toIso8601String()}',
      ),
    );

    final jsonPath = relativeEntityPath(entity);

    await saveJournalEntityJson(
      entity,
      documentsDirectory: device.documentsDirectory,
    );
    await device.journalDb.updateJournalEntity(entity);
    await device.service.enqueueMessage(
      SyncMessage.journalEntity(
        id: id,
        status: SyncEntryStatus.initial,
        vectorClock: vectorClock,
        jsonPath: jsonPath,
        originatingHostId: device.deviceName,
      ),
    );
  }

  final pending = await device.syncDb.getOutboxItems(
    limit: n + 1,
    statuses: const [OutboxStatus.pending],
  );
  expect(
    pending,
    hasLength(n),
    reason: 'Every local entry must be staged in the production outbox',
  );
}

Future<void> _startStagedMessages(_DeviceOutbox device) async {
  await _setMatrixSyncEnabled(device.journalDb, enabled: true);
  await device.service.enqueueNextSendRequest(delay: Duration.zero);
}

Future<void> _waitForOutboxDrain(
  _DeviceOutbox device, {
  required Duration timeout,
}) async {
  await waitUntilAsync(
    () async {
      final actionable = await device.syncDb.getOutboxItems(
        limit: 100,
        statuses: const [
          OutboxStatus.pending,
          OutboxStatus.sending,
          OutboxStatus.error,
        ],
      );
      final errors = actionable
          .where((item) => item.status == OutboxStatus.error.index)
          .toList();
      expect(
        errors,
        isEmpty,
        reason: '${device.deviceName} outbox must not strand failed rows',
      );
      return actionable.isEmpty;
    },
    timeout: timeout,
  );
}

Future<void> _sendTestMessages(
  int n, {
  required _DeviceOutbox device,
  required Duration timeout,
}) async {
  final sentEventsBefore = device.sender.sentEvents;
  final sentEntriesBefore = device.sender.sentEntries;
  final bundleCountBefore = device.sender.bundleSizes.length;

  await _stageTestMessages(n, device: device);
  await _startStagedMessages(device);
  await _waitForOutboxDrain(device, timeout: timeout);

  final sentEvents = device.sender.sentEvents - sentEventsBefore;
  final sentEntries = device.sender.sentEntries - sentEntriesBefore;
  final bundleSizes = device.sender.bundleSizes.sublist(bundleCountBefore);
  final expectedEvents =
      (n + SyncTuning.outboxBundleMaxSize - 1) ~/
      SyncTuning.outboxBundleMaxSize;

  expect(sentEntries, n);
  expect(
    sentEvents,
    expectedEvents,
    reason:
        'The production outbox should pack up to '
        '${SyncTuning.outboxBundleMaxSize} entries per Matrix event',
  );
  expect(
    bundleSizes,
    everyElement(inInclusiveRange(1, SyncTuning.outboxBundleMaxSize)),
  );
}

/// Performs SAS emoji verification between Alice (initiator) and Bob (responder).
/// Returns when both devices have no unverified devices remaining.
Future<void> _performSasVerification({
  required MatrixService alice,
  required MatrixService bob,
  required Duration timeout,
  required int defaultDelay,
  required void Function(Future<void> Function()) addTearDown,
}) async {
  // Diagnostic: print alice + bob device state periodically while
  // waiting, so a hang here is traceable to which side isn't seeing
  // the other. Runs for up to 15 s (5 ticks × 3 s); the main
  // `waitUntil` below still enforces the real 60 s timeout.
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(const Duration(seconds: 3));
    final aliceKeys = alice.client.userDeviceKeys;
    final bobKeys = bob.client.userDeviceKeys;
    debugPrint(
      '[sas.poll $i] alice.isLoggedIn=${alice.client.isLogged()} '
      'alice.userDeviceKeys.users=${aliceKeys.keys.toList()} '
      'alice.unverified=${alice.getUnverifiedDevices().length} '
      '| bob.isLoggedIn=${bob.client.isLogged()} '
      'bob.userDeviceKeys.users=${bobKeys.keys.toList()} '
      'bob.unverified=${bob.getUnverifiedDevices().length}',
    );
    if (alice.getUnverifiedDevices().isNotEmpty &&
        bob.getUnverifiedDevices().isNotEmpty) {
      break;
    }
  }

  // Wait for devices to discover each other
  await waitUntil(
    () => alice.getUnverifiedDevices().isNotEmpty,
    timeout: timeout,
  );
  await waitUntil(
    () => bob.getUnverifiedDevices().isNotEmpty,
    timeout: timeout,
  );

  final unverifiedAlice = alice.getUnverifiedDevices();
  final unverifiedBob = bob.getUnverifiedDevices();

  debugPrint('\nAlice - unverified: $unverifiedAlice');
  debugPrint('\nBob - unverified: $unverifiedBob');

  expect(unverifiedAlice, isNotNull);
  expect(unverifiedBob, isNotNull);

  final outgoingKeyVerificationStream = alice.keyVerificationStream;
  final incomingKeyVerificationRunnerStream =
      bob.incomingKeyVerificationRunnerStream;

  var emojisFromBob = '';
  var emojisFromAlice = '';

  final incomingSubscription = incomingKeyVerificationRunnerStream.listen(
    (runner) async {
      debugPrint(
        'Bob - incoming verification runner step: ${runner.lastStep}',
      );
      if (runner.lastStep == 'm.key.verification.request') {
        await runner.acceptVerification();
      }
      if (runner.lastStep == 'm.key.verification.key') {
        emojisFromAlice = extractEmojiString(runner.emojis);
        debugPrint('Bob received emojis: $emojisFromAlice');

        await waitUntil(
          () => emojisFromAlice == emojisFromBob && emojisFromAlice.isNotEmpty,
          timeout: timeout,
        );

        await runner.acceptEmojiVerification();
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      fail(
        'incomingKeyVerificationRunnerStream error: $error\n$stackTrace',
      );
    },
  );
  addTearDown(incomingSubscription.cancel);

  final outgoingSubscription = outgoingKeyVerificationStream.listen(
    (runner) async {
      debugPrint(
        'Alice - outgoing verification step: ${runner.lastStep}',
      );
      if (runner.lastStep == 'm.key.verification.key') {
        emojisFromBob = extractEmojiString(runner.emojis);
        debugPrint('Alice received emojis: $emojisFromBob');

        await waitUntil(
          () => emojisFromAlice == emojisFromBob && emojisFromBob.isNotEmpty,
          timeout: timeout,
        );

        await runner.acceptEmojiVerification();
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      fail(
        'keyVerificationStream error: $error\n$stackTrace',
      );
    },
  );
  addTearDown(outgoingSubscription.cancel);

  // Allow stream subscriptions to be fully established before initiating
  // verification
  await waitSeconds(defaultDelay);

  debugPrint('\n--- Alice verifies Bob');
  await alice.verifyDevice(unverifiedAlice.first);

  await waitUntil(() => emojisFromAlice.isNotEmpty, timeout: timeout);
  await waitUntil(
    () => emojisFromBob.isNotEmpty,
    timeout: timeout,
  );

  expect(emojisFromAlice, isNotEmpty);
  expect(emojisFromBob, isNotEmpty);
  expect(emojisFromAlice, emojisFromBob);

  debugPrint(
    '\n--- Alice and Bob both have no unverified devices',
  );

  await waitUntil(
    () => alice.getUnverifiedDevices().isEmpty,
    timeout: timeout,
  );
  await waitUntil(
    () => bob.getUnverifiedDevices().isEmpty,
    timeout: timeout,
  );

  expect(alice.getUnverifiedDevices(), isEmpty);
  expect(bob.getUnverifiedDevices(), isEmpty);
}

String extractEmojiString(Iterable<KeyVerificationEmoji>? emojis) {
  final buffer = StringBuffer();
  if (emojis != null) {
    for (final emoji in emojis) {
      buffer.write(' ${emoji.emoji}  ');
    }
  }
  return buffer.toString();
}
