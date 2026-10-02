import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/sync_event_trust.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

const _me = '@me:example.org';
const _roomId = '!sync:example.org';
const _sessionId = 'megolm-session';
const _ownCurveKey = 'own-curve';
const _peerCurveKey = 'peer-curve';
const _peerSigningKey = 'peer-ed25519';

void main() {
  late SyncDatabase syncDb;
  late MockDomainLogger logger;
  late MockMatrixClient client;
  late MockRoom room;
  late MockEncryption encryption;
  late MockKeyManager keyManager;
  late MockSessionKey session;
  late MockDeviceKeysList ownDevices;
  late MockDeviceKeys peer;
  late SyncEventTrust trust;

  MatrixEvent ciphertext({String algorithm = AlgorithmTypes.megolmV1AesSha2}) =>
      MatrixEvent(
        type: EventTypes.Encrypted,
        content: {
          'algorithm': algorithm,
          'ciphertext': 'opaque',
          'session_id': _sessionId,
          // Unauthenticated sender fields must never decide trust.
          'sender_key': _peerCurveKey,
          'device_id': 'PEER',
        },
        senderId: _me,
        eventId: r'$cipher',
        originServerTs: DateTime(2026, 10, 3),
      );

  MockEvent decrypted({
    String type = EventTypes.Message,
    MatrixEvent? original,
    bool withOriginal = true,
    String sender = _me,
  }) {
    final event = MockEvent();
    when(() => event.type).thenReturn(type);
    when(
      () => event.originalSource,
    ).thenReturn(withOriginal ? original ?? ciphertext() : null);
    when(() => event.senderId).thenReturn(sender);
    when(() => event.eventId).thenReturn(r'$payload');
    when(() => event.room).thenReturn(room);
    return event;
  }

  setUp(() {
    syncDb = SyncDatabase(inMemoryDatabase: true);
    logger = MockDomainLogger();
    client = MockMatrixClient();
    room = MockRoom();
    encryption = MockEncryption();
    keyManager = MockKeyManager();
    session = MockSessionKey();
    ownDevices = MockDeviceKeysList();
    peer = MockDeviceKeys();

    when(() => room.client).thenReturn(client);
    when(() => room.id).thenReturn(_roomId);
    when(() => client.encryption).thenReturn(encryption);
    when(() => client.userID).thenReturn(_me);
    when(
      () => client.userDeviceKeys,
    ).thenReturn(<String, DeviceKeysList>{_me: ownDevices});
    when(() => ownDevices.deviceKeys).thenReturn({'PEER': peer});
    when(() => encryption.keyManager).thenReturn(keyManager);
    when(() => encryption.identityKey).thenReturn(_ownCurveKey);
    when(
      () => keyManager.getInboundGroupSession(_roomId, _sessionId),
    ).thenReturn(session);
    when(() => session.isValid).thenReturn(true);
    when(() => session.roomId).thenReturn(_roomId);
    when(() => session.forwardingCurve25519KeyChain).thenReturn(const []);
    when(() => session.senderKey).thenReturn(_peerCurveKey);
    when(
      () => session.senderClaimedKeys,
    ).thenReturn(<String, String>{'ed25519': _peerSigningKey});
    when(() => peer.curve25519Key).thenReturn(_peerCurveKey);
    when(() => peer.ed25519Key).thenReturn(_peerSigningKey);
    when(() => peer.deviceId).thenReturn('PEER');
    when(() => peer.encryptToDevice).thenReturn(true);

    trust = SyncEventTrust(syncDb: syncDb, logging: logger);
  });

  tearDown(() => syncDb.close());

  Future<bool> peerRemembered() => syncDb.isTrustedSyncSender(
    userId: _me,
    curve25519Key: _peerCurveKey,
  );

  group('events that were never encrypted', () {
    test('plaintext from /sync is rejected', () async {
      expect(
        await trust.evaluate(decrypted(withOriginal: false)),
        SyncEventTrustVerdict.notEncrypted,
      );
      verifyNever(() => keyManager.getInboundGroupSession(any(), any()));
    });

    test('ciphertext that failed to decrypt is rejected', () async {
      expect(
        await trust.evaluate(decrypted(type: EventTypes.Encrypted)),
        SyncEventTrustVerdict.notEncrypted,
      );
    });

    test('an original source that is not ciphertext is rejected', () async {
      final forged = MatrixEvent(
        type: EventTypes.Message,
        content: const {'msgtype': 'com.lotti.sync.message'},
        senderId: _me,
        eventId: r'$forged',
        originServerTs: DateTime(2026, 10, 3),
      );
      expect(
        await trust.evaluate(decrypted(original: forged)),
        SyncEventTrustVerdict.notEncrypted,
      );
    });

    test('a non-Megolm algorithm is rejected', () async {
      expect(
        await trust.evaluate(
          decrypted(
            original: ciphertext(
              algorithm: AlgorithmTypes.olmV1Curve25519AesSha2,
            ),
          ),
        ),
        SyncEventTrustVerdict.notEncrypted,
      );
    });
  });

  group('session lookup', () {
    test('no encryption support means no session can vouch', () async {
      when(() => client.encryption).thenReturn(null);
      expect(
        await trust.evaluate(decrypted()),
        SyncEventTrustVerdict.unknownSession,
      );
    });

    test('a session evicted from memory is loaded from the store', () async {
      when(
        () => keyManager.getInboundGroupSession(_roomId, _sessionId),
      ).thenReturn(null);
      when(
        () => keyManager.loadInboundGroupSession(_roomId, _sessionId),
      ).thenAnswer((_) async => session);
      expect(
        await trust.evaluate(decrypted()),
        SyncEventTrustVerdict.trusted,
      );
    });

    test('an unknown session is rejected', () async {
      when(
        () => keyManager.getInboundGroupSession(_roomId, _sessionId),
      ).thenReturn(null);
      when(
        () => keyManager.loadInboundGroupSession(_roomId, _sessionId),
      ).thenAnswer((_) async => null);
      expect(
        await trust.evaluate(decrypted()),
        SyncEventTrustVerdict.unknownSession,
      );
    });

    test('an invalid session is rejected', () async {
      when(() => session.isValid).thenReturn(false);
      expect(
        await trust.evaluate(decrypted()),
        SyncEventTrustVerdict.unknownSession,
      );
    });

    test('a session bound to another room is rejected', () async {
      when(() => session.roomId).thenReturn('!other:example.org');
      expect(
        await trust.evaluate(decrypted()),
        SyncEventTrustVerdict.unknownSession,
      );
    });

    test(
      'a forwarded session is rejected even from a trusted forwarder',
      () async {
        when(
          () => session.forwardingCurve25519KeyChain,
        ).thenReturn(const ['origin-curve']);
        expect(
          await trust.evaluate(decrypted()),
          SyncEventTrustVerdict.forwardedSession,
        );
      },
    );
  });

  group("this device's own sessions", () {
    setUp(() => when(() => session.senderKey).thenReturn(_ownCurveKey));

    test('the echo of an own event is trusted', () async {
      expect(
        await trust.evaluate(decrypted()),
        SyncEventTrustVerdict.trusted,
      );
    });

    test('an own session claimed by another user is rejected', () async {
      expect(
        await trust.evaluate(decrypted(sender: '@mallory:example.org')),
        SyncEventTrustVerdict.senderMismatch,
      );
    });
  });

  group('listed sender devices', () {
    test(
      'a device this one shares keys with is trusted and remembered',
      () async {
        expect(
          await trust.evaluate(decrypted()),
          SyncEventTrustVerdict.trusted,
        );
        expect(await peerRemembered(), isTrue);
      },
    );

    test(
      'repeat events from a remembered device do not rewrite the ledger',
      () async {
        await trust.evaluate(decrypted());
        await syncDb.forgetTrustedSyncSender(
          userId: _me,
          curve25519Key: _peerCurveKey,
        );
        expect(
          await trust.evaluate(decrypted()),
          SyncEventTrustVerdict.trusted,
        );
        expect(await peerRemembered(), isFalse);
      },
    );

    test('an unverified or blocked device is rejected and forgotten', () async {
      await syncDb.rememberTrustedSyncSender(
        userId: _me,
        curve25519Key: _peerCurveKey,
        deviceId: 'PEER',
      );
      when(() => peer.encryptToDevice).thenReturn(false);
      expect(
        await trust.evaluate(decrypted()),
        SyncEventTrustVerdict.untrustedDevice,
      );
      expect(await peerRemembered(), isFalse);
    });

    test(
      'a device trusted earlier this process is forgotten once untrusted',
      () async {
        await trust.evaluate(decrypted());
        when(() => peer.encryptToDevice).thenReturn(false);
        await trust.evaluate(decrypted());
        when(() => peer.encryptToDevice).thenReturn(true);
        // Trust restored: the in-memory record was dropped too, so the ledger is
        // written again.
        await trust.evaluate(decrypted());
        expect(await peerRemembered(), isTrue);
      },
    );

    test(
      'a claimed signing key that differs from the device is rejected',
      () async {
        when(
          () => session.senderClaimedKeys,
        ).thenReturn(<String, String>{'ed25519': 'someone-else'});
        expect(
          await trust.evaluate(decrypted()),
          SyncEventTrustVerdict.senderMismatch,
        );
      },
    );

    test(
      'a session without a claimed signing key relies on the device list',
      () async {
        when(() => session.senderClaimedKeys).thenReturn(<String, String>{});
        expect(
          await trust.evaluate(decrypted()),
          SyncEventTrustVerdict.trusted,
        );
      },
    );

    test("only the event sender's devices can vouch for it", () async {
      final otherUser = MockDeviceKeysList();
      when(() => otherUser.deviceKeys).thenReturn({'PEER': peer});
      when(() => client.userDeviceKeys).thenReturn(<String, DeviceKeysList>{
        '@other:example.org': otherUser,
      });
      expect(
        await trust.evaluate(decrypted()),
        SyncEventTrustVerdict.unknownDevice,
      );
    });
  });

  group('sender devices the SDK no longer lists', () {
    setUp(() => when(() => ownDevices.deviceKeys).thenReturn({}));

    test('a never-trusted device is rejected', () async {
      expect(
        await trust.evaluate(decrypted()),
        SyncEventTrustVerdict.unknownDevice,
      );
    });

    test('a device trusted before it logged out still counts', () async {
      await syncDb.rememberTrustedSyncSender(
        userId: _me,
        curve25519Key: _peerCurveKey,
        deviceId: 'PEER',
      );
      expect(
        await trust.evaluate(decrypted()),
        SyncEventTrustVerdict.trusted,
      );
    });

    test('a remembered key does not vouch for another user', () async {
      await syncDb.rememberTrustedSyncSender(
        userId: '@other:example.org',
        curve25519Key: _peerCurveKey,
        deviceId: 'PEER',
      );
      expect(
        await trust.evaluate(decrypted()),
        SyncEventTrustVerdict.unknownDevice,
      );
    });
  });

  group('admits', () {
    test('passes a trusted event without logging', () async {
      expect(await trust.admits(decrypted(), subDomain: 'test'), isTrue);
      verifyNever(
        () => logger.log(
          any(),
          any(),
          subDomain: any(named: 'subDomain'),
          level: any(named: 'level'),
        ),
      );
    });

    test(
      'rejects an untrusted event with a warning naming the verdict',
      () async {
        expect(
          await trust.admits(decrypted(withOriginal: false), subDomain: 'test'),
          isFalse,
        );
        verify(
          () => logger.log(
            LogDomain.sync,
            r'sync.trust.rejected eventId=$payload verdict=notEncrypted',
            subDomain: 'test',
            level: InsightLevel.warn,
          ),
        ).called(1);
      },
    );
  });
}
