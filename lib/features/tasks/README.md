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
5. **High Confidence Auto-Check**: 
   - Items with high confidence are automatically marked as complete
   - Visual indicator remains to show AI made the change
   - Users can still undo if needed

### Creating New Checklist Items

The AI can automatically create new checklist items based on content analysis:

1. **Automatic Detection**: AI identifies new action items from:
   - Audio recordings: "I need to...", "Next I'll...", "We should..."
   - Task summaries: Newly mentioned tasks or requirements
   - Image analysis: Visual cues suggesting new tasks
2. **Smart Checklist Creation**:
   - If no checklist exists, creates a "to-do" checklist first
   - If checklists exist, adds to the first one
3. **Common Triggers**:
   - Future tense statements about tasks
   - Action items mentioned but not in existing checklists
   - Dependencies or follow-up tasks identified by AI

### Implementation Details

The AI-powered checklist features consist of:

1. **ChecklistCompletionFunctions**: Defines OpenAI-compatible functions:
   - `suggest_checklist_completion`: For marking items as complete
   - `add_checklist_item`: For creating new checklist items
2. **ChecklistCompletionService**: Manages suggestion state and notifications
3. **ChecklistItemWithSuggestionWidget**: Provides visual indication and interaction
4. **UnifiedAiInferenceRepository**: Processes tool calls and handles:
   - High confidence auto-checking with duplicate prevention
   - Smart checklist creation when none exists
   - Adding items to existing checklists
5. **Integration Points**:
   - Audio transcription with task context
   - Task summaries
   - Action item suggestions
   - Image analysis in task context

### Requirements

To use AI-powered checklist features:
- AI model must support function calling (OpenAI, Anthropic, Gemini)
- Prompts must include instructions for using the functions (recreate from templates)
- For completion suggestions: Task must have existing checklist items
- For creating items: Works with or without existing checklists

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

## Testing AI-Powered Checklist Features

### Testing Completion Suggestions
1. Create a task with checklist items
2. Ensure you're using an AI model with function calling support
3. Record an audio note mentioning completion of specific items
4. Watch for pulsing indicators on mentioned items
5. High confidence items are auto-checked with visual indicator
6. Tap to review and accept/dismiss suggestions

### Testing New Item Creation
1. Create a task (with or without existing checklists)
2. Record audio mentioning new tasks: "I need to review the PR" or "Next I'll update the documentation"
3. AI will either:
   - Create a "to-do" checklist with the new items (if no checklists exist)
   - Add items to the first existing checklist
4. New items appear immediately in the task

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

### Example 4: Automatic Item Creation

Working on "Website Redesign" task with no checklists yet.

Record audio: "I've finished the mockups. Next I need to get client approval, then implement the responsive design, and finally set up the deployment pipeline."

Result: AI creates a "to-do" checklist with:
- [ ] Get client approval
- [ ] Implement responsive design
- [ ] Set up deployment pipeline

### Example 5: Adding to Existing Checklists

Task "API Integration" already has a "Development" checklist:
- [x] Set up authentication
- [ ] Implement endpoints
- [ ] Write tests

Record audio: "While testing, I realized we also need to add rate limiting and update the API documentation."

Result: AI adds to the existing checklist:
- [x] Set up authentication
- [ ] Implement endpoints
- [ ] Write tests
- [ ] Add rate limiting
- [ ] Update API documentation

### Handling Multiple Operations

When AI processes audio or images, it can perform multiple operations:
- **Completion Suggestions**: Multiple items can be suggested simultaneously
- **Item Creation**: Multiple new items can be added in one operation
- **Mixed Operations**: AI can both suggest completions AND create new items
- **Smart Handling**: 
  - High confidence completions are auto-checked
  - Already checked items are skipped
  - New items go to appropriate checklists
- **Edge Cases**: System handles provider quirks like empty IDs transparently

### API Provider Compatibility

The feature works with providers that may send tool calls differently:
- **OpenAI**: Standard tool call format with unique IDs
- **Anthropic**: May send multiple tool calls with empty IDs (handled automatically)
- **Google Gemini**: May concatenate multiple JSON objects in arguments (parsed correctly)

All provider quirks are handled transparently - the UI experience remains consistent.