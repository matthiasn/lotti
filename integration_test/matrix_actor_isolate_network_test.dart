import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/actor/sync_actor_host.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:path/path.dart' as path;

const _defaultMatrixServer = 'http://localhost:8008';
const _testUser = String.fromEnvironment('TEST_USER');
const _testPassword = String.fromEnvironment('TEST_PASSWORD');
const _maxSendRetries = 15;
const _baseRetryDelay = Duration(milliseconds: 250);

Future<bool> _hostHasIncomingVerification({
  required SyncActorHost host,
  Duration timeout = const Duration(seconds: 15),
  Duration interval = const Duration(milliseconds: 250),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final state = await host.send('getVerificationState');
    if (state['hasIncoming'] == true) {
      return true;
    }
    await Future<void>.delayed(interval);
  }
  return false;
}

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

Map<String, Object?>? _latestVerificationState(
  List<Map<String, Object?>> events, {
  required String direction,
  String? requiredStep,
  bool requireEmojis = false,
}) {
  for (var i = events.length - 1; i >= 0; i--) {
    final event = events[i];
    if (event['event'] != 'verificationState') {
      continue;
    }
    if (event['direction'] != direction) {
      continue;
    }
    if (requiredStep != null && event['step'] != requiredStep) {
      continue;
    }

    final emojis = event['emojis'];
    if (requireEmojis && (emojis is! List || emojis.isEmpty)) {
      continue;
    }

    return event;
  }
  return null;
}

String _emojiFingerprint(Map<String, Object?> event) {
  final emojis = event['emojis'];
  if (emojis is! List) {
    return '';
  }
  return emojis.whereType<String>().join('|');
}

bool _hasIncomingMessageEvent(
  List<Map<String, Object?>> events, {
  required String roomId,
  required String text,
}) {
  return events.any(
    (event) =>
        event['event'] == 'incomingMessage' &&
        event['roomId'] == roomId &&
        event['text'] == text,
  );
}

Set<String> _toStringSet(Object? raw) {
  if (raw is List) {
    return raw.whereType<String>().toSet();
  }
  return <String>{};
}

bool _hasEntitiesChangedEventForIds(
  List<Map<String, Object?>> events,
  Set<String> expectedIds,
) {
  bool eventMatches(Map<String, Object?> event) {
    if (event['event'] != 'entitiesChanged') {
      return false;
    }

    final allIds = {
      ..._toStringSet(event['ids']),
      ..._toStringSet(event['notificationKeys']),
    };
    for (final id in allIds) {
      if (expectedIds.contains(id)) {
        return true;
      }
    }
    return false;
  }

  return events.any(eventMatches);
}

bool _hasEntitiesChangedNotification(
  List<Map<String, Object?>> events,
  Set<String> expectedNotificationKeys,
) {
  bool eventMatches(Map<String, Object?> event) {
    if (event['event'] != 'entitiesChanged') {
      return false;
    }

    final keys = _toStringSet(event['notificationKeys']);
    for (final key in keys) {
      if (expectedNotificationKeys.contains(key)) {
        return true;
      }
    }
    return false;
  }

  return events.any(eventMatches);
}

Future<void> _seedJournalPayloadFiles({
  required String payloadId,
  required Directory dbRootA,
  required Directory dbRootB,
  required DateTime timestamp,
}) async {
  final payload = JournalEntity.journalEntry(
    meta: Metadata(
      id: payloadId,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
      starred: false,
      private: false,
    ),
    entryText: EntryText(plainText: 'sync test payload $payloadId'),
  );

  final payloadJson = jsonEncode(payload.toJson());
  final relativePath = path.join('sync_payloads', '$payloadId.json');
  final fileA = File(path.join(dbRootA.path, relativePath));
  final fileB = File(path.join(dbRootB.path, relativePath));

  await fileA.parent.create(recursive: true);
  await fileB.parent.create(recursive: true);
  await fileA.writeAsString(payloadJson);
  await fileB.writeAsString(payloadJson);
}

Future<Set<String>> _seedOutboxMessages({
  required SyncDatabase outboxDb,
  required Directory senderDbRoot,
  required Directory receiverDbRoot,
  required String prefix,
  required int count,
  required DateTime baseTime,
}) async {
  final payloadIds = <String>{};
  for (var i = 1; i <= count; i++) {
    final payloadId = '$prefix-$i';
    final timestamp = baseTime.add(Duration(minutes: i));
    await _seedJournalPayloadFiles(
      payloadId: payloadId,
      dbRootA: senderDbRoot,
      dbRootB: receiverDbRoot,
      timestamp: timestamp,
    );

    final syncMessageJson = jsonEncode(
      SyncMessage.journalEntity(
        id: payloadId,
        status: SyncEntryStatus.initial,
        vectorClock: const VectorClock({}),
        jsonPath: path.join('sync_payloads', '$payloadId.json'),
      ).toJson(),
    );
    await outboxDb.addOutboxItem(
      OutboxCompanion(
        status: Value(OutboxStatus.pending.index),
        subject: Value('outbox subject $prefix $i'),
        message: Value(syncMessageJson),
        createdAt: Value(timestamp),
        updatedAt: Value(timestamp),
        retries: const Value(0),
      ),
    );

    payloadIds.add(payloadId);
  }

  return payloadIds;
}

Future<bool> _journalContainsEntries({
  required JournalDb journalDb,
  required Set<String> ids,
}) async {
  for (final id in ids) {
    final row = await journalDb.journalEntityById(id);
    if (row == null) {
      return false;
    }
  }
  return true;
}

bool _shouldLogHostEvent(Map<String, Object?> event) {
  final name = event['event'];
  if (name == 'ready' ||
      name == 'verificationState' ||
      name == 'incomingMessage' ||
      name == 'entitiesChanged' ||
      name == 'sendAck' ||
      name == 'sendFailed') {
    return true;
  }
  if (name == 'toDevice') {
    final type = event['type'];
    return type is String && type.startsWith('m.key.verification.');
  }
  return false;
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
        final actors = <SyncActorHost>[];
        final host1 = await SyncActorHost.spawn();
        final host2 = await SyncActorHost.spawn();
        actors
          ..add(host1)
          ..add(host2);
        addTearDown(() async {
          for (final actor in actors) {
            await actor.dispose();
          }
        });

        // Subscribe to event streams early for diagnostic logging and assertions.
        final host1Events = <Map<String, Object?>>[];
        final host2Events = <Map<String, Object?>>[];
        final host1EventSub = host1.events.listen((event) {
          host1Events.add(event);
          if (_shouldLogHostEvent(event)) {
            debugPrint('[TEST] host1 event: $event');
          }
        });
        final host2EventSub = host2.events.listen((event) {
          host2Events.add(event);
          if (_shouldLogHostEvent(event)) {
            debugPrint('[TEST] host2 event: $event');
          }
        });
        addTearDown(() async {
          await host1EventSub.cancel();
          await host2EventSub.cancel();
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
          '[TEST] host1 encryptionEnabled=${healthAfterBootstrap1['encryptionEnabled']} '
          'deviceId=${healthAfterBootstrap1['deviceId']}',
        );
        debugPrint(
          '[TEST] host2 encryptionEnabled=${healthAfterBootstrap2['encryptionEnabled']} '
          'deviceId=${healthAfterBootstrap2['deviceId']}',
        );
        debugPrint(
          '[TEST] device keys after bootstrap: host1=$host1DeviceKeys host2=$host2DeviceKeys',
        );

        debugPrint('[TEST] Allowing key cache and verification bootstrap...');
        await _waitUntil(
          message: 'Neither actor discovered a peer device key',
          timeout: const Duration(seconds: 60),
          interval: const Duration(milliseconds: 500),
          condition: () async {
            final host1Discovery = await host1.send('getHealth');
            final host2Discovery = await host2.send('getHealth');
            return _deviceKeyCount(host1Discovery) >= 2 ||
                _deviceKeyCount(host2Discovery) >= 2;
          },
        );
        debugPrint('[TEST] At least one actor detected a peer device key');

        // --- start verification with a single-pass flow (no start/cancel churn) ---
        var verificationStart = <String, Object?>{};
        var verificationStarter = 'DeviceA';
        var verificationResponder = 'DeviceB';
        var starterHost = host1;
        var responderHost = host2;
        var verificationReady = false;

        final response1 = await host1.send(
          'startVerification',
          payload: {'roomId': roomId},
        );
        debugPrint('[TEST] DeviceA startVerification attempt: $response1');
        if (response1['ok'] == true && response1['started'] == true) {
          final host2Incoming = await _hostHasIncomingVerification(
            host: host2,
            timeout: const Duration(seconds: 30),
          );
          if (host2Incoming) {
            verificationStart = response1;
            verificationStarter = 'DeviceA';
            verificationResponder = 'DeviceB';
            starterHost = host1;
            responderHost = host2;
            verificationReady = true;
          }
        }

        if (!verificationReady) {
          final response2 = await host2.send(
            'startVerification',
            payload: {'roomId': roomId},
          );
          debugPrint('[TEST] DeviceB startVerification attempt: $response2');
          verificationStart = response2;
          if (response2['ok'] == true && response2['started'] == true) {
            final host1Incoming = await _hostHasIncomingVerification(
              host: host1,
              timeout: const Duration(seconds: 30),
            );
            if (host1Incoming) {
              verificationStarter = 'DeviceB';
              verificationResponder = 'DeviceA';
              starterHost = host2;
              responderHost = host1;
              verificationReady = true;
            }
          }
        }

        if (!verificationReady) {
          final health1 = await host1.send('getHealth');
          final health2 = await host2.send('getHealth');
          final verificationState1 = await host1.send('getVerificationState');
          final verificationState2 = await host2.send('getVerificationState');
          fail(
            'Neither device could establish a verification request flow: '
            'lastStart=$verificationStart '
            'health1=$health1 health2=$health2 '
            'state1=$verificationState1 state2=$verificationState2',
          );
        }

        // --- start SAS verification across both devices ---
        debugPrint('[TEST] Starting verification from $verificationStarter...');
        expect(
          verificationStart['ok'],
          isTrue,
          reason: 'startVerification failed: $verificationStart',
        );
        expect(
          verificationStart['started'],
          isTrue,
          reason: 'startVerification did not start flow: $verificationStart',
        );

        await _waitUntil(
          message:
              '$verificationResponder did not receive verification request',
          timeout: const Duration(seconds: 60),
          condition: () async {
            final state = await responderHost.send('getVerificationState');
            return state['hasIncoming'] == true;
          },
        );

        final acceptResponse = await responderHost.send('acceptVerification');
        expect(
          acceptResponse['ok'],
          isTrue,
          reason: 'acceptVerification failed: $acceptResponse',
        );

        Map<String, Object?>? host1VerificationState;
        Map<String, Object?>? host2VerificationState;
        final starterDirection =
            verificationStarter == 'DeviceA' ? 'outgoing' : 'incoming';
        final responderDirection =
            verificationResponder == 'DeviceA' ? 'outgoing' : 'incoming';
        await _waitUntil(
          message: 'SAS events with matching emojis did not converge',
          timeout: const Duration(seconds: 45),
          condition: () async {
            host1VerificationState = _latestVerificationState(
              host1Events,
              direction:
                  host1 == starterHost ? starterDirection : responderDirection,
              requiredStep: 'm.key.verification.key',
              requireEmojis: true,
            );
            host2VerificationState = _latestVerificationState(
              host2Events,
              direction:
                  host2 == starterHost ? starterDirection : responderDirection,
              requiredStep: 'm.key.verification.key',
              requireEmojis: true,
            );

            if (host1VerificationState == null ||
                host2VerificationState == null) {
              return false;
            }

            return _emojiFingerprint(host1VerificationState!) ==
                _emojiFingerprint(host2VerificationState!);
          },
        );

        expect(host1VerificationState, isNot(equals(null)));
        expect(host2VerificationState, isNot(equals(null)));
        expect(
          _emojiFingerprint(host1VerificationState!),
          isNotEmpty,
          reason: 'No matched SAS emojis detected',
        );
        debugPrint(
          '[TEST] SAS match: ${_emojiFingerprint(host1VerificationState!)}',
        );

        final acceptSasStarter = await starterHost.send('acceptSas');
        expect(
          acceptSasStarter['ok'],
          isTrue,
          reason: 'acceptSas failed on $verificationStarter: $acceptSasStarter',
        );
        final acceptSasResponder = await responderHost.send('acceptSas');
        expect(
          acceptSasResponder['ok'],
          isTrue,
          reason:
              'acceptSas failed on $verificationResponder: $acceptSasResponder',
        );

        await _waitUntil(
          message: 'Verification did not clear on both hosts',
          timeout: const Duration(seconds: 30),
          condition: () async {
            final state1 = await host1.send('getVerificationState');
            final state2 = await host2.send('getVerificationState');
            return state1['hasIncoming'] == false &&
                state1['hasOutgoing'] == false &&
                state2['hasIncoming'] == false &&
                state2['hasOutgoing'] == false;
          },
        );

        final host1VerificationDone = _latestVerificationState(
          host1Events,
          direction:
              host1 == starterHost ? starterDirection : responderDirection,
        );
        final host2VerificationDone = _latestVerificationState(
          host2Events,
          direction:
              host2 == starterHost ? starterDirection : responderDirection,
        );
        expect(host1VerificationDone, isNot(equals(null)));
        expect(host2VerificationDone, isNot(equals(null)));

        final verificationStateEvents = host1Events
            .where((event) => event['event'] == 'verificationState')
            .toList();
        expect(verificationStateEvents, isNotEmpty);

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

        await _waitUntil(
          message: 'Host2 did not emit incomingMessage',
          timeout: const Duration(seconds: 30),
          condition: () async {
            return _hasIncomingMessageEvent(
              host2Events,
              roomId: roomId,
              text: textPayload,
            );
          },
        );
        expect(
          _hasIncomingMessageEvent(
            host2Events,
            roomId: roomId,
            text: textPayload,
          ),
          isTrue,
        );
        debugPrint(
          '[TEST] Host2 incomingMessage event detected for DeviceA send',
        );

        // Send back from DeviceB to validate symmetrical inbound detection.
        const textPayloadFromB = 'actor host single-user payload from B';
        final sendResultFromB = await _sendTextWithRetries(
          host: host2,
          roomId: roomId,
          message: textPayloadFromB,
        );
        debugPrint('[TEST] DeviceB send result: $sendResultFromB');
        expect(sendResultFromB['ok'], isTrue);
        await _waitUntil(
          message: 'Host1 did not emit incomingMessage',
          timeout: const Duration(seconds: 30),
          condition: () async {
            return _hasIncomingMessageEvent(
              host1Events,
              roomId: roomId,
              text: textPayloadFromB,
            );
          },
        );
        expect(
          _hasIncomingMessageEvent(
            host1Events,
            roomId: roomId,
            text: textPayloadFromB,
          ),
          isTrue,
        );
        debugPrint(
          '[TEST] Host1 incomingMessage event detected for DeviceB send',
        );

        final host1JournalDb = JournalDb(
          documentsDirectoryProvider: () async => dbRoot1,
          tempDirectoryProvider: () async => dbRoot1,
        );
        final host2JournalDb = JournalDb(
          documentsDirectoryProvider: () async => dbRoot2,
          tempDirectoryProvider: () async => dbRoot2,
        );
        addTearDown(() async {
          await host1JournalDb.close();
          await host2JournalDb.close();
        });

        const outboxItemCount = 3;
        final outboxDb1 = SyncDatabase(
          documentsDirectoryProvider: () async => dbRoot1,
          tempDirectoryProvider: () async => dbRoot1,
        );
        final outboxDb2 = SyncDatabase(
          documentsDirectoryProvider: () async => dbRoot2,
          tempDirectoryProvider: () async => dbRoot2,
        );
        final outboxBaseTime = DateTime(2024, 2, 1, 12);

        final host1PayloadIds = await _seedOutboxMessages(
          outboxDb: outboxDb1,
          senderDbRoot: dbRoot1,
          receiverDbRoot: dbRoot2,
          prefix: 'phase3-outbox-host1',
          count: outboxItemCount,
          baseTime: outboxBaseTime,
        );
        final host2PayloadIds = await _seedOutboxMessages(
          outboxDb: outboxDb2,
          senderDbRoot: dbRoot2,
          receiverDbRoot: dbRoot1,
          prefix: 'phase3-outbox-host2',
          count: outboxItemCount,
          baseTime: outboxBaseTime,
        );

        addTearDown(() async {
          await outboxDb1.close();
          await outboxDb2.close();
        });

        final host1EventsBaseline = host1Events.length;
        final host2EventsBaseline = host2Events.length;

        debugPrint('[TEST] Enqueued $outboxItemCount durable outbox rows');
        final host1KickResult = await host1.send('kickOutbox');
        expect(
          host1KickResult['ok'],
          isTrue,
          reason: 'host1 kickOutbox failed: $host1KickResult',
        );
        final host2KickResult = await host2.send('kickOutbox');
        expect(
          host2KickResult['ok'],
          isTrue,
          reason: 'host2 kickOutbox failed: $host2KickResult',
        );

        await _waitUntil(
          message: 'Host1 did not send all durable outbox messages',
          timeout: const Duration(seconds: 90),
          condition: () async {
            final ackCount = host1Events
                .skip(host1EventsBaseline)
                .where((event) => event['event'] == 'sendAck')
                .length;
            return ackCount >= outboxItemCount;
          },
        );

        await _waitUntil(
          message: 'Host2 did not receive all durable outbox messages',
          timeout: const Duration(seconds: 90),
          condition: () async {
            final deliveredCount = host2Events
                .skip(host2EventsBaseline)
                .where((event) => _hasEntitiesChangedEventForIds(
                      [event],
                      host1PayloadIds,
                    ))
                .length;
            return deliveredCount >= outboxItemCount;
          },
        );

        await _waitUntil(
          message: 'Host2 did not send all durable outbox messages',
          timeout: const Duration(seconds: 90),
          condition: () async {
            final ackCount = host2Events
                .skip(host2EventsBaseline)
                .where((event) => event['event'] == 'sendAck')
                .length;
            return ackCount >= outboxItemCount;
          },
        );

        await _waitUntil(
          message: 'Host1 did not receive all durable outbox messages',
          timeout: const Duration(seconds: 90),
          condition: () async {
            final deliveredCount = host1Events
                .skip(host1EventsBaseline)
                .where(
                  (event) => _hasEntitiesChangedEventForIds(
                    [event],
                    host2PayloadIds,
                  ),
                )
                .length;
            return deliveredCount >= outboxItemCount;
          },
        );

        final finalAckCount = host1Events
            .skip(host1EventsBaseline)
            .where((event) => event['event'] == 'sendAck')
            .length;
        expect(
          finalAckCount,
          outboxItemCount,
          reason:
              'Expected $outboxItemCount sendAck events, got $finalAckCount',
        );

        final finalDeliveredCount = host2Events
            .skip(host2EventsBaseline)
            .where((event) =>
                _hasEntitiesChangedEventForIds([event], host1PayloadIds))
            .length;
        expect(
          finalDeliveredCount,
          outboxItemCount,
          reason:
              'Expected $outboxItemCount durable incoming messages, got $finalDeliveredCount',
        );

        final host2AckCount = host2Events
            .skip(host2EventsBaseline)
            .where((event) => event['event'] == 'sendAck')
            .length;
        expect(
          host2AckCount,
          outboxItemCount,
          reason:
              'Expected $outboxItemCount host2 sendAck events, got $host2AckCount',
        );

        final host1DeliveredCount = host1Events
            .skip(host1EventsBaseline)
            .where((event) =>
                _hasEntitiesChangedEventForIds([event], host2PayloadIds))
            .length;
        expect(
          host1DeliveredCount,
          outboxItemCount,
          reason:
              'Expected $outboxItemCount durable incoming messages on host1, got $host1DeliveredCount',
        );

        expect(
          _hasEntitiesChangedNotification(
            host1Events
                .skip(host1EventsBaseline)
                .where((event) => event['event'] == 'entitiesChanged')
                .toList(),
            const {textEntryNotification},
          ),
          isTrue,
          reason:
              'Expected textEntryNotification in host1 entitiesChanged events',
        );
        expect(
          _hasEntitiesChangedNotification(
            host2Events
                .skip(host2EventsBaseline)
                .where((event) => event['event'] == 'entitiesChanged')
                .toList(),
            const {textEntryNotification},
          ),
          isTrue,
          reason:
              'Expected textEntryNotification in host2 entitiesChanged events',
        );

        await _waitUntil(
          message:
              'Host2 journal should contain inbound payload entries from Host1',
          timeout: const Duration(seconds: 30),
          condition: () async {
            return _journalContainsEntries(
              journalDb: host2JournalDb,
              ids: host1PayloadIds,
            );
          },
        );

        await _waitUntil(
          message:
              'Host1 journal should contain inbound payload entries from Host2',
          timeout: const Duration(seconds: 30),
          condition: () async {
            return _journalContainsEntries(
              journalDb: host1JournalDb,
              ids: host2PayloadIds,
            );
          },
        );

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
  });
}
