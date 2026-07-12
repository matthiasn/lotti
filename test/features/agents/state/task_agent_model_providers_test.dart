import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

void main() {
  AiConfigModel model({
    bool tools = true,
    List<Modality> input = const [Modality.text],
    List<Modality> output = const [Modality.text],
  }) {
    return AiConfigModel(
      id: 'model',
      name: 'Model',
      providerModelId: 'wire-model',
      inferenceProviderId: 'provider',
      createdAt: DateTime(2024),
      inputModalities: input,
      outputModalities: output,
      isReasoningModel: true,
      supportsFunctionCalling: tools,
    );
  }

  test('task-agent model capability requires text in/out and tool calling', () {
    expect(isTaskAgentThinkingModel(model()), isTrue);
    expect(isTaskAgentThinkingModel(model(tools: false)), isFalse);
    expect(
      isTaskAgentThinkingModel(model(input: const [Modality.image])),
      isFalse,
    );
    expect(
      isTaskAgentThinkingModel(model(output: const [Modality.image])),
      isFalse,
    );
  });
}
