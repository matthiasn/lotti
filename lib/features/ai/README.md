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

#### Database (`database/`)
- **`ai_config_db.drift`**: Drift database schema for persistent storage
- **`ai_config_repository.dart`**: Interface for CRUD operations on configurations

#### Repositories (`repository/`)
- **`unified_ai_inference_repository.dart`**: Main repository handling all AI inference requests
- **`cloud_inference_repository.dart`**: Handles communication with AI providers
- **`ai_input_repository.dart`**: Prepares task data for AI processing

#### State Management (`state/`)
- **`unified_ai_controller.dart`**: Main controller orchestrating AI operations
- **`inference_status_controller.dart`**: Tracks inference progress and status
- **`latest_summary_controller.dart`**: Manages the latest AI response for a task

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
- System message setting context
- Detailed user message with formatting instructions
- Placeholder `{{task}}` replaced with actual task JSON

### 2. Data Flow

1. **Input Preparation**: Task data is serialized to JSON including:
   - Task title, status, duration
   - Action items (completed and pending)
   - Log entries with timestamps and text

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

## Response Types

The system supports four AI response types:

1. **Task Summary** (`AiResponseType.taskSummary`)
   - Generates comprehensive task overviews
   - Response is markdown text
   - No special parsing required

2. **Action Item Suggestions** (`AiResponseType.actionItemSuggestions`)
   - Extracts potential action items from logs
   - Response is parsed as JSON array
   - Items not already in task are suggested

3. **Image Analysis** (`AiResponseType.imageAnalysis`)
   - Analyzes attached images in task context
   - When linked to a task, extracts only task-relevant information
   - Provides humorous dismissal for off-topic images
   - Response is descriptive text without AI disclaimer

4. **Audio Transcription** (`AiResponseType.audioTranscription`)
   - Transcribes audio recordings
   - Response is transcribed text

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
- **Preconfigured**: Use built-in templates from `preconfiguredPrompts.dart`
- **Custom**: Create custom prompts with variables and specific requirements

### Model Configuration

Models define:
- Which provider to use
- Model name (e.g., "gpt-4", "claude-opus-4")
- Supported modalities (text, image, audio)
- Token limits

## UI Components

### Settings Pages
- **`ai_settings_page.dart`**: Main settings hub with tabs for prompts, models, providers
- **`prompt_edit_page.dart`**: Create/edit prompt configurations
- **`inference_model_edit_page.dart`**: Configure AI models
- **`inference_provider_edit_page.dart`**: Manage API providers

### Response Display
- **`ai_response_summary.dart`**: Renders AI responses with markdown support (filters H1 titles for task summaries)
- **`latest_ai_response_summary.dart`**: Shows the most recent AI response for a task
- **`ai_response_summary_modal.dart`**: Full-screen view of AI responses

### Progress Indicators
- **`unified_ai_progress_view.dart`**: Shows inference progress
- **`ai_running_animation.dart`**: Animated indicator during processing

## Usage Example

```dart
// 1. User triggers AI summary from task view
final controller = UnifiedAiController(
  taskId: task.id,
  ref: ref,
  aiResponseType: AiResponseType.taskSummary,
);

// 2. Controller automatically:
//    - Fetches task data
//    - Selects appropriate prompt
//    - Runs inference
//    - Saves response

// 3. UI displays response
LatestAiResponseSummary(
  taskId: task.id,
  aiResponseType: AiResponseType.taskSummary,
)
```

## Common Questions

### Q: How are prompts customized?
A: Prompts use a template system with variables like `{{task}}`. The system replaces these with actual data before sending to the AI.

### Q: How does automatic title extraction work?
A: When generating task summaries, the AI suggests a title as an H1 header. If the current task title is less than 5 characters (e.g., empty or very short), it's automatically replaced with the AI's suggestion. This is particularly useful for tasks created from audio recordings.

### Q: How does context-aware image analysis work?
A: When an image is linked to a task, the image analysis prompt automatically includes the full task context (title, status, action items, log entries). The AI then:
- Extracts only information relevant to the task
- Provides a brief, humorous note if the image is off-topic (e.g., "This appears to be a photo of ducks by a lake, which seems unrelated to your database migration task. Moving on...")
- Focuses on actionable insights for task-relevant images
This prevents verbose, irrelevant image descriptions from cluttering task summaries.

### Q: Which AI providers are supported?
A: The system supports OpenAI, Anthropic, Google, Groq, OpenRouter, and custom OpenAI-compatible endpoints.

### Q: How are errors handled?
A: Errors are wrapped in `InferenceError` objects and displayed using `AiErrorDisplay` widget with user-friendly messages.

### Q: Can I use local models?
A: Yes, by configuring a custom endpoint pointing to a local inference server (e.g., Ollama).

## Testing

The system includes:
- Mock tests for repositories and controllers
- Integration tests using in-memory databases
- Widget tests for UI components

## Security Considerations

- API keys are stored locally in the encrypted database
- Keys are never logged or exposed in the UI
- Network requests use HTTPS
- Sensitive data is not included in error messages