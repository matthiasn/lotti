import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/features/sync/isolate/isolate_sync_service.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_host.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_protocol.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_stack.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_descriptor.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/model/sync_message_too_large_exception.dart';
import 'package:lotti/features/sync/models/sync_login_state.dart';
import 'package:lotti/features/sync/models/sync_verification.dart';
import 'package:lotti/features/sync/sync_service.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../sync_verification_fixtures.dart';

/// The `SyncService` proxy over a scripted host: each call becomes the right
/// command, each event feeds the right stream or reader, and a worker that
/// comes up is handed the credentials and started again.
void main() {
  const config = MatrixConfig(
    homeServer: 'https://hs.example.org',
    user: '@alice:example.org',
    password: 'pw',
  );
  const message = SyncMessage.agentBundle(agentId: 'a', wakeRunKey: 'k');
  const snapshot = SyncIsolateSnapshot(
    isLoggedIn: true,
    ownUserId: '@alice:example.org',
    ownDeviceId: 'DEV',
    homeserverHost: 'hs.example.org',
    syncRoomId: '!room:example.org',
    outgoingVerification: null,
    incomingVerification: null,
    stats: MatrixStats(sentCount: 2, messageCounts: {'journalEntity': 2}),
    isBridgeInFlight: false,
  );

  late MockSyncIsolateHost host;
  late MockSecureStorage storage;
  late MockInboundQueue queue;
  late MockDomainLogger logger;
  late AttachmentIndex index;
  late StreamController<SyncIsolateEvent> events;
  late StreamController<SyncIsolateState> states;
  late StreamController<List<ConnectivityResult>> connectivity;
  late List<SyncIsolateCommand> sent;
  late IsolateSyncService service;

  setUpAll(() {
    registerFallbackValue(const SyncIsolateGetSnapshot());
    registerFallbackValue(LogDomain.sync);
  });

  /// Scripts the host: every command is recorded, and answered by [answer]
  /// (a snapshot by default, so `_refreshSnapshot` always has one).
  void hostAnswers(Object? Function(SyncIsolateCommand command) answer) {
    when(() => host.send(any())).thenAnswer((invocation) async {
      final command =
          invocation.positionalArguments.single as SyncIsolateCommand;
      sent.add(command);
      return answer(command);
    });
  }

  setUp(() {
    host = MockSyncIsolateHost();
    storage = MockSecureStorage();
    queue = MockInboundQueue();
    logger = MockDomainLogger();
    index = AttachmentIndex(verboseLogging: false);
    events = StreamController<SyncIsolateEvent>.broadcast();
    states = StreamController<SyncIsolateState>.broadcast();
    connectivity = StreamController<List<ConnectivityResult>>.broadcast();
    sent = [];
    when(() => host.events).thenAnswer((_) => events.stream);
    when(() => host.states).thenAnswer((_) => states.stream);
    when(() => host.state).thenReturn(SyncIsolateState.running);
    when(
      () => logger.error(
        any(),
        any<Object>(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
        message: any(named: 'message'),
      ),
    ).thenReturn(null);
    hostAnswers((c) => c is SyncIsolateGetSnapshot ? snapshot : null);
    service = IsolateSyncService(
      host: host,
      secureStorage: storage,
      inboundQueue: queue,
      attachmentIndex: index,
      logger: logger,
      connectivityStream: connectivity.stream,
    );
  });

  tearDown(() async {
    await service.dispose();
    await events.close();
    await states.close();
    await connectivity.close();
    await index.dispose();
  });

  group('events feed the readers and streams', () {
    test('session, login state, room, ceremonies, roster and stats', () async {
      final loginStates = <SyncLoginState>[];
      final roomIds = <String?>[];
      final outgoing = <SyncVerificationState>[];
      final incoming = <SyncVerificationState>[];
      final requests = <SyncVerificationState>[];
      final stats = <MatrixStats>[];
      service.loginStateChanges.listen(loginStates.add);
      service.syncRoomIdChanges.listen(roomIds.add);
      service.outgoingVerifications.listen(outgoing.add);
      service.incomingVerifications.listen(incoming.add);
      service.incomingVerificationRequests.listen(requests.add);
      service.stats.listen(stats.add);
      final own = emojiStep(id: 'own');
      final theirs = verificationState(
        id: 'theirs',
        direction: SyncVerificationDirection.incoming,
      );
      final device = unverifiedPeerDevice();
      const counters = MatrixStats(sentCount: 5, messageCounts: {'x': 5});

      events
        ..add(
          const SyncIsolateSessionChanged(
            isLoggedIn: true,
            ownUserId: '@alice:example.org',
            ownDeviceId: 'DEV',
            homeserverHost: 'hs.example.org',
          ),
        )
        ..add(const SyncIsolateLoginStateChanged(SyncLoginState.loggedIn))
        ..add(const SyncIsolateRoomIdChanged('!room:example.org'))
        ..add(
          SyncIsolateVerificationChanged(
            stream: SyncIsolateVerificationStream.outgoing,
            state: own,
          ),
        )
        ..add(
          SyncIsolateVerificationChanged(
            stream: SyncIsolateVerificationStream.incoming,
            state: theirs,
          ),
        )
        ..add(
          SyncIsolateVerificationChanged(
            stream: SyncIsolateVerificationStream.request,
            state: theirs,
          ),
        )
        ..add(SyncIsolateUnverifiedDevicesChanged([device]))
        ..add(const SyncIsolateStatsChanged(counters));
      await pumpEventQueue();

      expect(service.isLoggedIn(), isTrue);
      expect(service.ownUserId, '@alice:example.org');
      expect(service.ownDeviceId, 'DEV');
      expect(service.homeserverHost, 'hs.example.org');
      expect(loginStates, [SyncLoginState.loggedIn]);
      expect(service.syncRoomId, '!room:example.org');
      expect(roomIds, ['!room:example.org']);
      expect(outgoing, [own]);
      expect(service.outgoingVerification, same(own));
      expect(incoming, [theirs]);
      expect(service.incomingVerification, same(theirs));
      expect(requests, [theirs]);
      expect(service.getUnverifiedDevices(), [device]);
      expect(stats, [counters]);
      expect(service.sentCount, 5);
      expect(service.messageCounts, {'x': 5});
    });

    test('a recorded descriptor lands in the mirror index', () async {
      const descriptor = AttachmentDescriptor(
        eventId: r'$att',
        roomId: '!room:example.org',
        relativePath: '/images/a.jpg',
        mimetype: 'image/jpeg',
      );

      events.add(const SyncIsolateAttachmentRecorded(descriptor));
      await pumpEventQueue();

      expect(index.findByEventId(r'$att'), same(descriptor));
      expect(index.find('/images/a.jpg'), same(descriptor));
    });

    test('the bridge state is tracked and its completion forwarded', () async {
      var completed = 0;
      service.queueControl.onBridgeCompleted = () => completed++;
      expect(service.queueControl.onBridgeCompleted, isNotNull);

      events.add(const SyncIsolateBridgeChanged(inFlight: true));
      await pumpEventQueue();
      expect(service.queueControl.isBridgeInFlight, isTrue);
      expect(completed, 0);

      events.add(const SyncIsolateBridgeChanged(inFlight: false));
      await pumpEventQueue();
      expect(service.queueControl.isBridgeInFlight, isFalse);
      expect(completed, 1);
    });

    test(
      "log, table and stack events are not the proxy's to act on",
      () async {
        events
          ..add(const SyncIsolateLog('hello'))
          ..add(const SyncIsolateTablesChanged(['inbound_event_queue']))
          ..add(const SyncIsolateStackChanged(ready: true));
        await pumpEventQueue();

        expect(sent, isEmpty);
      },
    );
  });

  group('a worker that comes up', () {
    test('is handed the credentials this side knows and started again, then '
        'read', () async {
      when(
        () => storage.read(key: matrixConfigKey),
      ).thenAnswer((_) async => jsonEncode(config));
      await service.init();
      sent.clear();

      states.add(SyncIsolateState.running);
      await pumpEventQueue();

      expect(sent.map((c) => c.runtimeType), [
        SyncIsolateConfigure,
        SyncIsolateInitStack,
        SyncIsolateGetSnapshot,
      ]);
      expect((sent.first as SyncIsolateConfigure).config, config);
      expect(service.syncRoomId, '!room:example.org');
      expect(service.sentCount, 2);
    });

    test('before init and before any config read, only the snapshot is '
        'taken', () async {
      states.add(SyncIsolateState.running);
      await pumpEventQueue();

      expect(sent.map((c) => c.runtimeType), [SyncIsolateGetSnapshot]);
    });

    test('other states do nothing', () async {
      states
        ..add(SyncIsolateState.starting)
        ..add(SyncIsolateState.restarting);
      await pumpEventQueue();

      expect(sent, isEmpty);
    });

    test('a failed resume is logged, not thrown', () async {
      hostAnswers(
        (_) => throw const SyncIsolateFailure(
          SyncIsolateErrorCode.notRunning,
          'gone again',
        ),
      );

      states.add(SyncIsolateState.running);
      await pumpEventQueue();

      verify(
        () => logger.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'isolate.proxy.resume',
        ),
      ).called(1);
    });
  });

  group('init', () {
    test(
      'reads the keychain, waits for the worker, configures and starts it',
      () async {
        when(
          () => storage.read(key: matrixConfigKey),
        ).thenAnswer((_) async => jsonEncode(config));
        when(() => host.state).thenReturn(SyncIsolateState.starting);

        final starting = service.init();
        await pumpEventQueue();
        expect(sent, isEmpty, reason: 'nothing is sent before the worker runs');

        states.add(SyncIsolateState.running);
        await starting;

        // The running transition also resumes; both paths configure and start.
        expect(sent.whereType<SyncIsolateConfigure>(), isNotEmpty);
        expect(sent.whereType<SyncIsolateInitStack>(), isNotEmpty);
        expect(sent.whereType<SyncIsolateConfigure>().first.config, config);
        expect(service.isLoggedIn(), isTrue);
      },
    );

    test(
      'without stored credentials the worker is configured with none',
      () async {
        when(
          () => storage.read(key: matrixConfigKey),
        ).thenAnswer((_) async => null);

        await service.init();

        expect((sent.first as SyncIsolateConfigure).config, isNull);
        expect(await service.loadConfig(), isNull);
      },
    );
  });

  group('credentials stay on this side', () {
    test('setConfig writes the keychain and tells the worker', () async {
      when(
        () => storage.write(
          key: matrixConfigKey,
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await service.setConfig(config);

      verify(
        () => storage.write(
          key: matrixConfigKey,
          value: jsonEncode(config),
        ),
      ).called(1);
      expect((sent.single as SyncIsolateConfigure).config, config);
      expect(await service.loadConfig(), config);
      verifyNever(() => storage.read(key: any(named: 'key')));
    });

    test('deleteConfig clears the keychain and tells the worker', () async {
      when(
        () => storage.delete(key: matrixConfigKey),
      ).thenAnswer((_) async {});

      await service.deleteConfig();

      verify(() => storage.delete(key: matrixConfigKey)).called(1);
      expect((sent.single as SyncIsolateConfigure).config, isNull);
      expect(await service.loadConfig(), isNull);
    });

    test('a worker that is down does not fail setConfig', () async {
      when(
        () => storage.write(
          key: matrixConfigKey,
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      hostAnswers(
        (_) => throw const SyncIsolateFailure(
          SyncIsolateErrorCode.notRunning,
          'down',
        ),
      );

      await expectLater(service.setConfig(config), completes);
    });

    test('changePassword changes it on the server, then persists it', () async {
      when(
        () => storage.read(key: matrixConfigKey),
      ).thenAnswer((_) async => jsonEncode(config));
      when(
        () => storage.write(
          key: matrixConfigKey,
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await service.changePassword(oldPassword: 'pw', newPassword: 'new');

      expect(sent.first, isA<SyncIsolateChangePassword>());
      expect((sent.last as SyncIsolateConfigure).config?.password, 'new');
      verify(
        () => storage.write(
          key: matrixConfigKey,
          value: jsonEncode(config.copyWith(password: 'new')),
        ),
      ).called(1);
    });
  });

  group('commands', () {
    test('the session, room and device calls become their commands', () async {
      hostAnswers(
        (c) => switch (c) {
          SyncIsolateLogin() => true,
          SyncIsolateConnect() => false,
          SyncIsolateGetRoom() => '!a',
          SyncIsolateJoinRoom() => '!b',
          SyncIsolateCreateRoom() => '!c',
          SyncIsolateFindSyncRoom() => null,
          SyncIsolateGetSyncDevices() => [unverifiedPeerDevice()],
          SyncIsolateGetSyncMetrics() => const SyncMetrics(dbApplied: 1),
          SyncIsolateGetDiagnosticsText() => 'diag',
          SyncIsolateGetDiagnosticInfo() => {'k': 'v'},
          _ => null,
        },
      );

      expect(await service.login(waitForLifecycle: false), isTrue);
      expect(await service.connect(), isFalse);
      await service.logout();
      expect(await service.getRoom(), '!a');
      expect(await service.joinRoom('!b'), '!b');
      expect(await service.createRoom(), '!c');
      expect(await service.findSyncRoom(), isNull);
      await service.saveRoom('!d');
      await service.clearPersistedRoom();
      await service.publishRotationProof(
        roomId: '!e',
        bundleId: 'b',
        challenge: 'c',
      );
      expect((await service.getSyncDevices()).single.deviceId, 'DEVICE1');
      await service.deleteDeviceById('D', reauthPassword: 'pw');
      await service.verifyDevice(userId: '@a:x', deviceId: 'D');
      expect((await service.getSyncMetrics())?.dbApplied, 1);
      expect(await service.getSyncDiagnosticsText(), 'diag');
      expect(await service.getDiagnosticInfo(), {'k': 'v'});
      await service.forceRescan(includeCatchUp: false);
      await service.retryNow();

      expect(sent.map((c) => c.runtimeType), [
        SyncIsolateLogin,
        SyncIsolateConnect,
        SyncIsolateLogout,
        SyncIsolateGetRoom,
        SyncIsolateJoinRoom,
        SyncIsolateCreateRoom,
        SyncIsolateFindSyncRoom,
        SyncIsolateSaveRoom,
        SyncIsolateClearPersistedRoom,
        SyncIsolatePublishRotationProof,
        SyncIsolateGetSyncDevices,
        SyncIsolateDeleteDevice,
        SyncIsolateVerifyDevice,
        SyncIsolateGetSyncMetrics,
        SyncIsolateGetDiagnosticsText,
        SyncIsolateGetDiagnosticInfo,
        SyncIsolateForceRescan,
        SyncIsolateRetryNow,
      ]);
      final login = sent.first as SyncIsolateLogin;
      expect(login.waitForLifecycle, isFalse);
      final delete = sent[11] as SyncIsolateDeleteDevice;
      expect((delete.deviceId, delete.reauthPassword), ('D', 'pw'));
      final rescan = sent[16] as SyncIsolateForceRescan;
      expect(rescan.includeCatchUp, isFalse);
    });

    test('each ceremony action carries its kind and id', () async {
      await service.acceptVerification('a');
      await service.acceptEmojiVerification('b');
      await service.cancelVerification('c');
      await service.handOffOutgoingVerificationTo('d');

      expect(
        sent.map(
          (c) => (
            (c as SyncIsolateVerificationAction).kind,
            c.id,
          ),
        ),
        [
          (SyncIsolateVerificationActionKind.accept, 'a'),
          (SyncIsolateVerificationActionKind.acceptEmoji, 'b'),
          (SyncIsolateVerificationActionKind.cancel, 'c'),
          (SyncIsolateVerificationActionKind.handOffOutgoingTo, 'd'),
        ],
      );
    });

    test(
      'reading the roster answers the cache and asks for a fresh one',
      () async {
        expect(service.getUnverifiedDevices(), isEmpty);
        await pumpEventQueue();

        expect(sent.single, isA<SyncIsolateGetUnverifiedDevices>());
      },
    );

    test('a send runs the sent hook on a true reply only', () async {
      final hooked = <SyncMessage>[];
      service.onSyncMessageSent = (m) async => hooked.add(m);
      var accept = true;
      hostAnswers((c) => c is SyncIsolateSendMessage ? accept : null);

      expect(await service.sendMatrixMsg(message, myRoomId: '!r'), isTrue);
      accept = false;
      expect(await service.sendMatrixMsg(message), isFalse);

      expect(hooked, [message]);
      final first = sent.first as SyncIsolateSendMessage;
      expect(first.roomId, '!r');
      expect((sent.last as SyncIsolateSendMessage).roomId, isNull);
    });

    test(
      'the queue control sends its commands and answers retrySkipped',
      () async {
        hostAnswers((c) => c is SyncIsolateRetrySkipped ? 7 : null);

        await service.queueControl.triggerBridge();
        service.queueControl.maybeStartGapRecovery();
        expect(await service.queueControl.retrySkipped(), 7);
        await service.journalChanged();
        await pumpEventQueue();

        expect(sent.map((c) => c.runtimeType), [
          SyncIsolateTriggerBridge,
          SyncIsolateMaybeStartGapRecovery,
          SyncIsolateRetrySkipped,
          SyncIsolateJournalChanged,
        ]);
      },
    );

    test('connectivity is forwarded as online or offline', () async {
      connectivity
        ..add([ConnectivityResult.wifi])
        ..add([ConnectivityResult.none]);
      await pumpEventQueue();

      expect(
        sent.map((c) => (c as SyncIsolateConnectivityChanged).online),
        [true, false],
      );
    });
  });

  group('failures', () {
    void hostThrows(SyncIsolateFailure failure) =>
        hostAnswers((_) => throw failure);

    test('a too-large payload is rethrown as SyncMessageTooLargeException, '
        'inline body and all', () async {
      hostThrows(
        const SyncIsolateFailure(
          SyncIsolateErrorCode.failed,
          'SyncIsolateSendMessage: too big',
          thrown: SyncIsolateThrown.messageTooLarge,
          detail: 'bytes=9\n${SyncIsolateStack.inlineBodyMarker}',
        ),
      );

      await expectLater(
        service.sendMatrixMsg(message),
        throwsA(
          isA<SyncMessageTooLargeException>()
              .having((e) => e.detail, 'detail', 'bytes=9')
              .having((e) => e.inlineBody, 'inlineBody', isTrue),
        ),
      );
    });

    test(
      'a refused credential is rethrown as SyncReauthRequiredException',
      () async {
        hostThrows(
          const SyncIsolateFailure(
            SyncIsolateErrorCode.failed,
            'refused',
            thrown: SyncIsolateThrown.reauthRequired,
            detail: 'Invalid password',
          ),
        );

        await expectLater(
          service.deleteDeviceById('D'),
          throwsA(
            isA<SyncReauthRequiredException>().having(
              (e) => e.message,
              'message',
              'Invalid password',
            ),
          ),
        );
      },
    );

    test(
      'a missing event is rethrown as FileSystemException with its path',
      () async {
        hostThrows(
          const SyncIsolateFailure(
            SyncIsolateErrorCode.failed,
            'not available',
            thrown: SyncIsolateThrown.fileSystem,
            detail: '/images/a.jpg',
          ),
        );

        await expectLater(
          service.command(const SyncIsolateGetRoom()),
          throwsA(
            isA<FileSystemException>().having(
              (e) => e.path,
              'path',
              '/images/a.jpg',
            ),
          ),
        );
      },
    );

    test('a false precondition is rethrown as StateError', () async {
      hostThrows(
        const SyncIsolateFailure(
          SyncIsolateErrorCode.failed,
          'keyless',
          thrown: SyncIsolateThrown.state,
        ),
      );

      await expectLater(
        service.verifyDevice(userId: '@a:x', deviceId: 'D'),
        throwsStateError,
      );
    });

    test('anything else is the failure itself', () async {
      hostThrows(
        const SyncIsolateFailure(SyncIsolateErrorCode.timeout, 'slow'),
      );

      await expectLater(
        service.getRoom(),
        throwsA(
          isA<SyncIsolateFailure>().having(
            (f) => f.code,
            'code',
            SyncIsolateErrorCode.timeout,
          ),
        ),
      );
    });

    test(
      'a fire-and-forget command logs a failure other than notRunning',
      () async {
        hostThrows(
          const SyncIsolateFailure(SyncIsolateErrorCode.failed, 'boom'),
        );

        await service.journalChanged();

        verify(
          () => logger.error(
            LogDomain.sync,
            any<Object>(),
            subDomain: 'isolate.proxy.SyncIsolateJournalChanged',
          ),
        ).called(1);
      },
    );
  });

  test("inboundQueue is the UI isolate's own connection", () {
    expect(service.inboundQueue, same(queue));
  });
}
