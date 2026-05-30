import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_pipeline.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_lifecycle_coordinator.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class MockMatrixSyncGateway extends Mock implements MatrixSyncGateway {}

class MockMatrixSessionManager extends Mock implements MatrixSessionManager {}

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockPipeline extends Mock implements SyncPipeline {}

class MockClient extends Mock implements Client {}

class _FakeClient extends Fake implements Client {}

class _ManualLoginStateStream extends Stream<LoginState> {
  void Function(LoginState)? handler;

  @override
  StreamSubscription<LoginState> listen(
    void Function(LoginState event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    handler = onData;
    return _NoopLoginStateSubscription();
  }
}

class _NoopLoginStateSubscription implements StreamSubscription<LoginState> {
  @override
  Future<void> cancel() async {}

  @override
  Future<E> asFuture<E>([E? futureValue]) => Completer<E>().future;

  @override
  bool get isPaused => false;

  @override
  void onData(void Function(LoginState data)? handleData) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void onError(Function? handleError) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}
}

enum _GeneratedLifecycleOperationKind {
  loggedInEvent,
  loggedOutEvent,
  reconcileLoggedIn,
  reconcileLoggedOut,
  initializeAgain,
  disposeCoordinator,
}

class _GeneratedLifecycleOperation {
  const _GeneratedLifecycleOperation(this.kind);

  final _GeneratedLifecycleOperationKind kind;

  @override
  String toString() => kind.name;
}

class _GeneratedLifecycleExpected {
  const _GeneratedLifecycleExpected({
    required this.pipelineStarts,
    required this.pipelineDisposes,
    required this.finalActive,
  });

  final int pipelineStarts;
  final int pipelineDisposes;
  final bool finalActive;
}

class _GeneratedLifecycleScenario {
  const _GeneratedLifecycleScenario({
    required this.initiallyLoggedIn,
    required this.operations,
  });

  final bool initiallyLoggedIn;
  final List<_GeneratedLifecycleOperation> operations;

  _GeneratedLifecycleExpected expected() {
    var active = initiallyLoggedIn;
    var subscriptionActive = true;
    var disposed = false;
    var starts = initiallyLoggedIn ? 1 : 0;
    var disposes = 0;

    for (final operation in operations) {
      switch (operation.kind) {
        case _GeneratedLifecycleOperationKind.loggedInEvent:
          if (!disposed && subscriptionActive && !active) {
            active = true;
            starts++;
          }
        case _GeneratedLifecycleOperationKind.loggedOutEvent:
          if (!disposed && subscriptionActive && active) {
            active = false;
            disposes++;
          }
        case _GeneratedLifecycleOperationKind.reconcileLoggedIn:
          if (!disposed && !active) {
            active = true;
            starts++;
          }
        case _GeneratedLifecycleOperationKind.reconcileLoggedOut:
          if (!disposed && active) {
            active = false;
            disposes++;
          }
        case _GeneratedLifecycleOperationKind.initializeAgain:
          break;
        case _GeneratedLifecycleOperationKind.disposeCoordinator:
          disposed = true;
          subscriptionActive = false;
          active = false;
      }
    }

    return _GeneratedLifecycleExpected(
      pipelineStarts: starts,
      pipelineDisposes: disposes,
      finalActive: active,
    );
  }

  @override
  String toString() {
    return '_GeneratedLifecycleScenario('
        'initiallyLoggedIn: $initiallyLoggedIn, '
        'operations: $operations'
        ')';
  }
}

extension _AnyGeneratedLifecycleScenario on glados.Any {
  glados.Generator<_GeneratedLifecycleOperationKind>
  get lifecycleOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedLifecycleOperationKind.values);

  glados.Generator<_GeneratedLifecycleOperation> get lifecycleOperation =>
      lifecycleOperationKind.map(_GeneratedLifecycleOperation.new);

  glados.Generator<_GeneratedLifecycleScenario> get lifecycleScenario =>
      glados.CombinableAny(this).combine2(
        glados.BoolAny(this).bool,
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 28, lifecycleOperation),
        (
          bool initiallyLoggedIn,
          List<_GeneratedLifecycleOperation> operations,
        ) => _GeneratedLifecycleScenario(
          initiallyLoggedIn: initiallyLoggedIn,
          operations: operations,
        ),
      );
}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(_FakeClient());
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
      when(() => sessionManager.client).thenReturn(MockClient());
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
          final manual = _ManualLoginStateStream();
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
          when(() => sessionManager.client).thenReturn(MockClient());
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
              case _GeneratedLifecycleOperationKind.loggedInEvent:
                loginStates.add(LoginState.loggedIn);
              case _GeneratedLifecycleOperationKind.loggedOutEvent:
                loginStates.add(LoginState.loggedOut);
              case _GeneratedLifecycleOperationKind.reconcileLoggedIn:
                loggedIn = true;
                unawaited(coord.reconcileLifecycleState());
              case _GeneratedLifecycleOperationKind.reconcileLoggedOut:
                loggedIn = false;
                unawaited(coord.reconcileLifecycleState());
              case _GeneratedLifecycleOperationKind.initializeAgain:
                unawaited(coord.initialize());
              case _GeneratedLifecycleOperationKind.disposeCoordinator:
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
