import 'package:glados/glados.dart' as glados;

enum GeneratedWakeRunnerOperationKind {
  acquire,
  release,
  waitForCompletion,
  abort,
}

enum GeneratedWakeRunnerAgentSlot { first, second, third, fourth }

final generatedWakeRunnerBase = DateTime(2026, 5, 19, 9);

String generatedWakeRunnerAgentId(GeneratedWakeRunnerAgentSlot slot) =>
    'generated-runner-agent-${slot.name}';

class GeneratedWakeRunnerOperation {
  const GeneratedWakeRunnerOperation({
    required this.kind,
    required this.agentSlot,
  });

  final GeneratedWakeRunnerOperationKind kind;
  final GeneratedWakeRunnerAgentSlot agentSlot;

  String get agentId => generatedWakeRunnerAgentId(agentSlot);

  @override
  String toString() {
    return 'GeneratedWakeRunnerOperation('
        'kind: $kind, agentSlot: $agentSlot)';
  }
}

class GeneratedWakeRunnerScenario {
  const GeneratedWakeRunnerScenario({required this.operations});

  final List<GeneratedWakeRunnerOperation> operations;

  @override
  String toString() {
    return 'GeneratedWakeRunnerScenario(operations: $operations)';
  }
}

class GeneratedWakeRunnerWaiter {
  GeneratedWakeRunnerWaiter({
    required this.agentId,
    required this.actualCompleted,
    required this.expectedCompleted,
  });

  final String agentId;
  bool actualCompleted;
  bool expectedCompleted;
}

extension AnyGeneratedWakeRunnerScenario on glados.Any {
  glados.Generator<GeneratedWakeRunnerOperationKind>
  get wakeRunnerOperationKind =>
      glados.AnyUtils(this).choose(GeneratedWakeRunnerOperationKind.values);

  glados.Generator<GeneratedWakeRunnerAgentSlot> get wakeRunnerAgentSlot =>
      glados.AnyUtils(this).choose(GeneratedWakeRunnerAgentSlot.values);

  glados.Generator<GeneratedWakeRunnerOperation> get wakeRunnerOperation =>
      glados.CombinableAny(this).combine2(
        wakeRunnerOperationKind,
        wakeRunnerAgentSlot,
        (
          GeneratedWakeRunnerOperationKind kind,
          GeneratedWakeRunnerAgentSlot agentSlot,
        ) => GeneratedWakeRunnerOperation(kind: kind, agentSlot: agentSlot),
      );

  glados.Generator<GeneratedWakeRunnerScenario> get wakeRunnerScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(1, 45, wakeRunnerOperation)
          .map(
            (operations) => GeneratedWakeRunnerScenario(
              operations: operations,
            ),
          );
}
