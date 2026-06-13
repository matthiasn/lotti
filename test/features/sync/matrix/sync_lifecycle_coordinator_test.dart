import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/sync_lifecycle_coordinator.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'sync_lifecycle_coordinator_test_helpers.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(FakeClient());
  });

  group('SyncLifecycleCoordinator with pipeline', () {
    late MockMatrixSyncGateway gateway;
    late MockMatrixSessionManager sessionManager;
    late MockSyncRoomManager roomManager;
    late MockDomainLogger logging;
    late MockPipeline pipeline;
    late StreamController<LoginState> loginStates;

    SyncLifecycleCoordinator makeCoordinator() {
      return SyncLifecycleCoordinator(
        gateway: gateway,
        sessionManager: sessionManager,
        roomManager: roomManager,
        loggingService: logging,
        pipeline: pipeline,
      );
    }

    setUp(() {
      gateway = MockMatrixSyncGateway();
      sessionManager = MockMatrixSessionManager();
      roomManager = MockSyncRoomManager();
      logging = MockDomainLogger();
      pipeline = MockPipeline();
      loginStates = StreamController<LoginState>.broadcast(sync: true);
      when(
        () => gateway.loginStateChanges,
      ).thenAnswer((_) => loginStates.stream);

      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(
        () => roomManager.hydrateRoomSnapshot(
          client: any<Client>(named: 'client'),
        ),
      ).thenAnswer((_) async {});
      when(() => sessionManager.client).thenReturn(MockMatrixClient());
      when(() => pipeline.initialize()).thenAnswer((_) async {});
      when(() => pipeline.start()).thenAnswer((_) async {});
      when(() => pipeline.dispose()).thenAnswer((_) async {});
      when(
        () => logging.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenReturn(null);
      when(
        () => logging.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});
    });

    tearDown(() async {
      await loginStates.close();
    });

    test(
      'initialize calls pipeline.initialize and activates if already logged in',
      () async {
        when(() => sessionManager.isLoggedIn()).thenReturn(true);
        final coord = makeCoordinator();

        await coord.initialize();

        verify(() => pipeline.initialize()).called(1);
        verify(
          () => roomManager.hydrateRoomSnapshot(client: any(named: 'client')),
        ).called(1);
        verify(() => pipeline.start()).called(1);
        expect(coord.isActive, isTrue);
      },
    );

    test('reacts to login event and starts pipeline once', () async {
      fakeAsync((async) {
        when(() => sessionManager.isLoggedIn()).thenReturn(false);
        final coord = makeCoordinator();
        unawaited(coord.initialize());
        async.flushMicrotasks();

        // Emit loggedIn twice rapidly
        loginStates
          ..add(LoginState.loggedIn)
          ..add(LoginState.loggedIn);
        async.elapse(const Duration(milliseconds: 50));

        verify(
          () => roomManager.hydrateRoomSnapshot(client: any(named: 'client')),
        ).called(greaterThanOrEqualTo(1));
        verify(() => pipeline.start()).called(1);
        expect(coord.isActive, isTrue);
      });
    });

    test('reacts to loggedOut and disposes pipeline', () async {
      fakeAsync((async) {
        when(() => sessionManager.isLoggedIn()).thenReturn(false);
        final coord = makeCoordinator();
        unawaited(coord.initialize());
        async.flushMicrotasks();

        loginStates.add(LoginState.loggedIn);
        async.elapse(const Duration(milliseconds: 10));
        loginStates.add(LoginState.loggedOut);
        async.elapse(const Duration(milliseconds: 50));

        verify(() => pipeline.dispose()).called(1);
        expect(coord.isActive, isFalse);
      });
    });

    test('logout before activation completes is ignored', () async {
      fakeAsync((async) {
        when(() => sessionManager.isLoggedIn()).thenReturn(false);
        final startCompleter = Completer<void>();
        when(() => pipeline.start()).thenAnswer((_) => startCompleter.future);

        final coord = makeCoordinator();
        unawaited(coord.initialize());
        async.flushMicrotasks();

        loginStates
          ..add(LoginState.loggedIn)
          // Immediately log out before start completes
          ..add(LoginState.loggedOut);
        // Now complete start
        startCompleter.complete();
        async.elapse(const Duration(milliseconds: 150));
        // Because logout arrived while not active, coordinator does not queue a
        // deactivation. Activation completes and remains active.
        verifyNever(() => pipeline.dispose());
        expect(coord.isActive, isTrue);
      });
    });

    test('dispose cancels subscription; further events ignored', () async {
      fakeAsync((async) {
        when(() => sessionManager.isLoggedIn()).thenReturn(false);
        final coord = makeCoordinator();
        unawaited(coord.initialize());
        async.flushMicrotasks();
        unawaited(coord.dispose());
        async.flushMicrotasks();

        // Emit an event after dispose; expect no calls
        clearInteractions(pipeline);
        loginStates.add(LoginState.loggedIn);
        async.elapse(const Duration(milliseconds: 20));
        verifyNever(() => pipeline.start());
        expect(coord.isActive, isFalse);
      });
    });

    test(
      'login event delivered mid-dispose short-circuits via _isDisposed',
      () async {
        fakeAsync((async) {
          // Use a stream that captures the listener so we can invoke it
          // directly after dispose has set _isDisposed = true. This simulates
          // a delivery that races with subscription cancellation.
          final manual = ManualLoginStateStream();
          when(() => gateway.loginStateChanges).thenAnswer((_) => manual);
          when(() => sessionManager.isLoggedIn()).thenReturn(false);

          final coord = makeCoordinator();
          unawaited(coord.initialize());
          async.flushMicrotasks();

          expect(manual.handler, isNotNull);

          unawaited(coord.dispose());
          async.flushMicrotasks();

          clearInteractions(pipeline);
          clearInteractions(roomManager);

          manual.handler!(LoginState.loggedIn);
          async.elapse(const Duration(milliseconds: 20));

          verifyNever(() => pipeline.start());
          verifyNever(
            () => roomManager.hydrateRoomSnapshot(
              client: any<Client>(named: 'client'),
            ),
          );
          expect(coord.isActive, isFalse);
        });
      },
    );

    test('updateHooks installs onLogin hook invoked on activation', () async {
      when(() => sessionManager.isLoggedIn()).thenReturn(false);
      final coord = makeCoordinator();
      await coord.initialize();

      var onLoginCalls = 0;
      var onLogoutCalls = 0;
      coord.updateHooks(
        onLogin: () async => onLoginCalls++,
        onLogout: () async => onLogoutCalls++,
      );

      loginStates.add(LoginState.loggedIn);
      await Future<void>.delayed(Duration.zero);

      expect(coord.isActive, isTrue);
      expect(onLoginCalls, 1);
      expect(onLogoutCalls, 0);

      loginStates.add(LoginState.loggedOut);
      await Future<void>.delayed(Duration.zero);

      expect(coord.isActive, isFalse);
      expect(onLogoutCalls, 1);
    });

    test('updateHooks ignores null hooks and keeps prior callbacks', () async {
      when(() => sessionManager.isLoggedIn()).thenReturn(false);
      final coord = makeCoordinator();
      await coord.initialize();

      var onLoginCalls = 0;
      coord
        ..updateHooks(onLogin: () async => onLoginCalls++)
        // Passing nulls must not clear the previously installed onLogin hook.
        ..updateHooks();

      loginStates.add(LoginState.loggedIn);
      await Future<void>.delayed(Duration.zero);

      expect(onLoginCalls, 1);
    });

    test('initialization failure logs error and rethrows', () async {
      when(() => sessionManager.isLoggedIn()).thenReturn(false);
      final failure = StateError('init boom');
      when(() => pipeline.initialize()).thenThrow(failure);
      final coord = makeCoordinator();

      await expectLater(coord.initialize(), throwsA(same(failure)));

      verify(
        () => logging.error(
          LogDomain.sync,
          failure,
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'initialize',
        ),
      ).called(1);
      expect(coord.isActive, isFalse);
    });

    test('activation failure logs error and rethrows', () async {
      when(() => sessionManager.isLoggedIn()).thenReturn(true);
      final failure = StateError('start boom');
      when(() => pipeline.start()).thenThrow(failure);
      final coord = makeCoordinator();

      await expectLater(coord.initialize(), throwsA(same(failure)));

      verify(
        () => logging.error(
          LogDomain.sync,
          failure,
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'activate',
        ),
      ).called(1);
      expect(coord.isActive, isFalse);
    });

    test(
      'deactivation failure logs error, rethrows, and clears active',
      () async {
        when(() => sessionManager.isLoggedIn()).thenReturn(true);
        final failure = StateError('dispose boom');
        when(() => pipeline.dispose()).thenThrow(failure);
        final coord = makeCoordinator();
        await coord.initialize();
        expect(coord.isActive, isTrue);

        // Flip to logged-out so reconcile drives the deactivation path.
        when(() => sessionManager.isLoggedIn()).thenReturn(false);
        await expectLater(
          coord.reconcileLifecycleState(),
          throwsA(same(failure)),
        );

        verify(
          () => logging.error(
            LogDomain.sync,
            failure,
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'deactivate',
          ),
        ).called(1);
        // finally block clears _isActive even though dispose threw.
        expect(coord.isActive, isFalse);
      },
    );

    test('logout awaits an in-flight activation before deactivating', () async {
      fakeAsync((async) {
        when(() => sessionManager.isLoggedIn()).thenReturn(false);
        final startCompleter = Completer<void>();
        when(() => pipeline.start()).thenAnswer((_) => startCompleter.future);

        final coord = makeCoordinator();
        unawaited(coord.initialize());
        async.flushMicrotasks();

        // Begin activation; it parks on the pending pipeline.start().
        loginStates.add(LoginState.loggedIn);
        async.flushMicrotasks();
        expect(coord.isActive, isFalse);

        // Reconcile to logged-out while activation is still pending. This drives
        // the `_pendingTransition != null` await branch in _handleLoggedOut.
        when(() => sessionManager.isLoggedIn()).thenReturn(false);
        unawaited(coord.reconcileLifecycleState());
        async.flushMicrotasks();

        // Activation now completes, becomes active, and the queued logout then
        // deactivates.
        startCompleter.complete();
        async.elapse(const Duration(milliseconds: 50));

        verify(() => pipeline.start()).called(1);
        verify(() => pipeline.dispose()).called(1);
        expect(coord.isActive, isFalse);
      });
    });

    glados.Glados(
      glados.any.lifecycleScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'generated lifecycle transitions activate and deactivate once per state',
      (scenario) {
        fakeAsync((async) {
          final gateway = MockMatrixSyncGateway();
          final sessionManager = MockMatrixSessionManager();
          final roomManager = MockSyncRoomManager();
          final logging = MockDomainLogger();
          final pipeline = MockPipeline();
          final loginStates = StreamController<LoginState>.broadcast(
            sync: true,
          );
          var loggedIn = scenario.initiallyLoggedIn;
          var pipelineStarts = 0;
          var pipelineDisposes = 0;

          when(
            () => gateway.loginStateChanges,
          ).thenAnswer((_) => loginStates.stream);
          when(roomManager.initialize).thenAnswer((_) async {});
          when(
            () => roomManager.hydrateRoomSnapshot(
              client: any<Client>(named: 'client'),
            ),
          ).thenAnswer((_) async {});
          when(() => sessionManager.client).thenReturn(MockMatrixClient());
          when(sessionManager.isLoggedIn).thenAnswer((_) => loggedIn);
          when(pipeline.initialize).thenAnswer((_) async {});
          when(pipeline.start).thenAnswer((_) async {
            pipelineStarts++;
          });
          when(pipeline.dispose).thenAnswer((_) async {
            pipelineDisposes++;
          });
          when(
            () => logging.log(
              any<LogDomain>(),
              any<String>(),
              subDomain: any<String>(named: 'subDomain'),
            ),
          ).thenReturn(null);
          when(
            () => logging.error(
              any<LogDomain>(),
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: any<String>(named: 'subDomain'),
            ),
          ).thenAnswer((_) async {});

          final coord = SyncLifecycleCoordinator(
            gateway: gateway,
            sessionManager: sessionManager,
            roomManager: roomManager,
            loggingService: logging,
            pipeline: pipeline,
          );
          unawaited(coord.initialize());
          async.flushMicrotasks();

          for (final operation in scenario.operations) {
            switch (operation.kind) {
              case GeneratedLifecycleOperationKind.loggedInEvent:
                loginStates.add(LoginState.loggedIn);
              case GeneratedLifecycleOperationKind.loggedOutEvent:
                loginStates.add(LoginState.loggedOut);
              case GeneratedLifecycleOperationKind.reconcileLoggedIn:
                loggedIn = true;
                unawaited(coord.reconcileLifecycleState());
              case GeneratedLifecycleOperationKind.reconcileLoggedOut:
                loggedIn = false;
                unawaited(coord.reconcileLifecycleState());
              case GeneratedLifecycleOperationKind.initializeAgain:
                unawaited(coord.initialize());
              case GeneratedLifecycleOperationKind.disposeCoordinator:
                unawaited(coord.dispose());
            }
            async.flushMicrotasks();
          }

          final expected = scenario.expected();
          expect(pipelineStarts, expected.pipelineStarts, reason: '$scenario');
          expect(
            pipelineDisposes,
            expected.pipelineDisposes,
            reason: '$scenario',
          );
          expect(coord.isActive, expected.finalActive, reason: '$scenario');
          verify(pipeline.initialize).called(1);
          verify(roomManager.initialize).called(1);
          unawaited(loginStates.close());
          async.flushMicrotasks();
        });
      },
      tags: 'glados',
    );
  });
}
