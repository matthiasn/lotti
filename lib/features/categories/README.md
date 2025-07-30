# Categories Feature

This module provides a comprehensive category management system for organizing journal entries with support for AI-powered automation and content filtering.

## Overview

The Categories feature allows users to create, manage, and assign categories to their journal entries. Categories provide organizational structure and enable powerful features like AI prompt filtering and automatic content processing.

### Key Features

1. **Category Management**: Create, edit, and delete categories with custom names and colors
2. **Visual Organization**: Assign colors to categories for easy visual identification
3. **Privacy Controls**: Mark categories as private to hide them when private mode is enabled
4. **Favorites**: Mark frequently used categories as favorites for quick access
5. **AI Integration**: Configure which AI prompts are available per category
6. **Automatic Processing**: Set up automatic AI prompt execution for specific content types

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
  - `CategoryAutomaticPrompts`: Automatic prompt settings

## AI-Powered Category Settings

### Overview

Categories can now be configured with AI settings that control which prompts are available and which prompts should run automatically when certain types of content are added to entries in that category.

### Allowed AI Prompts

Each category can specify which AI prompts are available when viewing entries in that category:

```dart
class CategoryDefinition {
  // null = all prompts allowed (default)
  // [] = no prompts allowed
  // ['prompt-id-1', 'prompt-id-2'] = only specified prompts allowed
  final List<String>? allowedPromptIds;
}
```

**Use Cases:**
- **Work Category**: Only allow professional prompts (task summaries, action items)
- **Personal Category**: Allow all prompts including creative ones
- **Sensitive Category**: Disable all AI processing for privacy
- **Project Category**: Focus on specific project-related prompts

### Automatic Prompt Execution (Coming Soon)

Categories can configure prompts to run automatically when specific content is added:

```dart
class CategoryDefinition {
  final Map<String, List<String>>? automaticPrompts;
  // Example:
  // {
  //   'audioTranscription': ['task-summary', 'action-items'],
  //   'imageAnalysis': ['extract-text'],
  //   'taskSummary': ['weekly-report']
  // }
}
```

**Automatic Triggers:**
1. **Audio Transcription**: After transcribing audio, automatically run specified prompts
2. **Image Analysis**: When images are attached, automatically analyze them
3. **Task Summary**: Periodically generate summaries for tasks in the category

### Implementation Roadmap

#### Phase 1: UI and Data Model ✅
- [x] Category AI settings UI in detail page
- [x] Allowed prompts selection interface
- [x] Automatic prompts configuration
- [x] Data persistence and model updates

#### Phase 2: Prompt Filtering 🚧
- [ ] Filter AI popup menu based on category's allowed prompts
- [ ] Hide restricted prompts from the UI
- [ ] Show informative message when no prompts are allowed

#### Phase 3: Automatic Execution 🚧
- [ ] Create background service for automatic prompt execution
- [ ] Implement triggers for each response type
- [ ] Add queue management for multiple automatic prompts
- [ ] Link generated responses to source entries

#### Phase 4: User Experience 🚧
- [ ] Add processing status indicators
- [ ] Show notifications for completed automatic prompts
- [ ] Allow users to review and accept/reject automatic results
- [ ] Add settings to pause/resume automatic processing

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
    'task-summary',
    'action-item-suggestions',
    'meeting-notes'
  ],
  // No automatic prompts for manual control
  automaticPrompts: {},
);
```

### Setting Up Automatic Processing for Projects

```dart
// Create a project category with automation
final projectCategory = CategoryDefinition(
  id: 'project-456',
  name: 'App Development',
  color: Colors.green,
  allowedPromptIds: null, // All prompts allowed
  automaticPrompts: {
    'audioTranscription': [
      'task-summary',
      'action-item-suggestions'
    ],
    'imageAnalysis': [
      'extract-code',
      'ui-feedback'
    ],
  },
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
  allowedPromptIds: [], // No AI prompts allowed
  automaticPrompts: {}, // No automatic processing
);
```

## Benefits

### For Privacy-Conscious Users
- Complete control over which categories allow AI processing
- Ability to create AI-free zones for sensitive content
- Private mode integration for additional privacy

### For Productivity Users
- Automatic prompt execution saves time and effort
- Consistent processing of similar content types
- Reduced need for manual AI invocation

### For Organization
- Visual categorization with colors
- Quick filtering by favorites or active status
- Language-specific processing per category

## Future Enhancements

1. **Category Templates**: Pre-configured categories for common use cases
2. **Bulk Operations**: Apply AI prompts to all entries in a category
3. **Category Analytics**: Insights into category usage and AI processing
4. **Sharing**: Export/import category configurations
5. **Smart Suggestions**: AI-powered category assignment suggestions

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
- `automatic_prompts`: JSON object mapping response types to prompt IDs
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