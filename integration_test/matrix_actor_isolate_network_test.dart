import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/actor/sync_actor_host.dart';

const _defaultMatrixServer = 'http://localhost:8008';
const _testUser = String.fromEnvironment('TEST_USER');
const _testPassword = String.fromEnvironment('TEST_PASSWORD');
const _maxSendRetries = 15;
const _baseRetryDelay = Duration(milliseconds: 250);

Future<void> _waitUntil({
  required String message,
  required Future<bool> Function() condition,
  Duration timeout = const Duration(seconds: 20),
  Duration interval = const Duration(milliseconds: 250),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) {
      return;
    }
    await Future<void>.delayed(interval);
  }

  fail('$message after ${timeout.inSeconds}s');
}

Future<Map<String, Object?>> _sendTextWithRetries({
  required SyncActorHost host,
  required String roomId,
  required String message,
}) async {
  Object? lastError;
  for (var attempt = 1; attempt <= _maxSendRetries; attempt++) {
    debugPrint('[TEST] Sending text attempt $attempt/$_maxSendRetries...');
    final sendResult = await host.send(
      'sendText',
      payload: {
        'roomId': roomId,
        'message': message,
        'messageType': 'm.text',
      },
    );

    if (sendResult['ok'] == true) {
      return sendResult;
    }

    lastError = sendResult['error'];
    debugPrint('[TEST] sendText attempt $attempt failed: $sendResult');

    await Future<void>.delayed(Duration(
      milliseconds: _baseRetryDelay.inMilliseconds +
          (attempt * _baseRetryDelay.inMilliseconds ~/ 2),
    ));
  }

  return {
    'ok': false,
    'error': lastError ?? 'sendText failed after retries',
    'attempts': _maxSendRetries,
  };
}

String get _matrixServer {
  const fromEnv = String.fromEnvironment('TEST_SERVER');
  if (fromEnv.isNotEmpty) {
    return fromEnv;
  }
  return _defaultMatrixServer;
}

Future<bool> _isMatrixReachable(String baseUrl) async {
  final client = HttpClient();
  try {
    final request =
        await client.getUrl(Uri.parse('$baseUrl/_matrix/client/versions'));
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode == HttpStatus.ok;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

int _deviceKeyCount(Map<String, Object?> health) {
  final deviceKeys = health['deviceKeys'];
  if (deviceKeys is! Map) {
    return 0;
  }
  final count = deviceKeys['count'];
  return count is int ? count : 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Matrix isolate actor network integration', () {
    test(
      'single-user two-device flow via production SyncActorHost',
      () async {
        final baseUrl = _matrixServer;
        final reachable = await _isMatrixReachable(baseUrl);
        if (!reachable) {
          fail('Matrix homeserver is not reachable at $baseUrl');
        }

        if (_testUser.isEmpty || _testPassword.isEmpty) {
          fail('TEST_USER/TEST_PASSWORD not provided via --dart-define');
        }

        final dbRoot1 =
            await Directory.systemTemp.createTemp('actor_host_dev1_');
        final dbRoot2 =
            await Directory.systemTemp.createTemp('actor_host_dev2_');
        addTearDown(() async {
          // ignore: avoid_slow_async_io
          if (await dbRoot1.exists()) {
            await dbRoot1.delete(recursive: true);
          }
          // ignore: avoid_slow_async_io
          if (await dbRoot2.exists()) {
            await dbRoot2.delete(recursive: true);
          }
        });

        // Spawn two actor hosts simulating two devices of the same user
        debugPrint('[TEST] Spawning actor hosts...');
        final host1 = await SyncActorHost.spawn();
        final host2 = await SyncActorHost.spawn();
        addTearDown(() async {
          await host1.dispose();
          await host2.dispose();
        });

        // Subscribe to event streams early for diagnostic logging
        host1.events.listen((event) {
          if (event['event'] == 'log') {
            debugPrint('[SyncActor:A] ${event['message']}');
          } else {
            debugPrint('[TEST] host1 event: $event');
          }
        });
        host2.events.listen((event) {
          if (event['event'] == 'log') {
            debugPrint('[SyncActor:B] ${event['message']}');
          } else {
            debugPrint('[TEST] host2 event: $event');
          }
        });

        // --- ping both actors ---
        debugPrint('[TEST] Pinging both actors...');
        final ping1 = await host1.send('ping');
        debugPrint('[TEST] host1 ping: $ping1');
        expect(ping1['ok'], isTrue, reason: 'host1 ping');
        final ping2 = await host2.send('ping');
        debugPrint('[TEST] host2 ping: $ping2');
        expect(ping2['ok'], isTrue, reason: 'host2 ping');

        // --- init both actors as the SAME user, different devices ---
        const initTimeout = Duration(minutes: 2);
        debugPrint('[TEST] Initializing host1 (DeviceA)...');
        final init1 = await host1.send(
          'init',
          payload: {
            'homeServer': baseUrl,
            'user': _testUser,
            'password': _testPassword,
            'dbRootPath': dbRoot1.path,
            'deviceDisplayName': 'DeviceA',
            'eventPort': host1.eventSendPort,
          },
          timeout: initTimeout,
        );
        debugPrint('[TEST] host1 init: $init1');
        expect(init1['ok'], isTrue, reason: 'host1 init: $init1');

        debugPrint('[TEST] Initializing host2 (DeviceB)...');
        final init2 = await host2.send(
          'init',
          payload: {
            'homeServer': baseUrl,
            'user': _testUser,
            'password': _testPassword,
            'dbRootPath': dbRoot2.path,
            'deviceDisplayName': 'DeviceB',
            'eventPort': host2.eventSendPort,
          },
          timeout: initTimeout,
        );
        debugPrint('[TEST] host2 init: $init2');
        expect(init2['ok'], isTrue, reason: 'host2 init: $init2');

        // --- DeviceA creates room, DeviceB joins ---
        debugPrint('[TEST] Creating room from DeviceA...');
        final createResult = await host1.send(
          'createRoom',
          payload: {
            'name': 'Actor Sync Room ${DateTime.now().millisecondsSinceEpoch}',
          },
        );
        debugPrint('[TEST] createRoom result: $createResult');
        expect(
          createResult['ok'],
          isTrue,
          reason: 'createRoom: $createResult',
        );
        final roomIdValue = createResult['roomId'];
        if (roomIdValue is! String) {
          fail('Expected roomId to be a String, got: $roomIdValue');
        }
        final roomId = roomIdValue;

        // Same user's second device joins the room
        debugPrint('[TEST] DeviceB joining room $roomId...');
        var joined = false;
        for (var i = 0; i < 20 && !joined; i++) {
          final joinResult = await host2.send(
            'joinRoom',
            payload: {'roomId': roomId},
          );
          debugPrint('[TEST] joinRoom attempt ${i + 1}: $joinResult');
          if (joinResult['ok'] == true) {
            joined = true;
          } else {
            await Future<void>.delayed(const Duration(milliseconds: 250));
          }
        }
        expect(joined, isTrue, reason: 'DeviceB failed to join room $roomId');

        // --- wait for implicit sync bootstrap after init ---
        debugPrint('[TEST] Allowing implicit sync bootstrapping...');
        await _waitUntil(
          message: 'DeviceA did not reach syncing state',
          timeout: const Duration(seconds: 15),
          interval: const Duration(milliseconds: 200),
          condition: () async {
            final health = await host1.send('getHealth');
            return health['syncLoopActive'] == true;
          },
        );
        await _waitUntil(
          message: 'DeviceB did not reach syncing state',
          timeout: const Duration(seconds: 15),
          interval: const Duration(milliseconds: 200),
          condition: () async {
            final health = await host2.send('getHealth');
            return health['syncLoopActive'] == true;
          },
        );
        final healthAfterBootstrap1 = await host1.send('getHealth');
        final healthAfterBootstrap2 = await host2.send('getHealth');
        final host1DeviceKeys = _deviceKeyCount(healthAfterBootstrap1);
        final host2DeviceKeys = _deviceKeyCount(healthAfterBootstrap2);
        debugPrint(
          '[TEST] device keys after bootstrap: host1=$host1DeviceKeys host2=$host2DeviceKeys',
        );

        // --- send text from DeviceA with retry while sync is active ---
        debugPrint('[TEST] Sending text from DeviceA...');
        const textPayload = 'actor host single-user payload';
        final sendResult = await _sendTextWithRetries(
          host: host1,
          roomId: roomId,
          message: textPayload,
        );
        debugPrint('[TEST] sendText result: $sendResult');
        expect(
          sendResult['ok'],
          isTrue,
          reason: 'sendText failed after retries: $sendResult',
        );
        expect(sendResult['eventId'], isA<String>());
        debugPrint('[TEST] Sent event: ${sendResult['eventId']}');

        debugPrint('[TEST] Checking encryption health of both hosts...');
        final health1 = await host1.send('getHealth');
        debugPrint('[TEST] host1 health: $health1');
        expect(health1['encryptionEnabled'], isTrue);

        final health2 = await host2.send('getHealth');
        debugPrint('[TEST] host2 health: $health2');
        expect(health2['encryptionEnabled'], isTrue);

        debugPrint('[TEST] Test completed successfully');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    // TODO(sync-actor): Add self-verification test once vodozemac session
    // bootstrapping between fresh isolates is stable.
  });
}
