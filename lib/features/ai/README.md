# AI Feature

This module provides a comprehensive AI integration system for generating task summaries, action item suggestions, image analysis, and audio transcription using various AI providers.

## Overview

The AI feature consists of several key components:

1. **Configuration Management**: Store and manage API keys, prompts, and model configurations
2. **Inference Profiles**: Named bundles of model assignments per capability slot (thinking, image recognition, transcription, image generation) with skill assignments that control which capabilities auto-trigger
3. **Skills**: Model-agnostic AI capability definitions (transcription, image analysis, etc.) with instructions and context policies — the profile's model slots determine which model executes each skill
4. **Prompt Creation**: Build structured prompts for different AI tasks
4. **Inference Execution**: Run AI inference through various providers (OpenAI, Anthropic, Google, etc.)
5. **Response Processing**: Parse and display AI-generated responses
6. **UI Components**: Settings pages, response displays, and configuration management
7. **Conversation Support**: Multi-turn interactions with context preservation
8. **Automatic Setup**: Model pre-population and intelligent defaults
9. **Error Recovery**: Comprehensive error handling and user-friendly messages

## Embedding Search

The AI feature also owns the local embedding pipeline used for semantic search.

- **`database/embedding_store.dart`** defines the backend-neutral `EmbeddingStore` contract used by services, repositories, and maintenance UI.
- **`database/objectbox_embedding_entity.dart`** defines the ObjectBox chunk entity used for vector persistence and HNSW indexing.
- **`database/objectbox_embedding_store.dart`** provides the sole supported ObjectBox-backed ANN search implementation.
- Sandboxed macOS builds require the `SS586VG7L7.lottiobx` application-group entitlement and pass the matching `macosApplicationGroup` to ObjectBox at store open time.
- Higher-level code depends on `EmbeddingStore`, not directly on ObjectBox internals, so storage-specific changes stay localized to DI and the store implementation.

## Architecture

### Core Components

#### Models (`model/`)
- **`ai_config.dart`**: Union type for different configuration types (API keys, prompts, models, inference profiles, skills)
- **`skill_assignment.dart`**: `SkillAssignment` freezed class — references a skill by ID with an `automate` toggle, stored on inference profiles
- **`resolved_profile.dart`**: Immutable data class for a fully resolved inference profile with provider references and skill assignments
- **`ai_input.dart`**: Data structures for task input (task details, action items, log entries)
- **`cloud_inference_config.dart`**: Configuration for cloud inference providers
- **`inference_error.dart`**: Error types and handling for AI operations

#### Database (`database/`)
- **`ai_config_db.drift`**: Drift database schema for persistent storage
- **`ai_config_repository.dart`**: Repository facade for CRUD operations and
  shared in-memory config snapshots
  - Type-based watchers derive from one shared all-config snapshot instead of
    issuing separate Drift watches per AI config type
  - Direct config reads still keep per-id and per-type caches for repeated
    warm lookups

#### Repositories (`repository/`)

The repository layer has been refactored for better separation of concerns:

- **`unified_ai_inference_repository.dart`**: Main repository handling all AI inference requests
  - Orchestrates inference across different providers
  - Handles response processing and auto-checklist creation
  - Manages function calling and tool responses

- **`cloud_inference_repository.dart`**: Coordinates cloud-based AI providers
  - Routes requests to appropriate provider-specific repositories
  - Manages OpenAI-compatible endpoints
  - Handles Anthropic ping message filtering

- **`ollama_inference_repository.dart`**: Handles local Ollama model inference
  - Supports both `/api/generate` and `/api/chat` endpoints
  - Automatic endpoint selection based on function calling requirements
  - Model installation and warm-up management
  - Retry logic with exponential backoff
  - Custom `ModelNotInstalledException` for better error handling

- **`gemini_inference_repository.dart`**: Native Gemini streaming adapter with OpenAI-compatible output
  - Calls Gemini `:streamGenerateContent` directly using provider base URL and API key
  - Translates Gemini payloads into `CreateChatCompletionStreamResponse` deltas
  - Surfaces a single consolidated `<think>` block when thinking is enabled (all Gemini 2.5+ models support thinking)
  - Emits OpenAI-style tool-call chunks with turn-prefixed IDs (`tool_turn{N}_{index}`) and indices to support accumulation across multi-turn conversations
  - Robust stream parsing via `gemini_stream_parser.dart`: handles SSE `data:` lines, NDJSON, and JSON array framing without relying on line boundaries
  - Non-streaming fallback via `:generateContent` kicks in only if the streaming path produced no events, aggregating thinking, text, and tools

- **`gemini_utils.dart`**: Shared helpers used by the Gemini repository
  - `buildStreamGenerateContentUri` / `buildGenerateContentUri` – constructs correct Gemini endpoints from a base URL
  - `buildRequestBody` – builds request payloads including thinking config and function tools (mapped from OpenAI style)
  - `stripLeadingFraming` – removes SSE `data:` prefixes and JSON array framing from mixed-format streams

- **`gemini_stream_parser.dart`**: Streaming JSON parser for mixed-framing Gemini responses
  - Incremental parser resilient to SSE `data:` lines, NDJSON, and JSON array framing
  - Accumulates objects across chunks and ignores braces inside string literals
  - Returns decoded `Map<String,dynamic>` objects ready for adapter consumption

- **`transcription_repository.dart`**: Base class for all transcription repositories
  - Shared `executeTranscription()` template with timeout handling, response parsing, error wrapping
  - Used by Whisper, OpenAI, and Mistral transcription repositories

- **`transcription_exception.dart`**: Unified `TranscriptionException` with provider field

- **`whisper_inference_repository.dart`**: Handles audio transcription via local Whisper
  - Extends `TranscriptionRepository` — sends JSON POST to `/v1/audio/transcriptions`

- **`openai_transcription_repository.dart`**: Handles OpenAI transcription models
  - Extends `TranscriptionRepository` — sends multipart/form-data to OpenAI endpoint

- **`mistral_transcription_repository.dart`**: Handles Mistral Voxtral batch transcription
  - Extends `TranscriptionRepository` — sends multipart/form-data to Mistral endpoint

- **`mistral_realtime_transcription_repository.dart`**: WebSocket client for Mistral's Voxtral real-time transcription API
  - Standalone class (not extending `TranscriptionRepository` — WebSocket streams are a different paradigm from HTTP batch)
  - Connects to `wss://api.mistral.ai/v1/audio/transcriptions/realtime` (derived from provider's base URL)
  - Sends PCM 16-bit LE, 16kHz, mono audio as base64-encoded chunks
  - Provides typed streams: `transcriptionDeltas`, `transcriptionDone`, `detectedLanguage`, `errors`
  - `isRealtimeModel()` static method identifies realtime model IDs (contains `transcribe-realtime`)

- **`ai_input_repository.dart`**: Prepares task data for AI processing

#### Services (`services/`)
- **`auto_checklist_service.dart`**: Handles automatic checklist creation logic and decision making
- **`checklist_completion_service.dart`**: Manages checklist item completion suggestions and tracking
- **`profile_automation_service.dart`**: Skill-driven automation for asset processing. Provides `tryTranscribe()` and `tryAnalyzeImage()` — resolves the task's agent profile, checks for a matching skill assignment with `automate: true`, builds prompts via `SkillPromptBuilder`, and invokes the appropriate provider. Respects `enableSpeechRecognition` opt-out and applies the skill's `contextPolicy`.

#### Conversation Management (`conversation/`)
- **`conversation_manager.dart`**: Manages multi-turn AI conversations
  - Maintains conversation context and message history
  - Handles tool calls and responses
  - Provides event streaming for real-time updates
  - Stores thought signatures keyed by tool call ID for Gemini 3 multi-turn support
  - Clears signatures when conversation is re-initialized
- **`conversation_repository.dart`**: Repository for conversation persistence
  - Creates and manages conversation sessions
  - Routes messages to appropriate inference providers via `InferenceRepositoryInterface`
  - Passes `turnCount` to ensure unique tool call IDs across conversation turns
  - Manages conversation lifecycle and cleanup

#### Inference Interface (`repository/`)
- **`inference_repository_interface.dart`**: Abstract interface for all inference providers
  - Enables conversation-based processing for all providers (Ollama, Gemini, OpenAI, etc.)
  - Defines `generateTextWithMessages` for multi-turn conversations
  - Includes `turnIndex` parameter for unique tool call ID generation
  - Supports thought signatures for Gemini 3 models
- **`cloud_inference_wrapper.dart`**: Adapter for cloud providers
  - Implements `InferenceRepositoryInterface` for cloud providers
  - Delegates to `CloudInferenceRepository.generateWithMessages`
  - Passes through thought signatures and turn index

#### Functions (`functions/`)
- **`checklist_completion_functions.dart`**: OpenAI-style function definitions for checklist operations
  - `suggest_checklist_completion`: Suggests items that appear completed
  - `add_multiple_checklist_items`: Adds one or more items to checklists via an array of objects `{ title, isChecked? }`
  - `update_checklist_items`: Updates existing checklist items by ID - supports marking items as checked/unchecked and fixing titles (e.g., spelling corrections)
- **`lotti_checklist_update_handler.dart`**: Handler for updating existing checklist items
  - Validates item IDs and update fields (isChecked, title)
  - Normalizes whitespace in titles
  - Handles batch updates (up to 20 items per call)
  - Reactive title corrections (only when user mentions the item)
  - Graceful skipping: invalid/out-of-scope IDs are skipped (not treated as errors)
  - Centralized error creation via `_createErrorResult` helper
  - Centralized skip tracking via `_skip` helper
- **`task_functions.dart`**: Function definitions for task operations
  - `set_task_language`: Automatically detects and sets task language
- **`lotti_batch_checklist_handler.dart`**: Batch checklist item creation handler
- **`function_handler.dart`**: Abstract base class for extensible function handling
  - Provides common interface for processing function calls
  - Handles duplicate detection and error recovery
  - Early function name validation to prevent misrouted calls

##### Extensible Function Handler Pattern

The system uses an extensible pattern for handling AI function calls. Each handler:
1. Extends the abstract `FunctionHandler` class
2. Implements required methods for processing calls and handling errors
3. Validates function names early to prevent processing misrouted calls
4. Provides retry prompts for failed attempts

Example of extending the system with a new function type:

```dart
class CalendarEventHandler extends FunctionHandler {
  CalendarEventHandler();

  final Set<String> _createdEvents = {};

  @override
  String get functionName => 'createCalendarEvent';

  @override
  FunctionCallResult processFunctionCall(ChatCompletionMessageToolCall call) {
    // Early check: verify function name matches
    if (call.function.name != functionName) {
      return FunctionCallResult(
        success: false,
        functionName: functionName,
        arguments: call.function.arguments,
        data: {'toolCallId': call.id},
        error: 'Function name mismatch: expected "$functionName", got "${call.function.name}"',
      );
    }

    try {
      final args = jsonDecode(call.function.arguments) as Map<String, dynamic>;
      final title = args['title'] as String?;
      final date = args['date'] as String?;

      if (title != null && date != null) {
        return FunctionCallResult(
          success: true,
          functionName: functionName,
          arguments: call.function.arguments,
          data: {
            'title': title,
            'date': date,
            'toolCallId': call.id,
          },
        );
      } else {
        final missingFields = <String>[];
        if (title == null) missingFields.add('title');
        if (date == null) missingFields.add('date');

        return FunctionCallResult(
          success: false,
          functionName: functionName,
          arguments: call.function.arguments,
          data: {
            'attemptedTitle': title ?? args['name'] ?? args['event'] ?? '',
            'attemptedDate': date ?? args['datetime'] ?? args['when'] ?? '',
            'toolCallId': call.id,
          },
          error: 'Missing required fields: ${missingFields.join(', ')}',
        );
      }
    } catch (e) {
      return FunctionCallResult(
        success: false,
        functionName: functionName,
        arguments: call.function.arguments,
        data: {'toolCallId': call.id},
        error: 'Invalid JSON: $e',
      );
    }
  }

  @override
  bool isDuplicate(FunctionCallResult result) {
    if (!result.success) return false;

    final title = result.data['title'] as String?;
    final date = result.data['date'] as String?;
    if (title == null || date == null) return false;

    final key = '${title.toLowerCase()}|$date';
    if (_createdEvents.contains(key)) {
      return true;
    }

    _createdEvents.add(key);
    return false;
  }

  @override
  String? getDescription(FunctionCallResult result) {
    if (result.success) {
      return '${result.data['title']} on ${result.data['date']}';
    } else {
      final title = result.data['attemptedTitle'] as String?;
      final date = result.data['attemptedDate'] as String?;
      if (title != null && title.isNotEmpty) {
        return date != null && date.isNotEmpty ? '$title on $date' : title;
      }
      return null;
    }
  }

  @override
  String createToolResponse(FunctionCallResult result) {
    if (result.success) {
      return 'Created event: ${getDescription(result)}';
    } else {
      return 'Error: ${result.error}';
    }
  }

  @override
  String getRetryPrompt({
    required List<FunctionCallResult> failedItems,
    required List<String> successfulDescriptions,
  }) {
    final errorSummary = failedItems.map((item) {
      final attempted = getDescription(item);
      final attemptedStr = attempted != null ? ' for "$attempted"' : '';
      return '- ${item.error}$attemptedStr';
    }).join('\n');

    return '''
I noticed errors in your calendar event creation:
$errorSummary

Successfully created events: ${successfulDescriptions.join(', ')}

Please retry with the correct format:
{"title": "event title", "date": "YYYY-MM-DD"}''';
  }

  void reset() {
    _createdEvents.clear();
  }
}
```

To integrate a new handler:
1. Create the handler class extending `FunctionHandler`
2. Add it to the conversation processor's handler list
3. Define the corresponding OpenAI function tool
4. The system automatically handles retries, duplicates, and error recovery

#### State Management (`state/`)
- **`unified_ai_controller.dart`**: Main controller orchestrating AI operations
  - Uses helper methods (`_updateInferenceStatus`, `_startActiveInference`, etc.) for consistent state updates
  - Handles both primary and linked entity status updates symmetrically
- **`inference_status_controller.dart`**: Tracks inference progress and status
- **`active_inference_controller.dart`**: Tracks active inferences with linked entity support
  - **Dual-Entry System**: Creates symmetric entries for both primary and linked entities
  - **ActiveInferenceByEntity**: Finds active inferences for any entity (primary or linked)

#### Helpers & Extensions
- **`helpers/entity_state_helper.dart`**: Utilities for managing entity state during AI operations
- **`helpers/skill_prompt_builder.dart`**: Assembles final system/user messages from skill instructions + runtime context. Injects placeholders (speech dictionary, task context, etc.) based on `skillType` + `contextPolicy` — skill definitions contain only prose.
- **`helpers/profile_automation_resolver.dart`**: Resolves the profile for a task's agent, delegates to `ProfileResolver.resolve()` to use the same resolution chain as agent wakes.
- **`helpers/automatic_image_analysis_trigger.dart`**: Fires image analysis when an image is added to a task. Uses the profile-driven skill path exclusively — requires a task agent with an image analysis skill assigned in the profile.
- **Extensions for type safety and convenience**:
  - `input_data_type_extensions.dart`: Extensions for InputDataType enum
  - `modality_extensions.dart`: Extensions for Modality enum
  - `inference_provider_extensions.dart`: Extensions for provider types
  - `ai_error_utils.dart`: Error handling utilities

#### Form States
- **`prompt_form_state.dart`**: State management for prompt creation/editing forms
- **`inference_model_form_state.dart`**: State management for model configuration forms
- **`inference_provider_form_state.dart`**: State management for provider configuration forms

#### Utilities (`util/`)
- **`ai_error_utils.dart`**: Comprehensive error handling and categorization
  - Categorizes errors (network, auth, rate limit, model errors)
  - Provides user-friendly error messages
  - Extracts detailed error information from various providers
- **`known_models.dart`**: Predefined model configurations
  - Models for all supported providers (OpenAI, Anthropic, Gemini, etc.)
  - Automatic model detection based on provider
- **`model_prepopulation_service.dart`**: Automatic model setup
  - Creates known model configurations when adding providers
  - Saves setup time for common models
- **`preconfigured_prompts.dart`**: Built-in prompt templates
  - Prompt types include image analysis, coding prompt generation, image prompt generation, image generation, and cover art generation
  - Legacy ASR prompts (`audio_transcription`, `audio_transcription_task_context`) are defined but no longer seeded — transcription is handled by profile-driven skills
  - Consistent formatting and instructions
  - Unique IDs enable [prompt template tracking](#prompt-template-tracking)
- **`skill_seeding_service.dart`**: Seeds preconfigured skills (transcription, image analysis, image generation, prompt generation) on first launch. Idempotent — checks by ID before inserting. Exposes `defaultSkills` static list for reference by profile seeder and UI.
- **`profile_seeding_service.dart`**: Seeds default inference profiles with `skillAssignments`. Also provides `upgradeExisting()` to backfill skill assignments on existing default profiles during app upgrade.

#### Constants & Configuration
- **`constants/provider_config.dart`**: Configuration constants for AI providers
  - Default base URLs for each provider
  - Model availability mappings
  - Provider-specific settings

## Supported AI Providers

The system supports multiple inference providers through a modular architecture:

### Cloud Providers
- **OpenAI**: GPT-3.5, GPT-4, and other models via official API
- **Anthropic**: Claude models (Opus, Sonnet, Haiku) with streaming support
- **Google Gemini**: Gemini Pro and Flash models with native streaming adapter
  - Uses `gemini_inference_repository.dart` for REST calls and OpenAI-compatible streaming
  - All Gemini 2.5+ models (including Flash) support thinking with consolidated `<think>` blocks
  - Function calling maps to OpenAI-style tool calls with stable IDs and indices
  - Usage statistics tracking (prompt tokens, completion tokens, thoughts tokens, cached tokens)
  - Processing duration measurement for performance monitoring
  - **Image Generation**: Nano Banana Pro model for generating cover art images (16:9 aspect ratio, 2K resolution)
- **OpenRouter**: Access to multiple models through unified API
- **Nebius AI Studio**: Enterprise AI platform support
- **Generic OpenAI-Compatible**: Any service implementing OpenAI's API specification

### Local Providers
- **Ollama**: Run open-source models locally
  - Automatic model installation with progress tracking
  - Support for function calling via `/api/chat` endpoint
  - Model warm-up for better performance
  - Supports models like Llama, Mistral, Qwen, DeepSeek
  - **Desktop only** - automatically hidden on mobile platforms

- **Whisper**: Local audio transcription
  - Runs on local Whisper server
  - Supports various audio formats via base64 encoding
  - Integrated with task context for better accuracy
  - **Desktop only** - automatically hidden on mobile platforms

### Platform-Aware Prompt Filtering

The AI system automatically filters prompts based on platform capabilities:

- **Desktop platforms** (macOS, Windows, Linux): All AI models and prompts are available
- **Mobile platforms** (iOS, Android): Local-only models (Whisper, Ollama, Gemini 3n) are automatically filtered out
- **Fallback logic**: When a default automatic prompt uses a local-only model on mobile, the system automatically selects the next available cloud-based alternative
- **Visual indicators**: Default automatic prompts are highlighted with a gold accent (border and icon background) in the AI prompt selection modal

This platform-aware filtering prevents users from seeing unusable model options on mobile, while desktop users retain full access to local inference capabilities.

## How Task Summaries Work

### 1. Prompt Creation

Task summary prompts are defined in `util/preconfigured_prompts.dart` and configured through the prompt management system:

```dart
const taskSummaryPrompt = PreconfiguredPrompt(
  name: 'Task Summary',
  // Creates a detailed prompt instructing the AI to:
  // - Start with a single H1 header suggesting a task title
  // - Summarize the task for someone returning after a long time
  // - List achieved results (with ✅ emojis)
  // - List remaining steps (numbered)
  // - Note learnings (💡) and annoyances (🤯)
  // - Indicate if the task is complete
);
```

The prompt template includes:
- System message setting context (with language preference if set)
- Detailed user message with formatting instructions
- Placeholder `{{task}}` replaced with actual task JSON
- Placeholder `{{linked_tasks}}` replaced with related task context (see below)

#### Available Placeholders

| Placeholder | Description | Available For |
|-------------|-------------|---------------|
| `{{task}}` | Current task's JSON data (title, status, log entries, action items) | All task-related prompts |
| `{{linked_tasks}}` | JSON object with parent/child task context (see details below) | All prompt types |
| `{{current_entry}}` | Focused entry being analyzed (id, type, createdAt, text/transcript) | Recording modal, linked-entry AI popup |
| `{{labels}}` | All available label definitions as JSON | Action item prompts |
| `{{assigned_labels}}` | Labels assigned to the current task | Action item prompts |
| `{{suppressed_labels}}` | Label IDs that AI should not suggest | Action item prompts |
| `{{deleted_checklist_items}}` | Soft-deleted checklist items (to avoid recreating) | Action item prompts |
| `{{audioTranscript}}` | Raw audio transcript text | Audio transcription prompts |
| `{{languageCode}}` | Task's language code (e.g., "en", "de") | Task summary, transcription prompts |
| `{{correction_examples}}` | Transcription correction examples | Audio transcription prompts |
| `{{speech_dictionary}}` | Speech recognition dictionary | Audio transcription prompts |

#### Linked Tasks Placeholder (`{{linked_tasks}}`)

The `{{linked_tasks}}` placeholder injects structured context about related tasks:

```json
{
  "linked_from": [...],  // Child tasks that link TO this task (subtasks)
  "linked_to": [...],    // Parent tasks this task links TO (epics)
  "note": "If summaries contain links to GitHub PRs..."
}
```

Each linked task includes:
- `id`, `title`, `status`, `statusSince` (timestamp of status transition)
- `priority` (P0-P3), `estimate`, `timeSpent`, `createdAt`
- `labels` (list of `{id, name}` tuples)
- `languageCode`, `latestSummary` (most recent AI-generated summary)

**Key behaviors:**
- Tasks are sorted chronologically (oldest first)
- Deleted tasks are filtered out
- Tasks without summaries are included (metadata still provides context)
- Full summaries are included (no truncation)
- Works for non-task entities (images, audio) by finding their linked task

**Prompts using this placeholder:**
- `task_summary` - Include related context in summaries
- `prompt_generation` - Provide broader project context for coding prompts
- `image_analysis_task_context` - Understand image context from related work
- Skills with `contextPolicy` set to include linked tasks also use this placeholder

### 2. Data Flow

1. **Input Preparation**: Task data is serialized to JSON including:
   - Task title, status, duration
   - Action items (completed and pending)
   - Log entries with timestamps and text
   - Language preference (if set)
   - Transcript languages from audio entries

2. **Inference Execution**:
   ```dart
   // In UnifiedAiInferenceRepository
   await _runCloudInference(
     input: taskJson,
     promptConfig: promptConfig,
     inferenceProvider: provider,
   );
   ```

3. **Response Streaming**: AI responses are streamed and accumulated

### 3. Response Parsing and Processing

For task summaries, the response is treated as markdown text:
- No JSON parsing (unlike action item suggestions)
- The complete response is saved as an `AiResponseEntry`
- Post-processing includes automatic title extraction (see below)
- Automatic link extraction appends a Links section (see below)
- Displayed using `GptMarkdown` widget for proper formatting

### 4. Automatic Title Extraction

When generating task summaries, the system automatically extracts suggested titles:
- The AI is prompted to start with an H1 header (`# Title`)
- The title is extracted using regex pattern: `^#\s+(.+)$`
- If the current task title is less than 5 characters, it's replaced with the AI suggestion
- This enables automatic title generation for tasks created from audio recordings
- The extracted title updates the task entity in the database
- When displaying summaries, the H1 title is filtered out to avoid redundancy

### 5. Automatic Link Extraction

Task summaries include AI-driven link extraction that aggregates URLs found within the task's entries:

- **Scanning**: AI is instructed to scan log entries for URLs (http://, https://, or other valid URL schemes)
- **Unique URLs**: AI extracts every unique URL found across all entries
- **Succinct Titles**: AI generates short, descriptive titles (2-5 words) for each link
- **Markdown Format**: Links are formatted as `[Succinct Title](URL)` for clickable rendering
- **Conditional Display**: Links section should be omitted if no URLs are found

Example output in summaries:
```markdown
## Links
- [Flutter Documentation](https://docs.flutter.dev)
- [Linear: APP-123](https://linear.app/team/issue/APP-123)
- [Lotti PR #456](https://github.com/matthiasn/lotti/pull/456)
- [GitHub Issue #789](https://github.com/user/repo/issues/789)
```

**Note**: This is prompt-driven behavior relying on AI compliance. Results are best-effort and may vary by model.

## Automatic Image Analysis Trigger

When images are added to a task (via drag-and-drop, paste, or import), the system can automatically trigger image analysis if the task's category has image analysis prompts configured.

### How It Works

1. **Image Addition**: User adds an image to a task via any method
2. **Callback Invocation**: `JournalRepository.createImageEntry()` invokes `onCreated` callback
3. **Profile Resolution**: `AutomaticImageAnalysisTrigger` resolves the task's agent profile via `ProfileAutomationService.tryAnalyzeImage()`
4. **Skill Check**: If the profile has an image analysis skill with `automate: true`, it is invoked via `SkillInferenceRunner`
5. **Fire-and-Forget**: Analysis runs in background via `unawaited()` - never blocks image import

### Implementation

- **`AutomaticImageAnalysisTrigger`**: Helper class in `lib/features/ai/helpers/automatic_image_analysis_trigger.dart`
- **`JournalRepository.createImageEntry()`**: Modified to accept `onCreated` callback
- **Integration Points**: `importDroppedImages()`, `importPastedImages()`, `importImageAssets()`

### Key Features

- **Profile-driven**: Uses the task's agent profile to determine which skill and model to use
- **Non-blocking**: Fire-and-forget pattern ensures image import is never delayed
- **Linked context**: When image is linked to a task, `linkedTaskId` is passed for context-aware analysis

## Automatic Checklist Creation with Smart Re-run

### Overview

The AI system includes automatic checklist creation for action item suggestions. When AI generates action item suggestions for a task that has no existing checklists, it automatically creates a checklist containing all the suggested items, then intelligently re-runs the AI suggestions to provide fresh recommendations.

### How It Works

1. **AI generates action item suggestions** for a task (first run)
2. **Post-processing check** in `UnifiedAiInferenceRepository._handlePostProcessing()`
3. **Decision logic**:
   - If task has no existing checklists → auto-create checklist with all suggestions
   - If task has existing checklists → show manual drag-and-drop suggestions (existing behavior)
4. **Automatic re-run**: After checklist creation, the same AI prompt runs again
5. **Smart results**: Second run typically produces 0 suggestions since items are now in the checklist

### Implementation Details

#### Key Components:
- **`AutoChecklistService`**: Core service handling auto-creation logic and decision making
- **`UnifiedAiInferenceRepository._handleActionItemSuggestions()`**: Post-processing method that triggers auto-creation
- **`UnifiedAiInferenceRepository._rerunActionItemSuggestions()`**: Automatic re-run logic
- **`UnifiedAiInferenceRepository._getCurrentEntityState()`**: Reads fresh entity state before updates
- **`ChecklistRepository.createChecklist()`**: Creates checklist with initial items
- **Simple semaphore protection**: Prevents concurrent auto-creation for the same task

#### Smart Re-run System

Instead of hiding suggestions, the system automatically re-runs the AI prompt after checklist creation:

- **Automatic trigger**: After successful checklist creation, the exact same prompt that was used originally runs again
- **Context awareness**: AI recognizes items are now in the checklist and typically suggests nothing
- **Natural UX**: Users see the auto-created checklist plus minimal/empty suggestions
- **No state tracking**: No need for complex `autoChecklistCreated` field management
- **Consistent results**: Re-run uses the exact same prompt configuration, ensuring consistent behavior

## Usage Statistics and Performance Tracking

The AI system tracks usage statistics and performance metrics for monitoring API consumption and response times.

### Tracked Metrics

- **Input Tokens**: Number of tokens in the prompt/input
- **Output Tokens**: Number of tokens in the response
- **Thoughts Tokens**: Reasoning tokens used by thinking models (Gemini-specific)
- **Cached Input Tokens**: Tokens served from provider cache
- **Processing Duration**: Time from request start to stream completion (milliseconds)

### Implementation

Usage statistics are captured in `AiResponseData` with nullable fields for backward compatibility:
```dart
AiResponseData(
  // ... existing fields
  inputTokens: usage?.promptTokens,
  outputTokens: usage?.completionTokens,
  thoughtsTokens: usage?.completionTokensDetails?.reasoningTokens,
  durationMs: stopwatch.elapsedMilliseconds,
)
```

### UI Display

Usage statistics are displayed in the AI Response Summary Modal when available:
- Token breakdown (input, output, thoughts)
- Processing duration in seconds
- Total token count

### Provider Support

| Provider | Token Tracking | Thoughts Tokens | Duration |
|----------|---------------|-----------------|----------|
| Gemini   | ✅             | ✅               | ✅        |
| OpenAI   | ✅             | ✅ (Thinking models) | ✅    |
| Anthropic| ✅             | ❌               | ✅        |
| Ollama   | ❌             | ❌               | ✅        |

## Response Types

The system supports five active AI response types (two legacy types — `taskSummary` and `checklistUpdates` — are retained in the enum for DB backwards-compatibility but are now handled by the agent system):

1. **Image Analysis** (`AiResponseType.imageAnalysis`)
   - Analyzes attached images in task context
   - When linked to a task, extracts only task-relevant information
   - Provides humorous dismissal for off-topic images
   - Response is descriptive text without AI disclaimer

2. **Audio Transcription** (`AiResponseType.audioTranscription`)
   - Transcribes audio recordings
   - When linked to a task, uses task context for better accuracy with names and concepts
   - Response is transcribed text
   - Supports automatic language detection

3. **Coding Prompt Generation** (`AiResponseType.promptGeneration`)
   - Transforms audio recording + task context into a detailed coding prompt
   - Triggered from audio entries linked to tasks
   - Uses `{{audioTranscript}}` placeholder for user's verbal description
   - Output format: `## Summary` + `## Prompt` sections
   - Designed for copy-paste into AI coding assistants (Claude Code, GitHub Copilot)
   - Uses `GeneratedPromptCard` UI with prominent copy button

4. **Image Prompt Generation** (`AiResponseType.imagePromptGeneration`)
   - Transforms audio recording + task context into a detailed image generation prompt
   - Triggered from audio entries linked to tasks (same as coding prompt)
   - Uses `{{audioTranscript}}` placeholder for user's visual description
   - Output format: `## Summary` + `## Prompt` sections
   - Designed for copy-paste into AI image generators (Midjourney, DALL-E, Gemini)
   - Includes visual metaphor guidelines, style options, and technical parameters
   - Uses `GeneratedPromptCard` UI with prominent copy button

5. **Image Generation** (`AiResponseType.imageGeneration`)
   - Generates cover art images directly using AI (Gemini Nano Banana Pro model)
   - Triggered from audio entries linked to tasks via action menu
   - Uses task context and audio transcript to build image prompts
   - Produces 16:9 aspect ratio images at 2K resolution (1920x1080) suitable for task cover art
   - Review modal allows editing prompt, regenerating, or accepting images
   - Accepted images are saved as journal entries and set as task cover

## Image Generation (Cover Art)

### Overview

The AI system supports native image generation for creating task cover art. This feature uses Gemini's image generation model (Nano Banana Pro) to generate images based on task context and user voice descriptions.

### How It Works

1. **Trigger**: User selects "Generate cover art" from an audio entry's action menu (when linked to a task)
2. **Prompt Building**: System constructs a prompt from:
   - Audio transcript (user's verbal description of desired image)
   - Task title and status
   - System message from preconfigured cover art generation prompt
3. **Generation**: Gemini image generation model creates the image
4. **Review Modal**: User can:
   - Accept the image as cover art
   - Edit the prompt and regenerate
   - Cancel without saving
5. **Import**: Accepted images are saved as journal entries and set as the task's cover art

### Implementation Components

#### State Management
- **`ImageGenerationController`**: Riverpod controller managing generation state
- **`ImageGenerationState`**: Freezed union type with states:
  - `initial`: Idle state before generation
  - `generating`: In-progress with prompt
  - `success`: Completed with image bytes and MIME type
  - `error`: Failed with error message

#### Repository Layer
- **`GeminiInferenceRepository.generateImage()`**: Direct Gemini API call for image generation
- **`CloudInferenceRepository.generateImage()`**: Routes to Gemini repository
- **`GeminiUtils.buildImageGenerationRequestBody()`**: Builds request with 16:9 aspect ratio and 2K resolution

#### UI Components
- **`ImageGenerationReviewModal`**: Full-screen modal for image review
  - Shows generation progress with spinner
  - Displays generated image with accept/edit actions
  - Provides prompt editor for modifications
  - Handles error states with retry option
- **`ModernGenerateCoverArtItem`**: Action menu item for triggering generation

#### Image Import
- **`importGeneratedImageBytes()`**: Helper function to save generated images
  - Creates journal image entry from bytes
  - Links to parent task
  - Optionally sets as task cover art

### Model Configuration

The Nano Banana Pro model is defined in `known_models.dart`:
```dart
const KnownModel(
  providerModelId: 'models/gemini-3-pro-image-preview',
  name: 'Gemini 3 Pro Image (Nano Banana Pro)',
  inputModalities: [Modality.text, Modality.image],
  outputModalities: [Modality.text, Modality.image],
  isReasoningModel: false,
  description: 'High-quality image generation model for cover art and visual mnemonics. '
      'Generates images directly from task context and voice descriptions.',
)
```

### Preconfigured Prompt

The cover art generation system prompt guides the AI to:
- Generate visually striking, artistic images
- Use 16:9 aspect ratio at 2K resolution for task cover art
- Incorporate task context, user descriptions, and visual metaphors for learnings/annoyances
- Avoid text in generated images
- Create unique, creative interpretations

## Function Calling and Tool Use

The system supports OpenAI-style function calling for enhanced AI capabilities:

### Checklist Completion Suggestions

Models that support function calling can automatically suggest when checklist items have been completed:

- **Detection**: AI analyzes audio, text, and images for completion evidence
- **Evidence Types**: Past tense verbs, explicit statements, visual confirmation
- **Visual Feedback**: Pulsing colored indicators show confidence level
- **Auto-check**: High confidence suggestions are automatically checked
- **User Control**: Single-tap to accept or dismiss suggestions

### Adding Checklist Items

AI can automatically create new checklist items based on content analysis:

- **Smart Creation**: Creates "to-do" checklist if none exists
- **Context Awareness**: Works during any inference type
- **Common Triggers**: "I need to...", "Next I'll...", task mentions
- **Batch Processing**: Uses conversation-based approach for efficient handling
- **Error Recovery**: Automatic retry with corrected format on failures

### Updating Checklist Items

AI can update existing checklist items based on user intent:

- **Semantic Matching**: Say "I did the shopping" and the AI marks the matching item complete—no exact text match required
- **Title Corrections**: Fix transcription errors like "mac OS" → "macOS" or "i Phone" → "iPhone"
- **Combined Updates**: Change both status and title in a single call
- **Graceful Skipping**: Invalid or out-of-scope item IDs are skipped without causing errors (per prompt contract: "not an error for you")
- **Function-Specific Retry**: Validation errors (missing ID, wrong types) trigger update-specific retry prompts with correct format guidance
- **Context-Aware Continuation**: Update-only success shows appropriate message ("You've updated N item(s)") rather than misleading "No items created"

#### Error Handling Philosophy

The update handler distinguishes between two types of issues:

1. **Validation Errors** (retry-able): Missing required fields, wrong types, empty arrays → Sets `hadErrors=true`, provides specific retry guidance
2. **Skipped Items** (graceful): Item not found, doesn't belong to task, no changes detected → Logged but NOT treated as errors, allows conversation to complete normally

This ensures the AI receives actionable feedback for fixable problems while gracefully handling expected edge cases like stale item IDs.

#### Per-Entry Directive Behavior (Checklist Updates)

When running Checklist Updates, the user's request is provided as a list of entries. Directives are scoped per entry:

- Ignore for checklist: If an entry contains phrases like "Don't consider this for checklist items" or "Ignore for checklist", that entry is ignored for item extraction.
- Plan-only single item: If an entry contains phrases like "The rest is an implementation plan" or "Single checklist item for this plan", that entire entry collapses to at most one created item. If the entry specifies "Single checklist item: <title>", that exact title is used; otherwise a generic "Draft implementation plan" is created (in the request's language).
- Isolation: Do not blend directives across entries; each entry is evaluated independently.

This keeps long implementation plans from exploding into many items while allowing adjacent entries to produce normal actionable items.

#### Current Entry Hint & Deleted Items Guardrail

- Invocation sources that have a focused entry (recording modal, linked-entry AI popup) pass the entry ID through the pipeline as `linkedEntityId`. The prompt builder serializes that entry (id, type, createdAt, user-edited text/transcript) into the `{{current_entry}}` block so the LLM prioritizes fresh content.
- Task-level AI popups leave `linkedEntityId` null; the prompt omits the `Current Entry` block and the model considers the full task log.
- The builder also streams every soft-deleted checklist item linked to the task (title + deletedAt) into `{{deleted_checklist_items}}`. The prompt instructs the model to avoid recreating those titles unless the user explicitly asks to revive them.

### Language Detection

Automatic language detection for multilingual support:

- **41 Languages Supported**: Many major world languages
- **Automatic Detection**: AI analyzes content to detect primary language
- **Confidence Levels**: High, medium, or low confidence ratings
- **Persistence**: Language preference saved with task

### Function Call Processing

- **Streaming Support**: Tool calls accumulated from streaming chunks
- **Empty ID Handling**: Auto-generates unique IDs when providers send empty IDs
- **Concatenated JSON**: Parses multiple JSON objects in single tool call
- **Model Requirements**: Requires `supportsFunctionCalling: true` in model config

## Language Support

### Overview

The AI system supports multilingual task summary generation in 41 languages, allowing users to receive AI-generated content in their preferred language.

### Supported Languages

- **European**: English, Spanish, French, German, Italian, Portuguese, Dutch, Polish, Russian, Ukrainian, Czech, Bulgarian, Croatian, Danish, Estonian, Finnish, Greek, Hungarian, Latvian, Lithuanian, Norwegian, Romanian, Serbian, Slovak, Slovenian, Swedish
- **Asian**: Chinese, Japanese, Korean, Hindi, Bengali, Indonesian, Thai, Vietnamese, Turkish
- **Middle Eastern**: Arabic, Hebrew
- **African**: Swahili, Igbo, Nigerian Pidgin, Yoruba

### How It Works

1. **Automatic Detection**: AI analyzes audio transcripts and text content
2. **Language Setting**: Sets detected language with confidence level
3. **Summary Generation**: All content generated in selected language
4. **Manual Override**: Users can change language via task header
   - Selecting a new language immediately regenerates the AI task summary in that language

## Configuration System

### API Key Management

```dart
// Create an API key configuration
final config = AiConfig.apiKey(
  id: 'openai-key',
  baseUrl: 'https://api.openai.com/v1',
  apiKey: 'sk-...',
  name: 'OpenAI API Key',
  createdAt: DateTime.now(),
  supportsThinkingOutput: true,
);

// Save configuration
await repository.saveConfig(config);
```

### Prompt Configuration

Prompts can be:
- **Preconfigured**: Built-in templates for common tasks
- **Custom**: User-created prompts with variables
- **Context-aware**: Automatically adapt based on entity relationships
- **Tracked**: Optionally track updates from preconfigured templates

### Model Configuration

Models define:
- Provider to use
- Model name and capabilities
- Function calling support
- Token limits
- Supported modalities

### Prompt Template Tracking

The system supports tracking updates from preconfigured prompt templates, ensuring prompts stay synchronized with template improvements.

#### How It Works

1. **Template Creation**: Tracking is enabled by default when creating from a preconfigured template
2. **Visual Toggle**: A sync icon toggle controls tracking status
3. **Tracked Mode**:
   - System and user messages load dynamically from the template
   - Prompt fields become read-only
   - Template improvements apply automatically
4. **Custom Mode**:
   - Fields become editable
   - Custom changes are preserved
   - Template ID is retained for re-enabling

#### Implementation

- **Data Model**: Added `trackPreconfigured` (boolean) and `preconfiguredPromptId` (string) to `AiConfigPrompt`
- **Dynamic Loading**: `PromptBuilderHelper` loads messages from templates when tracking is enabled
- **UI State**: Visual toggle with sync icon indicates tracking status
- **Persistence**: Tracking settings persist through saves and edits

#### Benefits

- Automatic updates from template improvements
- No manual prompt maintenance required
- Toggle between tracked and custom modes
- Clear visual tracking status

## UI Components

### Settings Pages
- **`ai_settings_page.dart`**: Main settings hub with tabs
- **`prompt_edit_page.dart`**: Create/edit prompts
- **`inference_model_edit_page.dart`**: Configure models
- **`inference_provider_edit_page.dart`**: Manage providers

### Response Display
- **`ai_response_summary.dart`**: Markdown rendering with H1 filtering
- **`ai_response_summary_modal.dart`**: Full-screen view

### Progress Indicators
- **`unified_ai_progress_view.dart`**: Real-time progress with model installation
- **`animation/ai_running_animation.dart`**: Siri-wave animated processing indicator
- **Model Installation Dialog**: Integrated UI for installing Ollama models

### AI Assistant Access
- **`unified_ai_popup_menu.dart`**: Context-aware AI menu with two-section layout
  - **Skills section** (top): Shows available skills for the entity, triggering via profile resolution
  - **Legacy prompts section** (bottom): Shows traditional prompts filtered by category
  - `hasAvailablePromptsProvider` checks both skills and prompts to determine button visibility
  - Quick access to AI features from any entity
  - Dynamic filtering based on entity type and category

### Settings Services
- **`ui/settings/ai_settings_filter_service.dart`**: Advanced filtering system
  - Filter by provider, capabilities, reasoning support
  - Search across all configuration types
- **`ui/settings/ai_settings_navigation_service.dart`**: Smooth navigation
  - Consistent slide transitions
  - Centralized navigation logic
- **`ui/settings/services/ai_config_delete_service.dart`**: Smart deletion
  - Cascading deletes for related configurations
  - Undo functionality
  - Stylish confirmation dialogs

## Linked Entity Inference Tracking

The system supports running inferences on entities linked to other entities:

### Dual-Entry System

When inference starts with a linked entity, two symmetric entries are created:
1. **Primary Entity Entry**: Main entity with `linkedEntityId`
2. **Linked Entity Entry**: Linked entity pointing back

This ensures:
- Both entities track inference independently
- UI shows indicators for both entities
- Status updates propagate to both
- Progress visible from both perspectives

## Technical Implementation Details

### Repository Architecture

The repository layer follows a hierarchical design:

```
UnifiedAiInferenceRepository (orchestration)
    ↓                           ↓
CloudInferenceRepository    ConversationRepository (for multi-turn)
    ↓                           ↓
Provider-Specific:          ConversationManager
- OllamaInferenceRepository    ↓
- WhisperInferenceRepository   Event Streaming
- OpenAI/Anthropic/etc
```

The conversation layer enables:
- Multi-turn interactions with context preservation
- Streaming responses with real-time UI updates
- Tool call handling across conversation turns
- Automatic error recovery and retry logic

### Error Handling

Each provider has custom exception types:
- `ModelNotInstalledException`: Ollama model not installed
- `TranscriptionException`: Audio transcription errors (unified across providers, with `provider` field)
- `InferenceError`: General inference failures

### Concurrency Protection

Simple mechanisms prevent race conditions:
- **Read-Current-Write Pattern**: Always read fresh state before updates
- **Semaphore Protection**: `Set<String>` prevents duplicate operations
- **Single-threaded Safety**: Flutter's event loop prevents true concurrency

## Testing

Comprehensive test coverage includes:

### Unit Tests
- Repository mocking and behavior verification
- Service logic and edge cases
- Controller state management
- Function calling and tool processing

### Integration Tests
- End-to-end inference flows
- Auto-checklist creation
- Language detection and persistence
- Error recovery

### Provider-Specific Tests
- Ollama: Model management, retries, endpoint selection
- Whisper: Transcription, error handling, response formatting
- Cloud providers: Streaming, function calls, authentication

## Security Considerations

- API keys stored via OS secure storage (`flutter_secure_storage`): Keychain (iOS/macOS), Android Keystore, Windows Credential Locker (DPAPI), Linux Secret Service (libsecret)
- Keys never logged or exposed in UI
- HTTPS for all network requests
- Sensitive data excluded from error messages
- Local models run without external data transmission

## Common Questions

### Q: How do I add a new AI provider?
A: Create a new repository implementing the provider's API, add the provider type to `InferenceProviderType` enum, and update `CloudInferenceRepository` to route requests.

### Q: How does automatic title extraction work?
A: The AI suggests titles as H1 headers. Tasks with titles under 5 characters automatically use the AI suggestion, particularly useful for audio-created tasks.

### Q: Which models support function calling?
A: OpenAI GPT-4, Anthropic Claude, Google Gemini, and some Ollama models (when using `/api/chat` endpoint).

### Q: How does the system handle Ollama models?
A: Ollama models are automatically installed when needed, with progress tracking. The system selects the appropriate endpoint based on function calling requirements.

### Q: Can I use custom OpenAI-compatible endpoints?
A: Yes, configure a "Generic OpenAI" provider with your custom endpoint URL and API key.

### Q: How does language detection work?
A: AI analyzes task content (especially audio transcripts) and calls `set_task_language` function with detected language and confidence level.

### Q: What happens during concurrent modifications?
A: The Read-Current-Write pattern ensures AI reads fresh state before updates, preserving user changes made during processing.

## Category-Based AI Settings

The AI system integrates with the Categories feature for fine-grained control over which prompts are available for different content types. See the [Categories Feature README](../categories/README.md#ai-powered-category-settings) for details.

## TODO / Future Work

### Legacy Enum Removal (`AiResponseType.taskSummary` / `AiResponseType.checklistUpdates`)

Both enum values carry `@Deprecated` annotations and are excluded from
automatic prompt execution (`getActivePromptsForContext`) and the response-type
picker UI. They are retained solely for JSON/DB backwards-compatibility.

**Steps to fully remove them:**

1. Write a DB migration that deletes or re-maps any persisted rows whose
   `aiResponseType` equals `'TaskSummary'` or `'ChecklistUpdates'` (the
   serialized JSON values from `taskSummaryConst` / `checklistUpdatesConst`).
2. Remove the two enum members and their `@JsonValue` constants from
   `lib/features/ai/state/consts.dart`.
3. Remove the corresponding `case` branches in `localizedName`, `icon`,
   `_handlePostProcessing`, and `_getTypeIcon`.
4. Delete the `isLegacyType` extension getter.
5. Run `make build_runner` to regenerate Freezed/JSON code.
6. Search the codebase for any remaining references and clean them up.

### Future Improvements

##### How Gemini ties into chat

- Provider routing: `cloud_inference_repository.dart` selects `GeminiInferenceRepository` when `InferenceProviderType.gemini` is active. The repository streams OpenAI-compatible deltas.
- Tool calls: the Gemini adapter emits tool calls with turn-prefixed IDs (`tool_turn{N}_{index}`) and indices. The turn prefix ensures unique IDs across conversation turns, preventing signature and name lookup collisions. The conversation layer accumulates arguments across chunks using those identifiers and remains backward-compatible with "Gemini-style" complete tool-call batches.
- Thinking blocks: all Gemini 2.5+ models (including Flash) support thinking. The adapter emits a single consolidated `<think>` block before visible content when thinking is enabled. The conversation manager simply appends the received content to the assistant message buffer.
- Fallback behavior: if a Gemini stream yields no deltas at all, the adapter performs a single non-streaming call and emits at most three deltas (thinking, text, tools) so the UI never shows an empty bubble.
- Usage statistics: the adapter parses `usageMetadata` from Gemini responses and emits usage information (prompt tokens, completion tokens, thoughts tokens) in the final stream chunk.
- Thought signatures: for Gemini 3 models, thought signatures are captured from function calls and stored keyed by tool call ID. These signatures must be included when replaying function calls in subsequent turns for multi-turn conversation support.
