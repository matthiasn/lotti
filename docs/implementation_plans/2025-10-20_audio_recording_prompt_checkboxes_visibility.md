# Audio Recording Modal — Automatic Prompt Checkboxes Visibility

## Summary

- Ensure the audio recording modal only shows automatic inference checkboxes when the selected category has at least one auto-enabled prompt for that response type.
- Hide the entire automatic prompts section when none of the types qualify.
- Rules per checkbox:
  - `Speech Recognition`: show only if the category has at least one `AudioTranscription` auto-enabled prompt.
  - `Checklist Updates`: show only when recording is linked to a task (`linkedId != null`), speech recognition is enabled, and the category has at least one `ChecklistUpdates` auto-enabled prompt.
  - `Task Summary`: show only when recording is linked to a task (`linkedId != null`), speech recognition is enabled, and the category has at least one `TaskSummary` auto-enabled prompt.

## Goals

- Align checkbox visibility strictly with category-level “automatic prompts” configuration.
- Prevent misleading toggles when no automatic prompts are configured or selected for a category.
- Keep current behavior for triggering inference after recording; only visibility changes.

## Non‑Goals

- Changing how prompts are created/edited or how automatic prompts are assigned to categories.
- Changing inference execution logic or model selection.
- Adding new prompt types or modifying `AiResponseType` semantics.

## UX and Interaction

- If no checkboxes qualify, render nothing (no placeholder spacing) for the automatic prompts section.
- Maintain current labels and layout for existing checkboxes when they are eligible.
- No additional settings surface or disabled states in this iteration.

## Architecture

1) Centralize visibility rules
   - Add a pure helper to determine what to show based on:
     - Category `automaticPrompts: Map<AiResponseType, List<String>>?`
     - Linked context (`linkedId`)
     - Current recorder state (`enableSpeechRecognition` flag)
   - New file: `lib/features/speech/helpers/automatic_prompt_visibility.dart`
     - API proposal:
       - `class AutomaticPromptVisibility { final bool speech; final bool checklist; final bool summary; }`
       - `AutomaticPromptVisibility derive({ Map<AiResponseType, List<String>>? automaticPrompts, bool hasLinkedTask, bool isSpeechRecognitionEnabled })`
     - Each flag returns true only when the category has a non-empty list for the relevant `AiResponseType` and other contextual gates pass.

2) Use the helper in the modal
   - Update `lib/features/speech/ui/widgets/recording/audio_recording_modal.dart` in `_buildAutomaticPromptOptions` to:
     - Read `categoryDetailsControllerProvider(widget.categoryId!)` and extract `automaticPrompts`.
     - Compute `hasLinkedTask = widget.linkedId != null`.
     - Compute `isSpeechRecognitionEnabled = (state.enableSpeechRecognition ?? true) && hasAudioTranscriptionPrompts`.
     - Call the helper to get `speech/checklist/summary` visibility flags.
     - Return `SizedBox.shrink()` when all three are false; otherwise render only the enabled checkboxes.

3) Optional: add stable keys for tests
   - Keys (only if needed for reliable selection in widget tests):
     - `Key('speech_recognition_checkbox')`
     - `Key('checklist_updates_checkbox')`
     - `Key('task_summary_checkbox')`

## Data Flow

- Inputs
  - Category: `categoryDetailsControllerProvider(categoryId)` → `CategoryDetailsState.category.automaticPrompts`
  - Recorder state: `audioRecorderControllerProvider` → `enableSpeechRecognition`, `linkedId`
- Visibility computation
  - Pure function returns three booleans controlling checkbox rendering.
- UI output
  - Conditional rendering of `LottiAnimatedCheckbox` components per flag; shrink entirely if none.

## i18n / Strings

- Keep existing labels as-is for this change:
  - `Speech Recognition`, `Checklist Updates`, `Task Summary`.
- Consider a follow-up to use localized names via `AiResponseTypeDisplay` for consistency.

## Accessibility

- No changes to semantics; ensure checkboxes remain focusable and labeled when rendered.
- Nothing is rendered when ineligible; no hidden-but-focusable elements.

## Testing Strategy

1) Unit tests for visibility helper
   - File: `test/features/speech/helpers/automatic_prompt_visibility_test.dart`
   - Cases:
     - `automaticPrompts == null` → all false.
     - Keys present with empty lists → all false for those types.
     - Only `AudioTranscription` non-empty → `speech == true`, others false without linked task.
     - `ChecklistUpdates` non-empty + no linked task → `checklist == false`.
     - `TaskSummary` non-empty + no linked task → `summary == false`.
     - `ChecklistUpdates`/`TaskSummary` non-empty + linked task + speech disabled → both false.
     - All three non-empty + linked task + speech enabled → all true.

2) Widget tests for modal (consolidated)
   - File: `test/features/speech/ui/widgets/recording/audio_recording_modal_test.dart`
   - Override providers to supply:
     - A category with various `automaticPrompts` shapes.
     - A seeded `AudioRecorderState` (enable speech: true/false; linkedId: present/absent).
   - Pump `AudioRecordingModalContent(categoryId: ..., linkedId: ...)` and assert presence/absence of each checkbox (by key or text).
   - Verify the entire section is not built when all flags are false.

## Performance

- Negligible; visibility is computed synchronously from small maps and booleans.
- No additional streams or rebuilds beyond the existing provider subscriptions.

## Edge Cases & Handling

- Category selected but `automaticPrompts` is empty or missing keys → nothing renders.
- Category with only transcription prompts → only `Speech Recognition` renders.
- Category with checklist/summary prompts but no linked task → hide those checkboxes.
- User toggles off speech recognition → hide dependent checkboxes immediately.
- Loading category details (category is null) → render nothing (current behavior preserved).

## Files to Modify / Add

- Add: `lib/features/speech/helpers/automatic_prompt_visibility.dart`
- Update: `lib/features/speech/ui/widgets/recording/audio_recording_modal.dart` (use helper; tighten guards)
- Add tests (consolidated for widget):
  - `test/features/speech/helpers/automatic_prompt_visibility_test.dart`
  - `test/features/speech/ui/widgets/recording/audio_recording_modal_test.dart`

## Rollout Plan

1) Implement helper with unit tests.
2) Replace inline logic in the modal with the helper; add widget tests.
3) Run `make analyze` and `make test`; ensure zero analyzer warnings.
4) Manual verification:
   - Task with no category → no checkboxes.
   - Category with no auto-enabled prompts → no checkboxes.
   - Category with only transcription → only `Speech Recognition`.
   - Category with checklist/summary + linked task + speech enabled → both shown.

## Open Questions

- Should labels be localized using `AiResponseTypeDisplay.localizedName` for consistency?
- Do we want to surface a brief hint when nothing renders (e.g., “No automatic prompts configured for this category”)? Proposed: not in this iteration.

## Implementation Checklist

- [ ] Helper returns correct booleans across edge cases
- [ ] Modal uses helper and hides section when nothing qualifies
- [ ] Widget tests cover presence/absence permutations
- [ ] `make analyze` yields zero warnings
- [ ] Manual verification across task/category permutations

## Implementation discipline

- Always ensure the analyzer has no complaints and everything compiles. Also run the formatter 
  frequently.
- Prefer running commands via the dart-mcp server.
- Only move on to adding new files when already created tests are all green.
- Write meaningful tests that actually assert on valuable information. Refrain from adding BS 
  assertions such as finding a row or whatnot. Focus on useful information.
- Aim for full coverage of every code path.
