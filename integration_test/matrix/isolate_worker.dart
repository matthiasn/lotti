import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
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
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../test/mocks/mocks.dart';
import '../../test/utils/utils.dart';
import 'isolate_messages.dart';
import 'test_utils.dart';

/// Entry point for Matrix client isolate.
///
/// This function runs in a separate isolate and handles all Matrix client
/// operations. It receives messages from the main isolate, processes them,
/// and sends responses back.
///
/// The isolate maintains its own:
/// - GetIt instance for dependency injection
/// - In-memory databases for testing
/// - Matrix client with its own SQLite database
/// - Message processing loop
Future<void> matrixClientIsolate(List<dynamic> args) async {
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
        await _handleInitMessage(
          message: message,
          isolateDebugPrint: isolateDebugPrint,
          mainSendPort: mainSendPort,
          getIt: getIt,
          onSuccess: (service, db, dir, name) {
            matrixService = service;
            journalDb = db;
            docDir = dir;
            deviceName = name;
          },
        );
      } else if (message is LoginMessage) {
        await _handleLoginMessage(
          matrixService: matrixService,
          deviceName: deviceName,
          isolateDebugPrint: isolateDebugPrint,
          mainSendPort: mainSendPort,
        );
      } else if (message is CreateRoomMessage) {
        await _handleCreateRoomMessage(
          matrixService: matrixService,
          mainSendPort: mainSendPort,
        );
      } else if (message is JoinRoomMessage) {
        await _handleJoinRoomMessage(
          message: message,
          matrixService: matrixService,
          mainSendPort: mainSendPort,
        );
      } else if (message is InviteUserMessage) {
        await _handleInviteUserMessage(
          message: message,
          matrixService: matrixService,
          mainSendPort: mainSendPort,
        );
      } else if (message is StartKeyVerificationMessage) {
        await _handleStartKeyVerificationMessage(
          matrixService: matrixService,
          deviceName: deviceName,
          isolateDebugPrint: isolateDebugPrint,
          mainSendPort: mainSendPort,
        );
      } else if (message is VerifyDeviceMessage) {
        await _handleVerifyDeviceMessage(
          matrixService: matrixService,
          mainSendPort: mainSendPort,
        );
      } else if (message is SendTestMessagesMessage) {
        await _handleSendTestMessagesMessage(
          message: message,
          matrixService: matrixService,
          deviceName: deviceName,
          mainSendPort: mainSendPort,
        );
      } else if (message is GetStatsMessage) {
        await _handleGetStatsMessage(
          matrixService: matrixService,
          journalDb: journalDb,
          mainSendPort: mainSendPort,
        );
      } else if (message is ShutdownMessage) {
        await _handleShutdownMessage(
          journalDb: journalDb,
          mainSendPort: mainSendPort,
        );
        break;
      } else {
        isolateDebugPrint(
            'Isolate: Unknown message type: ${message.runtimeType}');
      }
      isolateDebugPrint('Isolate: Ready for next message...');
    }
  } catch (e, stack) {
    isolateDebugPrint('Fatal error in isolate: $e\n$stack');
    mainSendPort.send(StatusResponse('Fatal isolate error: $e'));
  }
}

// Message handlers

Future<void> _handleInitMessage({
  required InitMessage message,
  required void Function(String) isolateDebugPrint,
  required SendPort mainSendPort,
  required GetIt getIt,
  required void Function(
    MatrixService service,
    JournalDb db,
    Directory dir,
    String name,
  ) onSuccess,
}) async {
  try {
    isolateDebugPrint(
        'Isolate: Received InitMessage for ${message.deviceName}');
    
    // Initialize dependencies
    final docDir = Directory(message.docDirPath);
    final deviceName = message.deviceName;

    isolateDebugPrint('Isolate $deviceName: Setting up mocks...');
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
    await vod.init();

    isolateDebugPrint('Isolate $deviceName: Creating journal database...');
    final journalDb = JournalDb(
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
    final client = await createInMemoryMatrixClient(
      dbName:
          '${deviceName}_isolate_${DateTime.now().millisecondsSinceEpoch}',
      deviceDisplayName: deviceName,
    );

    isolateDebugPrint('Isolate $deviceName: Creating MatrixService...');
    final matrixConfig = MatrixConfig(
      homeServer: message.homeServer,
      user: message.user,
      password: message.password,
    );

    final matrixService = MatrixService(
      matrixConfig: matrixConfig,
      client: client,
      deviceDisplayName: deviceName,
      overriddenJournalDb: journalDb,
      overriddenSettingsDb: SettingsDb(inMemoryDatabase: true),
      disableConnectivityMonitoring: true,
    );

    isolateDebugPrint(
        'Isolate $deviceName: Initialization complete, sending response...');
    
    onSuccess(matrixService, journalDb, docDir, deviceName);
    mainSendPort.send(StatusResponse('Initialized'));
  } catch (e, stack) {
    isolateDebugPrint('Isolate init failed with error: $e');
    isolateDebugPrint('Stack trace: $stack');
    mainSendPort.send(StatusResponse('Init failed: $e'));
  }
}

Future<void> _handleLoginMessage({
  required MatrixService? matrixService,
  required String? deviceName,
  required void Function(String) isolateDebugPrint,
  required SendPort mainSendPort,
}) async {
  isolateDebugPrint(
      'Isolate ${deviceName ?? "unknown"}: Received LoginMessage');
  try {
    if (matrixService == null || deviceName == null) {
      throw Exception(
          'MatrixService not initialized - InitMessage must be sent first');
    }
    
    isolateDebugPrint('Isolate $deviceName: Starting login...');
    
    // Call matrixConnect directly
    isolateDebugPrint('Isolate $deviceName: Checking homeserver...');
    await matrixService.client.checkHomeserver(
      Uri.parse(matrixService.matrixConfig!.homeServer),
    );

    isolateDebugPrint('Isolate $deviceName: Initializing client...');
    await matrixService.client.init(
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: false,
    );

    final isLoggedIn = matrixService.isLoggedIn();
    isolateDebugPrint('Isolate $deviceName: Is logged in: $isLoggedIn');

    if (!isLoggedIn) {
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
    }

    isolateDebugPrint(
        'Isolate $deviceName: Starting key verification listener...');
    await matrixService.startKeyVerificationListener();
    
    mainSendPort.send(
        StatusResponse('Logged in: ${matrixService.client.deviceID}'));
  } catch (e, stack) {
    isolateDebugPrint(
        'Isolate ${deviceName ?? "unknown"}: Login failed with error: $e');
    isolateDebugPrint('Stack trace: $stack');
    mainSendPort.send(StatusResponse('Login failed: $e'));
  }
}

Future<void> _handleCreateRoomMessage({
  required MatrixService? matrixService,
  required SendPort mainSendPort,
}) async {
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
}

Future<void> _handleJoinRoomMessage({
  required JoinRoomMessage message,
  required MatrixService? matrixService,
  required SendPort mainSendPort,
}) async {
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
}

Future<void> _handleInviteUserMessage({
  required InviteUserMessage message,
  required MatrixService? matrixService,
  required SendPort mainSendPort,
}) async {
  try {
    if (matrixService == null) {
      throw Exception('MatrixService not initialized');
    }
    await matrixService.inviteToSyncRoom(userId: message.userId);
    mainSendPort.send(StatusResponse('Invited user'));
  } catch (e) {
    mainSendPort.send(StatusResponse('Invite failed: $e'));
  }
}

Future<void> _handleStartKeyVerificationMessage({
  required MatrixService? matrixService,
  required String? deviceName,
  required void Function(String) isolateDebugPrint,
  required SendPort mainSendPort,
}) async {
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
}

Future<void> _handleVerifyDeviceMessage({
  required MatrixService? matrixService,
  required SendPort mainSendPort,
}) async {
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
}

Future<void> _handleSendTestMessagesMessage({
  required SendTestMessagesMessage message,
  required MatrixService? matrixService,
  required String? deviceName,
  required SendPort mainSendPort,
}) async {
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
}

Future<void> _handleGetStatsMessage({
  required MatrixService? matrixService,
  required JournalDb? journalDb,
  required SendPort mainSendPort,
}) async {
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
}

Future<void> _handleShutdownMessage({
  required JournalDb? journalDb,
  required SendPort mainSendPort,
}) async {
  try {
    if (journalDb != null) {
      await journalDb.close();
    }
    mainSendPort.send(StatusResponse('Shutdown complete'));
  } catch (e) {
    mainSendPort.send(StatusResponse('Shutdown failed: $e'));
  }
}

const uuid = Uuid();