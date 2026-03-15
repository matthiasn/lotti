# Categories Feature

This module provides a comprehensive category management system for organizing journal entries with support for AI-powered automation and content filtering.

## Overview

The Categories feature allows users to create, manage, and assign categories to their journal entries. Categories provide organizational structure and enable powerful features like AI prompt filtering and automatic content processing.

### Key Features

1. **Category Management**: Create, edit, and delete categories with custom names, colors, and icons
2. **Visual Organization**: Choose from 100 curated icons and assign colors for easy visual identification
3. **Privacy Controls**: Mark categories as private to hide them when private mode is enabled
4. **Favorites**: Mark frequently used categories as favorites for quick access
5. **AI Integration**: Configure which AI prompts are available per category
6. **Speech Dictionary**: Store domain-specific terms for improved transcription accuracy
7. **Correction Examples**: Learn from user corrections to improve AI suggestions over time

## Architecture

### Core Components

#### Models (`model/`)
- **`category_definition.dart`**: Main category data model with AI settings
- **`categories_filter.dart`**: Filtering options for category lists

#### Database (`database/`)
- **`categories_db.drift`**: Drift database schema for categories
- **`categories_repository.dart`**: Repository for CRUD operations

#### State Management (`state/`)
- **`categories_list_controller.dart`**: Manages the list of all categories
- **`category_details_controller.dart`**: Handles individual category editing
- **`categories_filter_controller.dart`**: Controls category list filtering

#### UI Components (`ui/`)
- **Pages**: List view and detail/edit pages
- **Widgets**: Reusable components for category management
  - `CategoryNameField`: Name input with validation
  - `CategoryColorPicker`: Color selection widget
  - `CategorySwitchTiles`: Privacy, active, and favorite toggles
  - `CategoryLanguageDropdown`: Language preference selector
  - `CategoryPromptSelection`: AI prompt configuration
  - `CategorySpeechDictionary`: Speech recognition dictionary editor
  - `CategoryCorrectionExamples`: Correction examples viewer with swipe-to-delete

## AI-Powered Category Settings

### Overview

Categories can now be configured with AI settings that control which prompts are available and which prompts should run automatically when certain types of content are added to entries in that category.

### Allowed AI Prompts

Each category can specify which AI prompts are available when viewing entries in that category:

```dart
class CategoryDefinition {
  // null = no prompts allowed (secure by default)
  // [] = no prompts allowed (explicit)
  // ['prompt-id-1', 'prompt-id-2'] = only specified prompts allowed
  final List<String>? allowedPromptIds;
}
```

**Use Cases:**
- **Work Category**: Only allow professional prompts (task summaries, action items)
- **Personal Category**: Allow specific personal prompts (journaling, reflection)
- **Sensitive Category**: Disable all AI processing for privacy (null or [])
- **Project Category**: Focus on specific project-related prompts

### Automatic Processing (Legacy)

The `automaticPrompts` field on `CategoryDefinition` is retained in the data model for backward
compatibility and is no longer configurable in the category detail UI. New automation setup is
profile/skill-driven on the task's agent, while legacy `automaticPrompts` data may still be read
for backward-compatibility paths. See the
[Agents README](../agents/README.md#skill-assignments) for details.

## AI Defaults (Profile & Agent Template Inheritance)

Categories can define default AI settings that are automatically inherited by new tasks created
within the category. This provides a single configuration point for teams or workflows where every
task should use the same AI profile and/or agent template.

### Default Inference Profile (`defaultProfileId`)

When set, new tasks created in the category inherit this profile ID on `TaskData.profileId`.
This immediately enables profile-driven automation (speech-to-text, image analysis) without
requiring an agent to be assigned first. The profile automation system falls back to the task's
inherited profile when no agent is present.

### Default Agent Template (`defaultTemplateId`)

When set, an agent is automatically created for new tasks in the category using this template.
The auto-assigned agent enters an `awaitingContent` state and will not execute until the task
has meaningful content: a non-empty title, non-empty body text, or at least one linked entry
with non-empty text. This prevents premature agent runs on blank tasks while still
pre-assigning the agent so it activates as soon as the user adds content.

### Configuration

Both defaults are configured in the category detail page under the **AI Defaults** section.
The profile picker uses `ProfileSelector` and the template picker uses `TemplateSelector`
(filtered to `taskAgent` templates only).

### Implementation

- `createTask()` in `create_entry.dart` looks up the category's `defaultProfileId` via
  `EntitiesCacheService` and sets it on `TaskData.profileId`.
- `autoAssignCategoryAgent()` is called from widget contexts (with `WidgetRef`) after task
  creation. It looks up `defaultTemplateId` and creates an agent via `TaskAgentService`.
- `ProfileAutomationResolver.resolveForTask()` falls back to `task.data.profileId` when
  agent-based resolution fails (via `TaskProfileLookup` callback).
- `WakeOrchestrator._shouldSkipForAwaitingContent()` checks the `awaitingContent` flag and
  skips the wake if the task has no content yet.

## Speech Dictionary

Categories can store a speech dictionary of domain-specific terms to improve transcription accuracy.

### Overview

The speech dictionary helps with:
- **Proper nouns**: Names like "Sigurðsson" or places like "Kirkjubæjarklaustur"
- **Technical terms**: Product names like "macOS", "iPhone", or "Claude Code"
- **Domain jargon**: Industry-specific terminology unique to each category

### Data Model

```dart
class CategoryDefinition {
  // List of correct spellings for speech recognition
  final List<String>? speechDictionary;
  // Example: ['macOS', 'Kirkjubæjarklaustur', 'Claude Code']
}
```

### How It Works

1. **Storage**: Terms stored as a list of strings per category
2. **Prompt Injection**: `{{speech_dictionary}}` placeholder injects terms into AI prompts
3. **Context**: Dictionary is fetched from task's category (or linked task for audio/images)
4. **Sync**: Dictionaries sync across devices via existing category sync

### Adding Terms

**From Category Settings:**
- Edit category → Speech Dictionary field
- Enter semicolon-separated terms: `macOS; iPhone; Claude Code`

**From Text Editor (Context Menu):**
- Select corrected text in QuillEditor
- Right-click or long-press → "Add to Speech Dictionary"
- Term is added to the current task's category

### Implementation

- **Widget**: `CategorySpeechDictionary` - semicolon-separated text field
- **Service**: `SpeechDictionaryService` - handles term addition with validation
- **Prompt Helper**: `PromptBuilderHelper` - injects dictionary into AI prompts
- **Context Menu**: Custom `contextMenuBuilder` in QuillEditor

### Validation

- Empty terms are rejected
- Terms are trimmed of whitespace
- Maximum term length: 50 characters
- Duplicates are allowed (user's responsibility)

## Checklist Correction Examples

Categories can store correction examples learned from user's manual edits to improve AI accuracy.

### Overview

When users manually correct a checklist item title (e.g., "test flight" → "TestFlight"), the correction is captured and stored on the category. These examples are then injected into AI prompts to teach the model domain-specific terminology and preferences.

### Data Model

```dart
class ChecklistCorrectionExample {
  final String before;     // Original text before correction
  final String after;      // Corrected text after user edit
  final DateTime? capturedAt;  // When the correction was captured
}

class CategoryDefinition {
  // List of correction examples for AI learning
  final List<ChecklistCorrectionExample>? correctionExamples;
}
```

### How It Works

1. **Capture**: When a user edits a checklist item title, the before/after pair is captured
2. **Filtering**: Trivial changes (whitespace-only, case-only on short text, duplicates) are skipped
3. **Storage**: Valid corrections are appended to the category's `correctionExamples` list
4. **Prompt Injection**: `{{correction_examples}}` placeholder injects examples into AI prompts
5. **Token Budget**: Maximum 500 examples injected; warning shown at 400+
6. **Sync**: Corrections sync across devices via existing category sync

### Smart Filtering

Not all edits are worth capturing. The service filters out:
- **No change**: Edits that result in identical text after whitespace normalization
- **Trivial case changes**: Single letter or very short texts with only case changes
- **Duplicates**: Corrections already present in the category

### Adding Corrections

Corrections are captured automatically when:
- User edits a checklist item title
- The edit represents a meaningful change
- The task is assigned to a category

### UI Components

- **Widget**: `CategoryCorrectionExamples` in category settings
- **Display**: List of before→after pairs with timestamps
- **Delete**: Swipe-to-delete individual examples
- **Warning**: Yellow banner when approaching token limit (400+ examples)

### Implementation

- **Service**: `CorrectionCaptureService` - handles capture with smart filtering
- **Notifier**: `CorrectionCaptureNotifier` - emits events for snackbar feedback
- **Controller**: `ChecklistItemController.updateTitle()` - triggers capture via `unawaited()`
- **Prompt Helper**: `PromptBuilderHelper` - injects examples into AI prompts

### Prompt Integration

Examples are injected into prompts for:
- `AiResponseType.audioTranscription` - Helps with domain-specific transcription

Format in prompt:
```
The user has made the following corrections to checklist items in this category.
Use these as guidance for correct terminology and formatting:

- "test flight" → "TestFlight"
- "mac OS" → "macOS"
- "i Phone" → "iPhone"
```

## Usage Examples

### Creating a Work Category with Limited AI Access

```dart
// Create a category for work entries
final workCategory = CategoryDefinition(
  id: 'work-123',
  name: 'Work',
  color: Colors.blue,
  isPrivate: false,
  allowedPromptIds: [
    'action-item-suggestions',
    'meeting-notes'
  ],
);
```

### Creating a Private Category with No AI

```dart
// Create a private category with no AI processing
final privateCategory = CategoryDefinition(
  id: 'private-789',
  name: 'Personal Thoughts',
  color: Colors.purple,
  isPrivate: true, // Hidden in private mode
  allowedPromptIds: [], // No AI prompts allowed (same as null)
);
```

## Benefits

### For Privacy-Conscious Users
- Complete control over which categories allow AI processing
- Ability to create AI-free zones for sensitive content
- Private mode integration for additional privacy

### For Productivity Users
- AI prompt filtering per category saves time
- Consistent content organization across entries
- Speech dictionaries improve transcription accuracy

### For Organization
- Visual categorization with colors
- Quick filtering by favorites or active status
- Language-specific processing per category

## Future Enhancements

1. **Category Templates**: Pre-configured categories for common use cases
2. **Category Analytics**: Insights into category usage
3. **Sharing**: Export/import category configurations
4. **Smart Suggestions**: AI-powered category assignment suggestions

## Technical Details

### Database Schema

Categories are stored in the `categories` table with the following key fields:
- `id`: Unique identifier
- `name`: Category name
- `color`: Hex color code
- `private`: Boolean for private mode
- `active`: Boolean for visibility in lists
- `favorite`: Boolean for quick access
- `allowed_prompt_ids`: JSON array of allowed prompt IDs
- `automatic_prompts`: JSON object mapping response types to prompt IDs (legacy — no longer exposed in UI)
- `language_code`: ISO 639-1 language code for content processing

### State Management

The feature uses Riverpod for state management with:
- `categoriesProvider`: Provides filtered list of categories
- `categoryDetailsControllerProvider`: Manages individual category editing
- `categoriesFilterControllerProvider`: Controls list filtering options

### Integration Points

1. **Journal Entries**: Categories can be assigned to any journal entry
2. **AI System**: Categories control AI prompt availability and automation
3. **Task Management**: Tasks can be categorized for better organization
4. **Search**: Categories are searchable and filterable

