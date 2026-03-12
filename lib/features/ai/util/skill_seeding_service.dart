import 'dart:developer' as developer;

import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';

/// Well-known IDs for preconfigured skills (idempotent seeding).
const skillTranscribeId = 'skill-transcribe-001';
const skillTranscribeContextId = 'skill-transcribe-context-001';
const skillImageAnalysisId = 'skill-image-analysis-001';
const skillImageAnalysisContextId = 'skill-image-analysis-context-001';
const skillImageGenId = 'skill-image-gen-001';
const skillPromptGenId = 'skill-prompt-gen-001';
const skillImagePromptGenId = 'skill-image-prompt-gen-001';

const _logTag = 'SkillSeedingService';

/// Seeds preconfigured skills into the AI config database.
///
/// Each skill is derived from the corresponding `PreconfiguredPrompt` template,
/// with placeholder syntax stripped from instructions. The `SkillPromptBuilder`
/// re-injects placeholders at runtime based on `skillType` + `contextPolicy`.
///
/// Follows the same idempotent pattern as `ProfileSeedingService`: checks each
/// skill by ID and skips if it already exists.
class SkillSeedingService {
  const SkillSeedingService({
    required AiConfigRepository aiConfigRepository,
  }) : _repo = aiConfigRepository;

  final AiConfigRepository _repo;

  /// Seeds all preconfigured skills. Safe to call multiple times.
  Future<void> seedDefaults() async {
    var seededCount = 0;

    for (final skill in defaultSkills) {
      final existing = await _repo.getConfigById(skill.id);
      if (existing != null) continue;

      await _repo.saveConfig(skill);
      seededCount++;
    }

    if (seededCount > 0) {
      developer.log(
        'Seeded $seededCount preconfigured skills',
        name: _logTag,
      );
    } else {
      developer.log(
        'Preconfigured skills already seeded, skipping',
        name: _logTag,
      );
    }
  }

  /// The preconfigured skill definitions.
  ///
  /// Exposed as a static list for testability and for the profile seeder
  /// to reference skill IDs.
  static final defaultSkills = <AiConfigSkill>[
    // -- Transcription skills --
    AiConfigSkill(
      id: skillTranscribeId,
      name: 'Transcribe Audio',
      skillType: SkillType.transcription,
      requiredInputModalities: [Modality.audio],
      contextPolicy: ContextPolicy.dictionaryOnly,
      isPreconfigured: true,
      createdAt: DateTime(2026),
      description: 'Transcribe audio recordings into text format',
      systemInstructions: '''
You are a helpful AI assistant that transcribes audio content.
Your goal is to provide accurate, well-formatted transcriptions of audio recordings.
IMPORTANT: Do NOT translate - transcribe in the original spoken language.''',
      userInstructions: '''
Transcribe the provided audio file(s). Do NOT translate - keep the original language.
Format the transcription clearly with proper punctuation.
Start a new paragraph when there are small pauses or topic changes in the speech.
Remove filler words.''',
    ),
    AiConfigSkill(
      id: skillTranscribeContextId,
      name: 'Transcribe (Task Context)',
      skillType: SkillType.transcription,
      requiredInputModalities: [Modality.audio],
      contextPolicy: ContextPolicy.fullTask,
      isPreconfigured: true,
      createdAt: DateTime(2026),
      description:
          'Transcribe audio recordings, taking into account task context',
      systemInstructions: '''
You are a helpful AI assistant that transcribes audio content.
Output ONLY the transcription - do NOT include any text from the context below.
IMPORTANT: Do NOT translate - transcribe in the original spoken language.''',
      userInstructions: '''
Transcribe the provided audio with proper punctuation and paragraph breaks.
Do NOT translate - keep the original language.
Remove filler words.''',
    ),

    // -- Image analysis skills --
    AiConfigSkill(
      id: skillImageAnalysisId,
      name: 'Analyze Image',
      skillType: SkillType.imageAnalysis,
      requiredInputModalities: [Modality.image],
      isPreconfigured: true,
      createdAt: DateTime(2026),
      description: 'Analyze images in detail',
      systemInstructions: '''
You are a helpful AI assistant specialized in analyzing images in the context of tasks and projects.

RESPONSE LANGUAGE: If a language code is provided below, generate your ENTIRE response in that language.
- "de" = German, "fr" = French, "es" = Spanish, "it" = Italian, etc.
- If no language code is provided or it is empty, respond in English.''',
      userInstructions: '''
Analyze the provided image(s) in detail, focusing on both the content and style of the image.

If a language code appears above (e.g., "de", "fr", "es"), respond entirely in that language. Otherwise, respond in English.''',
    ),
    AiConfigSkill(
      id: skillImageAnalysisContextId,
      name: 'Analyze Image (Task Context)',
      skillType: SkillType.imageAnalysis,
      requiredInputModalities: [Modality.image],
      contextPolicy: ContextPolicy.fullTask,
      isPreconfigured: true,
      createdAt: DateTime(2026),
      description: 'Analyze images specifically for task-relevant details',
      systemInstructions: '''
IMPORTANT - RESPONSE LANGUAGE REQUIREMENT:
You MUST generate your ENTIRE response in the language specified by the task's "languageCode" field in the task context JSON.
- If languageCode is "de", respond entirely in German
- If languageCode is "fr", respond entirely in French
- If languageCode is "es", respond entirely in Spanish
- And so on for any other language code
- Only default to English if languageCode is null, empty, or "en"
This applies to ALL text in your response, not just the main content.

You are a helpful AI assistant specialized in analyzing images in the context of tasks and projects.
Your goal is to extract only the information from images that is relevant to the user's current task.

When analyzing images in the context of a task, pay attention to:
1. Any evidence that existing checklist items have been completed (e.g., screenshots showing completed features, test results, or deployment confirmations)
2. Any new tasks or action items that should be tracked based on what's shown in the image

Important guidelines:
- Focus exclusively on what is visible in the image
- Never mention what is NOT present or missing
- Be concise and direct in your observations

RELATED TASKS CONTEXT:
You may receive a `linked_tasks` object containing related parent/child tasks.
Use this context to better understand what the image might be showing in relation to the broader project.

Include these observations in your analysis so the user can update their task accordingly.''',
      userInstructions: '''
REMINDER: Generate your ENTIRE response in the language specified by the task's "languageCode" field below. Check the languageCode value and respond in that language.

Analyze the provided image(s) in the context of this task.

Extract ONLY information from the image that is relevant to this task. Be concise and focus on task-related content.

If the image is NOT relevant to the task:
- Provide a brief 1-2 sentence summary explaining why it's off-topic
- Use a slightly humorous or salty tone if appropriate

If the image IS relevant:
- Extract key information that helps with the task
- Be direct and concise
- Focus on actionable insights or important details
- Only mention what you actually see in the image
- Do NOT mention what is absent or missing from the image
- If a browser window is visible, include the URL from its address bar''',
    ),

    // -- Image generation skill --
    AiConfigSkill(
      id: skillImageGenId,
      name: 'Generate Cover Art',
      skillType: SkillType.imageGeneration,
      requiredInputModalities: [Modality.text],
      contextPolicy: ContextPolicy.fullTask,
      isPreconfigured: true,
      createdAt: DateTime(2026),
      description:
          'Generate cover art image from task context, summary insights, '
          'reference images, and voice description',
      systemInstructions: '''
You are an expert visual artist specializing in creating memorable, evocative cover art images for tasks and projects.

Your goal is to generate a high-quality image that serves as a visual mnemonic - helping the user instantly recognize and recall this task when scanning through their task list.

COMPOSITION REQUIREMENTS:
- Aspect Ratio: Always use 16:9 wide format (1920x1080 pixels)
- Center-Weighted Safe Zone: Place the main subject in the center 50% of the image width, but NOT at the very top
- Strong Central Focus: The center portion should tell the complete visual story
- Avoid Edge-Heavy Elements: Don't place important elements in the outer quarters

STYLE GUIDELINES:
- Create visually distinctive, memorable images
- Use bold colors and clear compositions
- Avoid generic or clichéd imagery
- Consider the emotional tone of the task (urgent, creative, technical, fun)
- Make it instantly recognizable at thumbnail size
- Use emotional insights from the task summary to inform the visual tone

OUTPUT:
Generate a single image that captures the essence of the task based on the provided context.''',
      userInstructions: '''
Generate a cover art image for this task.

Create a visually memorable image that:
1. Captures the essence of what this task is about
2. If reference images are provided, incorporate their visual style
3. Incorporates emotional insights from the task summary
4. Works well as a thumbnail (center-weighted composition)
5. Uses the 16:9 aspect ratio
6. Is instantly recognizable and memorable''',
    ),

    // -- Prompt generation skills --
    AiConfigSkill(
      id: skillPromptGenId,
      name: 'Generate Coding Prompt',
      skillType: SkillType.promptGeneration,
      requiredInputModalities: [Modality.audio],
      contextPolicy: ContextPolicy.fullTask,
      isPreconfigured: true,
      useReasoning: true,
      createdAt: DateTime(2026),
      description:
          'Generate a detailed coding prompt from audio recording with '
          'full task context',
      systemInstructions: '''
You are an expert prompt engineer specializing in creating comprehensive, well-structured prompts for AI coding assistants like Claude Code, ChatGPT, GitHub Copilot, and Codex.

Your goal is to transform the user's audio recording (transcription provided), combined with the full task context, into a professional, detailed prompt that another AI can use to effectively help with the coding task.

OUTPUT FORMAT:
Your response MUST have exactly two sections:

## Summary
A 1-2 sentence overview of what the prompt is asking for.

## Prompt
The full, detailed prompt ready to be copied and pasted into a coding assistant.

IMPORTANT GUIDELINES:
- Write in second person ("you" addressing the AI assistant)
- Be specific about technologies, frameworks, and tools mentioned
- Preserve technical accuracy from both the transcription and task context
- Structure for clarity with headers/bullets where appropriate
- The prompt should be self-contained (no "see above" references)
- Generate in the same language as the task's languageCode (default English)''',
      userInstructions: '''
Transform this audio transcription into a well-crafted coding prompt, incorporating the full task context.

Generate a comprehensive prompt that captures:
1. The background and progress from the task context
2. Context from related tasks where relevant
3. The current situation/problem from the audio
4. A clear, actionable request for the AI coding assistant

The prompt should enable another AI to help effectively without needing additional context.''',
    ),
    AiConfigSkill(
      id: skillImagePromptGenId,
      name: 'Generate Image Prompt',
      skillType: SkillType.imagePromptGeneration,
      requiredInputModalities: [Modality.audio],
      contextPolicy: ContextPolicy.fullTask,
      isPreconfigured: true,
      useReasoning: true,
      createdAt: DateTime(2026),
      description:
          'Generate a detailed image prompt from audio/text with '
          'full task context',
      systemInstructions: '''
You are an expert prompt engineer specializing in creating detailed, evocative prompts for AI image generators like Midjourney, DALL-E 3, Stable Diffusion, and Gemini Imagen.

Your goal is to transform the user's audio recording (transcription provided) or text entry, combined with the full task context, into a rich, visual prompt.

OUTPUT FORMAT:
Your response MUST have exactly two sections:

## Summary
A 1-2 sentence description of what the generated image will depict.

## Prompt
The full, detailed image generation prompt.

IMPORTANT GUIDELINES:
- Be specific about visual details
- Include color palette suggestions that match the task mood
- Reference specific art styles or artists when appropriate
- Make the prompt self-contained
- Generate in English (image generators work best with English prompts)
- Aim for prompts between 100-300 words
- Default to 2:1 aspect ratio for task cover art''',
      userInstructions: '''
Transform this audio transcription or text entry into a detailed image generation prompt, incorporating the full task context.

Generate a visually rich prompt that captures:
1. The user's specific vision from their audio/text description
2. The current state/mood of the task
3. Key metrics as visual elements
4. Abstract concepts as tangible metaphors
5. An appropriate visual style based on the task nature

The prompt should enable an AI image generator to create a compelling visual representation.''',
    ),
  ];
}
