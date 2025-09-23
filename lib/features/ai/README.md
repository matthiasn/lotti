# AI Feature

This module provides a comprehensive AI integration system for generating task summaries, action item suggestions, image analysis, and audio transcription using various AI providers.

## Overview

The AI feature consists of several key components:

1. **Configuration Management**: Store and manage API keys, prompts, and model configurations
2. **Prompt Creation**: Build structured prompts for different AI tasks
3. **Inference Execution**: Run AI inference through various providers (OpenAI, Anthropic, Google, etc.)
4. **Response Processing**: Parse and display AI-generated responses
5. **UI Components**: Settings pages, response displays, and configuration management
6. **Conversation Support**: Multi-turn interactions with context preservation
7. **Automatic Setup**: Model pre-population and intelligent defaults
8. **Error Recovery**: Comprehensive error handling and user-friendly messages

## Architecture

### Core Components

#### Models (`model/`)
- **`ai_config.dart`**: Union type for different configuration types (API keys, prompts, models)
- **`ai_input.dart`**: Data structures for task input (task details, action items, log entries)
- **`cloud_inference_config.dart`**: Configuration for cloud inference providers
- **`inference_error.dart`**: Error types and handling for AI operations

#### Database (`database/`)
- **`ai_config_db.drift`**: Drift database schema for persistent storage
- **`ai_config_repository.dart`**: Interface for CRUD operations on configurations

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
  - Surfaces a single consolidated `<thinking>` block for non-flash models when enabled; always hides thoughts for flash
  - Emits OpenAI-style tool-call chunks with stable IDs (`tool_#`) and indices to support accumulation
  - Robust stream parsing via `gemini_stream_parser.dart`: handles SSE `data:` lines, NDJSON, and JSON array framing without relying on line boundaries
  - Non-streaming fallback via `:generateContent` kicks in only if the streaming path produced no events, aggregating thinking, text, and tools

- **`gemini_utils.dart`**: Shared helpers used by the Gemini repository
  - `isFlashModel` – detects flash variants to control thought visibility
  - `buildStreamGenerateContentUri` / `buildGenerateContentUri` – constructs correct Gemini endpoints from a base URL
  - `buildRequestBody` – builds request payloads including thinking config and function tools (mapped from OpenAI style)
  - `stripLeadingFraming` – removes SSE `data:` prefixes and JSON array framing from mixed-format streams
  
- **`gemini_stream_parser.dart`**: Streaming JSON parser for mixed-framing Gemini responses
  - Incremental parser resilient to SSE `data:` lines, NDJSON, and JSON array framing
  - Accumulates objects across chunks and ignores braces inside string literals
  - Returns decoded `Map<String,dynamic>` objects ready for adapter consumption

- **`whisper_inference_repository.dart`**: Handles audio transcription
  - Interfaces with locally running Whisper instances
  - Converts audio to transcription responses
  - Custom `WhisperTranscriptionException` for error handling

- **`gemma3n_inference_repository.dart`**: Local Gemma 3n model support
  - Provides audio transcription using local Gemma 3n server
  - Supports streaming text generation with OpenAI-compatible API
  - Handles both transcription and chat completion requests
  - Custom `Gemma3nInferenceException` for error handling
  - Automatic model name normalization (removes `google/` prefix)
  - Robust JSON response parsing with error recovery

- **`ai_input_repository.dart`**: Prepares task data for AI processing

#### Services (`services/`)
- **`auto_checklist_service.dart`**: Handles automatic checklist creation logic and decision making
- **`checklist_completion_service.dart`**: Manages checklist item completion suggestions and tracking
- **`task_summary_refresh_service.dart`**: Centralizes task summary refresh logic for checklist modifications
  - Eliminates code duplication across repositories
  - Handles checklist-to-task relationship resolution
  - Provides consistent error handling

#### Conversation Management (`conversation/`)
- **`conversation_manager.dart`**: Manages multi-turn AI conversations
  - Maintains conversation context and message history
  - Handles tool calls and responses
  - Provides event streaming for real-time updates
- **`conversation_repository.dart`**: Repository for conversation persistence
  - Creates and manages conversation sessions
  - Routes messages to appropriate inference providers
  - Manages conversation lifecycle and cleanup

#### Functions (`functions/`)
- **`checklist_completion_functions.dart`**: OpenAI-style function definitions for checklist operations
  - `suggest_checklist_completion`: Suggests items that appear completed
  - `add_checklist_item`: Adds new items to checklists
- **`task_functions.dart`**: Function definitions for task operations
  - `set_task_language`: Automatically detects and sets task language
- **`lotti_conversation_processor.dart`**: Conversation-based processing for better batching
  - Handles multiple checklist items efficiently
  - Provides error recovery and retry mechanisms
  - Supports batch operations with `add_multiple_checklist_items`
- **`lotti_checklist_handler.dart`**: Single checklist item creation handler
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
- **`latest_summary_controller.dart`**: Manages the latest AI response for a task
- **`active_inference_controller.dart`**: Tracks active inferences with linked entity support
  - **Dual-Entry System**: Creates symmetric entries for both primary and linked entities
  - **ActiveInferenceByEntity**: Finds active inferences for any entity (primary or linked)
- **`direct_task_summary_refresh_controller.dart`**: Manages direct task summary refresh requests
  - Implements debouncing with per-task timers
  - Monitors inference status to avoid conflicts
  - Provides direct refresh path bypassing notification system

#### Helpers & Extensions
- **`helpers/entity_state_helper.dart`**: Utilities for managing entity state during AI operations
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
  - Six main prompt types (Task Summary, Checklist Updates, etc.)
  - Consistent formatting and instructions
  - Unique IDs enable [prompt template tracking](#prompt-template-tracking)

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
- **Google Gemini**: Gemini Pro and flash models with native streaming adapter
  - Uses `gemini_inference_repository.dart` for REST calls and OpenAI-compatible streaming
  - Thought visibility policy: flash models hide thoughts; non-flash can surface a consolidated `<thinking>` block
  - Function calling maps to OpenAI-style tool calls with stable IDs and indices
- **OpenRouter**: Access to multiple models through unified API
- **Nebius AI Studio**: Enterprise AI platform support
- **Generic OpenAI-Compatible**: Any service implementing OpenAI's API specification

### Local Providers
- **Ollama**: Run open-source models locally
  - Automatic model installation with progress tracking
  - Support for function calling via `/api/chat` endpoint
  - Model warm-up for better performance
  - Supports models like Llama, Mistral, Qwen, DeepSeek

- **Whisper**: Local audio transcription
  - Runs on local Whisper server
  - Supports various audio formats via base64 encoding
  - Integrated with task context for better accuracy

- **Gemma 3n**: Local Gemma model with audio capabilities
  - Runs on local server (default port 11343)
  - Provides both audio transcription and text generation
  - OpenAI-compatible API for seamless integration
  - No API key required (local execution)
  - Supports streaming responses for real-time interaction
  - Optimized for high-quality transcription with 2000 token default

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
- Displayed using `GptMarkdown` widget for proper formatting

### 4. Automatic Title Extraction

When generating task summaries, the system automatically extracts suggested titles:
- The AI is prompted to start with an H1 header (`# Title`)
- The title is extracted using regex pattern: `^#\s+(.+)$`
- If the current task title is less than 5 characters, it's replaced with the AI suggestion
- This enables automatic title generation for tasks created from audio recordings
- The extracted title updates the task entity in the database
- When displaying summaries, the H1 title is filtered out to avoid redundancy

### 5. Direct Task Summary Refresh

The system includes a direct refresh mechanism that updates task summaries when checklist items are modified. For a user-focused description of this feature, see the [Tasks Feature README - Automatic Task Summary Updates](../tasks/README.md#automatic-task-summary-updates).

#### Overview

When users interact with checklists (adding items, checking/unchecking items, updating items), the system automatically triggers a refresh of the associated task's AI summary. This ensures task summaries stay up-to-date with the latest checklist state.

#### Implementation Components

1. **`DirectTaskSummaryRefreshController`**: Core controller managing refresh requests
   - Implements per-task debouncing (500ms) to batch rapid changes
   - Uses listener-based approach to handle ongoing inferences
   - Maintains separate timers for each task to prevent interference

2. **`TaskSummaryRefreshService`**: Centralized service for refresh operations
   - Eliminates code duplication across repositories
   - Handles checklist-to-task relationship lookups
   - Provides error isolation to prevent cascade failures

3. **Integration Points**: Automatic triggers in checklist operations
   - `createChecklistItem()`: Triggers refresh when new items are added
   - `updateChecklistItem()`: Triggers refresh when items are modified
   - `addItemToChecklist()`: Triggers refresh for batch additions

#### How It Works

1. **User Action**: User modifies a checklist item (add, update, check/uncheck)
2. **Repository Call**: The checklist repository calls `TaskSummaryRefreshService`
3. **Task Lookup**: Service finds all tasks linked to the modified checklist
4. **Refresh Request**: For each linked task, requests a summary refresh
5. **Debouncing**: Multiple rapid changes are batched with 500ms debounce
6. **Inference Check**: If inference is already running, sets up a listener to retry when complete
7. **Summary Update**: New task summary is generated reflecting checklist changes

#### Key Features

- **Direct Communication**: Bypasses notification system to avoid circular dependencies
- **Smart Debouncing**: Per-task timers prevent unnecessary API calls
- **Concurrent Safety**: Handles multiple tasks and checklists independently
- **Error Resilience**: Failures in one refresh don't affect others
- **Status Awareness**: Monitors inference status to avoid conflicts

#### Example Flow

```
User checks off "Buy milk" in shopping checklist
    ↓
ChecklistRepository.updateChecklistItem()
    ↓
TaskSummaryRefreshService.triggerTaskSummaryRefreshForChecklist()
    ↓
DirectTaskSummaryRefreshController.requestTaskSummaryRefresh()
    ↓
[500ms debounce timer]
    ↓
Triggers new AI inference for task summary
    ↓
Task summary updates to reflect completed item
```

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

## Response Types

The system supports four AI response types:

1. **Task Summary** (`AiResponseType.taskSummary`)
   - Generates comprehensive task overviews
   - Response is markdown text
   - Automatic title extraction for tasks with short titles
   - Language-aware generation based on task content

2. **Action Item Suggestions** (`AiResponseType.actionItemSuggestions`)
   - Extracts potential action items from logs
   - Response is parsed as JSON array
   - Items not already in task are suggested
   - **Automatic Checklist Creation with Smart Re-run** - If no checklists exist for the task, automatically creates a checklist with all AI suggestions, then re-runs the prompt to show updated suggestions (typically empty since items are now in the checklist)

3. **Image Analysis** (`AiResponseType.imageAnalysis`)
   - Analyzes attached images in task context
   - When linked to a task, extracts only task-relevant information
   - Provides humorous dismissal for off-topic images
   - Response is descriptive text without AI disclaimer

4. **Audio Transcription** (`AiResponseType.audioTranscription`)
   - Transcribes audio recordings
   - When linked to a task, uses task context for better accuracy with names and concepts
   - Response is transcribed text
   - Supports automatic language detection

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

### Language Detection

Automatic language detection for multilingual support:

- **38 Languages Supported**: All major world languages
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

The AI system supports multilingual task summary generation in 38 languages, allowing users to receive AI-generated content in their preferred language.

### Supported Languages

- **European**: English, Spanish, French, German, Italian, Portuguese, Dutch, Polish, Russian, Ukrainian, Czech, Bulgarian, Croatian, Danish, Estonian, Finnish, Greek, Hungarian, Latvian, Lithuanian, Norwegian, Romanian, Serbian, Slovak, Slovenian, Swedish
- **Asian**: Chinese, Japanese, Korean, Hindi, Bengali, Indonesian, Thai, Vietnamese, Turkish
- **Middle Eastern**: Arabic, Hebrew
- **African**: Swahili

### How It Works

1. **Automatic Detection**: AI analyzes audio transcripts and text content
2. **Language Setting**: Sets detected language with confidence level
3. **Summary Generation**: All content generated in selected language
4. **Manual Override**: Users can change language via task header

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
- **`latest_ai_response_summary.dart`**: Animated response updates
- **`expandable_ai_response_summary.dart`**: Interactive TLDR with accordion expansion
- **`ai_response_summary_modal.dart`**: Full-screen view

### Progress Indicators
- **`unified_ai_progress_view.dart`**: Real-time progress with model installation
- **`animation/ai_running_animation.dart`**: Siri-wave animated processing indicator
- **Model Installation Dialog**: Integrated UI for installing Ollama models

### AI Assistant Access
- **`unified_ai_popup_menu.dart`**: Context-aware AI menu
  - Shows available prompts for current entity type
  - Quick access to AI features from any entity
  - Dynamic prompt filtering based on context

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
- `WhisperTranscriptionException`: Audio transcription errors
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

## Conversation-Based Processing

### Overview

The AI system uses a conversation-based approach for checklist updates to improve efficiency and handle complex scenarios better. This approach is particularly effective for models that may not process all items in a single function call.

### Benefits

1. **Efficient Batching**: The system includes a batch function `add_multiple_checklist_items` that can create multiple items at once
2. **Error Recovery**: If function calls fail, the system automatically retries with helpful prompts
3. **Duplicate Prevention**: Intelligently prevents creating duplicate items across single and batch operations
4. **Better Model Support**: Works well with models that may only process one item at a time (like some open-source models)

### How It Works

1. **Initial Request**: User's prompt is sent with available function tools
2. **Function Calls**: AI makes function calls to create checklist items (single or batch)
3. **Error Handling**: If calls fail, system provides corrective prompts automatically
4. **Continuation**: System can ask AI to continue if more items are needed
5. **Completion**: Process ends when all items are created or max turns reached

### Implementation Details

The conversation-based approach uses several key components:
- **ConversationManager**: Maintains message history and handles tool responses
- **ConversationRepository**: Manages conversation lifecycle and routes to providers
- **LottiConversationProcessor**: Orchestrates the checklist creation flow
- **Event Streaming**: Provides real-time updates via `ConversationEvent` stream

### Safe JSON Accumulation for Streaming Tool Calls

The conversation repository implements a robust mechanism for accumulating streaming JSON arguments in tool calls, preventing corruption that can occur with naive string concatenation.

#### The Problem

When AI providers stream tool call responses, JSON arguments often arrive in multiple chunks:
- Chunks may split UTF-8 characters across boundaries
- Network delays can cause out-of-order arrival
- Simple concatenation can create invalid JSON

Example of the issue:
```
Chunk 1: {"items": ["cheese", "pep
Chunk 2: peroni", "mushrooms"]}
Naive concatenation: {"items": ["cheese", "pepperoni", "mushrooms"]}  // Corrupted!
```

#### The Solution

The repository uses `StringBuffer` instances to safely accumulate arguments:

```dart
// Safe accumulation using StringBuffer for each tool call
final toolCallArgumentBuffers = <String, StringBuffer>{};

// When processing chunks:
if (existingIndex >= 0) {
  final existing = toolCalls[existingIndex];
  final toolCallKey = existing.id;
  
  // Get or create buffer for this tool call
  final buffer = toolCallArgumentBuffers[toolCallKey] ??
      StringBuffer(existing.function.arguments);
  toolCallArgumentBuffers[toolCallKey] = buffer;
  
  // Append new chunk to buffer
  buffer.write(toolCallChunk.function?.arguments ?? '');
  
  // Update the tool call with buffered arguments
  toolCalls[existingIndex] = ChatCompletionMessageToolCall(
    id: existing.id,
    type: existing.type,
    function: ChatCompletionMessageFunctionCall(
      name: existing.function.name,
      arguments: buffer.toString(),
    ),
  );
}
```

#### Technical Benefits

1. **Thread-Safe Accumulation**: StringBuffer handles proper character encoding
2. **Preserves Chunk Order**: Each tool call has its own buffer indexed by ID
3. **Memory Efficient**: Buffers are created only when needed
4. **Handles Edge Cases**: 
   - Empty chunks are safely ignored
   - Missing arguments default to empty strings
   - Split UTF-8 sequences are preserved correctly

#### Provider-Specific Handling

The system also includes special handling for providers like Gemini that send multiple complete tool calls in a single chunk:

```dart
// Detect Gemini-style batched tool calls
final isGeminiStyle = delta!.toolCalls!.length > 1 &&
    delta.toolCalls!.every((tc) =>
        (tc.id == null || tc.id!.isEmpty) &&
        tc.index == null &&
        tc.function?.arguments != null &&
        tc.function!.arguments!.isNotEmpty);
```

This ensures compatibility across different AI provider implementations while maintaining data integrity.

### Current Limitations

**Cloud Provider Support**: Currently, the conversation-based approach only works with Ollama (local) providers. Cloud providers (OpenAI, Anthropic, Google Gemini, etc.) fall back to the traditional single-request approach. This is a temporary limitation that will be addressed in future updates.

## Category-Based AI Settings

The AI system integrates with the Categories feature for fine-grained control over which prompts are available for different content types. See the [Categories Feature README](../categories/README.md#ai-powered-category-settings) for details.

## TODO / Future Work

### Cloud Provider Support for Conversation-Based Processing

Currently, the conversation-based processing approach is limited to Ollama providers. To enable full support for cloud providers (OpenAI, Anthropic, Google Gemini, etc.), the following implementation plan should be followed:

#### 1. Create a Unified Inference Interface

Create an interface that both `OllamaInferenceRepository` and cloud providers can implement:

```dart
abstract class InferenceRepositoryInterface {
  /// Generate text with full conversation history
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
  });
}
```

#### 2. Implement Cloud Provider Adapter

Create an adapter that wraps `CloudInferenceRepository` to implement the conversation interface:

```dart
class CloudInferenceWrapper implements InferenceRepositoryInterface {
  final CloudInferenceRepository cloudRepository;
  
  @override
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
  }) {
    // Convert messages to prompt and delegate to cloud repository
  }
}
```

#### 3. Update Conversation Repository

Modify `ConversationRepository` to accept the abstract interface instead of concrete `OllamaInferenceRepository`:

```dart
Future<void> sendMessage({
  required InferenceRepositoryInterface inferenceRepo, // Instead of OllamaInferenceRepository
  // ... other parameters
})
```

#### 4. Factory Pattern for Repository Creation

In `UnifiedAiInferenceRepository._processWithConversation()`:

```dart
InferenceRepositoryInterface createInferenceRepo(AiConfigInferenceProvider provider) {
  switch (provider.inferenceProviderType) {
    case InferenceProviderType.ollama:
      return OllamaInferenceRepository();
    case InferenceProviderType.openai:
    case InferenceProviderType.anthropic:
    case InferenceProviderType.google:
      return CloudInferenceWrapper(
        cloudRepository: ref.read(cloudInferenceRepositoryProvider),
      );
    // ... other providers
  }
}
```

#### 5. Handle Provider-Specific Differences

- **Streaming**: Ensure consistent event streaming across providers
- **Tool Call Format**: Normalize tool call responses between providers
- **Error Handling**: Unified error handling across different provider APIs
- **Authentication**: Pass appropriate credentials based on provider type

#### 6. Testing Strategy

- Unit tests for each adapter implementation
- Integration tests with mock providers
- End-to-end tests with real providers (behind feature flags)
- Performance comparison between providers

#### 7. Migration Path

1. Implement interface and adapters without changing existing code
2. Add feature flag for cloud conversation support
3. Gradually enable for each provider after testing
4. Remove fallback to non-conversation approach once stable

### Other Future Improvements

- **Streaming UI Updates**: Show checklist items as they're created in real-time
- **Progress Indicators**: Better visual feedback during batch operations
- **Undo/Redo**: Support for undoing batch checklist operations
- **Template Support**: Predefined checklist templates for common tasks
- **Smart Grouping**: Automatically group related checklist items
- **Priority Detection**: AI-suggested priority levels for checklist items
- **Non-Streaming Response Option**: Add support for non-streaming API responses to handle providers (like Gemini) that return malformed streaming tool calls. This would:
  - Add a `preferNonStreaming` flag to `AiConfigInferenceProvider`
  - Use `createChatCompletion` instead of `createChatCompletionStream` for flagged providers
  - Convert non-streaming responses to streams for API consistency
  - Solve issues with concatenated JSON in tool call arguments
  - Provide cleaner tool call parsing without accumulation complexity
##### How Gemini ties into chat

- Provider routing: `cloud_inference_repository.dart` selects `GeminiInferenceRepository` when `InferenceProviderType.gemini` is active. The repository streams OpenAI-compatible deltas.
- Tool calls: the Gemini adapter emits tool calls with unique IDs (`tool_0`, `tool_1`, …) and indices. The conversation layer accumulates arguments across chunks using those identifiers and remains backward-compatible with "Gemini-style" complete tool-call batches.
- Thinking blocks: for non-flash models the adapter optionally emits a single consolidated `<thinking>` block before visible content; for flash models thoughts are never emitted. The conversation manager simply appends the received content to the assistant message buffer.
- Fallback behavior: if a Gemini stream yields no deltas at all, the adapter performs a single non-streaming call and emits at most three deltas (thinking, text, tools) so the UI never shows an empty bubble.
