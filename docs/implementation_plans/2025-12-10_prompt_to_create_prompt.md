# Prompt to Create Prompt: AI-Generated Coding Prompts from Audio Recordings

**Status**: Planning

## Overview

This feature allows users to create audio recordings describing a problem or task context, then use AI to transform that recording (with full task context) into a well-crafted prompt suitable for coding assistants like Claude Code, ChatGPT, Codex, or AI research tools.

The generated prompt captures:
- Full task context (title, status, checklist items, prior entries, time spent)
- The user's current situation as described in the audio
- A structured, comprehensive prompt ready to paste into any coding assistant

## Problem Statement

Users often create audio recordings in Lotti describing:
- Problems they're encountering while coding
- Context about what they've been working on
- Ideas for new features or refactoring
- Questions they want to research

Currently, these recordings are transcribed but the user must manually:
1. Gather context from the task
2. Write a coherent prompt that explains the situation
3. Include relevant details that the AI assistant needs

This is tedious and misses the opportunity to leverage all the rich context already stored in Lotti.

## Goals

1. Add a new AI response type (`promptGeneration`) for generating coding prompts
2. Create a specialized entry card for generated prompts with:
   - Brief summary visible by default
   - Prominent copy button for easy clipboard access
   - Expandable section showing the full prompt
   - Read-only display (no editing needed)
3. Allow this action from the AI popup menu on audio entries
4. Support automatic triggering via category configuration
5. Use thinking/reasoning models (Gemini 2.5 Pro, Claude) for high-quality output

## Related Implementation Plans

- [2025-12-01_automatic_image_analysis_and_task_summary_triggers.md](./2025-12-01_automatic_image_analysis_and_task_summary_triggers.md) - Automatic AI triggering patterns
- [2025-11-30_speech_dictionary_per_category.md](./2025-11-30_speech_dictionary_per_category.md) - Speech dictionary and audio context patterns
- [2025-11-23_ai_streaming_toggle.md](./2025-11-23_ai_streaming_toggle.md) - Non-streaming responses for task prompts

## Architecture Analysis

### Current AI Infrastructure

**AI Response Types** (`lib/features/ai/state/consts.dart`):
```dart
enum AiResponseType {
  actionItemSuggestions, // deprecated
  taskSummary,
  imageAnalysis,
  audioTranscription,
  checklistUpdates,
}
```

**AI Response Data** (`lib/classes/entity_definitions.dart`):
```dart
abstract class AiResponseData with _$AiResponseData {
  const factory AiResponseData({
    required String model,
    required String systemMessage,
    required String prompt,
    required String thoughts,
    required String response,
    String? promptId,
    List<AiActionItem>? suggestedActionItems,
    AiResponseType? type,
    double? temperature,
  }) = _AiResponseData;
}
```

**Entry Display** - `ExpandableAiResponseSummary` shows TLDR + expandable content with:
- `ModernBaseCard` wrapper
- `GptMarkdown` for rendering
- Expand/collapse animation
- Double-tap for full modal view

**Popup Menu** - `UnifiedAiPopUpMenu` filters prompts by:
- Entity type (audio, image, task)
- Required input data
- Platform capabilities

### Task Context System

`AiInputRepository` gathers comprehensive task data:
- Task metadata (title, status, estimated duration, time spent)
- All linked entries with timestamps
- Audio transcripts with language detection
- Checklist items with completion status
- Labels and category information

This context is injected via `{{task}}` placeholder in prompts.

## Implementation Plan

### Phase 1: Data Model Extensions

#### 1.1 Add New AiResponseType

**File**: `lib/features/ai/state/consts.dart`

```dart
const promptGenerationConst = 'PromptGeneration';

enum AiResponseType {
  // ... existing types ...
  @JsonValue(promptGenerationConst)
  promptGeneration,
}

extension AiResponseTypeDisplay on AiResponseType {
  String localizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      // ... existing cases ...
      case AiResponseType.promptGeneration:
        return l10n.aiResponseTypePromptGeneration;
    }
  }

  IconData get icon {
    switch (this) {
      // ... existing cases ...
      case AiResponseType.promptGeneration:
        return Icons.auto_fix_high; // or Icons.psychology, Icons.code
    }
  }
}
```

#### 1.2 Add Localization Strings

**File**: `lib/l10n/app_en.arb`

```json
"aiResponseTypePromptGeneration": "Generated Prompt",
"promptGenerationCardTitle": "AI Coding Prompt",
"promptGenerationCopyTooltip": "Copy prompt to clipboard",
"promptGenerationCopiedSnackbar": "Prompt copied to clipboard",
"promptGenerationExpandTooltip": "Show full prompt"
```

**File**: `lib/l10n/app_de.arb`

```json
"aiResponseTypePromptGeneration": "Generierter Prompt",
"promptGenerationCardTitle": "KI-Coding-Prompt",
"promptGenerationCopyTooltip": "Prompt in Zwischenablage kopieren",
"promptGenerationCopiedSnackbar": "Prompt in Zwischenablage kopiert",
"promptGenerationExpandTooltip": "Vollständigen Prompt anzeigen"
```

### Phase 2: Preconfigured Prompt Template

#### 2.1 Create Prompt Generation Template

**File**: `lib/features/ai/util/preconfigured_prompts.dart`

```dart
/// Lookup map update
const Map<String, PreconfiguredPrompt> preconfiguredPrompts = {
  // ... existing entries ...
  'prompt_generation': promptGenerationPrompt,
};

/// Prompt Generation template - transforms audio + task context into a coding prompt
const promptGenerationPrompt = PreconfiguredPrompt(
  id: 'prompt_generation',
  name: 'Generate Coding Prompt',
  systemMessage: '''
You are an expert prompt engineer specializing in creating comprehensive, well-structured prompts for AI coding assistants like Claude Code, ChatGPT, GitHub Copilot, and Codex.

Your goal is to transform the user's audio recording (transcription provided), combined with the full task context, into a professional, detailed prompt that another AI can use to effectively help with the coding task.

OUTPUT FORMAT:
Your response MUST have exactly two sections:

## Summary
A 1-2 sentence overview of what the prompt is asking for. This should be scannable and immediately convey the request.

## Prompt
The full, detailed prompt ready to be copied and pasted into a coding assistant. This section should:
- Start with comprehensive context from the task (what's been done, current status)
- Include relevant details from previous entries/logs
- Describe the current situation or problem from the audio
- Reference specific checklist items if relevant
- Specify what help is needed
- Include any technical details mentioned
- End with a clear ask or question

PROMPT STRUCTURE GUIDELINES:
1. **Context Section**: Summarize the task background, what has been accomplished (use checklist items marked done), and current status
2. **Current Situation**: What the user is working on right now based on the audio
3. **Problem/Request**: The specific help needed
4. **Technical Details**: Any error messages, code snippets, or specific requirements mentioned
5. **Desired Outcome**: What success looks like

IMPORTANT GUIDELINES:
- Write in second person ("you" addressing the AI assistant)
- Be specific about technologies, frameworks, and tools mentioned
- Preserve technical accuracy from both the transcription and task context
- Structure for clarity with headers/bullets where appropriate
- Include any error messages or symptoms mentioned verbatim
- If debugging, specify what has already been tried (from logs/entries)
- The prompt should be self-contained (no "see above" references)
- Generate in the same language as the task's languageCode (default English)''',
  userMessage: '''
Transform this audio transcription into a well-crafted coding prompt, incorporating the full task context.

**Audio Transcription:**
{{audioTranscript}}

**Full Task Context:**
```json
{{task}}
```

Generate a comprehensive prompt that captures:
1. The background and progress from the task context
2. The current situation/problem from the audio
3. A clear, actionable request for the AI coding assistant

The prompt should enable another AI to help effectively without needing additional context.''',
  requiredInputData: [InputDataType.audioFiles, InputDataType.task],
  aiResponseType: AiResponseType.promptGeneration,
  useReasoning: true,
  description:
      'Generate a detailed coding prompt from audio recording with full task context',
);
```

**Note**: This prompt **requires task context** - it only appears in the AI menu for audio entries that are linked to a task. The whole value proposition is combining the audio with the rich task history.

#### 2.2 Add audioTranscript Placeholder Support

**File**: `lib/features/ai/helpers/prompt_builder_helper.dart`

Add handling for `{{audioTranscript}}` placeholder:

```dart
// In the placeholder replacement logic, add:
if (userMessage.contains('{{audioTranscript}}')) {
  final audioEntry = entity;
  if (audioEntry is JournalAudio) {
    // Use edited text if available, otherwise use original transcript
    final transcript = audioEntry.entryText?.plainText ??
        audioEntry.data.transcript ??
        '[No transcription available]';
    userMessage = userMessage.replaceAll('{{audioTranscript}}', transcript);
  } else {
    userMessage = userMessage.replaceAll('{{audioTranscript}}',
        '[Audio entry expected but not found]');
  }
}
```

### Phase 3: Specialized Entry Card

#### 3.1 Create GeneratedPromptCard Widget

**New File**: `lib/features/ai/ui/generated_prompt_card.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/ai_response_summary_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Specialized card for displaying AI-generated coding prompts.
///
/// Features:
/// - Brief summary visible by default
/// - Prominent copy button
/// - Expandable full prompt view
/// - Read-only (no editing)
class GeneratedPromptCard extends StatefulWidget {
  const GeneratedPromptCard(
    this.aiResponse, {
    required this.linkedFromId,
    super.key,
  });

  final AiResponseEntry aiResponse;
  final String? linkedFromId;

  @override
  State<GeneratedPromptCard> createState() => _GeneratedPromptCardState();
}

class _GeneratedPromptCardState extends State<GeneratedPromptCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;
  late String _summary;
  late String _fullPrompt;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _parseContent();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _parseContent() {
    final response = widget.aiResponse.data.response;

    // Parse the structured response format
    // Expected format:
    // ## Summary
    // <summary text>
    //
    // ## Prompt
    // <full prompt>

    final summaryRegex = RegExp(
      r'##\s*Summary\s*\n+([\s\S]*?)(?=##\s*Prompt|$)',
      caseSensitive: false,
    );
    final promptRegex = RegExp(
      r'##\s*Prompt\s*\n+([\s\S]*)',
      caseSensitive: false,
    );

    final summaryMatch = summaryRegex.firstMatch(response);
    final promptMatch = promptRegex.firstMatch(response);

    _summary = summaryMatch?.group(1)?.trim() ??
        response.split('\n').first.trim();
    _fullPrompt = promptMatch?.group(1)?.trim() ?? response;
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _fullPrompt));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.messages.promptGenerationCopiedSnackbar),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModernBaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with title and action buttons
          Row(
            children: [
              Icon(
                AiResponseType.promptGeneration.icon,
                color: context.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.messages.promptGenerationCardTitle,
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Copy button (prominent)
              IconButton(
                icon: Icon(
                  Icons.copy_rounded,
                  color: context.colorScheme.primary,
                ),
                tooltip: context.messages.promptGenerationCopyTooltip,
                onPressed: _copyToClipboard,
              ),
              // Expand/collapse button
              GestureDetector(
                onTap: _toggleExpanded,
                child: RotationTransition(
                  turns: _rotationAnimation,
                  child: Icon(
                    Icons.expand_more,
                    size: 24,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Summary (always visible)
          GestureDetector(
            onDoubleTap: () {
              ModalUtils.showSinglePageModal<void>(
                context: context,
                builder: (BuildContext _) {
                  return AiResponseSummaryModalContent(
                    widget.aiResponse,
                    linkedFromId: widget.linkedFromId,
                  );
                },
              );
            },
            child: SelectionArea(
              child: Text(
                _summary,
                style: context.textTheme.bodyMedium,
                maxLines: _isExpanded ? null : 3,
                overflow: _isExpanded ? null : TextOverflow.ellipsis,
              ),
            ),
          ),
          // Expandable full prompt
          AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              if (_expandAnimation.value == 0) {
                return const SizedBox.shrink();
              }
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _expandAnimation.value,
                  child: child,
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Full Prompt:',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectionArea(
                    child: GptMarkdown(_fullPrompt),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 3.2 Integrate Card into Entry Display

**File**: `lib/features/journal/ui/widgets/entry_detail_linked_from.dart` (or similar)

Add logic to use `GeneratedPromptCard` when displaying prompt generation responses:

```dart
// In the widget that displays AI responses on entries:
Widget buildAiResponseWidget(AiResponseEntry response, String? linkedFromId) {
  if (response.data.type == AiResponseType.promptGeneration) {
    return GeneratedPromptCard(
      response,
      linkedFromId: linkedFromId,
    );
  }
  // ... existing logic for other response types
  return ExpandableAiResponseSummary(
    response,
    linkedFromId: linkedFromId,
  );
}
```

### Phase 4: Category Configuration Support

#### 4.1 Add promptGeneration to AutomaticPrompts

The existing `CategoryDefinition.automaticPrompts` map already supports new response types:

```dart
Map<AiResponseType, List<String>>? automaticPrompts
```

Categories can be configured to auto-trigger prompt generation for audio entries by adding:
```dart
automaticPrompts: {
  AiResponseType.audioTranscription: ['audio_transcription_task_context'],
  AiResponseType.promptGeneration: ['prompt_generation_task_context'],
}
```

#### 4.2 Trigger Logic (Optional - Phase 4.2)

If we want prompt generation to auto-trigger after transcription completes (similar to how task summary triggers), add to `UnifiedAiInferenceRepository._handlePostProcessing()`:

```dart
case AiResponseType.audioTranscription:
  // ... existing code to update audio ...

  // Optionally trigger prompt generation if configured
  if (linkedEntityId != null) {
    final trigger = ref.read(automaticPromptGenerationTriggerProvider);
    await trigger.triggerPromptGeneration(
      audioEntryId: entity.id,
      linkedTaskId: linkedEntityId,
      categoryId: entity.meta.categoryId,
    );
  }
```

**Decision**: Start with manual triggering only. Auto-trigger can be added later based on user feedback.

### Phase 5: Testing

#### 5.1 Unit Tests

**New File**: `test/features/ai/util/preconfigured_prompts_prompt_generation_test.dart`

Test cases:
1. `prompt generation template has correct structure`
2. `prompt generation with task context includes all placeholders`
3. `audioTranscript placeholder is replaced correctly`

**New File**: `test/features/ai/helpers/prompt_builder_helper_prompt_generation_test.dart`

Test cases:
1. `builds prompt with audioTranscript placeholder`
2. `uses edited text over original transcript when available`
3. `handles missing transcript gracefully`
4. `combines task context with audio transcript`

#### 5.2 Widget Tests

**New File**: `test/features/ai/ui/generated_prompt_card_test.dart`

Test cases:
1. `displays summary by default`
2. `expands to show full prompt on tap`
3. `copy button copies full prompt to clipboard`
4. `double tap opens full modal`
5. `parses Summary and Prompt sections correctly`
6. `handles malformed response gracefully`

#### 5.3 Integration Tests

**Update**: `test/features/ai/repository/unified_ai_inference_repository_test.dart`

Test cases:
1. `prompt generation response is stored correctly`
2. `prompt generation type is set on AiResponseData`

## Files to Create

- `lib/features/ai/ui/generated_prompt_card.dart` - Specialized card widget
- `test/features/ai/ui/generated_prompt_card_test.dart` - Widget tests
- `test/features/ai/util/preconfigured_prompts_prompt_generation_test.dart` - Prompt template tests
- `test/features/ai/helpers/prompt_builder_helper_prompt_generation_test.dart` - Builder tests

## Files to Modify

- `lib/features/ai/state/consts.dart` - Add `promptGeneration` enum value
- `lib/features/ai/util/preconfigured_prompts.dart` - Add prompt templates
- `lib/features/ai/helpers/prompt_builder_helper.dart` - Add `audioTranscript` placeholder
- `lib/l10n/app_en.arb` - English strings
- `lib/l10n/app_de.arb` - German strings
- Entry display widgets - Use `GeneratedPromptCard` for prompt generation responses

## Risk Assessment

### Low Risk
- Adding new enum value (backward compatible)
- Adding new preconfigured prompts
- Adding new widget
- Adding localization strings

### Medium Risk
- Placeholder handling in prompt builder (affects all prompt building)
- Integration with entry display system

### Mitigations
- New enum value has JSON serialization annotation
- Placeholder replacement is additive, won't break existing placeholders
- New widget is isolated, doesn't affect existing card rendering
- Comprehensive test coverage

## Success Metrics

1. Users can trigger prompt generation from audio entry AI menu
2. Generated prompts include comprehensive task context
3. Copy button successfully copies prompt to clipboard
4. Card correctly parses and displays Summary/Prompt sections
5. Expandable view shows full prompt with proper formatting
6. No impact on existing AI response types

## Future Enhancements

1. **Auto-trigger**: Automatically generate prompt after transcription completes (configurable)
2. **Template Selection**: Allow users to choose prompt style (debugging, feature request, refactoring, research)
3. **Share Integration**: Direct sharing to messaging apps or email
4. **History View**: Quick access to recent generated prompts across all tasks
5. **Prompt Refinement**: Ability to regenerate with additional context or different focus

## Summary

This feature transforms Lotti into a powerful prompt engineering assistant by:

1. **Leveraging existing context** - Full task history, checklist status, and prior entries
2. **Using audio as input** - Natural voice capture of problems and context
3. **AI-powered transformation** - Thinking models create well-structured prompts
4. **Frictionless copying** - One-tap copy to use in any coding assistant

The implementation builds on existing infrastructure (AI response types, popup menus, category configuration) while adding a specialized display component for this unique use case.
