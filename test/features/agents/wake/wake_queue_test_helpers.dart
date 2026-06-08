import 'package:glados/glados.dart' as glados;

enum GeneratedWakeQueueOperationKind {
  enqueue,
  dequeue,
  mergeTokens,
  removeByAgent,
  requeueLastDequeued,
  clearHistoryWhenEmpty,
}

enum GeneratedWakeQueueRunKeySlot { first, second, third, fourth }

enum GeneratedWakeQueueAgentSlot { first, second, third }

enum GeneratedWakeQueueTokenSlot { first, second, third, fourth }

/// Workspace partition for a generated job. `none` maps to a `null`
/// workspace key (task/project agents); `dayA`/`dayB` are two day workspaces
/// under one planner identity — generated independently of the agent slot so
/// the model exercises "same agent, different workspace" partitioning.
enum GeneratedWakeQueueWorkspaceSlot { none, dayA, dayB }

final generatedWakeQueueBase = DateTime(2026, 5, 18, 10);

String generatedWakeQueueRunKey(GeneratedWakeQueueRunKeySlot slot) =>
    'generated-wake-run-${slot.name}';

String generatedWakeQueueAgentId(GeneratedWakeQueueAgentSlot slot) =>
    'generated-wake-agent-${slot.name}';

String generatedWakeQueueToken(GeneratedWakeQueueTokenSlot slot) =>
    'generated-wake-token-${slot.name}';

String? generatedWakeQueueWorkspace(GeneratedWakeQueueWorkspaceSlot slot) =>
    switch (slot) {
      GeneratedWakeQueueWorkspaceSlot.none => null,
      GeneratedWakeQueueWorkspaceSlot.dayA => 'day:dayplan-2026-05-18',
      GeneratedWakeQueueWorkspaceSlot.dayB => 'day:dayplan-2026-05-19',
    };

class GeneratedWakeQueueOperation {
  const GeneratedWakeQueueOperation({
    required this.kind,
    required this.runKeySlot,
    required this.agentSlot,
    required this.tokenSlot,
    required this.workspaceSlot,
  });

  final GeneratedWakeQueueOperationKind kind;
  final GeneratedWakeQueueRunKeySlot runKeySlot;
  final GeneratedWakeQueueAgentSlot agentSlot;
  final GeneratedWakeQueueTokenSlot tokenSlot;
  final GeneratedWakeQueueWorkspaceSlot workspaceSlot;

  String get runKey => generatedWakeQueueRunKey(runKeySlot);

  String get agentId => generatedWakeQueueAgentId(agentSlot);

  String get token => generatedWakeQueueToken(tokenSlot);

  String? get workspaceKey => generatedWakeQueueWorkspace(workspaceSlot);

  @override
  String toString() {
    return 'GeneratedWakeQueueOperation('
        'kind: $kind, runKeySlot: $runKeySlot, '
        'agentSlot: $agentSlot, tokenSlot: $tokenSlot, '
        'workspaceSlot: $workspaceSlot)';
  }
}

class GeneratedWakeQueueScenario {
  const GeneratedWakeQueueScenario({required this.operations});

  final List<GeneratedWakeQueueOperation> operations;

  @override
  String toString() {
    return 'GeneratedWakeQueueScenario(operations: $operations)';
  }
}

class GeneratedWakeQueueModelJob {
  GeneratedWakeQueueModelJob({
    required this.runKey,
    required this.agentId,
    required Set<String> triggerTokens,
    required this.workspaceKey,
  }) : triggerTokens = Set<String>.of(triggerTokens);

  final String runKey;
  final String agentId;
  final Set<String> triggerTokens;
  final String? workspaceKey;
}

class GeneratedWakeQueueModel {
  final queue = <GeneratedWakeQueueModelJob>[];
  final seenRunKeys = <String>{};
  GeneratedWakeQueueModelJob? lastDequeued;
}

extension AnyGeneratedWakeQueueScenario on glados.Any {
  glados.Generator<GeneratedWakeQueueOperationKind>
  get wakeQueueOperationKind =>
      glados.AnyUtils(this).choose(GeneratedWakeQueueOperationKind.values);

  glados.Generator<GeneratedWakeQueueRunKeySlot> get wakeQueueRunKeySlot =>
      glados.AnyUtils(this).choose(GeneratedWakeQueueRunKeySlot.values);

  glados.Generator<GeneratedWakeQueueAgentSlot> get wakeQueueAgentSlot =>
      glados.AnyUtils(this).choose(GeneratedWakeQueueAgentSlot.values);

  glados.Generator<GeneratedWakeQueueTokenSlot> get wakeQueueTokenSlot =>
      glados.AnyUtils(this).choose(GeneratedWakeQueueTokenSlot.values);

  glados.Generator<GeneratedWakeQueueWorkspaceSlot>
  get wakeQueueWorkspaceSlot =>
      glados.AnyUtils(this).choose(GeneratedWakeQueueWorkspaceSlot.values);

  glados.Generator<GeneratedWakeQueueOperation> get wakeQueueOperation =>
      glados.CombinableAny(this).combine5(
        wakeQueueOperationKind,
        wakeQueueRunKeySlot,
        wakeQueueAgentSlot,
        wakeQueueTokenSlot,
        wakeQueueWorkspaceSlot,
        (
          GeneratedWakeQueueOperationKind kind,
          GeneratedWakeQueueRunKeySlot runKeySlot,
          GeneratedWakeQueueAgentSlot agentSlot,
          GeneratedWakeQueueTokenSlot tokenSlot,
          GeneratedWakeQueueWorkspaceSlot workspaceSlot,
        ) => GeneratedWakeQueueOperation(
          kind: kind,
          runKeySlot: runKeySlot,
          agentSlot: agentSlot,
          tokenSlot: tokenSlot,
          workspaceSlot: workspaceSlot,
        ),
      );

  glados.Generator<GeneratedWakeQueueScenario> get wakeQueueScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(0, 40, wakeQueueOperation)
          .map(
            (operations) => GeneratedWakeQueueScenario(
              operations: operations,
            ),
          );
}
