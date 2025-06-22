# Journal Feature

This module provides the core journaling functionality for Lotti, managing entries, tasks, checklists, and various entity types with full-text search and synchronization capabilities.

## Overview

The Journal feature is the heart of Lotti, providing:

1. **Entry Management**: Create, edit, and organize journal entries of various types
2. **Task System**: Comprehensive task tracking with status management and checklists
3. **Rich Text Editing**: Quill-based editor with markdown support
4. **Entity Types**: Support for text, tasks, events, audio, images, and measurements
5. **Search & Filter**: Full-text search and advanced filtering capabilities
6. **Synchronization**: Cross-device sync with conflict resolution

## Architecture

### Core Components

#### Models (`model/`)
- **`entry_state.dart`**: State management for individual entries (saved/dirty states)
- **`editor_mode_enum.dart`**: Enumeration for editor states (edit, view, etc.)
- **`entry_sort_action.dart`**: Sorting options for entry lists

#### State Management (`state/`)
- **`entry_controller.dart`**: Main controller for individual journal entries
  - Manages entry lifecycle (load, edit, save)
  - Handles focus states and editor toolbar visibility
  - Coordinates with persistence layer
- **`filtered_timeline_controller.dart`**: Manages filtered views of entries
- **`entry_filter_controller.dart`**: Handles search and filter states
- **`timeline_search_controller.dart`**: Powers the search functionality

#### Repository (`repository/`)
- **`journal_repository.dart`**: Main data access layer for journal operations
  - CRUD operations for all entity types
  - Query and search functionality
  - Synchronization support

#### UI Components (`ui/`)

##### Pages
- **`entry_detail_page.dart`**: Full-screen entry view and editor
- **`infinite_journal_page.dart`**: Main journal timeline with infinite scrolling
- **`empty_scaffold.dart`**: Placeholder for empty states

##### Widgets
- **`editor/`**: Rich text editor components
  - `editor_widget.dart`: Main Quill editor implementation
  - `editor_toolbar.dart`: Formatting toolbar
  - `editor_tools.dart`: Utility functions for editor operations
  - `checklist_item_modal.dart`: Checklist management
  
- **`list_cards/`**: Entry card components for timeline
  - `journal_card.dart`: Main card wrapper
  - `entry_details.dart`: Entry metadata display
  - `entry_card_header.dart`: Header with title and status
  - `task_card_checklist.dart`: Checklist preview for tasks

- **`modals/`**: Modal dialogs
  - `save_dialog.dart`: Confirmation for unsaved changes
  - `entry_menu.dart`: Context menu for entries

## How Journal Entries Work

### 1. Entry Types

Lotti supports multiple entry types, each extending the base `JournalEntity`:

```dart
abstract class JournalEntity {
  final Metadata meta;
  final EntryText? entryText;
  final Geolocation? geolocation;
}
```

Entry types include:
- **JournalEntry**: Basic text entries
- **Task**: Entries with status, estimates, and checklists
- **JournalEvent**: Events with ratings and completion status
- **JournalAudio**: Audio recordings with transcripts
- **JournalImage**: Images with captions
- **MeasurementEntry**: Quantified data entries
- **SurveyEntry**: Survey responses
- **ChecklistItem**: Individual checklist items within tasks

### 2. Entry Controller State Management

The `EntryController` manages individual entry states using Riverpod:

```dart
@riverpod
class EntryController extends _$EntryController {
  // State includes:
  // - Entry data (loaded from database)
  // - Edit state (saved/dirty)
  // - UI state (focus, toolbar visibility)
  // - Form state (for structured data)
}
```

Key behaviors:
- **Auto-save drafts**: Changes are saved to temporary storage as you type
- **Dirty state tracking**: UI indicates unsaved changes
- **Focus management**: Editor toolbar appears on focus
- **Toolbar persistence**: Recent change - toolbar remains visible after losing focus

### 3. Rich Text Editing

The journal uses Flutter Quill for rich text editing:

```dart
// Editor state is managed through QuillController
controller = makeController(
  serializedQuill: entry.entryText?.quill,
  selection: _editorStateService.getSelection(id),
);

// Changes trigger auto-save to draft storage
controller.changes.listen((DocChange event) {
  _editorStateService.saveTempState(...);
  setDirty(value: true);
});
```

Features:
- **Rich formatting**: Bold, italic, lists, headers, etc.
- **Markdown support**: Import/export markdown text
- **Delta format**: Quill's JSON-based document format
- **Undo/redo**: Built-in history management

### 4. Task Management

Tasks extend journal entries with additional functionality:

```dart
class Task extends JournalEntity {
  final TaskData data;
  // Includes: status, estimate, checklistIds, statusHistory
}
```

Task features:
- **Status tracking**: Open, In Progress, Done, Cancelled, etc.
- **Time estimates**: Duration estimates for planning
- **Checklists**: Linked checklist items with completion tracking
- **Status history**: Full audit trail of status changes

### 5. Search and Filtering

The journal provides powerful search capabilities:

- **Full-text search**: SQLite FTS5 for fast text search
- **Entity filtering**: Filter by type, status, tags, date range
- **Smart queries**: Natural language date parsing
- **Saved filters**: Store and reuse complex filters

## Key Features

### Editor Toolbar Behavior

Recent improvement to editor toolbar visibility:
- Previously: Toolbar would hide when editor lost focus and entry wasn't dirty
- Now: Toolbar remains visible once shown, improving user experience
- Implementation: Removed conditional hiding in `focusNodeListener()`

### Auto-Save System

The journal implements a sophisticated auto-save system:
1. **Draft storage**: Changes saved to EditorStateService immediately
2. **Persistence**: Explicit save commits to database
3. **Conflict detection**: Vector clocks track concurrent edits
4. **Recovery**: Unsaved changes restored on app restart

### Checklist Management

Tasks can have associated checklists:
- **Drag-and-drop**: Reorder checklist items
- **Completion tracking**: Check off completed items
- **Nested checklists**: Checklist items can have sub-checklists
- **AI integration**: Automatic checklist creation from AI suggestions

### Category System

Entries can be organized by categories:
- **Hierarchical**: Categories support parent-child relationships
- **Color coding**: Visual distinction in timeline
- **Inheritance**: Linked entries can inherit categories
- **Batch operations**: Update categories for multiple entries

## Testing

The journal feature has comprehensive test coverage:

### Unit Tests (`test/features/journal/`)
- **State Tests**: Entry controller state management
- **Repository Tests**: Data access layer functionality
- **Model Tests**: Entity serialization and validation

### Widget Tests
- **Editor Tests**: Rich text editor functionality
- **Card Tests**: Entry card rendering and interactions
- **Modal Tests**: Dialog behavior and validation

### Integration Tests
- **Save Flow**: End-to-end entry creation and saving
- **Search Tests**: Full-text search functionality
- **Sync Tests**: Cross-device synchronization

## Usage Examples

### Creating a New Entry

```dart
// Navigate to entry creation
await beamToNamed(
  '/journal/${newId}',
  data: {'editMode': true},
);

// Entry controller automatically initializes
final controller = ref.read(
  entryControllerProvider(id: newId).notifier,
);
```

### Saving an Entry

```dart
// Save with optional parameters
await controller.save(
  title: 'Updated Title',       // For tasks
  estimate: Duration(hours: 2), // For tasks
  stopRecording: true,          // Stop time tracking
);
```

### Updating Task Status

```dart
// Update task status
await controller.updateTaskStatus('DONE');

// Status history is automatically maintained
```

### Managing Checklists

```dart
// Update checklist order
await controller.updateChecklistOrder([
  'checklist_id_1',
  'checklist_id_2',
  'checklist_id_3',
]);
```

## Common Questions

### Q: How is entry data structured?
A: Each entry has metadata (timestamps, IDs, sync info) and type-specific data. Text content is stored in the EntryText object supporting plain text, markdown, and Quill delta formats.

### Q: How does the dirty state work?
A: The controller tracks changes through the Quill controller. Any document change sets dirty=true. Saving clears the dirty state and updates the last saved timestamp.

### Q: What happens to unsaved changes?
A: Unsaved changes are stored in the EditorStateService (SQLite). If the app crashes or is closed, changes are restored when the entry is reopened.

### Q: How does category inheritance work?
A: When updating an entry's category, linked entries without a category automatically inherit the parent's category. This is useful for grouping related entries.

### Q: How does the timeline handle large datasets?
A: The InfiniteJournalPage uses lazy loading with pagination. Entries are loaded in batches as the user scrolls, with configurable page sizes.

### Q: What's the difference between starred and flagged?
A: Starred entries are user favorites for quick access. Flagged entries use the import flag for special processing or review.

## Performance Considerations

- **Lazy loading**: Entries loaded on demand in timeline
- **Text indexing**: FTS5 indexes for fast search
- **Delta compression**: Quill deltas are compact JSON
- **Image optimization**: Thumbnails generated for timeline
- **Debounced saves**: Auto-save throttled to prevent excessive writes

## Security & Privacy

- **Local first**: All data stored locally by default
- **Encryption**: Database encrypted on device
- **Private entries**: Flag for sensitive content
- **Selective sync**: Private entries can be excluded from sync
- **Audit trail**: Vector clocks track all modifications