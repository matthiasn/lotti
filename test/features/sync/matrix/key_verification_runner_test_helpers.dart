import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

// No internal SDK controllers in tests

// MockKeyVerification and MockDeviceKeys come from the centralized
// test/mocks/mocks.dart.

enum GeneratedVerificationStepKind {
  ready,
  key,
  doneStep,
  cancelStep,
  customStep,
}

class GeneratedVerificationTransition {
  const GeneratedVerificationTransition({
    required this.kind,
    required this.canceled,
    required this.stateDone,
    required this.slot,
  });

  final GeneratedVerificationStepKind kind;

  /// The SDK's `canceled` flag. Generated rather than derived from [kind]
  /// because a *remote* cancel sets it without this device ever seeing a
  /// cancel step of its own.
  final bool canceled;

  /// Whether the SDK reached `KeyVerificationState.done`.
  final bool stateDone;

  final int slot;

  /// Mirrors the SDK exactly: `canceled || state in {error, done}`. Deriving
  /// it rather than generating it freely keeps the fake honest — a free
  /// boolean could produce `isDone` with neither a cancel nor a done state,
  /// which the SDK cannot do.
  bool get isDone => canceled || stateDone;

  /// Cancellation wins, because every SDK path that sets `error` also sets
  /// `canceled` (matrix 8.1.0).
  KeyVerificationState get state {
    if (canceled) return KeyVerificationState.error;
    return stateDone
        ? KeyVerificationState.done
        : KeyVerificationState.waitingAccept;
  }

  /// What the runner should report for this transition.
  KeyVerificationOutcome get outcome {
    if (canceled || sdkStep == EventTypes.KeyVerificationCancel) {
      return KeyVerificationOutcome.cancelled;
    }
    if (sdkStep == EventTypes.KeyVerificationDone || stateDone) {
      return KeyVerificationOutcome.success;
    }
    return KeyVerificationOutcome.pending;
  }

  String? get sdkStep {
    switch (kind) {
      case GeneratedVerificationStepKind.ready:
        return null;
      case GeneratedVerificationStepKind.key:
        return 'm.key.verification.key';
      case GeneratedVerificationStepKind.doneStep:
        return EventTypes.KeyVerificationDone;
      case GeneratedVerificationStepKind.cancelStep:
        return 'm.key.verification.cancel';
      case GeneratedVerificationStepKind.customStep:
        return 'generated.verification.step.$slot';
    }
  }

  String get runnerStep => sdkStep ?? '';

  bool get isTerminal =>
      isDone ||
      sdkStep == EventTypes.KeyVerificationDone ||
      sdkStep == 'm.key.verification.cancel';

  KeyVerificationEmoji get emoji => KeyVerificationEmoji((slot % 6) + 1);

  @override
  String toString() {
    return 'GeneratedVerificationTransition('
        'kind: $kind, '
        'canceled: $canceled, '
        'stateDone: $stateDone, '
        'slot: $slot'
        ')';
  }
}

class GeneratedVerificationScenario {
  const GeneratedVerificationScenario(this.transitions);

  final List<GeneratedVerificationTransition> transitions;

  @override
  String toString() => 'GeneratedVerificationScenario($transitions)';
}

extension AnyGeneratedVerificationScenario on glados.Any {
  glados.Generator<GeneratedVerificationStepKind> get verificationStepKind =>
      glados.AnyUtils(this).choose(GeneratedVerificationStepKind.values);

  glados.Generator<GeneratedVerificationTransition>
  get verificationTransition => glados.CombinableAny(this).combine4(
    verificationStepKind,
    glados.BoolAny(this).bool,
    glados.BoolAny(this).bool,
    glados.IntAnys(this).intInRange(0, 24),
    (
      GeneratedVerificationStepKind kind,
      bool canceled,
      bool stateDone,
      int slot,
    ) => GeneratedVerificationTransition(
      kind: kind,
      canceled: canceled,
      stateDone: stateDone,
      slot: slot,
    ),
  );

  glados.Generator<GeneratedVerificationScenario> get verificationScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(1, 12, verificationTransition)
          .map(GeneratedVerificationScenario.new);
}

/// Creates the synchronous broadcast controller every runner test publishes
/// state changes through, registering its closure as a test teardown. Must be
/// called from within a test body so [addTearDown] is in scope.
StreamController<KeyVerificationRunner> runnerController() {
  final controller = StreamController<KeyVerificationRunner>.broadcast(
    sync: true,
  );
  addTearDown(controller.close);
  return controller;
}
