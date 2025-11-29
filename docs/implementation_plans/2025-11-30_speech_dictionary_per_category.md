# Speech Dictionary per Category

## Goals

- Improve speech recognition accuracy by providing category-specific dictionaries of correct
  spellings for names, places, technical terms, and domain-specific jargon.
- Allow users to add terms to the dictionary directly from the text editor via a context menu when
  correcting transcription errors.
- Pass dictionary terms as additional context to speech recognition prompts to guide transcription.
- Store dictionaries per category, synced across devices via the existing category sync mechanism.

## Context & Prior Work

- Speech recognition uses preconfigured prompts in `lib/features/ai/util/preconfigured_prompts.dart`
- Prompts support placeholders (e.g., `{{task}}`, `{{languageCode}}`) that are injected via
  `PromptBuilderHelper`
- Categories (`CategoryDefinition`) are synced via `SyncMessage.entityDefinition()` (last-write-wins,
  no vector clock conflict resolution currently)
- Category details page (`lib/features/categories/ui/pages/category_details_page.dart`) already has
  sections for AI model settings, automatic prompts, etc.
- Text editing uses Flutter Quill; no custom context menus currently exist in the codebase
- Transcript display uses `SelectableText` in `transcripts_list_item.dart`

## Problem Examples

- "macOS" transcribed as "MAC OS" or "Mac OS"
- Place names like "Kirkjubæjarklaustur" transcribed as "Kirkju Bear Kloster", etc.
- Customer-specific names and terminology consistently misspelled
- Technical jargon unique to specific work categories

## Proposed Data Model

Add a new optional field to `CategoryDefinition` in `lib/classes/entity_definitions.dart`:

```dart
const factory
EntityDefinition.categoryDefinition
({
// ... existing fields ...
List<String>? speechDictionary, // NEW: correct spellings for speech recognition
}) = CategoryDefinition;
```

**Storage Format**: Array of strings, where each string represents a correct term or phrase.

Examples:

- `["macOS", "Kirkjubæjarklaustur", "Sigurðsson"]`
- Multi-word terms: `["Claude Code", "Visual Studio Code"]`

**Rationale for Array over Semicolon-Separated String**:

- Enables future UI improvements (swipe-to-delete, drag-to-reorder)
- Cleaner serialization and no escaping issues
- Terms containing semicolons won't break parsing
- Editor can still display as semicolon-separated text for quick editing

## Proposed Architecture

### 1. Data Layer Changes

**File: `lib/classes/entity_definitions.dart`**

- Add `List<String>? speechDictionary` to `CategoryDefinition`

**File: `lib/database/conversions.dart`**

- No changes needed (full object is JSON-serialized in `serialized` column)

**Sync**: Dictionary syncs automatically as part of `CategoryDefinition` via existing sync
infrastructure.

### 2. Prompt Integration

**File: `lib/features/ai/util/preconfigured_prompts.dart`**

- Add new placeholder `{{speech_dictionary}}` to audio transcription prompts
- Updated system message example:

```dart

const audioTranscriptionWithTaskContextPrompt = PreconfiguredPrompt(
  // ...
  systemMessage: '''
You are a helpful AI assistant that transcribes audio content.
...

{{speech_dictionary}}
''',
);
```

**File: `lib/features/ai/helpers/prompt_builder_helper.dart`**

- Add handler for `{{speech_dictionary}}` placeholder
- Fetch category from task or linked task
- Format dictionary terms for prompt injection

Example injected text:

```
The following are correct spellings for domain-specific terms that may appear in the audio.
Use these exact spellings when you encounter words that sound similar:
macOS, Kirkjubæjarklaustur, Sigurðsson, Claude Code
```

### 3. Category Settings UI

**File: `lib/features/categories/ui/pages/category_details_page.dart`**

- Add new `LottiFormSection` for "Speech Dictionary"
- Placed after "Automatic Prompts" section

**New Widget: `lib/features/categories/ui/widgets/category_speech_dictionary.dart`**

Two interaction modes (user choice needed):

**Option A: Text Field (Semicolon-Separated)**

- Simple `TextField` showing terms as semicolon-separated list
- Easy to edit inline, copy/paste friendly
- Parse on save, join on display
- Pros: Simple, familiar, quick bulk editing
- Cons: Less visual structure

**Option B: List View with Chips**

- Each term displayed as a `Chip` or list item
- Swipe-left to delete
- "Add term" button at bottom
- Pros: Visual clarity, individual term actions
- Cons: More complex, slower for bulk entry

**Recommendation**: Start with Option A (semicolon-separated TextField) for simplicity. Can evolve
to Option B later if needed.

### 4. Context Menu in Text Editor

**Goal**: When user corrects a misspelled word in a transcript or text entry, right-click (desktop)
or long-press (mobile) shows "Add to Dictionary" option.

**Implementation Approach**:

**File: `lib/features/journal/ui/widgets/editor/editor_widget.dart`**

Flutter Quill supports custom context menus via `QuillEditorConfig.contextMenuBuilder`.

```dart
QuillEditor
(
controller: controller,
config: QuillEditorConfig(
contextMenuBuilder: (context, editableTextState) {
return _buildCustomContextMenu(context, editableTextState);
},
// ...
)
,
)
```

**Requirements**:

- Only show "Add to Dictionary" when text is selected
- Requires task context to determine category
- If task has no category, option is disabled/hidden
- On selection: prompt user to confirm the term, then append to category's `speechDictionary`

**New Files**:

- `lib/features/speech/ui/widgets/add_to_dictionary_menu_item.dart` - Menu item widget
- `lib/features/speech/repository/speech_dictionary_repository.dart` - Helper for adding terms

**Flow**:

1. User selects misspelled/corrected text
2. Right-click or long-press shows context menu with "Add to Dictionary"
3. Tap opens confirmation dialog showing selected text
4. On confirm:
  - Resolve category from current task
  - Append term to `category.speechDictionary`
  - Save category via `CategoryRepository.updateCategory()`
  - Show success snackbar

### 5. State Management

**File: `lib/features/categories/state/category_details_controller.dart`**

- Add method `updateSpeechDictionary(List<String> terms)`
- Track dirty state for dictionary changes

### 6. Find-and-Replace (Optional Enhancement)

After adding a term to the dictionary, optionally offer to replace all occurrences in the current
document.

**Flow**:

1. After confirming "Add to Dictionary"
2. Dialog: "Replace all occurrences of '[wrong]' with '[correct]' in this entry?"
3. On confirm: Use Quill controller to find/replace

**Status**: Deferred to future iteration unless explicitly requested.

## Workstreams

### 1. Data Model & Serialization

- [ ] Add `speechDictionary` field to `CategoryDefinition`
- [ ] Run `build_runner` to regenerate freezed classes
- [ ] Verify sync works (existing infrastructure handles automatically)

### 2. Prompt Integration

- [ ] Add `{{speech_dictionary}}` placeholder handling to `PromptBuilderHelper`
- [ ] Update `audioTranscriptionPrompt` system message to include placeholder
- [ ] Update `audioTranscriptionWithTaskContextPrompt` system message
- [ ] Test placeholder injection with/without dictionary

### 3. Category Settings UI

- [ ] Add `CategorySpeechDictionary` widget
- [ ] Integrate into `CategoryDetailsPage` as new form section
- [ ] Wire to `CategoryDetailsController.updateSpeechDictionary()`
- [ ] Add l10n strings for UI labels

### 4. Context Menu Integration

- [ ] Implement custom `contextMenuBuilder` for QuillEditor
- [ ] Create "Add to Dictionary" menu item
- [ ] Implement category resolution from current task context
- [ ] Add confirmation dialog
- [ ] Handle edge cases (no category, no selection)

### 5. Testing

- [ ] Unit: `PromptBuilderHelper` injects dictionary correctly
- [ ] Unit: `CategoryDetailsController` updates dictionary
- [ ] Widget: Dictionary editor saves/loads correctly
- [ ] Widget: Context menu appears with selection
- [ ] Integration: End-to-end add term flow

## Decisions

1. **UI Format**: Semicolon-separated text field in settings (simple, supports bulk editing)
2. **Context Menu Scope**: Only the main Quill editor (not transcripts or title fields)
3. **Dictionary Scope**: Category-specific only (no global dictionary for now)
4. **Find-and-Replace**: Manual correction only (no automatic replacement offer)
5. **Term Validation**: Reject empty strings, limit terms to 50 characters
6. **Duplicate Handling**: Allow duplicates (user's responsibility to manage)
7. **Prompt Length**: No artificial limits (user's responsibility)
8. **Context Menu**: Implement properly without fallback alternatives
9. **Category Resolution**: Disable "Add to Dictionary" when no category; show helpful message

## Rollout

1. Implement data model and prompt integration first (highest value, no UI changes)
2. Add settings UI for manual dictionary management
3. Add context menu for in-place term addition
4. (Optional) Add find-and-replace enhancement

## Files to Create/Modify

### New Files

- `lib/features/categories/ui/widgets/category_speech_dictionary.dart`
- `lib/features/speech/repository/speech_dictionary_repository.dart` (optional helper)
- `lib/features/journal/ui/widgets/editor/editor_context_menu.dart`

### Modified Files

- `lib/classes/entity_definitions.dart` - Add field
- `lib/features/ai/util/preconfigured_prompts.dart` - Add placeholder
- `lib/features/ai/helpers/prompt_builder_helper.dart` - Handle placeholder
- `lib/features/categories/ui/pages/category_details_page.dart` - Add section
- `lib/features/categories/state/category_details_controller.dart` - Add method
- `lib/features/journal/ui/widgets/editor/editor_widget.dart` - Add context menu
- `lib/l10n/*.arb` - Add l10n strings

### Test Files

- `test/features/ai/helpers/prompt_builder_helper_test.dart` - Dictionary injection tests
- `test/features/categories/ui/widgets/category_speech_dictionary_test.dart`
- `test/features/categories/state/category_details_controller_test.dart`
