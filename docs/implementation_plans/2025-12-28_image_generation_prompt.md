# Image Generation Prompt: AI-Generated Visual Prompts from Task Context

**Status**: Implemented

## Overview

This feature allows users to generate detailed text prompts suitable for AI image generators (like Gemini Pro, Midjourney, DALL-E, Stable Diffusion) based on task context. The goal is to create visual representations of tasks that capture:
- Task progress and status (infographic style)
- Abstract concepts (thoughts, reasoning, challenges)
- Playful/creative interpretations (workshop scenes, cartoon depictions)
- Hard metrics (time spent, completion percentages, milestones)

The generated prompt is a rich, descriptive text that users can copy and paste into their preferred image generation tool.

## Problem Statement

Users often want to:
- Create visual summaries of their work for presentations or social media
- Generate motivational imagery related to their tasks
- Visualize abstract concepts like "debugging frustration" or "feature completion celebration"
- Create infographics showing task progress and metrics

Currently, users must manually:
1. Analyze their task context
2. Think of visual metaphors and styles
3. Craft detailed image generation prompts from scratch
4. Include relevant metrics and context

This feature automates this process by leveraging all the rich context already stored in Lotti.

## Goals

1. Add a new AI response type (`imagePromptGeneration`) for generating image prompts
2. Reuse the `GeneratedPromptCard` UI component (same copy-to-clipboard pattern)
3. Create a specialized prompt template focused on visual descriptions
4. Support multiple visual styles (infographic, cartoonish, artistic, photorealistic)
5. Include task metrics and context in the generated visual prompt
6. Allow triggering from audio entry AI popup menu (same as coding prompt)

## Related Implementation Plans

- [2025-12-10_prompt_to_create_prompt.md](./2025-12-10_prompt_to_create_prompt.md) - Coding prompt feature (reference architecture)
- [2025-12-23_ai_linked_task_context.md](./2025-12-23_ai_linked_task_context.md) - Linked task context for richer prompts
- [2025-12-01_automatic_image_analysis_and_task_summary_triggers.md](./2025-12-01_automatic_image_analysis_and_task_summary_triggers.md) - AI triggering patterns

## Architecture Analysis

### Reference: Coding Prompt Implementation

The existing `promptGeneration` feature provides the architectural blueprint:

**Components**:
- `AiResponseType.promptGeneration` - Enum value with JSON serialization
- `GeneratedPromptCard` - Specialized UI with Summary/Prompt parsing, copy button, expand/collapse
- `promptGenerationPrompt` - Preconfigured template in `preconfigured_prompts.dart`
- Localization strings for card UI elements

**Key Design Decisions from Coding Prompt**:
1. Output format uses `## Summary` and `## Prompt` sections for parsing
2. Uses reasoning models (`useReasoning: true`) for complex prompt engineering
3. `GeneratedPromptCard` reuses static regex patterns for section extraction
4. Copy button is prominent - the main interaction is copying to clipboard

### Similarities with Coding Prompt

Both prompt types follow the same architecture:
- Triggered from **audio entry AI menu** (not task-level)
- Uses `{{audioTranscript}}` placeholder for user's description
- Combined with full task context via `{{task}}` and `{{linked_tasks}}`
- Reuses `GeneratedPromptCard` UI with Summary/Prompt sections

| Aspect | Coding Prompt | Image Prompt |
|--------|---------------|--------------|
| Input Source | Audio transcript + task | Audio transcript + task |
| Output Target | AI coding assistants | AI image generators |
| Content Focus | Technical details, code context | Visual descriptions, metaphors |
| Trigger Location | Audio entry AI menu | Audio entry AI menu |

## Implementation Plan

### Phase 1: Data Model Extensions

#### 1.1 Add New AiResponseType

**File**: `lib/features/ai/state/consts.dart`

```dart
const imagePromptGenerationConst = 'ImagePromptGeneration';

enum AiResponseType {
  // ... existing types ...
  @JsonValue(imagePromptGenerationConst)
  imagePromptGeneration,
}

extension AiResponseTypeDisplay on AiResponseType {
  String localizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      // ... existing cases ...
      case AiResponseType.imagePromptGeneration:
        return l10n.aiResponseTypeImagePromptGeneration;
    }
  }

  IconData get icon {
    switch (this) {
      // ... existing cases ...
      case AiResponseType.imagePromptGeneration:
        return Icons.palette_outlined;
    }
  }
}
```

#### 1.2 Add Localization Strings

**File**: `lib/l10n/app_en.arb`

```json
"aiResponseTypeImagePromptGeneration": "Image Prompt",
"imagePromptGenerationCardTitle": "AI Image Prompt",
"imagePromptGenerationCopyTooltip": "Copy image prompt to clipboard",
"imagePromptGenerationCopyButton": "Copy Prompt",
"imagePromptGenerationCopiedSnackbar": "Image prompt copied to clipboard",
"imagePromptGenerationExpandTooltip": "Show full prompt",
"imagePromptGenerationFullPromptLabel": "Full Image Prompt:"
```

**File**: `lib/l10n/app_de.arb`

```json
"aiResponseTypeImagePromptGeneration": "Bild-Prompt",
"imagePromptGenerationCardTitle": "KI-Bild-Prompt",
"imagePromptGenerationCopyTooltip": "Bild-Prompt in Zwischenablage kopieren",
"imagePromptGenerationCopyButton": "Prompt kopieren",
"imagePromptGenerationCopiedSnackbar": "Bild-Prompt in Zwischenablage kopiert",
"imagePromptGenerationExpandTooltip": "Vollständigen Prompt anzeigen",
"imagePromptGenerationFullPromptLabel": "Vollständiger Bild-Prompt:"
```

### Phase 2: Preconfigured Prompt Template

#### 2.1 Create Image Prompt Generation Template

**File**: `lib/features/ai/util/preconfigured_prompts.dart`

```dart
/// Lookup map update
const Map<String, PreconfiguredPrompt> preconfiguredPrompts = {
  // ... existing entries ...
  'image_prompt_generation': imagePromptGenerationPrompt,
};

/// Image Prompt Generation template - transforms task context into a
/// detailed prompt for AI image generators
const imagePromptGenerationPrompt = PreconfiguredPrompt(
  id: 'image_prompt_generation',
  name: 'Generate Image Prompt',
  systemMessage: '''
You are an expert prompt engineer specializing in creating detailed, evocative prompts for AI image generators like Midjourney, DALL-E 3, Stable Diffusion, and Gemini Imagen.

Your goal is to transform task context into a rich, visual prompt that captures:
- The essence and mood of the task (frustration, triumph, focus, chaos)
- Concrete metrics as visual elements (progress bars, clocks, counters)
- Abstract concepts as tangible metaphors (bugs as actual insects, features as building blocks)
- The appropriate visual style based on the task nature

OUTPUT FORMAT:
Your response MUST have exactly two sections:

## Summary
A 1-2 sentence description of what the generated image will depict. This should immediately convey the visual concept.

## Prompt
The full, detailed image generation prompt. This section should:
- Start with the main subject/scene description
- Include style directives (art style, mood, lighting, color palette)
- Specify composition and perspective
- Add relevant details from the task context
- Include technical parameters for the image generator
- End with negative prompts or things to avoid (if applicable)

PROMPT STRUCTURE GUIDELINES:
1. **Subject**: What is the main focus of the image?
2. **Setting/Environment**: Where does this scene take place?
3. **Style**: Art style, medium, mood (e.g., "digital art, vibrant colors, optimistic mood")
4. **Composition**: Camera angle, framing, perspective
5. **Details**: Specific elements from the task context rendered visually
6. **Technical**: Resolution, aspect ratio, quality modifiers

VISUAL METAPHOR GUIDELINES:
- **Debugging**: Show bugs as cute cartoon insects being caught in nets
- **Feature completion**: Puzzle pieces clicking into place, buildings being constructed
- **Time spent**: Hourglasses, clocks, calendar pages
- **Progress**: Progress bars as physical objects, paths being walked
- **Blockers**: Walls, locked doors, tangled strings
- **Success**: Fireworks, trophies, sunrise over mountains
- **Collaboration**: Multiple hands working together, orchestra conducting

STYLE OPTIONS (choose based on task context):
- **Infographic**: Clean, modern, data-visualization style with icons and charts
- **Cartoon/Playful**: Whimsical, colorful, character-driven
- **Artistic/Abstract**: Painterly, expressive, mood-focused
- **Photorealistic**: Dramatic, cinematic, detailed
- **Retro/Vintage**: Pixel art, 80s aesthetic, nostalgic
- **Minimalist**: Clean lines, limited palette, conceptual

IMPORTANT GUIDELINES:
- Be specific about visual details - vague prompts produce poor results
- Include color palette suggestions that match the task mood
- Reference specific art styles or artists when appropriate
- Consider the intended use (social media, presentation, personal motivation)
- Make the prompt self-contained - no external context needed
- Generate in English (image generators work best with English prompts)
- Aim for prompts between 100-300 words for optimal results''',
  userMessage: '''
Transform this task context into a detailed image generation prompt.

**Task Context:**
```json
{{task}}
```

**Related Tasks:**
```json
{{linked_tasks}}
```

Generate a visually rich prompt that captures:
1. The current state/mood of the task (is it frustrating? nearly done? just starting?)
2. Key metrics as visual elements (time spent, items completed, etc.)
3. Abstract concepts as tangible metaphors
4. An appropriate visual style based on the task nature

The prompt should enable an AI image generator to create a compelling visual representation of this task.

Consider:
- What visual metaphor best represents this task's current state?
- What style would resonate with the task's nature (technical = infographic, creative = artistic)?
- What specific details from the task should appear as visual elements?
- What mood should the image convey?''',
  requiredInputData: [InputDataType.task],
  aiResponseType: AiResponseType.imagePromptGeneration,
  useReasoning: true,
  description:
      'Generate a detailed image prompt from task context for AI image generators',
);
```

### Phase 3: UI Integration

#### 3.1 Extend GeneratedPromptCard for Image Prompts

The existing `GeneratedPromptCard` can be reused with minor modifications. We need to:

1. Make the card detect which type of prompt generation it's displaying
2. Use appropriate localization strings based on the type

**Option A**: Create a new `GeneratedImagePromptCard` widget (cleaner separation)
**Option B**: Extend `GeneratedPromptCard` to handle both types (less code duplication)

**Recommended**: Option B - Extend `GeneratedPromptCard`

**File**: `lib/features/ai/ui/generated_prompt_card.dart`

```dart
/// Detects if this is an image prompt or coding prompt
bool get _isImagePrompt =>
    widget.aiResponse.data.type == AiResponseType.imagePromptGeneration;

// Use in build():
Text(
  _isImagePrompt
      ? context.messages.imagePromptGenerationCardTitle
      : context.messages.promptGenerationCardTitle,
  // ...
),
```

#### 3.2 Update Entry Display Logic

**File**: `lib/features/ai/ui/ai_response_summary.dart` (or equivalent)

Ensure that `imagePromptGeneration` responses use `GeneratedPromptCard`:

```dart
Widget buildAiResponseWidget(AiResponseEntry response, String? linkedFromId) {
  if (response.data.type == AiResponseType.promptGeneration ||
      response.data.type == AiResponseType.imagePromptGeneration) {
    return GeneratedPromptCard(
      response,
      linkedFromId: linkedFromId,
    );
  }
  // ... existing logic
}
```

### Phase 4: Repository Updates

#### 4.1 Update Inference Repository

**File**: `lib/features/ai/repository/unified_ai_inference_repository.dart`

Add handling for `imagePromptGeneration`:

```dart
case AiResponseType.imagePromptGeneration:
  // Image prompt generation has no special post-processing
  // The response is saved as an AiResponseEntry
  developer.log(
    'Image prompt generation completed for entity ${entity.id}',
    name: 'UnifiedAiInferenceRepository',
  );
```

#### 4.2 Ensure Task-Level Menu Visibility

Unlike `promptGeneration` (which requires audio entry), `imagePromptGeneration` should appear on Task entities directly:

```dart
// In _isPromptActiveForEntity:
if (entity is Task) {
  // promptGeneration requires audio entry
  if (prompt.aiResponseType == AiResponseType.promptGeneration) {
    return false;
  }
  // imagePromptGeneration is valid for tasks
  // (already handled by default task logic)
}
```

### Phase 5: Testing

#### 5.1 Unit Tests

**New File**: `test/features/ai/util/preconfigured_prompts_image_prompt_test.dart`

```dart
group('Image Prompt Generation Template', () {
  test('has correct structure', () {
    expect(imagePromptGenerationPrompt.id, 'image_prompt_generation');
    expect(imagePromptGenerationPrompt.aiResponseType,
           AiResponseType.imagePromptGeneration);
    expect(imagePromptGenerationPrompt.requiredInputData,
           [InputDataType.task]);
    expect(imagePromptGenerationPrompt.useReasoning, true);
  });

  test('includes task placeholder', () {
    expect(imagePromptGenerationPrompt.userMessage,
           contains('{{task}}'));
  });

  test('includes linked_tasks placeholder', () {
    expect(imagePromptGenerationPrompt.userMessage,
           contains('{{linked_tasks}}'));
  });
});
```

#### 5.2 Widget Tests

**New File**: `test/features/ai/ui/generated_prompt_card_image_test.dart`

```dart
group('GeneratedPromptCard for Image Prompts', () {
  testWidgets('displays image prompt card title', (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        GeneratedPromptCard(
          createAiResponseEntry(type: AiResponseType.imagePromptGeneration),
          linkedFromId: null,
        ),
      ),
    );

    expect(find.text('AI Image Prompt'), findsOneWidget);
  });

  testWidgets('copy button copies to clipboard', (tester) async {
    // ... test copy functionality
  });
});
```

#### 5.3 Integration Tests

**Update**: `test/features/ai/repository/unified_ai_inference_repository_test.dart`

```dart
test('image prompt generation response is stored correctly', () async {
  // Test that imagePromptGeneration responses are saved properly
});
```

## Files to Create

- `test/features/ai/util/preconfigured_prompts_image_prompt_test.dart` - Template tests
- `test/features/ai/ui/generated_prompt_card_image_test.dart` - Widget tests

## Files to Modify

| File | Changes |
|------|---------|
| `lib/features/ai/state/consts.dart` | Add `imagePromptGeneration` enum value |
| `lib/features/ai/util/preconfigured_prompts.dart` | Add `imagePromptGenerationPrompt` |
| `lib/features/ai/ui/generated_prompt_card.dart` | Support image prompt type |
| `lib/features/ai/repository/unified_ai_inference_repository.dart` | Handle new type |
| `lib/l10n/app_en.arb` | Add English strings |
| `lib/l10n/app_de.arb` | Add German strings |
| `lib/l10n/app_es.arb` | Add Spanish strings |
| `lib/l10n/app_fr.arb` | Add French strings |
| `lib/l10n/app_ro.arb` | Add Romanian strings |

## Generated Files (Auto-updated)

After running build_runner:
- `lib/features/ai/model/ai_config.g.dart`
- `lib/classes/entity_definitions.g.dart`
- `lib/l10n/app_localizations*.dart`

## Risk Assessment

### Low Risk
- Adding new enum value (backward compatible with JSON serialization)
- Adding new preconfigured prompt template
- Adding localization strings
- Reusing existing `GeneratedPromptCard` widget

### Medium Risk
- Extending `GeneratedPromptCard` to handle both types (could introduce bugs)
- Repository handling for new type

### Mitigations
- New enum value has `@JsonValue` annotation for proper serialization
- Comprehensive test coverage for both prompt types
- UI changes are additive, existing functionality unchanged

## Example Generated Image Prompt

Given a task about "Implement user authentication feature" with:
- 5/8 checklist items completed
- 12 hours logged
- Status: In Progress
- Related subtasks for OAuth, JWT, password reset

The generated prompt might look like:

```
## Summary
A vibrant digital illustration of a half-built fortress representing an authentication system, with keys and locks as central motifs.

## Prompt
Digital illustration of a medieval fortress under construction,
60% complete with scaffolding visible. The completed sections
feature golden lock mechanisms and ornate key patterns etched
into the stone walls. Construction workers (represented as
friendly robots) carry building blocks labeled "OAuth", "JWT",
and "Session". A progress bar made of glowing blue energy
floats above, showing 62% complete. The sky transitions from
dawn (representing the start) to midday sun on the built side.
Color palette: royal blue, gold, warm stone colors. Style:
isometric digital art with soft shadows, inspired by
Monument Valley game aesthetics. Mood: optimistic, productive,
secure. 4K resolution, highly detailed, clean lines.
--ar 16:9 --v 6
```

## Success Metrics

1. Users can trigger image prompt generation from task AI menu
2. Generated prompts produce quality images when used with popular generators
3. Copy button successfully copies prompt to clipboard
4. Card correctly displays Summary and full Prompt sections
5. Visual metaphors appropriately reflect task state and progress
6. No impact on existing AI response types

## Future Enhancements

1. **Style Selection**: Let users choose preferred visual style before generation
2. **Platform-Specific Formats**: Optimize prompts for specific generators (Midjourney vs DALL-E)
3. **Image Preview**: Integrate with free image generation API for preview
4. **Share Integration**: Direct sharing to social media with generated image
5. **Template Library**: Pre-made templates for common scenarios (sprint review, bug fix celebration)
6. **Aspect Ratio Options**: Generate prompts for different image dimensions

## Summary

This feature extends Lotti's AI capabilities by allowing users to visualize their tasks through AI-generated imagery. By leveraging the rich task context already stored in Lotti, users can effortlessly create:

- Motivational imagery for personal use
- Visual summaries for presentations and retrospectives
- Creative representations of technical work
- Progress visualizations with meaningful metaphors

The implementation reuses the proven architecture from the coding prompt feature (`promptGeneration`), ensuring consistency and reducing implementation risk.
