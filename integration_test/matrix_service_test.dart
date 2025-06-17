import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:get_it/get_it.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../test/mocks/mocks.dart';
import '../test/utils/utils.dart';

Future<Client> createInMemoryMatrixClient({
  String? deviceDisplayName,
  String? dbName,
}) async {
  final database = await MatrixSdkDatabase.init(
    'lotti_sync',
    database: await databaseFactoryFfi.openDatabase(
      ':memory:',
      options: OpenDatabaseOptions(),
    ),
    sqfliteFactory: databaseFactoryFfi,
  );

  return Client(
    deviceDisplayName ?? 'lotti',
    verificationMethods: {
      KeyVerificationMethod.emoji,
      KeyVerificationMethod.reciprocate,
    },
    sendTimelineEventTimeout: const Duration(minutes: 2),
    database: database,
  );
}

// Message types for isolate communication
abstract class IsolateMessage {}

class InitMessage extends IsolateMessage {
  InitMessage({
    required this.homeServer,
    required this.user,
    required this.password,
    required this.deviceName,
    required this.docDirPath,
  });
  final String homeServer;
  final String user;
  final String password;
  final String deviceName;
  final String docDirPath;
}

class LoginMessage extends IsolateMessage {}

class CreateRoomMessage extends IsolateMessage {}

class JoinRoomMessage extends IsolateMessage {
  JoinRoomMessage(this.roomId);
  final String roomId;
}

class InviteUserMessage extends IsolateMessage {
  InviteUserMessage(this.userId);
  final String userId;
}

class StartKeyVerificationMessage extends IsolateMessage {}

class VerifyDeviceMessage extends IsolateMessage {}

class SendTestMessagesMessage extends IsolateMessage {
  SendTestMessagesMessage({
    required this.count,
    required this.roomId,
  });
  final int count;
  final String roomId;
}

class GetStatsMessage extends IsolateMessage {}

class ShutdownMessage extends IsolateMessage {}

// Response types
class RoomCreatedResponse {
  RoomCreatedResponse(this.roomId);
  final String roomId;
}

class StatsResponse {
  StatsResponse({
    required this.messageCount,
    required this.unverifiedDevices,
  });
  final int messageCount;
  final int unverifiedDevices;
}

class StatusResponse {
  StatusResponse(this.message);
  final String message;
}

class DebugMessage {
  DebugMessage(this.message);
  final String message;
}

// Isolate entry point for Matrix client
Future<void> _matrixClientIsolate(List<dynamic> args) async {
  final mainSendPort = args[0] as SendPort;
  final rootIsolateToken = args[1] as RootIsolateToken;

  void isolateDebugPrint(String message) {
    mainSendPort.send(DebugMessage(message));
  }

  // Override debugPrint to capture all debug output including from Matrix SDK
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      isolateDebugPrint(message);
    }
  };

  try {
    // Initialize the isolate for platform channels
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
    // Create a ReceivePort for this isolate
    final isolateReceivePort = ReceivePort();
    sqfliteFfiInit();

    // Send our SendPort back to the main isolate
    mainSendPort.send(isolateReceivePort.sendPort);

    // Initialize GetIt for this isolate - each isolate needs its own instance
    final getIt = GetIt.instance;
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    MatrixService? matrixService;
    JournalDb? journalDb;
    Directory? docDir;
    String? deviceName;

    // Listen for messages from orchestrator
    isolateDebugPrint('Isolate: Starting message listener loop...');
    await for (final message in isolateReceivePort) {
      if (message is InitMessage) {
        try {
          isolateDebugPrint(
              'Isolate: Received InitMessage for ${message.deviceName}');
          // Initialize dependencies
          docDir = Directory(message.docDirPath);
          deviceName = message.deviceName;

          final mockUpdateNotifications = MockUpdateNotifications();
          when(() => mockUpdateNotifications.updateStream).thenAnswer(
            (_) => Stream<Set<String>>.fromIterable([]),
          );
          when(() => mockUpdateNotifications.notify(any())).thenAnswer((_) {});

          isolateDebugPrint('Isolate $deviceName: Registering dependencies...');
          // Register all dependencies in this isolate's GetIt instance
          getIt
            ..registerSingleton<Directory>(docDir)
            ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
            ..registerSingleton<LoggingService>(LoggingService())
            ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
            ..registerSingleton<UserActivityService>(UserActivityService())
            ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
            ..registerSingleton<SettingsDb>(SettingsDb(inMemoryDatabase: true))
            ..registerSingleton<SecureStorage>(MockSecureStorage());

          isolateDebugPrint('Isolate $deviceName: Initializing vodozemac...');
          // Initialize vodozemac
          await vod.init();

          isolateDebugPrint(
              'Isolate $deviceName: Creating journal database...');
          // Create journal database
          journalDb = JournalDb(
            overriddenFilename: '${deviceName}_db.sqlite',
            inMemoryDatabase: true,
          );

          isolateDebugPrint('Isolate $deviceName: Creating Matrix client...');
          // Ensure the matrix directory exists
          final matrixDir = Directory('${docDir.path}/matrix');
          if (!matrixDir.existsSync()) {
            matrixDir.createSync(recursive: true);
            isolateDebugPrint('Isolate $deviceName: Created matrix directory');
          }

          // Create Matrix client with a unique database for this isolate
          // SQLite connections cannot be shared across isolates
          final client = await createInMemoryMatrixClient(
            dbName:
                '${deviceName}_isolate_${DateTime.now().millisecondsSinceEpoch}',
            deviceDisplayName: deviceName,
          );

          isolateDebugPrint('Isolate $deviceName: Creating MatrixService...');
          isolateDebugPrint(
              'Config - homeServer: ${message.homeServer}, user: ${message.user}');

          final matrixConfig = MatrixConfig(
            homeServer: message.homeServer,
            user: message.user,
            password: message.password,
          );

          // Ensure the client is properly initialized before creating MatrixService
          isolateDebugPrint(
              'Isolate $deviceName: Client state before MatrixService creation:');
          isolateDebugPrint('  - homeserver: ${client.homeserver}');
          isolateDebugPrint('  - isLogged: ${client.isLogged()}');

          // Disable connectivity monitoring in isolates
          // This is needed because Connectivity plugin doesn't work in isolates
          isolateDebugPrint(
              'Isolate $deviceName: About to create MatrixService...');
          try {
            matrixService = MatrixService(
              matrixConfig: matrixConfig,
              client: client,
              deviceDisplayName: deviceName,
              overriddenJournalDb: journalDb,
              overriddenSettingsDb: SettingsDb(inMemoryDatabase: true),
              disableConnectivityMonitoring: true,
            );
            isolateDebugPrint(
                'Isolate $deviceName: MatrixService created successfully');
          } catch (e) {
            isolateDebugPrint('Error creating MatrixService: $e');
            rethrow;
          }

          isolateDebugPrint(
              'Isolate $deviceName: Initialization complete, sending response...');
          mainSendPort.send(StatusResponse('Initialized'));
          isolateDebugPrint(
              'Isolate $deviceName: Init complete, continuing to listen for messages...');
        } catch (e, stack) {
          isolateDebugPrint('Isolate $deviceName: Init failed with error: $e');
          isolateDebugPrint('Stack trace: $stack');
          mainSendPort.send(StatusResponse('Init failed: $e'));
        }
      } else if (message is LoginMessage) {
        isolateDebugPrint(
            'Isolate ${deviceName ?? "unknown"}: Received LoginMessage');
        try {
          if (matrixService == null || deviceName == null) {
            throw Exception(
                'MatrixService not initialized - InitMessage must be sent first');
          }
          isolateDebugPrint('Isolate $deviceName: Starting login...');
          isolateDebugPrint(
              'Isolate $deviceName: MatrixService instance: $matrixService');
          isolateDebugPrint(
              'Isolate $deviceName: Client instance: ${matrixService.client}');
          isolateDebugPrint(
              'Isolate $deviceName: Calling matrixService.login()...');

          // Check if matrixConfig is present
          if (matrixService.matrixConfig == null) {
            isolateDebugPrint(
                'Isolate $deviceName: ERROR - matrixConfig is null!');
          } else {
            isolateDebugPrint('Isolate $deviceName: matrixConfig present');
            isolateDebugPrint(
                '  - homeServer: ${matrixService.matrixConfig!.homeServer}');
            isolateDebugPrint('  - user: ${matrixService.matrixConfig!.user}');
          }

          bool loginResult;
          try {
            // Call matrixConnect directly to get better debugging
            isolateDebugPrint(
                'Isolate $deviceName: Calling matrixConnect directly...');

            // First, try to check the homeserver
            try {
              isolateDebugPrint('Isolate $deviceName: Checking homeserver...');
              final homeserverInfo = await matrixService.client.checkHomeserver(
                Uri.parse(matrixService.matrixConfig!.homeServer),
              );
              isolateDebugPrint(
                  'Isolate $deviceName: Homeserver check successful: $homeserverInfo');
            } catch (e) {
              isolateDebugPrint(
                  'Isolate $deviceName: Homeserver check failed: $e');
              throw e;
            }

            // Initialize the client
            try {
              isolateDebugPrint('Isolate $deviceName: Initializing client...');
              await matrixService.client.init(
                waitForFirstSync: false,
                waitUntilLoadCompletedLoaded: false,
              );
              isolateDebugPrint(
                  'Isolate $deviceName: Client initialized successfully');
            } catch (e) {
              isolateDebugPrint('Isolate $deviceName: Client init failed: $e');
              throw e;
            }

            // Check if already logged in
            isolateDebugPrint('Isolate $deviceName: Checking login status...');
            final isLoggedIn = matrixService.isLoggedIn();
            isolateDebugPrint('Isolate $deviceName: Is logged in: $isLoggedIn');

            if (!isLoggedIn) {
              // Attempt login
              try {
                isolateDebugPrint('Isolate $deviceName: Attempting login...');
                final loginResponse = await matrixService.client.login(
                  LoginType.mLoginPassword,
                  identifier: AuthenticationUserIdentifier(
                      user: matrixService.matrixConfig!.user),
                  password: matrixService.matrixConfig!.password,
                  initialDeviceDisplayName: deviceName,
                );
                isolateDebugPrint(
                    'Isolate $deviceName: Login successful! Device ID: ${loginResponse.deviceId}');
                matrixService.loginResponse = loginResponse;
                loginResult = true;
              } catch (e) {
                isolateDebugPrint('Isolate $deviceName: Login failed: $e');
                loginResult = false;
              }
            } else {
              loginResult = true;
            }

            isolateDebugPrint(
                'Isolate $deviceName: Final login result: $loginResult');
          } catch (loginError, loginStack) {
            isolateDebugPrint(
                'Isolate $deviceName: Login threw exception: $loginError');
            isolateDebugPrint('Stack: $loginStack');
            rethrow;
          }
          if (!loginResult) {
            throw Exception('Login failed - matrixConnect returned false');
          }
          isolateDebugPrint(
              'Isolate $deviceName: Login successful, starting key verification listener...');
          await matrixService.startKeyVerificationListener();
          isolateDebugPrint(
              'Isolate $deviceName: Login complete, device ID: ${matrixService.client.deviceID}');
          mainSendPort.send(
              StatusResponse('Logged in: ${matrixService.client.deviceID}'));
        } catch (e, stack) {
          isolateDebugPrint(
              'Isolate ${deviceName ?? "unknown"}: Login failed with error: $e');
          isolateDebugPrint('Stack trace: $stack');
          mainSendPort.send(StatusResponse('Login failed: $e'));
        }
      } else if (message is CreateRoomMessage) {
        try {
          if (matrixService == null) {
            throw Exception('MatrixService not initialized');
          }
          final roomId = await matrixService.createRoom();
          await matrixService.joinRoom(roomId);
          await matrixService.listenToTimeline();
          mainSendPort.send(RoomCreatedResponse(roomId));
        } catch (e) {
          mainSendPort.send(StatusResponse('Create room failed: $e'));
        }
      } else if (message is JoinRoomMessage) {
        try {
          if (matrixService == null) {
            throw Exception('MatrixService not initialized');
          }
          await matrixService.joinRoom(message.roomId);
          await matrixService.listenToTimeline();
          mainSendPort.send(StatusResponse('Joined room'));
        } catch (e) {
          mainSendPort.send(StatusResponse('Join room failed: $e'));
        }
      } else if (message is InviteUserMessage) {
        try {
          if (matrixService == null) {
            throw Exception('MatrixService not initialized');
          }
          await matrixService.inviteToSyncRoom(userId: message.userId);
          mainSendPort.send(StatusResponse('Invited user'));
        } catch (e) {
          mainSendPort.send(StatusResponse('Invite failed: $e'));
        }
      } else if (message is StartKeyVerificationMessage) {
        try {
          if (matrixService == null || deviceName == null) {
            throw Exception('MatrixService not initialized');
          }
          // Set up verification listeners
          final unverifiedDevices = matrixService.getUnverifiedDevices();
          if (unverifiedDevices.isNotEmpty) {
            // Handle outgoing verification
            unawaited(
              matrixService.keyVerificationStream.forEach((runner) async {
                isolateDebugPrint(
                    '$deviceName - verification step: ${runner.lastStep}');
                isolateDebugPrint(
                    '$deviceName - emojis: ${runner.emojis?.map((e) => e.emoji).join(" ")}');
                if (runner.lastStep == 'm.key.verification.key') {
                  await runner.acceptEmojiVerification();
                  isolateDebugPrint(
                      '$deviceName - accepted emoji verification');
                }
              }),
            );

            // Handle incoming verification
            unawaited(
              matrixService.incomingKeyVerificationRunnerStream
                  .forEach((runner) async {
                isolateDebugPrint(
                    '$deviceName - incoming verification: ${runner.lastStep}');
                isolateDebugPrint(
                    '$deviceName - incoming emojis: ${runner.emojis?.map((e) => e.emoji).join(" ")}');
                if (runner.lastStep == 'm.key.verification.request') {
                  await runner.acceptVerification();
                  isolateDebugPrint(
                      '$deviceName - accepted verification request');
                }
                if (runner.lastStep == 'm.key.verification.key') {
                  await runner.acceptEmojiVerification();
                  isolateDebugPrint(
                      '$deviceName - accepted incoming emoji verification');
                }
              }),
            );
          }
          mainSendPort.send(StatusResponse('Verification listeners started'));
        } catch (e) {
          mainSendPort.send(StatusResponse('Start verification failed: $e'));
        }
      } else if (message is VerifyDeviceMessage) {
        try {
          if (matrixService == null) {
            throw Exception('MatrixService not initialized');
          }
          final unverifiedDevices = matrixService.getUnverifiedDevices();
          if (unverifiedDevices.isNotEmpty) {
            await matrixService.verifyDevice(unverifiedDevices.first);
          }
          mainSendPort.send(StatusResponse('Device verified'));
        } catch (e) {
          mainSendPort.send(StatusResponse('Verify device failed: $e'));
        }
      } else if (message is SendTestMessagesMessage) {
        try {
          if (matrixService == null || deviceName == null) {
            throw Exception('MatrixService not initialized');
          }
          for (var i = 0; i < message.count; i++) {
            final id = const Uuid().v1();
            final now = DateTime.now();

            final entity = JournalEntry(
              meta: Metadata(
                id: id,
                createdAt: now,
                dateFrom: now,
                dateTo: now,
                updatedAt: now,
                starred: true,
                vectorClock: VectorClock({deviceName: i}),
              ),
              entryText: EntryText(
                plainText: 'Test from $deviceName #$i - $now',
              ),
            );

            final jsonPath = relativeEntityPath(entity);
            await saveJournalEntityJson(entity);

            await matrixService.sendMatrixMsg(
              SyncMessage.journalEntity(
                id: id,
                status: SyncEntryStatus.initial,
                vectorClock: VectorClock({deviceName: i}),
                jsonPath: jsonPath,
              ),
              myRoomId: message.roomId,
            );
          }
          mainSendPort.send(StatusResponse('Messages sent'));
        } catch (e) {
          mainSendPort.send(StatusResponse('Send messages failed: $e'));
        }
      } else if (message is GetStatsMessage) {
        try {
          if (matrixService == null || journalDb == null) {
            throw Exception('MatrixService or JournalDb not initialized');
          }
          final messageCount = await journalDb.getJournalCount();
          final unverifiedDevices = matrixService.getUnverifiedDevices().length;
          mainSendPort.send(StatsResponse(
            messageCount: messageCount,
            unverifiedDevices: unverifiedDevices,
          ));
        } catch (e) {
          mainSendPort.send(StatusResponse('Get stats failed: $e'));
        }
      } else if (message is ShutdownMessage) {
        try {
          if (journalDb != null) {
            await journalDb.close();
          }
          mainSendPort.send(StatusResponse('Shutdown complete'));
          break;
        } catch (e) {
          mainSendPort.send(StatusResponse('Shutdown failed: $e'));
        }
      } else {
        isolateDebugPrint(
            'Isolate: Unknown message type: ${message.runtimeType}');
        isolateDebugPrint('Isolate: Message toString: $message');
        if (message is IsolateMessage) {
          isolateDebugPrint('Isolate: Message is IsolateMessage subtype');
        }
      }
      isolateDebugPrint('Isolate: Ready for next message...');
    }
  } catch (e, stack) {
    isolateDebugPrint('Fatal error in isolate: $e\n$stack');
    mainSendPort.send(StatusResponse('Fatal isolate error: $e'));
  }
}

// Helper class to manage isolate communication
class MatrixTestClient {
  MatrixTestClient({
    required this.name,
    required this.config,
  });

  final String name;
  final MatrixConfig config;
  Isolate? isolate;
  SendPort? sendPort;
  final _responseController = StreamController<dynamic>.broadcast();
  bool _isInitialized = false;

  Stream<dynamic> get responses => _responseController.stream;

  Future<void> start(String docDirPath) async {
    debugPrint('$name: Starting isolate...');
    final receivePort = ReceivePort();
    final completer = Completer<SendPort>();

    receivePort.listen((message) {
      debugPrint('$name: Received message type: ${message.runtimeType}');
      if (message is SendPort) {
        debugPrint('$name: Received SendPort from isolate');
        completer.complete(message);
      } else if (message is DebugMessage) {
        debugPrint('[ISOLATE $name] ${message.message}');
      } else {
        _responseController.add(message);
      }
    });

    debugPrint('$name: Spawning isolate...');
    final rootIsolateToken = RootIsolateToken.instance!;
    isolate = await Isolate.spawn(
      _matrixClientIsolate,
      [receivePort.sendPort, rootIsolateToken],
    );

    debugPrint('$name: Waiting for SendPort...');
    sendPort = await completer.future.timeout(const Duration(seconds: 10),
        onTimeout: () {
      throw TimeoutException('Failed to receive SendPort from isolate');
    });
    _isInitialized = true;
    debugPrint('$name: Got SendPort, sending init message...');
    debugPrint('$name: SendPort hashCode: ${sendPort.hashCode}');

    // Initialize the isolate
    sendPort!.send(InitMessage(
      homeServer: config.homeServer,
      user: config.user,
      password: config.password,
      deviceName: name,
      docDirPath: docDirPath,
    ));

    debugPrint('$name: Waiting for initialization response...');
    await _waitForResponse<StatusResponse>((r) => r.message == 'Initialized')
        .timeout(const Duration(seconds: 30), onTimeout: () {
      throw TimeoutException('Isolate initialization timeout');
    });
    debugPrint('$name: Initialization complete!');
  }

  Future<T> _waitForResponse<T>(bool Function(T) predicate) async {
    final response =
        await responses.where((r) => r is T).cast<T>().firstWhere(predicate);
    return response;
  }

  Future<void> login() async {
    _ensureInitialized();
    debugPrint('$name: Sending LoginMessage to isolate...');
    debugPrint('$name: SendPort is: $sendPort');
    debugPrint('$name: SendPort hashCode: ${sendPort.hashCode}');
    debugPrint('$name: LoginMessage type: ${LoginMessage().runtimeType}');
    // Add a small delay to ensure the isolate is ready
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // First try sending a simple string to test the port
    sendPort!.send('TEST_STRING');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    sendPort!.send(LoginMessage());
    debugPrint('$name: LoginMessage sent, waiting for response...');
    await _waitForResponse<StatusResponse>(
            (r) => r.message.startsWith('Logged in'))
        .timeout(const Duration(seconds: 30), onTimeout: () {
      throw TimeoutException('Login timeout after 30 seconds');
    });
  }

  Future<String> createRoom() async {
    _ensureInitialized();
    sendPort!.send(CreateRoomMessage());
    final response = await _waitForResponse<RoomCreatedResponse>((_) => true);
    return response.roomId;
  }

  Future<void> joinRoom(String roomId) async {
    _ensureInitialized();
    sendPort!.send(JoinRoomMessage(roomId));
    await _waitForResponse<StatusResponse>((r) => r.message == 'Joined room');
  }

  Future<void> inviteUser(String userId) async {
    _ensureInitialized();
    sendPort!.send(InviteUserMessage(userId));
    await _waitForResponse<StatusResponse>((r) => r.message == 'Invited user');
  }

  Future<void> startKeyVerification() async {
    _ensureInitialized();
    sendPort!.send(StartKeyVerificationMessage());
    await _waitForResponse<StatusResponse>(
        (r) => r.message == 'Verification listeners started');
  }

  Future<void> verifyDevice() async {
    _ensureInitialized();
    sendPort!.send(VerifyDeviceMessage());
    await _waitForResponse<StatusResponse>(
        (r) => r.message == 'Device verified');
  }

  Future<void> sendTestMessages(int count, String roomId) async {
    _ensureInitialized();
    sendPort!.send(SendTestMessagesMessage(count: count, roomId: roomId));
    await _waitForResponse<StatusResponse>((r) => r.message == 'Messages sent');
  }

  Future<StatsResponse> getStats() async {
    _ensureInitialized();
    sendPort!.send(GetStatsMessage());
    return _waitForResponse<StatsResponse>((_) => true);
  }

  Future<void> shutdown() async {
    if (_isInitialized && sendPort != null) {
      sendPort!.send(ShutdownMessage());
      try {
        await _waitForResponse<StatusResponse>(
                (r) => r.message == 'Shutdown complete')
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Error during shutdown: $e');
      }
    }
    isolate?.kill();
    await _responseController.close();
  }

  void _ensureInitialized() {
    if (!_isInitialized || sendPort == null) {
      throw StateError('MatrixTestClient not initialized. Call start() first.');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MatrixService Tests', () {
    const testUserEnv1 = 'TEST_USER1';
    const testUserEnv2 = 'TEST_USER2';
    const testServerEnv = 'TEST_SERVER';
    const testPasswordEnv = 'TEST_PASSWORD';
    const testSlowNetworkEnv = 'SLOW_NETWORK';

    const testSlowNetwork = bool.fromEnvironment(testSlowNetworkEnv);

    if (testSlowNetwork) {
      debugPrint('Testing with degraded network.');
    }

    if (!const bool.hasEnvironment(testUserEnv1)) {
      debugPrint('TEST_USER1 not defined!!! Run via run_matrix_tests.sh');
      exit(1);
    }

    if (!const bool.hasEnvironment(testUserEnv2)) {
      debugPrint('TEST_USER2 not defined!!! Run via run_matrix_tests.sh');
      exit(1);
    }

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

    test(
      'Create room & join',
      () async {
        // Note: This test requires a running Matrix server
        // Run via integration_test/run_matrix_tests.sh which will:
        // 1. Start the dendrite server via docker
        // 2. Create test users
        // 3. Run this test with proper environment variables
        final tmpDir = await getTemporaryDirectory();
        final docDir = Directory('${tmpDir.path}/${uuid.v1()}')
          ..createSync(recursive: true);
        debugPrint('Created temporary docDir ${docDir.path}');

        // Create test clients in isolates
        final alice = MatrixTestClient(name: 'Alice', config: config1);
        final bob = MatrixTestClient(name: 'Bob', config: config2);

        try {
          // Start isolates
          debugPrint('\n--- Starting Alice isolate');
          await alice.start(docDir.path);

          debugPrint('\n--- Starting Bob isolate');
          await bob.start(docDir.path);

          // Login
          debugPrint('\n--- Alice goes live');
          await alice.login();

          debugPrint('\n--- Bob goes live');
          await bob.login();

          // Create and join room
          debugPrint('\n--- Alice creates room');
          final roomId = await alice.createRoom();
          debugPrint('Alice - room created: $roomId');
          expect(roomId, isNotEmpty);

          // Invite Bob
          debugPrint('\n--- Alice invites Bob into room $roomId');
          await alice.inviteUser(bobUserName);
          await waitSeconds(defaultDelay);

          // Bob joins
          debugPrint('\n--- Bob joins room');
          await bob.joinRoom(roomId);
          await waitSeconds(defaultDelay);

          // Start key verification
          debugPrint('\n--- Starting key verification');
          await alice.startKeyVerification();
          await bob.startKeyVerification();
          await waitSeconds(defaultDelay);

          // Wait for unverified devices
          StatsResponse aliceStats;
          StatsResponse bobStats;
          do {
            await waitSeconds(1);
            aliceStats = await alice.getStats();
            bobStats = await bob.getStats();
          } while (aliceStats.unverifiedDevices == 0 ||
              bobStats.unverifiedDevices == 0);

          debugPrint(
              '\nAlice - unverified devices: ${aliceStats.unverifiedDevices}');
          debugPrint('Bob - unverified devices: ${bobStats.unverifiedDevices}');

          // Verify devices
          debugPrint('\n--- Alice verifies Bob');
          await alice.verifyDevice();
          await waitSeconds(defaultDelay);

          // Wait for verification to complete
          do {
            await waitSeconds(1);
            aliceStats = await alice.getStats();
            bobStats = await bob.getStats();
          } while (aliceStats.unverifiedDevices > 0 ||
              bobStats.unverifiedDevices > 0);

          debugPrint('\n--- Alice and Bob both have no unverified devices');
          expect(aliceStats.unverifiedDevices, 0);
          expect(bobStats.unverifiedDevices, 0);

          // Send test messages
          const n = testSlowNetwork ? 10 : 100;

          debugPrint('\n--- Alice sends $n messages');
          await alice.sendTestMessages(n, roomId);

          debugPrint('\n--- Bob sends $n messages');
          await bob.sendTestMessages(n, roomId);

          // Wait for messages to be received
          debugPrint('\n--- Waiting for messages to be received');
          do {
            await waitSeconds(2);
            aliceStats = await alice.getStats();
            bobStats = await bob.getStats();
            debugPrint(
                'Alice: ${aliceStats.messageCount}, Bob: ${bobStats.messageCount}');
          } while (aliceStats.messageCount < n || bobStats.messageCount < n);

          debugPrint('\n--- Alice finished receiving messages');
          expect(aliceStats.messageCount, n);
          debugPrint('Alice persisted ${aliceStats.messageCount} entries');

          debugPrint('\n--- Bob finished receiving messages');
          expect(bobStats.messageCount, n);
          debugPrint('Bob persisted ${bobStats.messageCount} entries');
        } finally {
          // Clean up
          debugPrint('\n--- Shutting down isolates');
          await alice.shutdown();
          await bob.shutdown();
        }
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  });
}

const uuid = Uuid();
