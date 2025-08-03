# AI Feature

This module provides a comprehensive AI integration system for generating task summaries, action item suggestions, image analysis, and audio transcription using various AI providers.

## Overview

The AI feature consists of several key components:

1. **Configuration Management**: Store and manage API keys, prompts, and model configurations
2. **Prompt Creation**: Build structured prompts for different AI tasks
3. **Inference Execution**: Run AI inference through various providers (OpenAI, Anthropic, Google, etc.)
4. **Response Processing**: Parse and display AI-generated responses
5. **UI Components**: Settings pages, response displays, and configuration management

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

- **`whisper_inference_repository.dart`**: Handles audio transcription
  - Interfaces with locally running Whisper instances
  - Converts audio to transcription responses
  - Custom `WhisperTranscriptionException` for error handling

- **`ai_input_repository.dart`**: Prepares task data for AI processing

#### Services (`services/`)
- **`auto_checklist_service.dart`**: Handles automatic checklist creation logic and decision making
- **`checklist_completion_service.dart`**: Manages checklist item completion suggestions and tracking

#### Functions (`functions/`)
- **`checklist_completion_functions.dart`**: OpenAI-style function definitions for checklist operations
  - `suggest_checklist_completion`: Suggests items that appear completed
  - `add_checklist_item`: Adds new items to checklists
- **`task_functions.dart`**: Function definitions for task operations
  - `set_task_language`: Automatically detects and sets task language

#### State Management (`state/`)
- **`unified_ai_controller.dart`**: Main controller orchestrating AI operations
  - Uses helper methods (`_updateInferenceStatus`, `_startActiveInference`, etc.) for consistent state updates
  - Handles both primary and linked entity status updates symmetrically
- **`inference_status_controller.dart`**: Tracks inference progress and status
- **`latest_summary_controller.dart`**: Manages the latest AI response for a task
- **`active_inference_controller.dart`**: Tracks active inferences with linked entity support
  - **Dual-Entry System**: Creates symmetric entries for both primary and linked entities
  - **ActiveInferenceByEntity**: Finds active inferences for any entity (primary or linked)
- **`checklist_suggestions_controller.dart`**: Manages checklist completion suggestions

## Supported AI Providers

The system supports multiple inference providers through a modular architecture:

### Cloud Providers
- **OpenAI**: GPT-3.5, GPT-4, and other models via official API
- **Anthropic**: Claude models (Opus, Sonnet, Haiku) with streaming support
- **Google Gemini**: Gemini Pro and other Google AI models
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

### Model Configuration

Models define:
- Provider to use
- Model name and capabilities
- Function calling support
- Token limits
- Supported modalities

## UI Components

### Settings Pages
- **`ai_settings_page.dart`**: Main settings hub with tabs
- **`prompt_edit_page.dart`**: Create/edit prompts
- **`inference_model_edit_page.dart`**: Configure models
- **`inference_provider_edit_page.dart`**: Manage providers

### Response Display
- **`ai_response_summary.dart`**: Markdown rendering with H1 filtering
- **`latest_ai_response_summary.dart`**: Animated response updates
- **`ai_response_summary_modal.dart`**: Full-screen view

### Progress Indicators
- **`unified_ai_progress_view.dart`**: Real-time progress
- **`ai_running_animation.dart`**: Animated processing indicator
- **Model Installation Dialog**: For Ollama models not yet installed

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
    ↓
CloudInferenceRepository (routing)
    ↓
Provider-Specific Repositories:
- OllamaInferenceRepository (local models)
- WhisperInferenceRepository (audio)
- OpenAI/Anthropic/etc (via OpenAI client)
```

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

- API keys stored in encrypted local database
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