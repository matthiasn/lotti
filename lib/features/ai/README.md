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

#### Services (`services/`)
- **`auto_checklist_service.dart`**: Handles automatic checklist creation logic and decision making

#### State Management (`state/`)
- **`unified_ai_controller.dart`**: Main controller orchestrating AI operations
  - Uses helper methods (`_updateInferenceStatus`, `_startActiveInference`, etc.) for consistent state updates
  - Handles both primary and linked entity status updates symmetrically
- **`inference_status_controller.dart`**: Tracks inference progress and status
- **`latest_summary_controller.dart`**: Manages the latest AI response for a task
- **`active_inference_controller.dart`**: Tracks active inferences with linked entity support
  - **Dual-Entry System**: Creates symmetric entries for both primary and linked entities
  - **ActiveInferenceByEntity**: Finds active inferences for any entity (primary or linked)

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

#### Decision Flow:
```dart
// In _handlePostProcessing() - Read-Current-Write Pattern
case AiResponseType.taskSummary:
  if (entity is Task) {
    // Get current task state to avoid overwriting concurrent changes
    final currentTask = await _getCurrentEntityState(entity.id) as Task?;
    if (currentTask == null) return;
    
    // Process with current state, not stale captured state
    await _updateTaskWithSummary(currentTask, response);
  }

case AiResponseType.actionItemSuggestions:
  if (entity is Task && suggestedActionItems != null && !isRerun) {
    // Get current task state for auto-creation decision
    final currentTask = await _getCurrentEntityState(entity.id) as Task?;
    if (currentTask != null) {
      await _handleActionItemSuggestions(currentTask, suggestedActionItems);
    }
  }

// In _handleActionItemSuggestions()
if (_autoCreatingTasks.contains(task.id)) {
  return; // Prevent duplicate auto-creation
}

final shouldAutoCreate = await autoChecklistService.shouldAutoCreate(taskId: task.id);
if (shouldAutoCreate) {
  _autoCreatingTasks.add(task.id);
  try {
    final result = await autoChecklistService.autoCreateChecklist(...);
    if (result.success) {
      await _rerunActionItemSuggestions(task); // Auto re-run
    }
  } finally {
    _autoCreatingTasks.remove(task.id);
  }
}
```

#### Smart Re-run System

Instead of hiding suggestions, the system automatically re-runs the AI prompt after checklist creation:

- **Automatic trigger**: After successful checklist creation, the exact same prompt that was used originally runs again
- **Context awareness**: AI recognizes items are now in the checklist and typically suggests nothing
- **Natural UX**: Users see the auto-created checklist plus minimal/empty suggestions
- **No state tracking**: No need for complex `autoChecklistCreated` field management
- **Consistent results**: Re-run uses the exact same prompt configuration, ensuring consistent behavior

#### Technical Implementation

1. **Read-Current-Write Pattern**:
   ```dart
   // Always read fresh state before updates
   Future<JournalEntity?> _getCurrentEntityState(String entityId) async {
     try {
       return await ref.read(aiInputRepositoryProvider).getEntity(entityId);
     } catch (e) {
       developer.log('Failed to get current entity state for $entityId', error: e);
       return null;
     }
   }
   ```

2. **Simple Semaphore Protection**:
   ```dart
   // Prevent concurrent auto-creation
   final Set<String> _autoCreatingTasks = {};
   
   if (_autoCreatingTasks.contains(task.id)) {
     return; // Skip if already processing
   }
   ```

3. **Automatic Re-run**:
   ```dart
   // In _handleActionItemSuggestions()
   if (result.success) {
     await _rerunActionItemSuggestions(task, promptConfig);
   }
   
   // In _rerunActionItemSuggestions()
   await _runInferenceInternal(
     entityId: task.id,
     promptConfig: originalPrompt, // Use exact same prompt as originally
     onProgress: (_) {}, // Silent re-run
     onStatusChange: (_) {},
     isRerun: true, // Prevent recursive auto-creation
   );
   ```

4. **Reliable Cleanup**:
   ```dart
   // Simple error handling with semaphore cleanup
   if (shouldAutoCreate) {
     _autoCreatingTasks.add(task.id);
     try {
       // Auto-creation and re-run logic
     } finally {
       // Always clean up semaphore, even if errors occur
       _autoCreatingTasks.remove(task.id);
     }
   }
   ```

#### Benefits

- **Eliminates manual work**: Saves up to 10 clicks (creating checklist + dragging multiple items)
- **Natural UX**: No hidden UI elements - users see logical progression
- **Simple concurrency protection**: Prevents duplicate auto-creation with minimal complexity
- **AI context awareness**: AI naturally produces fewer/no suggestions after items are in checklist
- **Seamless experience**: First-time users get immediate value from AI suggestions
- **Backwards compatible**: Existing manual flow unchanged for tasks with checklists
- **Self-healing**: System corrects duplicate suggestions through intelligent re-run
- **User change preservation**: Read-Current-Write pattern respects user modifications during AI processing
- **Single-threaded safety**: Leverages Flutter's event loop for natural concurrency handling

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
  - Task Summary
  - Action Item Suggestions
  - Image Analysis
  - Image Analysis in Task Context
  - Audio Transcription
  - Audio Transcription with Task Context
- **Custom**: Create custom prompts with variables and specific requirements

The system includes context-aware variations of prompts that activate when entities are linked to tasks, providing more relevant and focused AI responses.

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
- **`latest_ai_response_summary.dart`**: Shows the most recent AI response for a task with animated transitions
  - **Animated Transitions**: When regenerating summaries, keeps the old summary visible while showing a spinner in the header
  - **Smooth Animation**: Uses `AnimatedSize` and `AnimatedSwitcher` for fade and size transitions between old and new summaries
  - **State Preservation**: Previous response is cached to maintain UI continuity during regeneration
- **`ai_response_summary_modal.dart`**: Full-screen view of AI responses

### Progress Indicators
- **`unified_ai_progress_view.dart`**: Shows inference progress with real-time updates
- **`ai_running_animation.dart`**: Animated indicator during processing
- **`active_inference_controller.dart`**: Tracks active inferences across primary and linked entities

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

## Linked Entity Inference Tracking

The AI system supports running inferences on entities that are linked to other entities (e.g., audio transcription for an audio entry linked to a task). The system ensures both entities are aware of the running inference.

### How It Works

When an inference starts with a linked entity, the system creates **two symmetric active inference entries**:

1. **Primary Entity Entry**: For the main entity (e.g., audio) with `linkedEntityId` pointing to the linked entity (e.g., task)
2. **Linked Entity Entry**: For the linked entity with `linkedEntityId` pointing back to the primary entity

This dual-entry approach ensures:
- Both entities can track the inference status independently
- UI components can show inference indicators for both entities
- Status updates (running, error, complete) propagate to both entities
- Progress updates are visible from both entity perspectives

### Implementation

The `UnifiedAiController` uses helper methods to maintain consistency:

```dart
// Start inference for both entities
void _startActiveInference(promptId, responseType, {linkedEntityId}) {
  // Create entry for primary entity
  activeInferenceController(entityId).startInference(promptId, linkedEntityId);
  
  // Also create entry for linked entity
  if (linkedEntityId != null) {
    activeInferenceController(linkedEntityId).startInference(promptId, entityId);
  }
}

// Update status for both entities
void _updateInferenceStatus(status, responseType, {linkedEntityId}) {
  inferenceStatusController(entityId).setStatus(status);
  
  if (linkedEntityId != null) {
    inferenceStatusController(linkedEntityId).setStatus(status);
  }
}
```

### Benefits

- **No Central Registry Needed**: Each entity tracks its own involvement
- **Symmetric Design**: Both entities are treated equally
- **Simple Lookups**: Direct provider access without searching
- **Consistent Updates**: All operations (start, update, clear) follow the same pattern

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

### Q: When are task-context prompts shown in the AI menu?
A: Task-context prompts (like "Image Analysis in Task Context" or "Audio Transcription with Task Context") only appear in the AI popup menu when:
- An image/audio is linked to a task
- The prompt requires both the media type AND task context
The system automatically filters available prompts based on the current entity and its relationships, ensuring users only see relevant options.

### Q: Which AI providers are supported?
A: The system supports OpenAI, Anthropic, Google, Groq, OpenRouter, local Whisper models, and custom OpenAI-compatible endpoints.

### Q: How are errors handled?
A: Errors are wrapped in `InferenceError` objects and displayed using `AiErrorDisplay` widget with user-friendly messages.

### Q: Can I use local models?
A: Yes, by configuring a custom endpoint pointing to a local inference server (e.g., Ollama for text models, or local Whisper server for audio transcription).

### Q: How does the system handle concurrent modifications during AI processing?
A: The system uses a simple "Read-Current-Write" pattern to prevent stale data overwrites:
- **Fresh State Reading**: AI operations read current entity state immediately before making updates, not using stale captured state
- **Single-threaded Safety**: Since Flutter runs on a single-threaded event loop, true concurrent modifications aren't possible
- **User Change Preservation**: If a user modifies a task while AI is processing, AI respects the user's changes by reading fresh state before writing
- **Auto-checklist Protection**: Uses a simple `Set<String> _autoCreatingTasks` to prevent duplicate checklist creation for the same task
- **No Complex Transactions**: No database transactions or retry logic needed since conflicts are resolved by reading current state

### Q: How does the checklist completion suggestion feature work?
A: The system uses OpenAI-style function calling to detect when checklist items may have been completed:
- **Function Calling Support**: Models that support function calling (OpenAI, Anthropic, Gemini) can suggest checklist completions
- **Automatic Detection**: During audio transcriptions, task summaries, or image analysis, the AI looks for evidence of completion
- **Evidence Types**: Past tense verbs ("I finished..."), explicit statements ("That's done"), visual confirmation (screenshots)
- **Streaming Support**: Tool calls are accumulated from streaming chunks and processed after the response completes
- **Visual Indication**: Suggested items show a pulsing colored indicator (color indicates confidence level)
- **User Control**: Users can accept or dismiss suggestions with a single tap
- **High Confidence Auto-Check**: Items suggested with high confidence are automatically checked off while still showing the visual indicator
- **Smart Duplicate Prevention**: AI is instructed not to suggest completion for items that are already checked

### Q: How do I enable checklist completion suggestions?
A: To enable this feature:
1. Use a model that supports function calling (check `supportsFunctionCalling` in model settings)
2. Create or update prompts from the preconfigured templates (they now include instructions for using the function)
3. The feature works automatically when processing tasks with checklists
4. Suggestions appear as visual indicators on checklist items in the task UI

### Q: What is the add_checklist_item function?
A: The system can automatically create new checklist items based on AI analysis:
- **Automatic Detection**: AI identifies new action items or tasks mentioned in audio, text, or images
- **Smart Creation**: If no checklist exists, creates a "to-do" checklist first
- **Context Awareness**: Works during audio transcriptions, task summaries, and image analysis
- **Common Triggers**: "I need to...", "Next I'll...", "We should...", or any newly mentioned tasks

### Q: How does multilingual task summary generation work?
A: The system supports generating task summaries in 38 different languages:
- **Automatic Language Detection**: AI analyzes task content (especially audio transcripts) to detect the primary language
- **Manual Language Selection**: Users can manually set their preferred language for summaries via the task header
- **Language Persistence**: Once set (manually or automatically), the language preference is saved with the task
- **Supported Languages**: All 38 languages supported by Gemini Code Assist, including major languages like English, Spanish, Chinese, Japanese, Arabic, Hindi, and many more

## Language Support

### Overview

The AI system supports multilingual task summary generation, allowing users to receive AI-generated content in their preferred language. This feature is particularly useful for international teams and users who work in multiple languages.

### Supported Languages

The system supports all 38 languages from Gemini Code Assist:
- **European**: English (en), Spanish (es), French (fr), German (de), Italian (it), Portuguese (pt), Dutch (nl), Polish (pl), Russian (ru), Ukrainian (uk), Czech (cs), Bulgarian (bg), Croatian (hr), Danish (da), Estonian (et), Finnish (fi), Greek (el), Hungarian (hu), Latvian (lv), Lithuanian (lt), Norwegian (no), Romanian (ro), Serbian (sr), Slovak (sk), Slovenian (sl), Swedish (sv)
- **Asian**: Chinese (zh), Japanese (ja), Korean (ko), Hindi (hi), Bengali (bn), Indonesian (id), Thai (th), Vietnamese (vi), Turkish (tr)
- **Middle Eastern**: Arabic (ar), Hebrew (he)
- **African**: Swahili (sw)

### Language Detection and Setting

The system uses AI function calling to automatically detect and set task language:

```dart
// Function definition in TaskFunctions
static const String setTaskLanguage = 'set_task_language';

ChatCompletionTool(
  type: ChatCompletionToolType.function,
  function: FunctionObject(
    name: setTaskLanguage,
    description: 'Set the detected language for the task based on the content analysis',
    parameters: {
      'languageCode': {
        'type': 'string',
        'enum': ['ar', 'bn', 'bg', ...], // All 38 language codes
      },
      'confidence': {
        'type': 'string',
        'enum': ['high', 'medium', 'low'],
      },
      'reason': {
        'type': 'string',
        'description': 'Brief explanation of why this language was detected',
      },
    },
  ),
),
```

### How It Works

1. **Automatic Detection**: When generating a task summary, the AI analyzes:
   - Audio transcript languages (prioritized)
   - Text content in log entries
   - Overall task context

2. **Language Setting**: If no language is set, the AI:
   - Detects the primary language with confidence level
   - Calls `set_task_language` function
   - Updates the task with the detected language
   - Only sets language once (doesn't override existing preferences)

3. **Summary Generation**: Once a language is set:
   - System message includes language preference
   - AI generates all content in that language
   - Language preference persists for future summaries

4. **Manual Override**: Users can manually select language via:
   - Task header language widget
   - Modal with searchable language list
   - Visual country flags for easy identification

### Implementation Details

#### Data Model
```dart
// In TaskData
class TaskData {
  final String? languageCode; // ISO 639-1 code
  // ... other fields
}
```

#### System Message Enhancement
When a language preference exists, the system message is enhanced:
```dart
if (language != null) {
  systemMessage += '\n\nIMPORTANT: Generate the entire summary in ${language.name} (${language.code}). '
    'All text, headings, and content should be in this language.';
}
```

#### UI Components
- **TaskLanguageWidget**: Displays current language with flag
- **LanguageSelectionModalContent**: Searchable language selector
- **Visual Design**: Flags in rounded frames for dark mode visibility

## Technical Details

### Function Calling Implementation

The checklist completion suggestion feature uses OpenAI-compatible function calling:

```dart
// Function definition in ChecklistCompletionFunctions
static List<ChatCompletionTool> getTools() {
  return [
    const ChatCompletionTool(
      type: ChatCompletionToolType.function,
      function: FunctionObject(
        name: 'suggest_checklist_completion',
        description: 'Suggest that a checklist item should be marked as completed...',
        parameters: {
          'type': 'object',
          'properties': {
            'checklistItemId': {'type': 'string', 'description': 'The ID of the checklist item'},
            'reason': {'type': 'string', 'description': 'Why this item appears completed'},
            'confidence': {'type': 'string', 'enum': ['high', 'medium', 'low']},
          },
          'required': ['checklistItemId', 'reason', 'confidence'],
        },
      ),
    ),
  ];
}
```

**Tool Call Processing in Streaming:**
- Tool calls arrive as chunks in the streaming response
- `UnifiedAiInferenceRepository` accumulates chunks by index or ID
- **Empty ID Handling**: When the API sends multiple tool calls with empty IDs (common with some providers), the system automatically generates unique IDs (`tool_0`, `tool_1`, etc.) to prevent overwriting
- **Concatenated JSON Support**: Some providers send multiple JSON objects concatenated in a single tool call's arguments field. The system detects and parses these using regex pattern matching
- After streaming completes, tool calls are reconstructed and processed
- `ChecklistCompletionService` stores suggestions and notifies UI with visual pulsing indicators

**Model Support:**
- Models must have `supportsFunctionCalling: true` in their configuration
- Currently supported: OpenAI GPT-4, Anthropic Claude, Google Gemini
- Not supported: Local models (Ollama), Whisper (audio-only)

## Testing

The system includes comprehensive test coverage:

### Unit Tests
- **Repository Tests**: Mock tests for `AiInputRepository`, `UnifiedAiInferenceRepository`, `AiConfigRepository`
- **Service Tests**: Tests for `AutoChecklistService` including edge cases and error handling
- **Controller Tests**: Tests for `ChecklistSuggestionsController` and state management
- **Concurrency Tests**: Semaphore protection and race condition prevention
- **Language Support Tests**: 
  - Task functions schema validation for language detection
  - AI input repository language data inclusion
  - Unified AI inference repository language handling
  - Language preference persistence and override protection

### Integration Tests
- **Auto-checklist Creation**: End-to-end testing of automatic checklist creation flow
- **Smart Re-run System**: Testing of automatic re-run after checklist creation
- **Read-Current-Write Pattern**: Testing that AI respects user changes during processing
- **Concurrency Protection**: Testing simple semaphore prevents duplicate auto-creation
- **Error Handling**: Graceful failure modes and recovery

### Widget Tests
- **UI Components**: Tests for AI settings pages, response displays, and configuration management
- **Provider Integration**: Tests for Riverpod state management integration

### Key Test Coverage
- ✅ Basic auto-checklist creation functionality
- ✅ Read-Current-Write pattern prevents stale data overwrites
- ✅ Simple semaphore prevents duplicate auto-creation
- ✅ Re-run generates appropriate suggestions after checklist creation
- ✅ AI respects user modifications during processing
- ✅ Behavior when tasks already have existing checklists
- ✅ Error handling in auto-checklist service
- ✅ UI shows correct suggestions after re-run
- ✅ All existing functionality remains unbroken

## Category-Based AI Settings

The AI system integrates with the Categories feature to provide fine-grained control over which AI prompts are available for different types of content. Categories can specify allowed prompts and configure automatic prompt execution.

For detailed information about category-based AI settings, see the [Categories Feature README](../categories/README.md#ai-powered-category-settings).

## Security Considerations

- API keys are stored locally in the encrypted database
- Keys are never logged or exposed in the UI
- Network requests use HTTPS
- Sensitive data is not included in error messages