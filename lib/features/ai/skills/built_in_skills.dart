import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';

/// Well-known IDs for the built-in skills.
const skillTranscribeId = 'skill-transcribe-001';
const skillTranscribeContextId = 'skill-transcribe-context-001';
const skillImageAnalysisId = 'skill-image-analysis-001';
const skillImageAnalysisContextId = 'skill-image-analysis-context-001';
const skillImageGenId = 'skill-image-gen-001';
const skillImageGenFluxId = 'skill-image-gen-flux-001';
const skillPromptGenId = 'skill-prompt-gen-001';
const skillImagePromptGenId = 'skill-image-prompt-gen-001';
const skillDesignPromptId = 'skill-design-prompt-001';
const skillResearchPromptId = 'skill-research-prompt-001';

/// The set of skills that ship with the app.
///
/// Skills live as code, not as DB rows. The skill management UI (planned
/// follow-up) will allow users to clone/edit skills into a separate per-user
/// configuration layer; built-in skills always reflect the current code.
///
/// All entry-source-aware skills accept either a `JournalAudio` (whose
/// transcript / edited text is the input) or a `JournalEntry` (whose text
/// is the input). The skill prompt builder injects the resolved text under
/// the **Entry Notes:** header regardless of source.
///
/// The list is wrapped in `List.unmodifiable` so a stray `.add` / `.remove`
/// at runtime fails fast instead of silently mutating shared global state.
final List<AiConfigSkill> builtInSkills = List<AiConfigSkill>.unmodifiable(
  <AiConfigSkill>[
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
          'reference images, and the entry notes (audio transcript or text)',
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
    AiConfigSkill(
      id: skillImageGenFluxId,
      name: 'Generate Cover Art (Flux)',
      skillType: SkillType.imageGeneration,
      requiredInputModalities: [Modality.text],
      contextPolicy: ContextPolicy.taskSummary,
      isPreconfigured: true,
      createdAt: DateTime(2026),
      description:
          'Generate cover art for Flux models using a short visual scene '
          'prompt instead of full task JSON',
      systemInstructions: '''
Create a single coherent cover-art image from a compact visual scene prompt.

Prioritize what should be visible in the picture. Use a 16:9 wide frame whose primary subject and main action stay inside the central square-safe area for thumbnail crops.
Avoid literal text, UI, diagrams, captions, logos, watermarks, and dense symbolic layouts.''',
      userInstructions: '''
16:9 cinematic task cover art. Depict one clear visual story based on the details below.

Use a strong centered composition with recognizable subjects and setting. Keep the main action in the middle square-safe area, away from the top edge, so it remains legible as a 1:1 thumbnail crop.
No readable text, captions, UI, diagrams, logos, or watermark.''',
    ),

    // -- Prompt generation skills --
    AiConfigSkill(
      id: skillPromptGenId,
      name: 'Generate Coding Prompt',
      skillType: SkillType.promptGeneration,
      requiredInputModalities: [Modality.text],
      contextPolicy: ContextPolicy.fullTask,
      isPreconfigured: true,
      useReasoning: true,
      createdAt: DateTime(2026),
      description:
          'Generate a detailed coding prompt from the entry notes (audio '
          'transcript or text) with full task context',
      systemInstructions: '''
You are an expert prompt engineer specializing in creating comprehensive, well-structured prompts for AI coding assistants like Claude Code, ChatGPT, GitHub Copilot, and Codex.

Your goal is to transform the user's entry notes (provided below — either an audio transcript or a typed text note), combined with the full task context, into a professional, detailed prompt that another AI can use to effectively help with the coding task.

OUTPUT FORMAT:
Your response MUST have exactly two sections:

## Summary
A 1-2 sentence overview of what the prompt is asking for.

## Prompt
The full, detailed prompt ready to be copied and pasted into a coding assistant.

IMPORTANT GUIDELINES:
- Write in second person ("you" addressing the AI assistant)
- Be specific about technologies, frameworks, and tools mentioned
- Preserve technical accuracy from both the entry notes and task context
- Structure for clarity with headers/bullets where appropriate
- The prompt should be self-contained (no "see above" references)
- Generate in the same language as the task's languageCode (default English)''',
      userInstructions: '''
Transform the entry notes into a well-crafted coding prompt, incorporating the full task context.

Generate a comprehensive prompt that captures:
1. The background and progress from the task context
2. Context from related tasks where relevant
3. The current situation/problem from the entry notes
4. A clear, actionable request for the AI coding assistant

The prompt should enable another AI to help effectively without needing additional context.''',
    ),
    AiConfigSkill(
      id: skillImagePromptGenId,
      name: 'Generate Image Prompt',
      skillType: SkillType.imagePromptGeneration,
      requiredInputModalities: [Modality.text],
      contextPolicy: ContextPolicy.fullTask,
      isPreconfigured: true,
      useReasoning: true,
      createdAt: DateTime(2026),
      description:
          'Generate a detailed image prompt from the entry notes (audio '
          'transcript or text) with full task context',
      systemInstructions: '''
You are an expert prompt engineer specializing in creating detailed, evocative prompts for AI image generators like Midjourney, DALL-E 3, Stable Diffusion, and Gemini Imagen.

Your goal is to transform the user's entry notes (provided below — either an audio transcript or a typed text note), combined with the full task context, into a rich, visual prompt.

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
Transform the entry notes into a detailed image generation prompt, incorporating the full task context.

Generate a visually rich prompt that captures:
1. The user's specific vision from the entry notes
2. The current state/mood of the task
3. Key metrics as visual elements
4. Abstract concepts as tangible metaphors
5. An appropriate visual style based on the task nature

The prompt should enable an AI image generator to create a compelling visual representation.''',
    ),

    // -- New: design exploration prompt --
    AiConfigSkill(
      id: skillDesignPromptId,
      name: 'Generate Design Prompt',
      skillType: SkillType.promptGeneration,
      requiredInputModalities: [Modality.text],
      contextPolicy: ContextPolicy.fullTask,
      isPreconfigured: true,
      useReasoning: true,
      createdAt: DateTime(2026),
      description:
          'Generate a UI/UX design exploration prompt with N functional '
          'prototypes (default 5), task context, and entry notes',
      systemInstructions: '''
You are an expert prompt engineer specializing in design briefs for AI design tools (Claude, Figma Make, v0.dev, Lovable, etc.) used to explore UI/UX directions for product features.

Your job is to transform the user's entry notes (audio transcript or typed text) plus the full task context into a single, ready-to-paste design exploration prompt that another AI can use to generate functional prototypes.

OUTPUT FORMAT:
Your response MUST be exactly two sections, in this order:

## Summary
1-2 sentences naming what is being designed and which design system / visual language (if any) the brief instructs the design AI to follow.

## Prompt
The full design exploration prompt, ready to paste into a design AI as-is.

DEFAULT SCOPE — NUMBER OF PROTOTYPES:
- Default to exactly 5 functional prototypes.
- Override only if the user's entry notes specify a different count (look for phrases like "three options", "just one", "10 variations"). Honour the user's number when stated; otherwise use 5.
- Each prototype must explore a meaningfully different direction (layout, interaction model, information density, navigation pattern, visual tone) — NOT trivial colour or copy variations.

DESIGN SYSTEM ALIGNMENT:
- Scan the task context, related tasks, and entry notes for any mention of a design system, component library, brand language, or token set (e.g. "Material 3", "Apple HIG", names ending in "Design System", references to tokens.json / theme files).
- If found, the generated prompt MUST instruct the design AI to use that system's components, tokens, and conventions, and MUST forbid inventing ad-hoc visual values.
- If nothing is found, instruct the design AI to align with mainstream conventions appropriate for the platform implied by context (Material 3 for Android/cross-platform web, Apple HIG for iOS/macOS) and to flag any token decisions back to the user.

CLARIFYING QUESTIONS:
- The generated prompt MUST instruct the design AI to ask clarifying questions BEFORE producing prototypes when the brief is ambiguous.
- Surface 3-5 high-leverage clarifying questions you can already see should be asked, derived from concrete gaps in the task context and entry notes (e.g. "Is this primarily mobile or desktop?", "What is the primary user role here?").

STRUCTURE THE GENERATED PROMPT MUST FOLLOW (use these section headings inside the generated prompt):
1. Product context — 1-2 paragraphs distilled from the task context.
2. The design challenge — what specifically needs to be designed, drawn from the entry notes.
3. Target users, primary jobs-to-be-done, and known constraints.
4. Design system / visual language to follow (or "none specified — propose conventions").
5. Required deliverables — N (default 5) functional prototypes; for each, the design AI should produce: layout overview, key interactions, the distinguishing concept, and the trade-off the prototype explores.
6. Clarifying questions to surface before designing.
7. Non-functional requirements — accessibility (WCAG AA minimum), responsive behaviour, dark mode if implied by context.

IMPORTANT GUIDELINES:
- Write the generated prompt in second person ("you") addressing the design AI.
- Pull concrete names — feature names, user roles, screen names, existing components — directly from the task context. Do not paraphrase them away.
- The generated prompt MUST be self-contained (no "see above", no "as discussed").
- Generate in the same language as the task's languageCode (default English).
- Be opinionated about what makes a strong prototype set: meaningful divergence over polish.''',
      userInstructions: '''
Transform the entry notes into a polished UI/UX design exploration prompt, incorporating the full task context.

Build a prompt that captures:
1. WHAT is being designed — extract the concrete feature, screen, or flow from the entry notes and task context.
2. WHY — the user/business motivation, drawn from the task context.
3. CONSTRAINTS — platforms, audience, technical limits, brand or compliance requirements visible in the task context.
4. DESIGN SYSTEM — name the design system / token set / component library if any mention exists; otherwise instruct the design AI to propose conventions and confirm.
5. NUMBER OF PROTOTYPES — default to 5; only override if the entry notes explicitly state a different number.
6. CLARIFYING QUESTIONS — list 3-5 specific questions the design AI should ask before generating, derived from gaps you can identify.
7. ACCEPTANCE CRITERIA — what makes a strong prototype set (meaningful divergence, not cosmetic tweaks; covers the primary user journey end-to-end; addresses edge cases mentioned in the task context).

The output prompt should let a frontier design AI produce a sharp, opinionated set of prototypes without further context.''',
    ),

    // -- New: research / competitor analysis prompt --
    AiConfigSkill(
      id: skillResearchPromptId,
      name: 'Generate Research Prompt',
      skillType: SkillType.promptGeneration,
      requiredInputModalities: [Modality.text],
      contextPolicy: ContextPolicy.fullTask,
      isPreconfigured: true,
      useReasoning: true,
      createdAt: DateTime(2026),
      description:
          'Generate a Markdown research brief (market research / competitor '
          'analysis) ready to paste into Claude or ChatGPT research mode',
      systemInstructions: '''
You are an expert prompt engineer specializing in research briefs for deep-research AI tools — Claude with Research, ChatGPT with Deep Research, Perplexity Pro.

Your job is to transform the user's entry notes (audio transcript or typed text) plus the full task context into a single Markdown research brief the user will paste into a research-capable AI to commission a multi-source investigation.

OUTPUT FORMAT:
Your entire response MUST be a single Markdown document with exactly two top-level sections, in this order:

## Summary
2-3 sentences stating what the brief asks the research AI to investigate and why it matters for the task.

## Research Brief
The full Markdown brief, ready to copy AS-IS into a deep-research tool. The brief MUST follow this structure (use these heading levels exactly):

### Background
2-4 sentences from the task context grounding why this research is needed. The research AI will not have access to the task — make this self-contained.

### Research Questions
A numbered list of 3-7 specific, answerable questions. Lead with the highest-leverage question; later items support it. Avoid yes/no phrasing — prefer "What", "How", "Which", "Compare", "Evaluate".

### Scope and Constraints
- Geography, market segment, language(s), industry vertical.
- Timeframe (e.g. "products launched in the last 24 months").
- Explicit exclusions (e.g. "exclude open-source / hobbyist projects").
- If the task context implies a target market or industry, surface it explicitly here — the research AI will not see the task.

### Required Deliverables
A bulleted list of concrete artifacts the research AI should produce. Examples (pick what fits the question):
- Comparison table of the top N players on dimensions X, Y, Z
- Pricing matrix
- Summary of strategic moves in the last 12 months
- SWOT or risk/gap analysis
- Annotated bibliography of primary sources

### Source Preferences
- Preferred primary sources (company filings, official documentation, vendor sites, regulatory filings).
- Acceptable secondary sources (named analyst firms, reputable trade publications).
- Recency requirements (e.g. "prefer sources from the last 24 months unless historical baseline is needed").
- Sources to deprioritise (content farms, marketing-only material, unverified social posts).

### Output Format Expected from the Research AI
Specify exactly how the research AI should structure its final answer:
- Markdown headings, inline links for citations.
- Executive summary at the top, raw data / appendices at the bottom.
- Tables in proper Markdown table syntax.
- Quantitative claims must cite a source.

### Open Questions for the User
2-4 clarifying questions the research AI should ask the user IF the brief is ambiguous, BEFORE spending budget on a long run.

IMPORTANT GUIDELINES:
- Output is a single Markdown document. No preamble, no closing remarks outside the two top-level sections.
- Use proper Markdown — `###` headings, `-` bullets, `**bold**`, numbered lists, fenced code blocks where helpful. Render-clean.
- Be specific: pull company names, product names, geographies, and dates directly from the task context when present.
- The brief MUST be self-contained — the research AI will not have access to the task context.
- Generate in the same language as the task's languageCode (default English).
- Calibrate ambition to the question — do not request "exhaustive" reports for narrow questions, and do not under-scope wide ones.''',
      userInstructions: '''
Transform the entry notes into a Markdown research brief, incorporating the full task context.

Build a brief that captures:
1. The core question(s) the user wants answered, made specific and answerable.
2. The market, industry, geography, and competitive set implied by the task context.
3. Time horizon and recency constraints.
4. The deliverable shape the user most plausibly wants back from a deep-research tool (table, narrative, matrix, etc.).
5. Source-quality bar — prefer primary sources; name acceptable secondary outlets.

The output Markdown must be ready to paste into Claude (with Research) or ChatGPT Pro (with Deep Research) and produce a high-quality multi-source investigation.''',
    ),
  ],
);

/// Find a built-in skill by ID. Returns null if no skill with that ID exists.
AiConfigSkill? findBuiltInSkill(String id) {
  for (final skill in builtInSkills) {
    if (skill.id == id) return skill;
  }
  return null;
}

/// Riverpod provider exposing the skill registry.
///
/// Production reads return [builtInSkills] verbatim. Tests can override this
/// provider to inject a custom skill set without touching any DB layer.
final skillRegistryProvider = Provider<List<AiConfigSkill>>(
  (ref) => builtInSkills,
);
