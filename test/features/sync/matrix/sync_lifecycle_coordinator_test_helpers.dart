import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/pipeline/sync_pipeline.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

// MockMatrixSyncGateway / MockMatrixSessionManager / MockSyncRoomManager come
// from the centralized test/mocks/mocks.dart. SyncPipeline has no centralized
// mock, so MockPipeline is declared locally.
class MockPipeline extends Mock implements SyncPipeline {}

class FakeClient extends Fake implements Client {}

class ManualLoginStateStream extends Stream<LoginState> {
  void Function(LoginState)? handler;

  @override
  StreamSubscription<LoginState> listen(
    void Function(LoginState event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    handler = onData;
    return NoopLoginStateSubscription();
  }
}

class NoopLoginStateSubscription implements StreamSubscription<LoginState> {
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

enum GeneratedLifecycleOperationKind {
  loggedInEvent,
  loggedOutEvent,
  reconcileLoggedIn,
  reconcileLoggedOut,
  initializeAgain,
  disposeCoordinator,
}

class GeneratedLifecycleOperation {
  const GeneratedLifecycleOperation(this.kind);

  final GeneratedLifecycleOperationKind kind;

  @override
  String toString() => kind.name;
}

class GeneratedLifecycleExpected {
  const GeneratedLifecycleExpected({
    required this.pipelineStarts,
    required this.pipelineDisposes,
    required this.finalActive,
  });

  final int pipelineStarts;
  final int pipelineDisposes;
  final bool finalActive;
}

class GeneratedLifecycleScenario {
  const GeneratedLifecycleScenario({
    required this.initiallyLoggedIn,
    required this.operations,
  });

  final bool initiallyLoggedIn;
  final List<GeneratedLifecycleOperation> operations;

  GeneratedLifecycleExpected expected() {
    var active = initiallyLoggedIn;
    var subscriptionActive = true;
    var disposed = false;
    var starts = initiallyLoggedIn ? 1 : 0;
    var disposes = 0;

    for (final operation in operations) {
      switch (operation.kind) {
        case GeneratedLifecycleOperationKind.loggedInEvent:
          if (!disposed && subscriptionActive && !active) {
            active = true;
            starts++;
          }
        case GeneratedLifecycleOperationKind.loggedOutEvent:
          if (!disposed && subscriptionActive && active) {
            active = false;
            disposes++;
          }
        case GeneratedLifecycleOperationKind.reconcileLoggedIn:
          if (!disposed && !active) {
            active = true;
            starts++;
          }
        case GeneratedLifecycleOperationKind.reconcileLoggedOut:
          if (!disposed && active) {
            active = false;
            disposes++;
          }
        case GeneratedLifecycleOperationKind.initializeAgain:
          break;
        case GeneratedLifecycleOperationKind.disposeCoordinator:
          disposed = true;
          subscriptionActive = false;
          active = false;
      }
    }

    return GeneratedLifecycleExpected(
      pipelineStarts: starts,
      pipelineDisposes: disposes,
      finalActive: active,
    );
  }

  @override
  String toString() {
    return 'GeneratedLifecycleScenario('
        'initiallyLoggedIn: $initiallyLoggedIn, '
        'operations: $operations'
        ')';
  }
}

extension AnyGeneratedLifecycleScenario on glados.Any {
  glados.Generator<GeneratedLifecycleOperationKind>
  get lifecycleOperationKind =>
      glados.AnyUtils(this).choose(GeneratedLifecycleOperationKind.values);

  glados.Generator<GeneratedLifecycleOperation> get lifecycleOperation =>
      lifecycleOperationKind.map(GeneratedLifecycleOperation.new);

  glados.Generator<GeneratedLifecycleScenario> get lifecycleScenario =>
      glados.CombinableAny(this).combine2(
        glados.BoolAny(this).bool,
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 28, lifecycleOperation),
        (
          bool initiallyLoggedIn,
          List<GeneratedLifecycleOperation> operations,
        ) => GeneratedLifecycleScenario(
          initiallyLoggedIn: initiallyLoggedIn,
          operations: operations,
        ),
      );
}
