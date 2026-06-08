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
    required this.isDone,
    required this.slot,
  });

  final GeneratedVerificationStepKind kind;
  final bool isDone;
  final int slot;

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
        'isDone: $isDone, '
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
  get verificationTransition => glados.CombinableAny(this).combine3(
    verificationStepKind,
    glados.BoolAny(this).bool,
    glados.IntAnys(this).intInRange(0, 24),
    (
      GeneratedVerificationStepKind kind,
      bool isDone,
      int slot,
    ) => GeneratedVerificationTransition(
      kind: kind,
      isDone: isDone,
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
