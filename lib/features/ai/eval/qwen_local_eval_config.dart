import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

const qwen36A35bA3bTurboQuantMlx4BitModelId =
    'Qwen3.6-35B-A3B-TurboQuant-MLX-4bit';
const qwen36A35bA3bMlx4BitModelId = 'Qwen3.6-35B-A3B-4bit';
const qwen36A35bA3bMlx8BitModelId = 'Qwen3.6-35B-A3B-MLX-8bit';

const qwenLocalEvalKind = 'lotti.qwenLocalInferenceEvalReport';

const List<String> _coreTaskFieldToolNames = [
  TaskAgentToolNames.setTaskTitle,
  TaskAgentToolNames.setTaskStatus,
  TaskAgentToolNames.updateTaskEstimate,
  TaskAgentToolNames.updateTaskDueDate,
  TaskAgentToolNames.updateTaskPriority,
];

const defaultQwenLocalEvalProfiles = [
  QwenLocalEvalProfile(
    name: 'qwen36-a35b-a3b-turboquant-mlx4',
    providerModelId: qwen36A35bA3bTurboQuantMlx4BitModelId,
    modelClass: 'qwen36-a35b-a3b-omlx',
  ),
  QwenLocalEvalProfile(
    name: 'qwen36-a35b-a3b-mlx4',
    providerModelId: qwen36A35bA3bMlx4BitModelId,
    modelClass: 'qwen36-a35b-a3b-omlx',
  ),
  QwenLocalEvalProfile(
    name: 'qwen36-a35b-a3b-mlx8',
    providerModelId: qwen36A35bA3bMlx8BitModelId,
    modelClass: 'qwen36-a35b-a3b-omlx',
  ),
];

const defaultQwenLocalEvalScenarios = [
  QwenLocalEvalScenario(
    id: 'task_title_tool_call',
    userPrompt:
        'Task id task-1 is currently titled "Inbox item". Rename it to '
        '"Submit expense report".',
    exposedToolNames: _coreTaskFieldToolNames,
    expectedToolName: TaskAgentToolNames.setTaskTitle,
    expectedArgumentsSubset: {'title': 'Submit expense report'},
  ),
  QwenLocalEvalScenario(
    id: 'task_status_tool_call',
    userPrompt:
        'Task id task-2 is open. The user says work has started. Move the '
        'task to IN PROGRESS.',
    exposedToolNames: _coreTaskFieldToolNames,
    expectedToolName: TaskAgentToolNames.setTaskStatus,
    expectedArgumentsSubset: {'status': 'IN PROGRESS'},
  ),
  QwenLocalEvalScenario(
    id: 'task_estimate_tool_call',
    userPrompt:
        'Task id task-3 needs about two and a half hours of focused work. '
        'Set the remaining estimate accordingly.',
    exposedToolNames: _coreTaskFieldToolNames,
    expectedToolName: TaskAgentToolNames.updateTaskEstimate,
    expectedArgumentsSubset: {'minutes': 150},
  ),
  QwenLocalEvalScenario(
    id: 'task_due_date_tool_call',
    userPrompt:
        'Task id task-4 must be finished by July 4, 2026. Update the due '
        'date to that exact day.',
    exposedToolNames: _coreTaskFieldToolNames,
    expectedToolName: TaskAgentToolNames.updateTaskDueDate,
    expectedArgumentsSubset: {'dueDate': '2026-07-04'},
  ),
  QwenLocalEvalScenario(
    id: 'task_priority_tool_call',
    userPrompt:
        'Task id task-5 is urgent and should be handled as P1. Update the '
        'task priority.',
    exposedToolNames: _coreTaskFieldToolNames,
    expectedToolName: TaskAgentToolNames.updateTaskPriority,
    expectedArgumentsSubset: {'priority': 'P1'},
  ),
];

class QwenLocalEvalProfile {
  const QwenLocalEvalProfile({
    required this.name,
    required this.providerModelId,
    required this.modelClass,
  });

  final String name;
  final String providerModelId;
  final String modelClass;

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'providerModelId': providerModelId,
      'modelClass': modelClass,
    };
  }
}

class QwenLocalEvalScenario {
  const QwenLocalEvalScenario({
    required this.id,
    required this.userPrompt,
    required this.exposedToolNames,
    this.expectedToolName,
    this.expectedArgumentsSubset = const {},
    this.systemPrompt = _defaultSystemPrompt,
  });

  static const _defaultSystemPrompt =
      'You are evaluating Lotti task-agent function calling. Use a tool call '
      'when the user asks for a task mutation. When a tool call is appropriate, '
      'do not add explanatory prose.';

  final String id;
  final String systemPrompt;
  final String userPrompt;
  final List<String> exposedToolNames;
  final String? expectedToolName;
  final Map<String, Object?> expectedArgumentsSubset;

  bool get expectsToolCall => expectedToolName != null;

  bool get expectsArguments => expectedArgumentsSubset.isNotEmpty;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'exposedToolNames': exposedToolNames,
      'expectedToolName': expectedToolName,
      'expectedArgumentKeys': expectedArgumentsSubset.keys.toList(),
    };
  }
}

List<QwenLocalEvalScenario> selectQwenLocalEvalScenarios(
  List<String> scenarioIds,
) {
  if (scenarioIds.isEmpty) return defaultQwenLocalEvalScenarios;
  final byId = {
    for (final scenario in defaultQwenLocalEvalScenarios) scenario.id: scenario,
  };
  return scenarioIds
      .map((id) {
        final scenario = byId[id];
        if (scenario == null) {
          throw ArgumentError.value(
            id,
            'scenarioIds',
            'Unknown Qwen local eval scenario.',
          );
        }
        return scenario;
      })
      .toList(growable: false);
}

QwenLocalEvalProfile parseQwenLocalEvalProfile(String value) {
  final separator = value.indexOf('=');
  if (separator <= 0 || separator == value.length - 1) {
    throw FormatException(
      'Expected profile as name=model, got "$value".',
      value,
    );
  }
  final name = value.substring(0, separator);
  final model = value.substring(separator + 1);
  return QwenLocalEvalProfile(
    name: name,
    providerModelId: model,
    modelClass: name,
  );
}
