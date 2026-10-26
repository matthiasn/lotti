import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_protocol.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_stack.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_descriptor.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/model/sync_message_too_large_exception.dart';
import 'package:lotti/features/sync/models/sync_login_state.dart';
import 'package:lotti/features/sync/models/sync_verification.dart';
import 'package:lotti/features/sync/queue/inbound_queue_models.dart';
import 'package:lotti/features/sync/sync_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../sync_verification_fixtures.dart';

/// The worker-side stack over a mocked `MatrixService`: every command lands
/// on the service call it stands for, every service stream becomes an event.
void main() {
  const descriptor = AttachmentDescriptor(
    eventId: r'$att',
    roomId: '!room:example.org',
    relativePath: '/images/a.jpg',
    mimetype: 'image/jpeg',
  );
  const message = SyncMessage.agentBundle(agentId: 'a', wakeRunKey: 'k');

  late MockMatrixService service;
  late MockQueuePipelineCoordinator coordinator;
  late MockInboundQueue queue;
  late MockSyncDescriptorRecovery recovery;
  late MockSyncAttachmentFetcher attachmentFetcher;
  late AttachmentIndex index;
  late StreamController<SyncLoginState> loginStates;
  late StreamController<String?> roomIds;
  late StreamController<SyncVerificationState> outgoing;
  late StreamController<SyncVerificationState> incoming;
  late StreamController<SyncVerificationState> requests;
  late StreamController<MatrixStats> stats;
  late StreamController<QueueDepthSignal> depth;
  late StreamController<List<ConnectivityResult>> connectivity;
  late List<SyncIsolateEvent> events;
  late SyncIsolateStack stack;

  setUpAll(() {
    registerFallbackValue(message);
    registerFallbackValue(descriptor);
  });

  setUp(() {
    service = MockMatrixService();
    coordinator = MockQueuePipelineCoordinator();
    queue = MockInboundQueue();
    recovery = MockSyncDescriptorRecovery();
    attachmentFetcher = MockSyncAttachmentFetcher();
    index = AttachmentIndex(verboseLogging: false);
    loginStates = StreamController<SyncLoginState>.broadcast();
    roomIds = StreamController<String?>.broadcast();
    outgoing = StreamController<SyncVerificationState>.broadcast();
    incoming = StreamController<SyncVerificationState>.broadcast();
    requests = StreamController<SyncVerificationState>.broadcast();
    stats = StreamController<MatrixStats>.broadcast();
    depth = StreamController<QueueDepthSignal>.broadcast();
    connectivity = StreamController<List<ConnectivityResult>>();
    events = [];

    when(() => service.queueCoordinator).thenReturn(coordinator);
    when(() => service.inboundQueue).thenReturn(queue);
    when(() => service.loginStateChanges).thenAnswer((_) => loginStates.stream);
    when(() => service.syncRoomIdChanges).thenAnswer((_) => roomIds.stream);
    when(
      () => service.outgoingVerifications,
    ).thenAnswer((_) => outgoing.stream);
    when(
      () => service.incomingVerifications,
    ).thenAnswer((_) => incoming.stream);
    when(
      () => service.incomingVerificationRequests,
    ).thenAnswer((_) => requests.stream);
    when(() => service.stats).thenAnswer((_) => stats.stream);
    when(() => queue.depthChanges).thenAnswer((_) => depth.stream);
    when(() => service.isLoggedIn()).thenReturn(true);
    when(() => service.ownUserId).thenReturn('@alice:example.org');
    when(() => service.ownDeviceId).thenReturn('DEV');
    when(() => service.homeserverHost).thenReturn('example.org');
    when(() => service.syncRoomId).thenReturn('!room:example.org');
    when(() => service.outgoingVerification).thenReturn(null);
    when(() => service.incomingVerification).thenReturn(null);
    when(() => service.sentCount).thenReturn(3);
    when(() => service.messageCounts).thenReturn({'journalEntity': 3});
    when(() => coordinator.isBridgeInFlight).thenReturn(false);
    when(() => service.getUnverifiedDevices()).thenReturn([]);
    when(() => service.dispose()).thenAnswer((_) async {});

    stack = SyncIsolateStack(
      service: service,
      attachmentIndex: index,
      descriptorRecovery: recovery,
      attachmentFetcher: attachmentFetcher,
      emit: events.add,
      connectivity: connectivity,
    );
  });

  tearDown(() async {
    await Future.wait([
      loginStates.close(),
      roomIds.close(),
      outgoing.close(),
      incoming.close(),
      requests.close(),
      stats.close(),
      depth.close(),
      index.dispose(),
    ]);
  });

  group('events', () {
    test(
      'a login-state change is reported with the session it leaves and the '
      'roster it may have changed',
      () async {
        final device = unverifiedPeerDevice();
        when(() => service.getUnverifiedDevices()).thenReturn([device]);
        loginStates.add(SyncLoginState.loggedIn);
        await pumpEventQueue();

        expect(events, hasLength(3));
        expect(
          (events.first as SyncIsolateLoginStateChanged).state,
          SyncLoginState.loggedIn,
        );
        expect(
          (events.last as SyncIsolateUnverifiedDevicesChanged).devices,
          [device],
        );
        final session = events[1] as SyncIsolateSessionChanged;
        expect(session.isLoggedIn, isTrue);
        expect(session.ownUserId, '@alice:example.org');
        expect(session.ownDeviceId, 'DEV');
        expect(session.homeserverHost, 'example.org');
      },
    );

    test('room, verification and stats changes cross as they are', () async {
      final state = emojiStep(id: 'sas');
      const snapshot = MatrixStats(sentCount: 1, messageCounts: {});
      roomIds.add('!new:example.org');
      outgoing.add(state);
      incoming.add(state);
      requests.add(state);
      stats.add(snapshot);
      await pumpEventQueue();

      expect(
        (events[0] as SyncIsolateRoomIdChanged).roomId,
        '!new:example.org',
      );
      expect(
        events
            .sublist(1, 4)
            .map(
              (e) => (e as SyncIsolateVerificationChanged).stream,
            ),
        [
          SyncIsolateVerificationStream.outgoing,
          SyncIsolateVerificationStream.incoming,
          SyncIsolateVerificationStream.request,
        ],
      );
      expect(
        events
            .sublist(1, 4)
            .every(
              (e) => (e as SyncIsolateVerificationChanged).state.id == 'sas',
            ),
        isTrue,
      );
      expect((events[4] as SyncIsolateStatsChanged).stats, snapshot);
    });

    test('a descriptor the index records is reported for the mirror', () async {
      index.recordDescriptor(descriptor);
      await pumpEventQueue();

      expect(events, hasLength(1));
      expect(
        (events.single as SyncIsolateAttachmentRecorded).descriptor,
        same(descriptor),
      );
    });

    test('the bridge reports starting and finishing', () {
      final started =
          verify(
                () => coordinator.onBridgeStarted = captureAny(),
              ).captured.single
              as void Function();
      final completed =
          verify(
                () => coordinator.onBridgeCompleted = captureAny(),
              ).captured.single
              as void Function();

      started();
      completed();

      expect(
        events.map((e) => (e as SyncIsolateBridgeChanged).inFlight),
        [true, false],
      );
    });

    test('a queue write on this connection names the queue tables', () async {
      depth.add(const QueueDepthSignal(total: 1));
      await pumpEventQueue();

      expect(
        (events.single as SyncIsolateTablesChanged).tables,
        inboundQueueTables,
      );
    });
  });

  group('commands', () {
    test('init starts the service and reports the session', () async {
      when(() => service.init()).thenAnswer((_) async {});

      expect(await stack.handle(const SyncIsolateInitStack()), isNull);

      verify(() => service.init()).called(1);
      expect(events.map((e) => e.runtimeType), [
        SyncIsolateSessionChanged,
        SyncIsolateUnverifiedDevicesChanged,
      ]);
    });

    test('configure sets or deletes the credentials on the session', () async {
      const config = MatrixConfig(homeServer: 'h', user: 'u', password: 'p');
      when(() => service.setConfig(config)).thenAnswer((_) async {});
      when(() => service.deleteConfig()).thenAnswer((_) async {});

      await stack.handle(const SyncIsolateConfigure(config));
      await stack.handle(const SyncIsolateConfigure(null));

      verify(() => service.setConfig(config)).called(1);
      verify(() => service.deleteConfig()).called(1);
    });

    test(
      'login, connect and logout answer the session and report it',
      () async {
        when(
          () => service.login(waitForLifecycle: false),
        ).thenAnswer((_) async => true);
        when(() => service.connect()).thenAnswer((_) async => false);
        when(() => service.logout()).thenAnswer((_) async {});

        expect(
          await stack.handle(const SyncIsolateLogin(waitForLifecycle: false)),
          isTrue,
        );
        expect(await stack.handle(const SyncIsolateConnect()), isFalse);
        expect(await stack.handle(const SyncIsolateLogout()), isNull);

        expect(events.whereType<SyncIsolateSessionChanged>(), hasLength(3));
      },
    );

    test('a password change goes to the server', () async {
      when(
        () => service.changePassword(oldPassword: 'o', newPassword: 'n'),
      ).thenAnswer((_) async {});

      await stack.handle(
        const SyncIsolateChangePassword(oldPassword: 'o', newPassword: 'n'),
      );

      verify(
        () => service.changePassword(oldPassword: 'o', newPassword: 'n'),
      ).called(1);
    });

    test('connectivity is fed to the service as the plugin would', () async {
      final seen = <List<ConnectivityResult>>[];
      final sub = connectivity.stream.listen(seen.add);

      await stack.handle(const SyncIsolateConnectivityChanged(online: true));
      await stack.handle(const SyncIsolateConnectivityChanged(online: false));
      await pumpEventQueue();
      await sub.cancel();

      expect(seen, [
        [ConnectivityResult.wifi],
        [ConnectivityResult.none],
      ]);
    });

    test('the room commands delegate and answer', () async {
      when(() => service.getRoom()).thenAnswer((_) async => '!a');
      when(() => service.joinRoom('!b')).thenAnswer((_) async => '!b');
      when(() => service.createRoom()).thenAnswer((_) async => '!c');
      when(() => service.findSyncRoom()).thenAnswer((_) async => null);
      when(() => service.saveRoom('!d')).thenAnswer((_) async {});
      when(() => service.clearPersistedRoom()).thenAnswer((_) async {});
      when(
        () => service.publishRotationProof(
          roomId: '!e',
          bundleId: 'bundle',
          challenge: 'ch',
        ),
      ).thenAnswer((_) async {});

      expect(await stack.handle(const SyncIsolateGetRoom()), '!a');
      expect(await stack.handle(const SyncIsolateJoinRoom('!b')), '!b');
      expect(await stack.handle(const SyncIsolateCreateRoom()), '!c');
      expect(await stack.handle(const SyncIsolateFindSyncRoom()), isNull);
      expect(await stack.handle(const SyncIsolateSaveRoom('!d')), isNull);
      expect(await stack.handle(const SyncIsolateClearPersistedRoom()), isNull);
      expect(
        await stack.handle(
          const SyncIsolatePublishRotationProof(
            roomId: '!e',
            bundleId: 'bundle',
            challenge: 'ch',
          ),
        ),
        isNull,
      );
      verify(() => service.saveRoom('!d')).called(1);
      verify(() => service.clearPersistedRoom()).called(1);
    });

    test('the device commands delegate and answer', () async {
      final device = unverifiedPeerDevice();
      when(() => service.getUnverifiedDevices()).thenReturn([device]);
      when(() => service.getSyncDevices()).thenAnswer((_) async => [device]);
      when(
        () => service.deleteDeviceById('D', reauthPassword: 'pw'),
      ).thenAnswer((_) async {});
      when(
        () => service.verifyDevice(userId: '@a:x', deviceId: 'D'),
      ).thenAnswer((_) async {});

      expect(
        await stack.handle(const SyncIsolateGetUnverifiedDevices()),
        [device],
      );
      expect(await stack.handle(const SyncIsolateGetSyncDevices()), [device]);
      await stack.handle(
        const SyncIsolateDeleteDevice(deviceId: 'D', reauthPassword: 'pw'),
      );
      await stack.handle(
        const SyncIsolateVerifyDevice(userId: '@a:x', deviceId: 'D'),
      );

      verify(
        () => service.deleteDeviceById('D', reauthPassword: 'pw'),
      ).called(1);
      verify(
        () => service.verifyDevice(userId: '@a:x', deviceId: 'D'),
      ).called(1);
    });

    test('each verification action drives the ceremony by id', () async {
      when(() => service.acceptVerification('c')).thenAnswer((_) async {});
      when(() => service.acceptEmojiVerification('c')).thenAnswer((_) async {});
      when(() => service.cancelVerification('c')).thenAnswer((_) async {});
      when(
        () => service.handOffOutgoingVerificationTo('c'),
      ).thenAnswer((_) async {});

      for (final kind in SyncIsolateVerificationActionKind.values) {
        await stack.handle(SyncIsolateVerificationAction(kind: kind, id: 'c'));
      }

      verify(() => service.acceptVerification('c')).called(1);
      verify(() => service.acceptEmojiVerification('c')).called(1);
      verify(() => service.cancelVerification('c')).called(1);
      verify(() => service.handOffOutgoingVerificationTo('c')).called(1);
    });

    test(
      'a send goes to the service with its room and answers its bool',
      () async {
        when(
          () => service.sendMatrixMsg(message, myRoomId: '!r'),
        ).thenAnswer((_) async => true);

        expect(
          await stack.handle(
            const SyncIsolateSendMessage(message, roomId: '!r'),
          ),
          isTrue,
        );
      },
    );

    test('metrics, diagnostics, rescan and retry delegate', () async {
      const metrics = SyncMetrics(dbApplied: 2);
      when(() => service.getSyncMetrics()).thenAnswer((_) async => metrics);
      when(() => service.getSyncDiagnosticsText()).thenAnswer((_) async => 'd');
      when(
        () => service.getDiagnosticInfo(),
      ).thenAnswer((_) async => {'k': 'v'});
      when(
        () => service.forceRescan(includeCatchUp: false),
      ).thenAnswer((_) async {});
      when(() => service.retryNow()).thenAnswer((_) async {});

      expect(await stack.handle(const SyncIsolateGetSyncMetrics()), metrics);
      expect(await stack.handle(const SyncIsolateGetDiagnosticsText()), 'd');
      expect(await stack.handle(const SyncIsolateGetDiagnosticInfo()), {
        'k': 'v',
      });
      await stack.handle(const SyncIsolateForceRescan(includeCatchUp: false));
      await stack.handle(const SyncIsolateRetryNow());

      verify(() => service.forceRescan(includeCatchUp: false)).called(1);
      verify(() => service.retryNow()).called(1);
    });

    test('the queue commands reach the coordinator and the queue', () async {
      when(() => coordinator.triggerBridge()).thenAnswer((_) async {});
      when(() => coordinator.maybeStartGapRecovery()).thenReturn(null);
      when(() => queue.resurrectAll()).thenAnswer((_) async => 4);
      when(
        () => queue.resurrectByReason('missingBase'),
      ).thenAnswer((_) async => 1);

      await stack.handle(const SyncIsolateTriggerBridge());
      await stack.handle(const SyncIsolateMaybeStartGapRecovery());
      expect(await stack.handle(const SyncIsolateRetrySkipped()), 4);
      await stack.handle(const SyncIsolateJournalChanged());

      verify(() => coordinator.triggerBridge()).called(1);
      verify(() => coordinator.maybeStartGapRecovery()).called(1);
      verify(() => queue.resurrectByReason('missingBase')).called(1);
    });

    test(
      'the fetch commands answer recovery, bytes and the purged uri',
      () async {
        final bytes = Uint8List.fromList([1, 2]);
        when(
          () => recovery.recover(roomId: '!r', eventId: r'$e'),
        ).thenAnswer((_) async => descriptor);
        when(
          () => attachmentFetcher.download(descriptor, pathForError: '/p.json'),
        ).thenAnswer((_) async => bytes);
        when(
          () => attachmentFetcher.purgeCached(descriptor),
        ).thenAnswer((_) async => Uri.parse('mxc://x/y'));

        expect(
          await stack.handle(
            const SyncIsolateRecoverDescriptor(roomId: '!r', eventId: r'$e'),
          ),
          same(descriptor),
        );
        expect(
          await stack.handle(
            const SyncIsolateDownloadAttachment(
              descriptor,
              pathForError: '/p.json',
            ),
          ),
          same(bytes),
        );
        expect(
          await stack.handle(const SyncIsolatePurgeAttachment(descriptor)),
          Uri.parse('mxc://x/y'),
        );
      },
    );

    test('the snapshot reads the service and the bridge', () async {
      final state = verificationState(id: 'own');
      when(() => service.outgoingVerification).thenReturn(state);
      when(() => coordinator.isBridgeInFlight).thenReturn(true);

      final snapshot =
          (await stack.handle(const SyncIsolateGetSnapshot()))!
              as SyncIsolateSnapshot;

      expect(snapshot.isLoggedIn, isTrue);
      expect(snapshot.ownUserId, '@alice:example.org');
      expect(snapshot.ownDeviceId, 'DEV');
      expect(snapshot.homeserverHost, 'example.org');
      expect(snapshot.syncRoomId, '!room:example.org');
      expect(snapshot.outgoingVerification, same(state));
      expect(snapshot.incomingVerification, isNull);
      expect(snapshot.stats.sentCount, 3);
      expect(snapshot.stats.messageCounts, {'journalEntity': 3});
      expect(snapshot.isBridgeInFlight, isTrue);
    });

    test("the worker's own commands are refused here", () async {
      for (final command in const <SyncIsolateCommand>[
        SyncIsolatePing(),
        SyncIsolateShutdown(),
        SyncIsolateLeaseEntries(maxBatch: 1),
        SyncIsolateSettleEntries([]),
      ]) {
        await expectLater(stack.handle(command), throwsStateError);
      }
    });
  });

  group('failureFor', () {
    test('names the exception types the caller acts on', () {
      const command = SyncIsolateSendMessage(message);

      final tooLarge = SyncIsolateStack.failureFor(
        command,
        const SyncMessageTooLargeException('bytes=9', inlineBody: true),
      );
      expect(tooLarge.thrown, SyncIsolateThrown.messageTooLarge);
      expect(tooLarge.detail, 'bytes=9\n${SyncIsolateStack.inlineBodyMarker}');

      final reauth = SyncIsolateStack.failureFor(
        command,
        const SyncReauthRequiredException('refused'),
      );
      expect(reauth.thrown, SyncIsolateThrown.reauthRequired);
      expect(reauth.detail, 'refused');

      final file = SyncIsolateStack.failureFor(
        command,
        const FileSystemException('gone', '/images/a.jpg'),
      );
      expect(file.thrown, SyncIsolateThrown.fileSystem);
      expect(file.detail, '/images/a.jpg');

      final state = SyncIsolateStack.failureFor(command, StateError('keyless'));
      expect(state.thrown, SyncIsolateThrown.state);

      final other = SyncIsolateStack.failureFor(command, Exception('x'));
      expect(other.thrown, SyncIsolateThrown.none);
      expect(other.code, SyncIsolateErrorCode.failed);
      expect(other.message, contains('SyncIsolateSendMessage'));
    });
  });

  test(
    'dispose stops listening, disposes the service and the extras',
    () async {
      var extrasDisposed = false;
      final own = SyncIsolateStack(
        service: service,
        attachmentIndex: index,
        descriptorRecovery: recovery,
        attachmentFetcher: attachmentFetcher,
        emit: events.add,
        disposeExtras: () async => extrasDisposed = true,
      );

      await own.dispose();
      roomIds.add('!late');
      await pumpEventQueue();

      verify(() => service.dispose()).called(1);
      expect(extrasDisposed, isTrue);
      // Only the stack built in setUp is still listening.
      expect(events.whereType<SyncIsolateRoomIdChanged>(), hasLength(1));
    },
  );
}
