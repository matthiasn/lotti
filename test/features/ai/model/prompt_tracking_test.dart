import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/state/consts.dart';

void main() {
  group('Prompt Tracking Persistence', () {
    test(
        'should preserve trackPreconfigured and preconfiguredPromptId when converting to/from AiConfig',
        () {
      // Create a form state with tracking enabled
      final formState = PromptFormState(
        name: const PromptName.dirty('Test Prompt'),
        systemMessage: const PromptSystemMessage.dirty('System message'),
        userMessage: const PromptUserMessage.dirty('User message'),
        defaultModelId: 'model-123',
        modelIds: ['model-123'],
        useReasoning: true,
        requiredInputData: [InputDataType.task],
        aiResponseType:
            const PromptAiResponseType.dirty(AiResponseType.taskSummary),
        trackPreconfigured: true,
        preconfiguredPromptId: 'task_summary',
      );

      // Convert to AiConfig
      final aiConfig = formState.toAiConfig() as AiConfigPrompt;

      // Verify fields are preserved
      expect(aiConfig.trackPreconfigured, true);
      expect(aiConfig.preconfiguredPromptId, 'task_summary');

      // Create a new form state from the config (simulating loading from DB)
      final loadedFormState = PromptFormState(
        id: aiConfig.id,
        name: PromptName.pure(aiConfig.name),
        systemMessage: PromptSystemMessage.pure(aiConfig.systemMessage),
        userMessage: PromptUserMessage.pure(aiConfig.userMessage),
        defaultModelId: aiConfig.defaultModelId,
        modelIds: aiConfig.modelIds,
        useReasoning: aiConfig.useReasoning,
        requiredInputData: aiConfig.requiredInputData,
        aiResponseType: PromptAiResponseType.pure(aiConfig.aiResponseType),
        trackPreconfigured: aiConfig.trackPreconfigured,
        preconfiguredPromptId: aiConfig.preconfiguredPromptId,
      );

      // Verify loaded state has tracking fields
      expect(loadedFormState.trackPreconfigured, true);
      expect(loadedFormState.preconfiguredPromptId, 'task_summary');
    });

    test('should handle turning tracking on and off', () {
      // Start with tracking enabled
      var formState = PromptFormState(
        name: const PromptName.dirty('Test Prompt'),
        systemMessage: const PromptSystemMessage.dirty('System message'),
        userMessage: const PromptUserMessage.dirty('User message'),
        defaultModelId: 'model-123',
        modelIds: ['model-123'],
        aiResponseType:
            const PromptAiResponseType.dirty(AiResponseType.taskSummary),
        trackPreconfigured: true,
        preconfiguredPromptId: 'task_summary',
      );

      // Turn tracking off
      formState = formState.copyWith(trackPreconfigured: false);

      // preconfiguredPromptId should still be present
      expect(formState.trackPreconfigured, false);
      expect(formState.preconfiguredPromptId, 'task_summary');

      // Convert to AiConfig and back
      final aiConfig = formState.toAiConfig() as AiConfigPrompt;
      expect(aiConfig.trackPreconfigured, false);
      expect(aiConfig.preconfiguredPromptId, 'task_summary');
    });
  });
}
