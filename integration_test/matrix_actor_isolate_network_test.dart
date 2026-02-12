import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

const _defaultMatrixServer = 'http://localhost:8008';
const _testUser = String.fromEnvironment('TEST_USER1');
const _testUser2 = String.fromEnvironment('TEST_USER2');
const _testPassword = String.fromEnvironment('TEST_PASSWORD');

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

Future<void> _matrixNetworkActor(SendPort readyPort) async {
  final commandPort = ReceivePort();
  readyPort.send(commandPort.sendPort);

  await for (final dynamic raw in commandPort) {
    if (raw is! Map) {
      continue;
    }
    final action = raw['action'] as String?;
    final replyTo = raw['replyTo'];
    if (replyTo is! SendPort) {
      continue;
    }

    if (action == 'stop') {
      replyTo.send(<String, Object?>{'ok': true});
      commandPort.close();
      break;
    }

    if (action == 'fetchVersions') {
      final baseUrl = raw['baseUrl'] as String;
      final client = HttpClient();
      try {
        final request =
            await client.getUrl(Uri.parse('$baseUrl/_matrix/client/versions'));
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(body);
        final hasVersions = decoded is Map<String, dynamic> &&
            decoded['versions'] is List<dynamic>;

        replyTo.send(<String, Object?>{
          'ok': response.statusCode == HttpStatus.ok && hasVersions,
          'statusCode': response.statusCode,
          'hasVersions': hasVersions,
        });
      } catch (e) {
        replyTo.send(<String, Object?>{
          'ok': false,
          'error': e.toString(),
        });
      } finally {
        client.close(force: true);
      }
    }

    if (action == 'runTwoUserSdkFlow') {
      final baseUrl = raw['baseUrl'] as String;
      final user1 = raw['user1'] as String;
      final user2 = raw['user2'] as String;
      final password = raw['password'] as String;
      final dbRootPath = raw['dbRootPath'] as String;

      MatrixSdkGateway? gateway1;
      MatrixSdkGateway? gateway2;
      try {
        await vod.init();

        final user1Root = Directory('$dbRootPath/sdk_user1');
        final user2Root = Directory('$dbRootPath/sdk_user2');
        await user1Root.create(recursive: true);
        await user2Root.create(recursive: true);

        final client1 = await createMatrixClient(
          documentsDirectory: user1Root,
          deviceDisplayName: 'ActorSDK1',
          dbName: 'actor_sdk_user1',
        );
        final client2 = await createMatrixClient(
          documentsDirectory: user2Root,
          deviceDisplayName: 'ActorSDK2',
          dbName: 'actor_sdk_user2',
        );

        gateway1 = MatrixSdkGateway(
          client: client1,
          sentEventRegistry: SentEventRegistry(),
        );
        gateway2 = MatrixSdkGateway(
          client: client2,
          sentEventRegistry: SentEventRegistry(),
        );

        final config1 = MatrixConfig(
          homeServer: baseUrl,
          user: user1,
          password: password,
        );
        final config2 = MatrixConfig(
          homeServer: baseUrl,
          user: user2,
          password: password,
        );

        await gateway1.connect(config1);
        await gateway2.connect(config2);
        final login1 = await gateway1.login(
          config1,
          deviceDisplayName: 'ActorSDK1',
        );
        final login2 = await gateway2.login(
          config2,
          deviceDisplayName: 'ActorSDK2',
        );
        if (login1 == null || login2 == null) {
          throw StateError('SDK login returned null response');
        }

        final roomId = await gateway1.createRoom(
          name: 'Actor SDK Room ${DateTime.now().millisecondsSinceEpoch}',
          inviteUserIds: <String>[user2],
        );

        var joined = false;
        for (var i = 0; i < 20 && !joined; i++) {
          try {
            await gateway2.joinRoom(roomId);
            joined = true;
          } catch (_) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
          }
        }
        if (!joined) {
          throw StateError('SDK user2 failed to join room $roomId');
        }

        String emojisToString(Iterable<KeyVerificationEmoji>? emojis) {
          if (emojis == null) {
            return '';
          }
          try {
            return emojis.map((emoji) => emoji.emoji).join(' ');
          } catch (_) {
            return '';
          }
        }

        Future<void> waitForSasCompletion({
          required KeyVerification outgoing,
          required KeyVerification incoming,
        }) async {
          const keyStep = 'm.key.verification.key';
          var sawMatchingEmojis = false;
          for (var i = 0; i < 80; i++) {
            await gateway1!.client.sync();
            await gateway2!.client.sync();

            var outgoingEmojis = '';
            var incomingEmojis = '';
            try {
              outgoingEmojis = emojisToString(outgoing.sasEmojis);
            } catch (_) {}
            try {
              incomingEmojis = emojisToString(incoming.sasEmojis);
            } catch (_) {}

            if (outgoing.lastStep == keyStep &&
                incoming.lastStep == keyStep &&
                outgoingEmojis.isNotEmpty &&
                incomingEmojis.isNotEmpty &&
                outgoingEmojis == incomingEmojis) {
              sawMatchingEmojis = true;
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 200));
          }

          if (!sawMatchingEmojis) {
            throw StateError('SDK SAS emojis did not converge');
          }

          try {
            await outgoing.acceptSas();
          } catch (e) {
            throw StateError(
              'Outgoing acceptSas failed '
              '(out=${outgoing.lastStep}, in=${incoming.lastStep}): $e',
            );
          }

          for (var i = 0; i < 30 && !incoming.isDone; i++) {
            await gateway1!.client.sync();
            await gateway2!.client.sync();
            if (incoming.lastStep == 'm.key.verification.mac') {
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }

          if (!incoming.isDone) {
            try {
              await incoming.acceptSas();
            } catch (e) {
              throw StateError(
                'Incoming acceptSas failed '
                '(out=${outgoing.lastStep}, in=${incoming.lastStep}): $e',
              );
            }
          }

          var done = false;
          for (var i = 0; i < 50 && !done; i++) {
            await gateway1!.client.sync();
            await gateway2!.client.sync();
            done = outgoing.isDone && incoming.isDone;
            if (!done) {
              await Future<void>.delayed(const Duration(milliseconds: 200));
            }
          }
          if (!done) {
            throw StateError('SDK SAS did not complete');
          }
        }

        Future<DeviceKeys?> findPeerDevice({
          required MatrixSdkGateway source,
          required String peerUserId,
          required String ownUserId,
        }) async {
          await source.client.userOwnsEncryptionKeys(peerUserId);
          await source.client.userDeviceKeysLoading;

          final keysMap = source.client.userDeviceKeys[peerUserId]?.deviceKeys;
          if (keysMap == null || keysMap.isEmpty) {
            return null;
          }
          for (final device in keysMap.values) {
            if (device.userId == ownUserId) {
              continue;
            }
            if (!device.verified) {
              return device;
            }
          }
          return keysMap.values.first;
        }

        MatrixSdkGateway? initiator;
        MatrixSdkGateway? receiver;
        DeviceKeys? deviceToVerify;
        for (var i = 0; i < 80 && deviceToVerify == null; i++) {
          await gateway1.client.sync();
          await gateway2.client.sync();

          final fromUser1 = await findPeerDevice(
            source: gateway1,
            peerUserId: user2,
            ownUserId: user1,
          );
          if (fromUser1 != null) {
            initiator = gateway1;
            receiver = gateway2;
            deviceToVerify = fromUser1;
            break;
          }

          final fromUser2 = await findPeerDevice(
            source: gateway2,
            peerUserId: user1,
            ownUserId: user2,
          );
          if (fromUser2 != null) {
            initiator = gateway2;
            receiver = gateway1;
            deviceToVerify = fromUser2;
            break;
          }

          await Future<void>.delayed(const Duration(milliseconds: 200));
        }

        if (initiator == null || receiver == null || deviceToVerify == null) {
          throw StateError('SDK could not find peer device keys for SAS');
        }

        final verificationRequestCompleter = Completer<KeyVerification>();
        final verificationSub = receiver.keyVerificationRequests.listen(
          (request) {
            if (!verificationRequestCompleter.isCompleted) {
              verificationRequestCompleter.complete(request);
            }
          },
        );
        try {
          final outgoingVerification =
              await initiator.startKeyVerification(deviceToVerify);
          final incomingVerification = await verificationRequestCompleter.future
              .timeout(const Duration(seconds: 20));
          const requestStep = 'm.key.verification.request';
          for (var i = 0; i < 30; i++) {
            await gateway1.client.sync();
            await gateway2.client.sync();
            if (incomingVerification.lastStep == requestStep ||
                incomingVerification.lastStep ==
                    'm.key.verification.ready' ||
                incomingVerification.lastStep ==
                    'm.key.verification.start') {
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }

          if (incomingVerification.lastStep == requestStep ||
              incomingVerification.lastStep == 'm.key.verification.ready' ||
              incomingVerification.lastStep == 'm.key.verification.start') {
            await incomingVerification.acceptVerification();
          }
          await waitForSasCompletion(
            outgoing: outgoingVerification,
            incoming: incomingVerification,
          );
        } finally {
          await verificationSub.cancel();
        }

        const payload = 'actor isolate sdk payload';
        final eventId = await gateway1.sendText(
          roomId: roomId,
          message: payload,
          messageType: MessageTypes.Text,
        );

        var received = false;
        for (var i = 0; i < 60 && !received; i++) {
          await gateway2.client.sync();
          final room = gateway2.getRoomById(roomId);
          if (room != null) {
            final timeline = await room.getTimeline(limit: 50);
            received = timeline.events.any((event) {
              final content = event.content;
              return content['msgtype'] == MessageTypes.Text &&
                  content['body'] == payload;
            });
          }
          if (!received) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
          }
        }

        replyTo.send(<String, Object?>{
          'ok': received,
          'roomId': roomId,
          'eventId': eventId,
          'sasCompleted': true,
          'error': received ? null : 'sdk timeline did not contain payload',
        });
      } catch (e) {
        replyTo.send(<String, Object?>{
          'ok': false,
          'error': e.toString(),
        });
      } finally {
        await gateway1?.dispose();
        await gateway2?.dispose();
      }
    }
  }
}

Future<Map<String, Object?>> _sendActorCommand({
  required SendPort actorPort,
  required String action,
  String? baseUrl,
  String? user,
  String? user1,
  String? user2,
  String? password,
  String? dbRootPath,
}) async {
  final responsePort = ReceivePort();
  actorPort.send(<String, Object?>{
    'action': action,
    if (baseUrl != null) 'baseUrl': baseUrl,
    if (user != null) 'user': user,
    if (user1 != null) 'user1': user1,
    if (user2 != null) 'user2': user2,
    if (password != null) 'password': password,
    if (dbRootPath != null) 'dbRootPath': dbRootPath,
    'replyTo': responsePort.sendPort,
  });
  final result = await responsePort.first as Map;
  responsePort.close();
  return result.cast<String, Object?>();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Matrix isolate actor network integration', () {
    test(
      'actor isolate fetches versions from docker-backed homeserver',
      () async {
        final baseUrl = _matrixServer;
        final reachable = await _isMatrixReachable(baseUrl);
        if (!reachable) {
          debugPrint(
            'Skipping: Matrix homeserver is not reachable at $baseUrl',
          );
          return;
        }

        final readyPort = ReceivePort();
        final isolate =
            await Isolate.spawn(_matrixNetworkActor, readyPort.sendPort);
        final actorPort = await readyPort.first as SendPort;
        readyPort.close();

        try {
          final first = await _sendActorCommand(
            actorPort: actorPort,
            action: 'fetchVersions',
            baseUrl: baseUrl,
          );
          final second = await _sendActorCommand(
            actorPort: actorPort,
            action: 'fetchVersions',
            baseUrl: baseUrl,
          );

          expect(first['ok'], isTrue);
          expect(first['statusCode'], HttpStatus.ok);
          expect(first['hasVersions'], isTrue);

          expect(second['ok'], isTrue);
          expect(second['statusCode'], HttpStatus.ok);
          expect(second['hasVersions'], isTrue);

          if (_testUser.isNotEmpty &&
              _testUser2.isNotEmpty &&
              _testPassword.isNotEmpty) {
            final sdkDbRoot =
                await Directory.systemTemp.createTemp('matrix_sdk_actor_');
            addTearDown(() async {
              if (await sdkDbRoot.exists()) {
                await sdkDbRoot.delete(recursive: true);
              }
            });

            final sdkFlow = await _sendActorCommand(
              actorPort: actorPort,
              action: 'runTwoUserSdkFlow',
              baseUrl: baseUrl,
              user1: _testUser,
              user2: _testUser2,
              password: _testPassword,
              dbRootPath: sdkDbRoot.path,
            );
            expect(sdkFlow['ok'], isTrue, reason: sdkFlow.toString());
            expect(sdkFlow['sasCompleted'], isTrue, reason: sdkFlow.toString());
          } else {
            debugPrint(
              'Skipping two-user sync flow: TEST_USER1/TEST_USER2/TEST_PASSWORD not provided',
            );
          }
        } finally {
          await _sendActorCommand(actorPort: actorPort, action: 'stop');
          isolate.kill(priority: Isolate.immediate);
        }
      },
      timeout: const Timeout(Duration(minutes: 6)),
    );
  });
}
