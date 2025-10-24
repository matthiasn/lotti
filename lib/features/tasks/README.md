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
- `Task`: Main task entity with status, dates, linked checklists, and language preference
- `Checklist`: Container for checklist items
- `ChecklistItem`: Individual checklist item with completion status
- `TaskProgressState`: Tracks time spent vs. estimated
- `SupportedLanguage`: Enum of 38 supported languages for multilingual summaries

### Task Filter Persistence

The tasks tab maintains its own independent filter state:
- **Tab-Specific Storage**: Both category selections and task status filters are saved separately for the tasks tab
- **Independent Restoration**: When you restart the app, the tasks tab restores its own category and status filters
- **Task Status Scoping**: Task status filters (Open, In Progress, Done, etc.) are exclusive to the tasks tab
- **Storage Key**: Uses `TASKS_CATEGORY_FILTERS` for persistence
- **Migration Support**: Automatically migrates from legacy shared filters on first use
- **Separation of Concerns**: Category filters are per-tab, but task statuses are tasks-only

### UI Components

#### Task Details Page (`task_details_page.dart`)
The main interface for viewing and editing tasks, featuring:
- Header with title, status, category, language preference, and time tracking
- Checklists section with drag-and-drop reordering
- Linked entries timeline
- AI-powered features menu
- Auto-scroll to running timer entry when tapping the timer indicator

#### Checklist Components

**ChecklistWidget**: Displays a single checklist with:
- Expandable/collapsible header with progress indicator
- Reorderable list of checklist items
- Add new item functionality
- Delete and rename options
- Edit and Export controls in the header (edit first, then export)

##### Export and Share Checklists

- Copy as Markdown
  - Click the export icon to copy the entire checklist as GitHub‑flavored Markdown.
  - Format per line: `- [ ] Task` for incomplete, `- [x] Task` for complete.
  - Preserves item order; skips deleted items; trims and sanitizes titles.
  - Designed for pasting into Linear, GitHub, and other Markdown editors.

- Share for Messenger/Email
  - Long‑press the export icon to open the system share sheet (works on mobile and desktop/macOS). Secondary‑click/right‑click also works on desktop.
  - Format per line: `⬜ Task` (incomplete) or `✅ Task` (complete), no hyphen — optimal for chat and email clients.
  - The email subject uses the checklist title.
  - macOS share previews are system‑controlled; spacing cannot be customized.

- UX details
  - Desktop shows an export tooltip; mobile suppresses the tooltip so long‑press triggers share. Long‑press also works on desktop.
  - After the first successful copy, a one‑time SnackBar hints: “Long press to share”.

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

## Language Support

Tasks support multilingual AI-generated summaries in 38 different languages. This feature is particularly useful for:
- International teams working in different languages
- Users who record audio notes in their native language
- Tasks that involve multilingual content

### How It Works

1. **Automatic Language Detection**: When generating a task summary, the AI analyzes:
   - Language of audio transcripts (highest priority)
   - Text content in log entries
   - Overall task context

2. **Manual Language Selection**: Users can manually set their preferred language:
   - Click the language indicator in the task header
   - Search and select from 41 supported languages
   - Visual country flags for easy identification

3. **Language Persistence**: Once set (manually or automatically), the language preference:
   - Is saved with the task
   - Applies to all future AI-generated content
   - Can be changed at any time

### UI Components

**TaskLanguageWidget**: Displays in the task header
- Shows country flag when language is set
- Shows language icon placeholder when not set
- Tap to open language selection modal
- Flag in rounded frame for dark mode visibility

**LanguageSelectionModalContent**: Language selection interface
- Searchable list of 41 languages
- Country flags for visual identification
- Selected language appears at the top
- Clear option to remove language preference

### Supported Languages

All 41 languages from Gemini Code Assist are supported:
- **European**: English, Spanish, French, German, Italian, Portuguese, Dutch, Polish, Russian, Ukrainian, Czech, Bulgarian, Croatian, Danish, Estonian, Finnish, Greek, Hungarian, Latvian, Lithuanian, Norwegian, Romanian, Serbian, Slovak, Slovenian, Swedish
- **Asian**: Chinese, Japanese, Korean, Hindi, Bengali, Indonesian, Thai, Vietnamese, Turkish
- **Middle Eastern**: Arabic, Hebrew
- **African**: Swahili, Igbo, Nigerian Pidgin, Yoruba

## AI-Powered Features

### Automatic Task Summary Updates

Task summaries automatically refresh when you interact with checklists, ensuring your AI-generated summaries always reflect the current state of your task. This feature works seamlessly in the background without requiring manual refresh actions.

#### How It Works

1. **Triggered by Checklist Actions**:
   - Adding new checklist items
   - Checking or unchecking items
   - Updating item text
   - Reordering items
   - Any modification to linked checklists

2. **Smart Debouncing**: Multiple rapid changes are intelligently batched:
   - 500ms debounce timer per task
   - Prevents excessive API calls during bulk operations
   - Each task has its own timer to avoid interference

3. **Status-Aware Updates**:
   - If a summary is already being generated, waits for completion
   - Automatically retries after current generation finishes
   - No duplicate or conflicting requests

4. **Seamless Experience**:
   - Updates happen in the background
   - No manual intervention required
   - Task summary refreshes automatically
   - Progress indicators show when updates are running

#### Benefits

- **Always Current**: Task summaries reflect the latest checklist state
- **Context-Aware**: AI understands what items are completed vs. pending
- **Automatic Progress Tracking**: Summaries update to show task progress
- **No Manual Refresh**: Works automatically as you interact with checklists

#### Technical Implementation

For detailed technical information about the direct refresh mechanism, see the [AI Feature README - Direct Task Summary Refresh](../ai/README.md#direct-task-summary-refresh).

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

## Timer Indicator Auto-Scroll

When a timer is running for a task, tapping the floating timer indicator will:
1. Navigate to the task details page
2. Automatically scroll to position the running timer entry at the top of the screen
3. Works even when already viewing the task (triggers scroll again)

### Implementation

The feature uses a focus intent system:
- `TaskFocusController`: Manages scroll-to-entry intent per task
- `TaskFocusIntent`: Encapsulates the target entry ID and scroll alignment
- Intent is published when timer indicator is tapped for a task-linked timer
- Task details page listens for focus intents and triggers scroll via `Scrollable.ensureVisible`

### Technical Details

- Journal-linked timers continue to work as before (no auto-scroll)
- Uses GlobalObjectKey for each linked entry to enable scrolling
- Scroll animation duration: 300ms with easeInOut curve
- Default alignment: 0.0 (entry positioned at top of viewport)
- Intent is cleared after consumption to enable re-triggering

## State Management

The feature uses Riverpod for state management:

- `ChecklistController`: Manages individual checklist state
- `ChecklistItemController`: Manages individual item state
- `ChecklistCompletionService`: Manages AI suggestions
- `TaskProgressController`: Tracks time spent on tasks
- `TaskFocusController`: Manages scroll-to-entry focus intents

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

### Language Support Examples

#### Example 1: Automatic Language Detection from Audio

Create a task "Proyecto de migración de base de datos" and record audio in Spanish:
"He completado el análisis de la estructura actual y el diseño del nuevo esquema. Todavía necesito migrar los datos."

Result:
- AI detects Spanish language with high confidence
- Sets task language to Spanish (es)
- All future summaries are generated in Spanish

#### Example 2: Manual Language Selection

Working on "International Marketing Campaign":
1. Click the language icon in task header
2. Search for "Japanese" or scroll to find 🇯🇵
3. Select Japanese
4. All AI summaries now generate in Japanese

#### Example 3: Mixed Language Task

Task "多语言文档翻译" (Multilingual Documentation Translation) with entries in multiple languages:
- Chinese audio notes
- English text entries
- German screenshots

Result: AI detects primary language (Chinese) based on audio transcript prevalence and generates summaries in Chinese.

### Checklist Examples

#### Example 1: Audio-Based Completion Detection

Create a task "Deploy new feature" with checklist:
- [ ] Write unit tests
- [ ] Run integration tests
- [ ] Update documentation
- [ ] Deploy to staging

Record audio: "I've finished writing all the unit tests and the integration tests are passing. Still need to update the docs."

Result: The AI will suggest marking "Write unit tests" and "Run integration tests" as complete.

#### Example 2: Screenshot-Based Detection

Working on "Fix login bug" with checklist:
- [ ] Reproduce the issue
- [ ] Identify root cause
- [ ] Implement fix
- [ ] Test on multiple devices

Attach a screenshot showing successful login on different devices.

Result: The AI analyzes the image and suggests marking "Test on multiple devices" as complete.

#### Example 3: Task Summary Updates

Task "Refactor database module" with checklist:
- [ ] Analyze current structure
- [ ] Design new schema
- [ ] Migrate data
- [ ] Update API endpoints

Generate a task summary after working. If your logs mention "completed the data migration" or "finished updating all endpoints", those items will be suggested for completion.

#### Example 4: Automatic Item Creation

Working on "Website Redesign" task with no checklists yet.

Record audio: "I've finished the mockups. Next I need to get client approval, then implement the responsive design, and finally set up the deployment pipeline."

Result: AI creates a "to-do" checklist with:
- [ ] Get client approval
- [ ] Implement responsive design
- [ ] Set up deployment pipeline

#### Example 5: Adding to Existing Checklists

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
