# Automatic Image Analysis and Enhanced Task Summary Triggers

**Status**: Phase 1-3 Complete (Phase 4 deferred to separate PR)

## Implementation Progress

### Phase 1: Automatic Image Analysis Trigger ✓
- [x] 1.1 Create `AutomaticImageAnalysisTrigger` helper class
- [x] 1.2 Modify `JournalRepository.createImageEntry()` with `onCreated` callback
- [x] 1.3 Update image import functions (`importImageAssets`, `importDroppedImages`, `importPastedImages`)
- [x] 1.4 Update UI callers (drop targets, paste controller)

### Phase 2: Smart Task Summary Triggering (Core)
- [x] 2.1 Create `SmartTaskSummaryTrigger` helper class
- [x] 2.2 Add trigger in `UnifiedAiInferenceRepository._handlePostProcessing()` for image analysis completion
  - Note: Audio transcription trigger NOT added here (deferred to Phase 4) - `AutomaticPromptTrigger` handles audio with checkbox preference
- [x] 2.3 Add trigger on manual text save in entry_controller (uses linked task's category)

### Phase 3: Tests
- [x] 3.1 Unit tests for AutomaticImageAnalysisTrigger (10 tests, 100% coverage)
- [x] 3.2 Unit tests for SmartTaskSummaryTrigger (9 tests, 100% coverage)
- [ ] 3.3 Integration tests for image import (optional)

### Phase 4: Audio Modal Simplification (Future)
- [ ] 4.1 Remove task summary checkbox from audio modal
- [ ] 4.2 Remove `enableTaskSummary` from `AudioRecorderState`
- [ ] 4.3 Remove task summary handling from `AutomaticPromptTrigger`
- [ ] 4.4 Update audio modal tests

## Problem Statement

### Issue 1: Manual Image Analysis is Poor UX

When adding screenshots to a task (via drag-and-drop, paste, or import), the user must manually
trigger image analysis for each image through the AI popup menu. With 10-12 screenshots on a task,
this becomes tedious and error-prone (like missing an entry).

**Current behavior:**

1. User adds image to task
2. Image is saved but NOT analyzed
3. User must manually open AI popup and select "Analyze Image"
4. Repeat for every image

**Expected behavior:**

1. User adds image to task
2. If category has `automaticPrompts[AiResponseType.imageAnalysis]` configured, analysis runs
   automatically
3. User can continue working while analysis happens in background

### Issue 2: Task Summary Trigger UX is Confusing

The current UX for triggering task summaries is fragmented and confusing:

- Audio recording modal has a checkbox for "Enable Task Summary" that users must remember to check
- Task summary only updates after checklist modifications (via the 5-minute countdown)
- Image analysis completion does NOT trigger a task summary update
- Users often forget to enable the checkbox, missing out on automatic summaries

**Current triggers:**

- Checklist item changes (via 5-min countdown)
- Task save (title/estimate)
- Task status changes
- Task language changes

**Missing/inconsistent:**

- Image analysis completion (when linked to task) - NOT triggered
- Audio transcription completion - only if checkbox was manually enabled
- Manual text edits on linked entries - NOT triggered

### Proposed Simplified UX (Phase 4 - Deferred)

**Note:** The checkbox removal is deferred to Phase 4. Currently, audio still uses `AutomaticPromptTrigger`
with the checkbox preference. Image analysis and manual text saves use the new `SmartTaskSummaryTrigger`.

When Phase 4 is complete, the UX will use a simple rule:

**Task Summary Trigger Logic:**
1. If task **already has a summary**: schedule 5-min update (existing countdown mechanism)
2. If task **has no summary yet** AND category has automatic task summaries enabled: create first
   summary immediately

**Valid Trigger Events** (that provide meaningful content for a summary):
- Image analysis completion (linked to task)
- Audio transcription completion (linked to task)
- Manual text save in editor (linked entry with non-empty content)

**NOT a trigger** (to avoid lame first summaries):
- Just adding an empty text entry
- Creating an image without analysis
- Creating an audio without transcription

## Goals

1. ✅ Automatically trigger image analysis when images are added to task-linked entries
2. ⏳ Simplify task summary triggering - remove manual checkbox from audio modal (deferred to Phase 4)
3. ✅ Create first task summary immediately when meaningful content is added (if auto-summary enabled)
   - ✅ Image analysis completion triggers SmartTaskSummaryTrigger
   - ⏳ Audio transcription still uses checkbox via AutomaticPromptTrigger (Phase 4)
   - ✅ Manual text save triggers SmartTaskSummaryTrigger (uses task's category)
4. ✅ Update existing summaries via 5-minute countdown (existing mechanism)
5. ✅ Avoid infinite loops (AI-generated content does NOT trigger more AI)

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Image creation hook** | Callback Pattern | Simple, direct, already used elsewhere in codebase |
| **Checklist updates checkbox** | Keep it | Users retain control over auto-checklist creation |
| **Task ID lookup** | UI context + DB fallback | Reliability: try fast path first, ensure correctness |
| **Task summary checkbox removal** | Deferred (Phase 4) | Audio still uses `AutomaticPromptTrigger` with checkbox; full removal in separate PR |

## Related Implementation Plans

- [2025-11-25_task_summary_delayed_refresh.md](./2025-11-25_task_summary_delayed_refresh.md) - The
  5-minute countdown mechanism for task summaries
- [2025-10-26_auto_label_assignment_via_ai_function_calls.md](./2025-10-26_auto_label_assignment_via_ai_function_calls.md) -
  Automatic AI triggering patterns

## Current Architecture

### Image Addition Flow

All image addition paths converge at `JournalRepository.createImageEntry()`:

```
Drag-and-drop: handleDroppedMedia() → importDroppedImages() → createImageEntry()
Clipboard:     ImagePasteController.paste() → importPastedImages() → createImageEntry()
Menu import:   importImageAssets() → createImageEntry()
```

**Key files:**

- `lib/logic/image_import.dart` - Lines 48-133 (menu), 141-201 (drop), 405-452 (paste)
- `lib/features/journal/repository/journal_repository.dart` - Lines 210-245

### Automatic Prompt Triggering (Audio)

`AutomaticPromptTrigger` class handles automatic audio-related prompts:

- Audio transcription
- Checklist updates (after transcription)
- Task summary (after checklist updates)

**Key file:** `lib/features/speech/helpers/automatic_prompt_trigger.dart`

This class is called after audio recording completes from `RecorderController`.

### Category Configuration

Categories define automatic prompts via `automaticPrompts` map:

```dart
Map<AiResponseType, List<String>>? automaticPrompts
```

Supports: `audioTranscription`, `checklistUpdates`, `imageAnalysis`, `taskSummary`

**Key file:** `lib/classes/entity_definitions.dart` - Lines 133-151

### Task Summary Refresh

`DirectTaskSummaryRefreshController` manages the 5-minute countdown:

```dart
requestTaskSummaryRefresh
(
taskId) → schedules 5-min timer → triggers inference
```

**Key file:** `lib/features/ai/state/direct_task_summary_refresh_controller.dart`

## Implementation Plan

### Phase 1: Automatic Image Analysis Trigger

#### 1.1 Create Image Analysis Trigger Helper

**New file:** `lib/features/ai/helpers/automatic_image_analysis_trigger.dart`

```dart
/// Helper class to handle automatic image analysis after image import
class AutomaticImageAnalysisTrigger {
  AutomaticImageAnalysisTrigger({
    required this.ref,
    required this.loggingService,
    required this.categoryRepository,
  });

  final Ref ref;
  final LoggingService loggingService;
  final CategoryRepository categoryRepository;

  /// Triggers automatic image analysis if configured for the category
  ///
  /// Parameters:
  /// - imageEntryId: The ID of the newly created image entry
  /// - categoryId: The category of the image (from linked task or direct)
  /// - linkedTaskId: Optional task ID if image is linked to a task
  Future<void> triggerAutomaticImageAnalysis({
    required String imageEntryId,
    required String? categoryId,
    String? linkedTaskId,
  }) async {
    if (categoryId == null) return;

    try {
      final category = await categoryRepository.getCategoryById(categoryId);
      if (category?.automaticPrompts == null) return;

      final hasAutomaticImageAnalysis = category!.automaticPrompts!
          .containsKey(AiResponseType.imageAnalysis) &&
          category.automaticPrompts![AiResponseType.imageAnalysis]!.isNotEmpty;

      if (!hasAutomaticImageAnalysis) return;

      final imageAnalysisPromptIds =
      category.automaticPrompts![AiResponseType.imageAnalysis]!;

      // Get the first available prompt for the current platform
      final capabilityFilter = ref.read(promptCapabilityFilterProvider);
      final availablePrompt = await capabilityFilter.getFirstAvailablePrompt(
        imageAnalysisPromptIds,
      );

      if (availablePrompt == null) {
        loggingService.captureEvent(
          'No available image analysis prompts for current platform',
          domain: 'automatic_image_analysis_trigger',
          subDomain: 'triggerAutomaticImageAnalysis',
        );
        return;
      }

      loggingService.captureEvent(
        'Triggering automatic image analysis',
        domain: 'automatic_image_analysis_trigger',
        subDomain: 'triggerAutomaticImageAnalysis',
      );

      await ref.read(
        triggerNewInferenceProvider(
          entityId: imageEntryId,
          promptId: availablePrompt.id,
          linkedEntityId: linkedTaskId,
        ).future,
      );
    } catch (exception, stackTrace) {
      loggingService.captureException(
        exception,
        domain: 'automatic_image_analysis_trigger',
        subDomain: 'triggerAutomaticImageAnalysis',
        stackTrace: stackTrace,
      );
    }
  }
}

/// Provider for the automatic image analysis trigger helper
@riverpod
AutomaticImageAnalysisTrigger automaticImageAnalysisTrigger(Ref ref) {
  return AutomaticImageAnalysisTrigger(
    ref: ref,
    loggingService: getIt<LoggingService>(),
    categoryRepository: ref.read(categoryRepositoryProvider),
  );
}
```

#### 1.2 Modify Image Import Functions

All three image import functions need to:

1. Return the created entry ID
2. Accept a trigger parameter for automatic analysis

**Decision: Callback Pattern**

Modify `JournalRepository.createImageEntry()` to accept an optional callback:

```dart
static Future<JournalEntity?> createImageEntry(
  ImageData imageData, {
  String? linkedId,
  String? categoryId,
  void Function(JournalEntity)? onCreated,
}) async {
  // ... existing code ...

  if (onCreated != null && journalEntity != null) {
    onCreated(journalEntity);
  }

  return journalEntity;
}
```

This approach is simple, direct, and already used elsewhere in the codebase.

#### 1.3 Update Image Import Callers

**lib/logic/image_import.dart:**

```dart
Future<void> importDroppedImages({
  required DropDoneDetails data,
  String? linkedId,
  String? categoryId,
  AutomaticImageAnalysisTrigger? analysisTrigger, // NEW
}) async {
  for (final file in data.files) {
    // ... existing validation ...

    final entity = await JournalRepository.createImageEntry(
      imageData,
      linkedId: linkedId,
      categoryId: categoryId,
    );

    // NEW: Trigger automatic analysis if configured
    if (entity != null && analysisTrigger != null) {
      // Fire and forget - don't block import flow
      unawaited(
        analysisTrigger.triggerAutomaticImageAnalysis(
          imageEntryId: entity.id,
          categoryId: categoryId,
          linkedTaskId: linkedId,
        ),
      );
    }
  }
}
```

Same pattern for `importPastedImages()` and `importImageAssets()`.

#### 1.4 Update UI Callers

**lib/features/journal/ui/pages/entry_details_page.dart** (line 108-115):

```dart
DropTarget
(
onDragDone: (data) async {
final trigger = ref.read(automaticImageAnalysisTriggerProvider);
await handleDroppedMedia(
data: data,
linkedId: item.meta.id,
categoryId: item.meta.categoryId,
analysisTrigger: trigger, // NEW
);
},
// ...
)
```

**lib/features/tasks/ui/pages/task_details_page.dart** (line 109-115):

```dart
DropTarget
(
onDragDone: (data) async {
final trigger = ref.read(automaticImageAnalysisTriggerProvider);
await handleDroppedMedia(
data: data,
linkedId: task.meta.id,
categoryId: task.meta.categoryId,
analysisTrigger: trigger, // NEW
);
},
// ...
)
```

**lib/features/journal/state/image_paste_controller.dart:**

```dart
Future<void> _processPastedItem(ClipboardDataReader item,
    FileFormat format,
    String fileExtension,) {
  // ... existing code ...

  await importPastedImages(
  data: await file.readAll()
  ,
  fileExtension: fileExtension,
  linkedId: linkedFromId,
  categoryId: categoryId,
  analysisTrigger: ref.read(automaticImageAnalysisTriggerProvider), // NEW
  );
}
```

### Phase 2: Simplified Task Summary Triggering

#### 2.1 Create Smart Task Summary Trigger Helper

**New file:** `lib/features/ai/helpers/smart_task_summary_trigger.dart`

This helper encapsulates the new simplified trigger logic:

```dart
/// Smart task summary trigger with simplified UX
///
/// Logic:
/// - If task has existing summary: schedule 5-min update (existing countdown)
/// - If task has NO summary AND category has auto-summary enabled: create immediately
class SmartTaskSummaryTrigger {
  SmartTaskSummaryTrigger({
    required this.ref,
    required this.loggingService,
    required this.categoryRepository,
  });

  final Ref ref;
  final LoggingService loggingService;
  final CategoryRepository categoryRepository;

  /// Triggers task summary creation/update based on simplified logic
  ///
  /// Call this when meaningful content is added to a task:
  /// - Image analysis completion
  /// - Audio transcription completion
  /// - Manual text save (non-empty content)
  Future<void> triggerTaskSummary({
    required String taskId,
    required String? categoryId,
  }) async {
    if (categoryId == null) return;

    try {
      // Check if task already has a summary
      final latestSummary = await ref.read(
        latestSummaryControllerProvider(
          id: taskId,
          aiResponseType: AiResponseType.taskSummary,
        ).future,
      );

      final hasSummary = latestSummary != null;

      if (hasSummary) {
        // Existing summary: use 5-minute countdown mechanism
        loggingService.captureEvent(
          'Task has existing summary, scheduling 5-min update',
          domain: 'smart_task_summary_trigger',
          subDomain: 'triggerTaskSummary',
        );
        await ref
            .read(directTaskSummaryRefreshControllerProvider.notifier)
            .requestTaskSummaryRefresh(taskId);
      } else {
        // No summary yet: check if category has auto-summary enabled
        final category = await categoryRepository.getCategoryById(categoryId);
        final hasAutoSummary = category?.automaticPrompts != null &&
            category!.automaticPrompts!.containsKey(AiResponseType.taskSummary) &&
            category.automaticPrompts![AiResponseType.taskSummary]!.isNotEmpty;

        if (hasAutoSummary) {
          // Create first summary immediately
          loggingService.captureEvent(
            'No summary exists, creating first summary immediately',
            domain: 'smart_task_summary_trigger',
            subDomain: 'triggerTaskSummary',
          );

          final summaryPromptIds =
              category!.automaticPrompts![AiResponseType.taskSummary]!;

          final capabilityFilter = ref.read(promptCapabilityFilterProvider);
          final availablePrompt = await capabilityFilter.getFirstAvailablePrompt(
            summaryPromptIds,
          );

          if (availablePrompt != null) {
            await ref.read(
              triggerNewInferenceProvider(
                entityId: taskId,
                promptId: availablePrompt.id,
              ).future,
            );
          }
        } else {
          loggingService.captureEvent(
            'No summary and no auto-summary configured, skipping',
            domain: 'smart_task_summary_trigger',
            subDomain: 'triggerTaskSummary',
          );
        }
      }
    } catch (exception, stackTrace) {
      loggingService.captureException(
        exception,
        domain: 'smart_task_summary_trigger',
        subDomain: 'triggerTaskSummary',
        stackTrace: stackTrace,
      );
    }
  }
}

/// Provider for the smart task summary trigger
@riverpod
SmartTaskSummaryTrigger smartTaskSummaryTrigger(Ref ref) {
  return SmartTaskSummaryTrigger(
    ref: ref,
    loggingService: getIt<LoggingService>(),
    categoryRepository: ref.read(categoryRepositoryProvider),
  );
}
```

#### 2.2 Centralized Trigger in Unified AI Repository

Add smart task summary triggering in `UnifiedAiInferenceRepository._processCompleteResponse()`:

**lib/features/ai/repository/unified_ai_inference_repository.dart:**

```dart
case AiResponseType.imageAnalysis:
  // ... existing code to update image ...

  // NEW: Trigger smart task summary if linked to a task
  if (linkedEntityId != null) {
    final trigger = ref.read(smartTaskSummaryTriggerProvider);
    await trigger.triggerTaskSummary(
      taskId: linkedEntityId,
      categoryId: entity.meta.categoryId,
    );
  }

case AiResponseType.audioTranscription:
  // ... existing code to update audio ...

  // NEW: Trigger smart task summary if linked to a task
  // This replaces the checkbox-based approach in audio modal
  if (linkedEntityId != null) {
    final trigger = ref.read(smartTaskSummaryTriggerProvider);
    await trigger.triggerTaskSummary(
      taskId: linkedEntityId,
      categoryId: entity.meta.categoryId,
    );
  }
```

#### 2.3 Remove Task Summary Checkbox from Audio Modal

**Decision: Immediate removal of task summary checkbox only**

Remove task summary checkbox but **keep checklist updates checkbox** for user control:

- Remove `AudioRecorderState.enableTaskSummary` field
- Remove task summary checkbox from audio recording modal UI
- Remove task summary handling in `AutomaticPromptTrigger.triggerAutomaticPrompts()`
- **Keep** `enableChecklistUpdates` checkbox for user control over auto-checklist creation

The task summary is now triggered automatically via the centralized handler when transcription
completes, using the smart trigger logic:

- **Has existing summary** → schedule 5-min countdown update
- **No summary + auto-summary enabled** → create first summary immediately

**Key files to modify:**

- `lib/features/speech/state/recorder_state.dart` - Remove `enableTaskSummary` (keep `enableChecklistUpdates`)
- `lib/features/speech/ui/recorder/recording_modal.dart` - Remove task summary checkbox only
- `lib/features/speech/helpers/automatic_prompt_trigger.dart` - Remove task summary handling (keep checklist handling)

#### 2.4 Trigger on Manual Text Save (Linked Entries)

For manual text edits on linked entries, trigger smart summary when:

- Entry is linked to a task
- Entry has **non-empty** text content
- User explicitly saves via the editor

**Decision: Both approaches for task lookup** - Try UI context first, fall back to DB lookup

**lib/features/journal/state/entry_controller.dart:**

In the `save()` method, for non-task entries linked to a task:

```dart
// For non-task entries linked to a task, trigger smart summary
// Only if entry has meaningful text content (avoids lame first summaries)
if (entry is! Task) {
  // Try UI context first (if available), then fall back to DB lookup
  final linkedTaskId = _linkedTaskIdFromContext ?? await _lookupLinkedTaskId(entry.id);
  final hasNonEmptyText = entry.entryText?.plainText?.trim().isNotEmpty ?? false;

  if (linkedTaskId != null && hasNonEmptyText) {
    final trigger = ref.read(smartTaskSummaryTriggerProvider);
    await trigger.triggerTaskSummary(
      taskId: linkedTaskId,
      categoryId: entry.meta.categoryId,
    );
  }
}

/// Looks up linked task ID from entry links in database
Future<String?> _lookupLinkedTaskId(String entryId) async {
  final links = await _journalRepository.getLinksFromId(entryId);
  // Find a link where the target is a task
  for (final link in links) {
    final targetEntity = await _journalRepository.getJournalEntityById(link.toId);
    if (targetEntity is Task) {
      return targetEntity.id;
    }
  }
  return null;
}
```

**Important:** Only manually saving non-empty text triggers this. Creating an empty entry or
AI-generated content does NOT trigger (avoids lame first summaries and infinite loops).

### Phase 3: Tests

#### 3.1 Unit Tests for AutomaticImageAnalysisTrigger

**New file:** `test/features/ai/helpers/automatic_image_analysis_trigger_test.dart`

Test cases:

1. `triggers image analysis when category has automatic prompts configured`
2. `does not trigger when category has no automatic prompts`
3. `does not trigger when category has empty automatic prompts list`
4. `handles missing category gracefully`
5. `handles null categoryId gracefully`
6. `logs error when no available prompts for platform`
7. `passes linkedTaskId to inference provider`
8. `uses first available platform-compatible prompt`

#### 3.2 Unit Tests for SmartTaskSummaryTrigger

**New file:** `test/features/ai/helpers/smart_task_summary_trigger_test.dart`

Test cases:

1. `schedules 5-min update when task has existing summary`
2. `creates immediate summary when no summary exists and auto-summary enabled`
3. `does nothing when no summary exists and auto-summary not enabled`
4. `handles null categoryId gracefully`
5. `handles missing category gracefully`
6. `uses first available platform-compatible prompt for immediate summary`
7. `logs appropriate events for each code path`

#### 3.3 Integration Tests for Image Import

**Update:** `test/logic/image_import_test.dart`

Test cases:

1. `importDroppedImages triggers automatic analysis when trigger provided`
2. `importPastedImages triggers automatic analysis when trigger provided`
3. `importImageAssets triggers automatic analysis when trigger provided`
4. `automatic analysis is fire-and-forget (does not block import)`

#### 3.4 Tests for Centralized Task Summary Triggers

**Update:** `test/features/ai/repository/unified_ai_inference_repository_test.dart`

Test cases:

1. `image analysis completion triggers smart task summary when linked to task`
2. `audio transcription completion triggers smart task summary when linked to task`
3. `no summary trigger when not linked to task`

#### 3.5 Widget Tests

**Update:** `test/features/journal/ui/pages/entry_details_page_test.dart`
**Update:** `test/features/tasks/ui/pages/task_details_page_test.dart`

Test cases:

1. `dropping image on task triggers automatic analysis`
2. `pasting image on task triggers automatic analysis`

#### 3.6 Regression Tests for Removed Checkbox

**Update:** `test/features/speech/ui/recorder/recording_modal_test.dart`

Test cases:

1. `task summary checkbox is no longer shown`
2. `recording still works without task summary checkbox`

## Files to Modify

### New Files

- `lib/features/ai/helpers/automatic_image_analysis_trigger.dart`
- `lib/features/ai/helpers/smart_task_summary_trigger.dart`
- `test/features/ai/helpers/automatic_image_analysis_trigger_test.dart`
- `test/features/ai/helpers/smart_task_summary_trigger_test.dart`

### Modified Files

- `lib/logic/image_import.dart` - Add trigger parameter to import functions
- `lib/features/journal/repository/journal_repository.dart` - Add optional callback
- `lib/features/journal/state/image_paste_controller.dart` - Pass trigger
- `lib/features/journal/ui/pages/entry_details_page.dart` - Pass trigger to drop handler
- `lib/features/tasks/ui/pages/task_details_page.dart` - Pass trigger to drop handler
- `lib/features/ai/repository/unified_ai_inference_repository.dart` - Add smart trigger calls
- `lib/features/journal/state/entry_controller.dart` - Add smart trigger for manual text save
- `lib/features/speech/state/recorder_state.dart` - Remove/deprecate `enableTaskSummary`
- `lib/features/speech/ui/recorder/recording_modal.dart` - Remove task summary checkbox
- `lib/features/speech/helpers/automatic_prompt_trigger.dart` - Remove task summary handling

### Test Files

- `test/logic/image_import_test.dart`
- `test/features/ai/repository/unified_ai_inference_repository_test.dart`
- `test/features/journal/ui/pages/entry_details_page_test.dart`
- `test/features/tasks/ui/pages/task_details_page_test.dart`
- `test/features/speech/ui/recorder/recording_modal_test.dart`

## Risk Assessment

### Low Risk

- Adding new trigger helper classes
- Adding optional parameters to existing functions
- Adding tests

### Medium Risk

- Modifying image import flow - well-tested code path
- Modifying unified AI repository completion handler
- Immediate removal of task summary checkbox from audio modal (UX change)

### Mitigations

- All changes use optional parameters with defaults
- Fire-and-forget pattern ensures image import never blocks
- Comprehensive test coverage
- Use existing `requestTaskSummaryRefresh` with its 5-minute throttling
- Smart trigger logic avoids unnecessary API calls (checks for existing summary first)
- Keeping checklist updates checkbox provides user control where needed
- Task lookup uses both UI context and DB fallback for reliability

## Rollout Plan

1. Implement Phase 1 (automatic image analysis) with tests
2. Verify on local development with various image import methods
3. Implement Phase 2 (smart task summary triggers) with tests
4. Remove task summary checkbox from audio modal (immediate, keep checklist checkbox)
5. Verify complete flow: add image → analyze → update/create summary
6. PR review focusing on edge cases and error handling
7. Deploy to production

## Success Metrics

1. Images added to tasks with configured automatic prompts are analyzed without user intervention
2. First task summary is created immediately when meaningful content is added (image analysis,
   audio transcription, or manual text save)
3. Subsequent task summary updates use 5-minute countdown (existing behavior)
4. No manual checkbox clicks required for task summary functionality
5. No infinite loops or excessive API usage
6. No blocking of image import operations

## Summary

This implementation simplifies the AI automation UX by:

1. **Automatic image analysis** - When images are added to tasks with configured prompts, analysis
   runs automatically in the background

2. **Smart task summary triggers** - A unified trigger logic that:
   - Creates first summary immediately when meaningful content is added (if auto-summary enabled)
   - Schedules 5-min countdown for updates to existing summaries
   - Removes the need for manual checkbox management

3. **Meaningful content gates** - Only triggers on:
   - Image analysis completion
   - Audio transcription completion
   - Manual text save with non-empty content

4. **Avoids lame summaries** - Empty entries, raw images/audio without analysis don't trigger
   first summary creation
