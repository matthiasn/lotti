# Tasks Feature

The Tasks feature provides comprehensive task management with checklists, time tracking, and AI-powered assistance.

## Overview

Tasks in Lotti are structured journal entries that can contain:
- Title and description
- Status tracking (Open, In Progress, Done, etc.)
- Time estimates and actual time tracking
- Checklists with individual items
- Linked journal entries (text, images, audio)
- Categories for organization

## Key Components

### Data Models
- `Task`: Main task entity with status, dates, and linked checklists
- `Checklist`: Container for checklist items
- `ChecklistItem`: Individual checklist item with completion status
- `TaskProgressState`: Tracks time spent vs. estimated

### UI Components

#### Task Details Page (`task_details_page.dart`)
The main interface for viewing and editing tasks, featuring:
- Header with title, status, category, and time tracking
- Checklists section with drag-and-drop reordering
- Linked entries timeline
- AI-powered features menu

#### Checklist Components

**ChecklistWidget**: Displays a single checklist with:
- Expandable/collapsible header with progress indicator
- Reorderable list of checklist items
- Add new item functionality
- Delete and rename options

**ChecklistItemWidget**: Individual checklist item with:
- Checkbox for completion toggle
- Inline text editing
- Drag handle for reordering

**ChecklistItemWithSuggestionWidget**: Enhanced checklist item that supports AI-powered completion suggestions (new in 2025):
- All features of regular checklist items
- Visual indication when AI suggests completion
- Pulsing colored indicator (color indicates confidence: high/medium/low)
- Tap indicator to see AI's reasoning
- Accept or dismiss suggestions with one tap

## AI-Powered Features

### Checklist Completion Suggestions

The system uses AI function calling to intelligently suggest when checklist items might be completed:

1. **Automatic Detection**: During audio transcriptions, task summaries, or image analysis, the AI analyzes content for evidence of completion
2. **Evidence Types**:
   - Verbal statements: "I finished...", "That's done", "I've completed..."
   - Visual confirmation: Screenshots showing completed features, test results
   - Context clues: Past tense descriptions, results that imply completion
3. **Visual Feedback**: 
   - Pulsing indicator appears on suggested items
   - Color coding: Blue (high confidence), Purple (medium), Orange (low)
   - Non-intrusive: Doesn't auto-complete, just suggests
4. **User Control**:
   - Tap indicator to see why AI thinks it's complete
   - Accept to mark as done
   - Dismiss to remove suggestion

### Implementation Details

The checklist completion suggestion feature consists of:

1. **ChecklistCompletionFunctions**: Defines the OpenAI-compatible function for suggestions
2. **ChecklistCompletionService**: Manages suggestion state and notifications
3. **ChecklistItemWithSuggestionWidget**: Provides visual indication and interaction
4. **Integration Points**:
   - Audio transcription with task context
   - Task summaries
   - Action item suggestions
   - Image analysis in task context

### Requirements

To use checklist completion suggestions:
- AI model must support function calling (OpenAI, Anthropic, Gemini)
- Prompts must include instructions for using the function (recreate from templates)
- Task must have checklist items

## State Management

The feature uses Riverpod for state management:

- `ChecklistController`: Manages individual checklist state
- `ChecklistItemController`: Manages individual item state
- `ChecklistCompletionService`: Manages AI suggestions
- `TaskProgressController`: Tracks time spent on tasks

## Drag and Drop

Checklists support sophisticated drag-and-drop operations:
- Reorder items within a checklist
- Move items between different checklists
- Reorder checklists within a task
- Visual feedback during drag operations

## Best Practices

1. **Creating Tasks**: Start with a clear title and add checklists for trackable items
2. **Using AI Suggestions**: Record audio notes about your progress or paste screenshots
3. **Time Tracking**: Set realistic estimates and track actual time spent
4. **Organization**: Use categories and status updates to keep tasks organized

## Testing Checklist Completion Suggestions

1. Create a task with checklist items
2. Ensure you're using an AI model with function calling support
3. Record an audio note mentioning completion of specific items
4. Watch for pulsing indicators on mentioned items
5. Tap to review and accept/dismiss suggestions

## Usage Examples

### Example 1: Audio-Based Completion Detection

Create a task "Deploy new feature" with checklist:
- [ ] Write unit tests
- [ ] Run integration tests
- [ ] Update documentation
- [ ] Deploy to staging

Record audio: "I've finished writing all the unit tests and the integration tests are passing. Still need to update the docs."

Result: The AI will suggest marking "Write unit tests" and "Run integration tests" as complete.

### Example 2: Screenshot-Based Detection

Working on "Fix login bug" with checklist:
- [ ] Reproduce the issue
- [ ] Identify root cause
- [ ] Implement fix
- [ ] Test on multiple devices

Attach a screenshot showing successful login on different devices.

Result: The AI analyzes the image and suggests marking "Test on multiple devices" as complete.

### Example 3: Task Summary Updates

Task "Refactor database module" with checklist:
- [ ] Analyze current structure
- [ ] Design new schema
- [ ] Migrate data
- [ ] Update API endpoints

Generate a task summary after working. If your logs mention "completed the data migration" or "finished updating all endpoints", those items will be suggested for completion.

### Handling Multiple Suggestions

When multiple checklist items are mentioned in a single audio recording or task summary:
- All relevant items receive suggestions simultaneously
- Each suggestion has its own confidence level based on the clarity of evidence
- You can accept/dismiss suggestions individually
- The system handles edge cases like empty IDs from certain AI providers

### API Provider Compatibility

The feature works with providers that may send tool calls differently:
- **OpenAI**: Standard tool call format with unique IDs
- **Anthropic**: May send multiple tool calls with empty IDs (handled automatically)
- **Google Gemini**: May concatenate multiple JSON objects in arguments (parsed correctly)

All provider quirks are handled transparently - the UI experience remains consistent.