import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';

void main() {
  group('Image Prompt Generation Template', () {
    test('has correct structure and metadata', () {
      expect(imagePromptGenerationPrompt.id, 'image_prompt_generation');
      expect(imagePromptGenerationPrompt.name, 'Generate Image Prompt');
      expect(
        imagePromptGenerationPrompt.aiResponseType,
        AiResponseType.imagePromptGeneration,
      );
      expect(imagePromptGenerationPrompt.useReasoning, true);
    });

    test('requires task input data only', () {
      expect(
        imagePromptGenerationPrompt.requiredInputData,
        [InputDataType.task],
      );
    });

    test('includes audioTranscript placeholder for user description', () {
      final user = imagePromptGenerationPrompt.userMessage;
      expect(user, contains('{{audioTranscript}}'));
    });

    test('includes task and linked_tasks placeholders', () {
      final user = imagePromptGenerationPrompt.userMessage;
      expect(user, contains('{{task}}'));
      expect(user, contains('{{linked_tasks}}'));
    });

    test('specifies Summary and Prompt output format', () {
      final sys = imagePromptGenerationPrompt.systemMessage;
      expect(sys, contains('## Summary'));
      expect(sys, contains('## Prompt'));
      expect(sys, contains('OUTPUT FORMAT'));
    });

    test('includes visual metaphor guidelines', () {
      final sys = imagePromptGenerationPrompt.systemMessage;
      expect(sys, contains('VISUAL METAPHOR GUIDELINES'));
      expect(sys, contains('Debugging'));
      expect(sys, contains('Feature completion'));
      expect(sys, contains('Progress'));
      expect(sys, contains('Blockers'));
      expect(sys, contains('Success'));
    });

    test('includes style options', () {
      final sys = imagePromptGenerationPrompt.systemMessage;
      expect(sys, contains('STYLE OPTIONS'));
      expect(sys, contains('Infographic'));
      expect(sys, contains('Cartoon'));
      expect(sys, contains('Artistic'));
      expect(sys, contains('Photorealistic'));
      expect(sys, contains('Minimalist'));
      expect(sys, contains('Isometric'));
    });

    test('includes prompt structure guidelines', () {
      final sys = imagePromptGenerationPrompt.systemMessage;
      expect(sys, contains('PROMPT STRUCTURE GUIDELINES'));
      expect(sys, contains('Subject'));
      expect(sys, contains('Setting/Environment'));
      expect(sys, contains('Style'));
      expect(sys, contains('Composition'));
      expect(sys, contains('Technical'));
    });

    test('mentions target image generators', () {
      final sys = imagePromptGenerationPrompt.systemMessage;
      expect(sys, contains('Midjourney'));
      expect(sys, contains('DALL-E'));
      expect(sys, contains('Stable Diffusion'));
      expect(sys, contains('Gemini Imagen'));
    });

    test('includes related tasks context guidance', () {
      final sys = imagePromptGenerationPrompt.systemMessage;
      expect(sys, contains('RELATED TASKS CONTEXT'));
      expect(sys, contains('linked_from'));
      expect(sys, contains('linked_to'));
    });

    test('is registered in preconfiguredPrompts lookup', () {
      expect(
        preconfiguredPrompts['image_prompt_generation'],
        imagePromptGenerationPrompt,
      );
    });
  });
}
