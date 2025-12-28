import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';

void main() {
  group('Task Summary Prompt - Goal Section', () {
    test('includes Goal section instruction', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('**Goal**'));
      expect(user, contains('desired outcome'));
      expect(user, contains('essential purpose'));
    });

    test('specifies Goal should be succinct', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('1-3 sentences'));
    });

    test('includes Goal example format', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('**Goal:**'));
    });

    test('Goal section comes after TLDR in instructions', () {
      final user = taskSummaryPrompt.userMessage;
      final tldrExampleIndex = user.indexOf('Example TLDR format:');
      final goalInstructionIndex =
          user.indexOf('After the TLDR, include a **Goal**');
      expect(goalInstructionIndex, greaterThan(tldrExampleIndex));
    });

    test('Goal section comes before Achieved results in example', () {
      final user = taskSummaryPrompt.userMessage;
      final goalExampleIndex = user.indexOf('**Goal:** [1-3 sentence');
      final achievedIndex = user.indexOf('**Achieved results:**');
      expect(goalExampleIndex, greaterThan(-1));
      expect(achievedIndex, greaterThan(goalExampleIndex));
    });
  });

  group('Task Summary Prompt - Link Extraction', () {
    test('includes Links section instruction', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('**Links** section'));
      expect(user, contains('**Links:**'));
    });

    test('instructs to scan log entries for URLs', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('Scan ALL log entries'));
      expect(user, contains('URLs'));
      expect(user, contains('http://'));
      expect(user, contains('https://'));
    });

    test('instructs Markdown link format', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('[Succinct Title](URL)'));
      expect(user, contains('short, succinct title'));
    });

    test('instructs to extract unique URLs', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('unique URL'));
    });

    test('instructs to omit Links section when no links found', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('no links are found'));
      expect(user, contains('omit the Links section'));
    });

    test('includes example links section with various URL types', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('[Flutter Documentation]'));
      expect(user, contains('docs.flutter.dev'));
      expect(user, contains('[Linear: APP-123]'));
      expect(user, contains('linear.app'));
      expect(user, contains('[Lotti PR #456]'));
      expect(user, contains('[GitHub Issue'));
      expect(user, contains('github.com'));
      expect(user, contains('[Stack Overflow Solution]'));
      expect(user, contains('stackoverflow.com'));
    });

    test('includes disclaimer about example URLs', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('format examples only'));
      expect(user, contains('never copy these URLs'));
      expect(user, contains('only use actual URLs found in the task'));
    });
  });

  test('Checklist updates prompt instructs array-of-objects format', () {
    final prompt = checklistUpdatesPrompt.systemMessage;
    expect(prompt, contains('add_multiple_checklist_items'));
    expect(prompt, contains('JSON array of objects'));
    expect(prompt, isNot(contains('actionItemDescription')));
  });

  test('Checklist updates prompt user message includes Assigned Labels section',
      () {
    final user = checklistUpdatesPrompt.userMessage;
    expect(user, contains('Assigned Labels'));
    expect(user, contains('{{assigned_labels}}'));
  });

  test('Checklist updates prompt includes entry-scoped directive guidance', () {
    final sys = checklistUpdatesPrompt.systemMessage;
    expect(sys, contains('ENTRY-SCOPED DIRECTIVES'));
    expect(sys, contains("Don't consider this for checklist items"));
    expect(sys, contains('Single checklist item'));

    final user = checklistUpdatesPrompt.userMessage;
    expect(user, contains('Directive reminder'));
    expect(user, contains('Ignore for checklist'));
    expect(user, contains('The rest is an implementation plan'));
  });

  test('Checklist updates prompt includes update_checklist_items guidance', () {
    final sys = checklistUpdatesPrompt.systemMessage;
    expect(sys, contains('update_checklist_items'));
    expect(sys, contains('Update existing checklist items by ID'));
    expect(sys, contains('isChecked'));
    expect(sys, contains('title'));
    // Check for reactive behavior guidance
    expect(sys, contains('REACTIVE'));
    // Check for title correction examples (multiple common cases)
    expect(sys, contains('macOS'));
    expect(sys, contains('iPhone'));
    expect(sys, contains('GitHub'));
    expect(sys, contains('TestFlight'));
    // Check for error guidance
    expect(sys, contains('invalid'));
    expect(sys, contains('skipped'));
  });

  test('Checklist updates prompt includes negative examples', () {
    final sys = checklistUpdatesPrompt.systemMessage;
    // Check for DON'T examples to prevent misuse
    expect(sys, contains("Examples (DON'T)"));
    expect(sys, contains('proactively fix'));
    expect(sys, contains('INVALID'));
  });

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

  group('Coding Prompt Generation Template', () {
    test('has correct structure and metadata', () {
      expect(promptGenerationPrompt.id, 'prompt_generation');
      expect(promptGenerationPrompt.name, 'Generate Coding Prompt');
      expect(
        promptGenerationPrompt.aiResponseType,
        AiResponseType.promptGeneration,
      );
      expect(promptGenerationPrompt.useReasoning, true);
    });

    test('includes audioTranscript placeholder', () {
      final user = promptGenerationPrompt.userMessage;
      expect(user, contains('{{audioTranscript}}'));
    });

    test('includes task and linked_tasks placeholders', () {
      final user = promptGenerationPrompt.userMessage;
      expect(user, contains('{{task}}'));
      expect(user, contains('{{linked_tasks}}'));
    });

    test('specifies Summary and Prompt output format', () {
      final sys = promptGenerationPrompt.systemMessage;
      expect(sys, contains('## Summary'));
      expect(sys, contains('## Prompt'));
      expect(sys, contains('OUTPUT FORMAT'));
    });

    test('is registered in preconfiguredPrompts lookup', () {
      expect(
        preconfiguredPrompts['prompt_generation'],
        promptGenerationPrompt,
      );
    });
  });
}
