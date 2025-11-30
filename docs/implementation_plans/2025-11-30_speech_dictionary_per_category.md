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
Use these exact spellings when you encounter words that sound similar.
Preserve the exact casing as shown (e.g., "macOS" not "MacOS", "iPhone" not "Iphone").
Terms: ["macOS", "Kirkjubæjarklaustur", "Sigurðsson", "Claude Code"]
```

**Note**: Terms are formatted as a JSON array with proper escaping for quotes and backslashes.

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

### 1. Data Model & Serialization ✅

- [x] Add `speechDictionary` field to `CategoryDefinition`
- [x] Run `build_runner` to regenerate freezed classes
- [x] Verify sync works (existing infrastructure handles automatically)

### 2. Prompt Integration ✅

- [x] Add `{{speech_dictionary}}` placeholder handling to `PromptBuilderHelper`
- [x] Update `audioTranscriptionPrompt` system message to include placeholder
- [x] Update `audioTranscriptionWithTaskContextPrompt` system message
- [x] Test placeholder injection with/without dictionary (14 tests)

### 3. Category Settings UI ✅

- [x] Add `CategorySpeechDictionary` widget
- [x] Integrate into `CategoryDetailsPage` as new form section
- [x] Wire to `CategoryDetailsController` state management
- [x] Add l10n strings for UI labels

### 4. Context Menu Integration ✅

- [x] Implement custom `contextMenuBuilder` for QuillEditor
- [x] Create "Add to Dictionary" menu item
- [x] Implement category resolution from current task context
- [x] Add confirmation dialog
- [x] Handle edge cases (no category, no selection)

### 5. Testing ✅

- [x] Unit: `PromptBuilderHelper` injects dictionary correctly (18 tests)
- [x] Unit: `SpeechDictionaryService` term addition (25 tests)
- [x] Unit: `CategoryDetailsController` speech dictionary updates (2 tests)
- [x] Widget: Dictionary editor saves/loads correctly (19 tests)
- [x] Widget: Context menu integration (1 test)
- [x] Fixed existing tests affected by new field (FakeCategoryDefinition updates)

## Decisions

1. **UI Format**: Semicolon-separated text field in settings (simple, supports bulk editing)
2. **Context Menu Scope**: Only the main Quill editor (not transcripts or title fields)
3. **Dictionary Scope**: Category-specific only (no global dictionary for now)
4. **Find-and-Replace**: Manual correction only (no automatic replacement offer)
5. **Term Validation**: Reject empty strings, limit terms to 50 characters (`kMaxTermLength`)
6. **Duplicate Handling**: Case-insensitive duplicate detection prevents adding existing terms
7. **Prompt Length**: Warning shown when >30 terms (`kDictionaryWarningThreshold`), no hard limit
8. **Context Menu**: Implement properly without fallback alternatives
9. **Category Resolution**: Disable "Add to Dictionary" when no category; show helpful message
10. **Prompt Format**: JSON array with escaping for special characters (quotes, backslashes)
11. **User Feedback**: Snackbar messages for all actionable results (success, duplicate, too long, etc.)

## Rollout

1. Implement data model and prompt integration first (highest value, no UI changes)
2. Add settings UI for manual dictionary management
3. Add context menu for in-place term addition
4. (Optional) Add find-and-replace enhancement

## Files Created/Modified

### New Files ✅

- `lib/features/categories/ui/widgets/category_speech_dictionary.dart` - Widget for editing dictionary
- `lib/features/speech/services/speech_dictionary_service.dart` - Service for adding terms (with Riverpod provider)

**Note**: Context menu logic is integrated directly into `editor_widget.dart` rather than in a separate file.

### Modified Files ✅

- `lib/classes/entity_definitions.dart` - Added `speechDictionary` field
- `lib/features/ai/util/preconfigured_prompts.dart` - Added `{{speech_dictionary}}` placeholder
- `lib/features/ai/helpers/prompt_builder_helper.dart` - Handle placeholder injection
- `lib/features/categories/ui/pages/category_details_page.dart` - Added speech dictionary section
- `lib/features/categories/state/category_details_controller.dart` - State management
- `lib/features/journal/ui/widgets/editor/editor_widget.dart` - Custom context menu with "Add to Dictionary"
- `lib/l10n/app_en.arb` - Added l10n strings (labels, hints, success/error messages)
- `lib/l10n/app_de.arb` - German translations for all new strings

### Test Files ✅

- `test/features/ai/helpers/prompt_builder_helper_speech_dictionary_test.dart` - 18 tests
- `test/features/categories/ui/widgets/category_speech_dictionary_test.dart` - 19 tests
- `test/features/categories/state/category_details_controller_test.dart` - 2 new tests (speech dictionary)
- `test/features/speech/services/speech_dictionary_service_test.dart` - 25 tests
- `test/features/journal/ui/widgets/editor/editor_widget_test.dart` - 1 new test (context menu)

### Fixed Test Files ✅

- `test/features/speech/ui/widgets/recording/audio_recording_modal_test.dart` - Added `speechDictionary` to FakeCategoryDefinition
- `test/features/speech/ui/widgets/recording/audio_recording_modal_coverage_test.dart` - Added `speechDictionary` to FakeCategoryDefinition
- `test/features/categories/ui/pages/category_details_page_test.dart` - Fixed widget count expectations
