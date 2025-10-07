import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/matrix_timeline_listener.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_engine.dart';
import 'package:lotti/features/sync/matrix/sync_lifecycle_coordinator.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/matrix/fake_matrix_gateway.dart';

class _MockSettingsDb extends Mock implements SettingsDb {}

class _MockLoggingService extends Mock implements LoggingService {}

class _MockTimelineListener extends Mock implements MatrixTimelineListener {}

class _MockClient extends Mock implements Client {}

class _MockTimeline extends Mock implements Timeline {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const MatrixConfig(
        homeServer: 'https://example.org',
        user: '@user:server',
        password: 'pw',
      ),
    );
  });

  group('SyncEngine multi-device invites', () {
    late FakeMatrixGateway gatewayA;
    late FakeMatrixGateway gatewayB;
    late SyncEngine engineA;
    late SyncEngine engineB;
    late SyncRoomManager roomManagerA;
    late SyncRoomManager roomManagerB;
    late MatrixSessionManager sessionManagerA;
    late MatrixSessionManager sessionManagerB;
    late _MockTimelineListener timelineListenerA;
    late _MockTimelineListener timelineListenerB;
    late _MockSettingsDb settingsDbA;
    late _MockSettingsDb settingsDbB;
    late _MockLoggingService loggingService;
    late _MockClient clientA;
    late _MockClient clientB;
    late Map<String, String> persistedSettings;
    late StreamSubscription<LoginState> loginSubA;
    late StreamSubscription<LoginState> loginSubB;

    setUp(() {
      loggingService = _MockLoggingService();
      persistedSettings = <String, String>{};

      when(
        () => loggingService.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenReturn(null);
      when(
        () => loggingService.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<dynamic>(named: 'stackTrace'),
        ),
      ).thenReturn(null);

      clientA = _MockClient();
      clientB = _MockClient();
      when(() => clientA.sync())
          .thenAnswer((_) async => SyncUpdate(nextBatch: 'tokenA'));
      when(() => clientB.sync())
          .thenAnswer((_) async => SyncUpdate(nextBatch: 'tokenB'));

      var loggedInA = false;
      var loggedInB = false;
      when(() => clientA.isLogged()).thenAnswer((_) => loggedInA);
      when(() => clientB.isLogged()).thenAnswer((_) => loggedInB);

      gatewayA = FakeMatrixGateway(client: clientA);
      gatewayB = FakeMatrixGateway(client: clientB);

      settingsDbA = _MockSettingsDb();
      settingsDbB = _MockSettingsDb();

      when(() => settingsDbA.itemByKey(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as String;
        return persistedSettings[key];
      });
      when(() => settingsDbB.itemByKey(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as String;
        return persistedSettings[key];
      });
      when(() => settingsDbA.saveSettingsItem(any(), any())).thenAnswer(
        (invocation) async {
          persistedSettings[invocation.positionalArguments.first as String] =
              invocation.positionalArguments[1] as String;
          return 1;
        },
      );
      when(() => settingsDbB.saveSettingsItem(any(), any())).thenAnswer(
        (invocation) async {
          persistedSettings[invocation.positionalArguments.first as String] =
              invocation.positionalArguments[1] as String;
          return 1;
        },
      );
      when(() => settingsDbA.removeSettingsItem(any())).thenAnswer(
        (invocation) async {
          persistedSettings
              .remove(invocation.positionalArguments.first as String);
        },
      );
      when(() => settingsDbB.removeSettingsItem(any())).thenAnswer(
        (invocation) async {
          persistedSettings
              .remove(invocation.positionalArguments.first as String);
        },
      );

      roomManagerA = SyncRoomManager(
        gateway: gatewayA,
        settingsDb: settingsDbA,
        loggingService: loggingService,
      );
      roomManagerB = SyncRoomManager(
        gateway: gatewayB,
        settingsDb: settingsDbB,
        loggingService: loggingService,
      );

      sessionManagerA = MatrixSessionManager(
        gateway: gatewayA,
        roomManager: roomManagerA,
        loggingService: loggingService,
      );
      sessionManagerB = MatrixSessionManager(
        gateway: gatewayB,
        roomManager: roomManagerB,
        loggingService: loggingService,
      );

      timelineListenerA = _MockTimelineListener();
      timelineListenerB = _MockTimelineListener();

      when(() => timelineListenerA.initialize()).thenAnswer((_) async {});
      when(() => timelineListenerB.initialize()).thenAnswer((_) async {});
      when(() => timelineListenerA.start()).thenAnswer((_) async {});
      when(() => timelineListenerB.start()).thenAnswer((_) async {});

      final lifecycleCoordinatorA = SyncLifecycleCoordinator(
        gateway: gatewayA,
        sessionManager: sessionManagerA,
        timelineListener: timelineListenerA,
        roomManager: roomManagerA,
        loggingService: loggingService,
      );
      final lifecycleCoordinatorB = SyncLifecycleCoordinator(
        gateway: gatewayB,
        sessionManager: sessionManagerB,
        timelineListener: timelineListenerB,
        roomManager: roomManagerB,
        loggingService: loggingService,
      );

      engineA = SyncEngine(
        sessionManager: sessionManagerA,
        roomManager: roomManagerA,
        timelineListener: timelineListenerA,
        lifecycleCoordinator: lifecycleCoordinatorA,
        loggingService: loggingService,
      );
      engineB = SyncEngine(
        sessionManager: sessionManagerB,
        roomManager: roomManagerB,
        timelineListener: timelineListenerB,
        lifecycleCoordinator: lifecycleCoordinatorB,
        loggingService: loggingService,
      );

      when(() => timelineListenerA.timeline).thenReturn(_MockTimeline());
      when(() => timelineListenerB.timeline).thenReturn(_MockTimeline());

      loginSubA = gatewayA.loginStateChanges.listen((state) {
        loggedInA = state == LoginState.loggedIn;
      });
      loginSubB = gatewayB.loginStateChanges.listen((state) {
        loggedInB = state == LoginState.loggedIn;
      });
    });

    tearDown(() async {
      await engineA.dispose();
      await engineB.dispose();
      await roomManagerA.dispose();
      await roomManagerB.dispose();
      await gatewayA.dispose();
      await gatewayB.dispose();
      await loginSubA.cancel();
      await loginSubB.cancel();
    });

    test('invite flows propagate between two running engines', () async {
      var loginHookA = 0;
      var loginHookB = 0;

      await engineA.initialize(onLogin: () async {
        loginHookA += 1;
      });
      await engineB.initialize(onLogin: () async {
        loginHookB += 1;
      });

      gatewayA.emitLoginState(LoginState.loggedIn);
      gatewayB.emitLoginState(LoginState.loggedIn);
      await Future<void>.delayed(Duration.zero);

      expect(loginHookA, 1);
      expect(loginHookB, 1);

      final roomId = await roomManagerA.createRoom();

      final inviteFuture = roomManagerB.inviteRequests.first;
      gatewayB.emitInvite(
        RoomInviteEvent(
          roomId: roomId,
          senderId: '@deviceA:server',
        ),
      );

      final invite = await inviteFuture;
      expect(invite.roomId, roomId);
      expect(invite.senderId, '@deviceA:server');
      expect(invite.matchesExistingRoom, isFalse);
    });
  });
}
