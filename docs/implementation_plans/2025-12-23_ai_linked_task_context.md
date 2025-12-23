# Implementation Plan: Enhancing AI Context with Linked Task Data

**Date**: 2025-12-23
**Status**: Implementation Complete
**Feature**: Pass linked task data (parent/child tasks) into AI prompt context

---

## Implementation Progress

| Step | Status | Notes |
|------|--------|-------|
| Data model (`AiLinkedTaskContext`) | ✅ Done | Added to `ai_input.dart` |
| Repository methods | ✅ Done | `buildLinkedFromContext()`, `buildLinkedToContext()`, `buildLinkedTasksJson()` |
| Placeholder handler | ✅ Done | `{{linked_tasks}}` in `prompt_builder_helper.dart` |
| Update `prompt_generation` | ✅ Done | Primary use case - coding prompts |
| Update `audio_transcription_task_context` | ✅ Done | |
| Update `image_analysis_task_context` | ✅ Done | |
| Update `task_summary` | ✅ Done | |
| Run `build_runner` | ✅ Done | Generated files created |
| Tests | ✅ Done | `ai_linked_task_context_test.dart` - 24 tests passing |
| Analyzer & formatter | ✅ Done | No errors |

---

## Overview

This feature enhances the AI prompt context by including distilled information about related tasks. When generating summaries or analyzing a task, the AI will receive structured data about:

- **`linked_from`** (child tasks): Tasks that reference/link TO the current task
- **`linked_to`** (parent tasks): Tasks that the current task references/links TO

This provides the AI with valuable context about the task's position in a hierarchy and related work history.

---

## Requirements Summary

### Data Structure per Linked Task
| Field | Description | Source |
|-------|-------------|--------|
| `id` | Task ID | `task.meta.id` |
| `title` | Task title | `task.data.title` |
| `status` | Current status (OPEN, IN PROGRESS, etc.) | `task.data.status.toDbString` |
| `statusSince` | ISO8601 timestamp of last status transition | `task.data.status.createdAt` |
| `priority` | Task priority (P0, P1, P2, P3) | `task.data.priority.short` |
| `estimate` | Estimated duration (HH:MM format) | `task.data.estimate` |
| `timeSpent` | Actual time tracked (HH:MM format) | Calculated from linked entries |
| `createdAt` | Task creation date | `task.meta.createdAt` |
| `labels` | List of `{id, name}` tuples | `task.meta.labelIds` → resolved |
| `languageCode` | Detected language | `task.data.languageCode` |
| `latestSummary` | Most recent AI summary (full, not truncated) | Latest `AiResponseEntry` with `type=taskSummary` |

### Prompt Engineering Requirements
1. **GitHub/External Links Highlighting**: Links are already formatted as markdown `[Title](URL)` in summaries. The prompt instructs AI to use web search for external links (GitHub PRs, Issues, etc.) when relevant.
2. **Full Summaries**: Include complete summaries (no truncation) - context is valuable.
3. **No Task Limits**: Include all linked tasks regardless of count.
4. **Chronological Ordering**: Sort both lists by task creation date (oldest first).
5. **Include All Tasks**: Tasks without summaries are included with `null` summary - metadata still provides context.
6. **All Prompt Types**: The `{{linked_tasks}}` placeholder is available to all prompt types.

### Future Optimization (Documented, Not Implemented)
- **Large Prompt Storage**: As prompt inputs grow, storing them as synced files (similar to images) rather than text in the database should be considered. This avoids bloating individual database entries.

---

## Technical Design

### 1. New Data Model: `AiLinkedTaskContext`

**File**: `lib/features/ai/model/ai_input.dart`

```dart
@freezed
abstract class AiLinkedTaskContext with _$AiLinkedTaskContext {
  const factory AiLinkedTaskContext({
    required String id,
    required String title,
    required String status,
    required DateTime statusSince,
    required String priority,  // P0, P1, P2, P3
    required String estimate,
    required String timeSpent,
    required DateTime createdAt,
    required List<Map<String, String>> labels,
    String? languageCode,
    String? latestSummary,  // Contains markdown links naturally
  }) = _AiLinkedTaskContext;

  factory AiLinkedTaskContext.fromJson(Map<String, dynamic> json) =>
      _$AiLinkedTaskContextFromJson(json);
}
```

### 2. New Repository Method: Linked Task Context Builder

**File**: `lib/features/ai/repository/ai_input_repository.dart`

Add methods to:
1. `buildLinkedFromContext(taskId)` → Child tasks (tasks linking TO this task)
2. `buildLinkedToContext(taskId)` → Parent tasks (tasks this task links TO)
3. `_buildLinkedTaskContext(task)` → Convert a Task to `AiLinkedTaskContext`
4. `_getLatestTaskSummary(taskId)` → Get most recent AI summary for a task

```dart
/// Build context for tasks linked FROM the given task (children)
/// These are tasks that reference/link TO the current task
Future<List<AiLinkedTaskContext>> buildLinkedFromContext(String taskId) async;

/// Build context for tasks linked TO by the given task (parents)
/// These are tasks that the current task references/links TO
Future<List<AiLinkedTaskContext>> buildLinkedToContext(String taskId) async;
```

### 3. New Placeholder: `{{linked_tasks}}`

**File**: `lib/features/ai/helpers/prompt_builder_helper.dart`

Add handler for `{{linked_tasks}}` placeholder that injects:

```json
{
  "linked_from": [
    {
      "id": "abc123",
      "title": "Implement login form",
      "status": "DONE",
      "statusSince": "2025-12-20T14:30:00Z",
      "priority": "P1",
      "estimate": "02:00",
      "timeSpent": "01:45",
      "createdAt": "2025-12-15T10:00:00Z",
      "labels": [{"id": "l1", "name": "frontend"}],
      "languageCode": "en",
      "latestSummary": "Implemented the login form with validation...\n\n## Links\n- [PR #123](https://github.com/org/repo/pull/123)"
    }
  ],
  "linked_to": [
    {
      "id": "xyz789",
      "title": "Authentication Epic",
      "status": "IN PROGRESS",
      "statusSince": "2025-12-01T09:00:00Z",
      "priority": "P0",
      "estimate": "40:00",
      "timeSpent": "12:30",
      "createdAt": "2025-11-15T10:00:00Z",
      "labels": [{"id": "l2", "name": "auth"}, {"id": "l3", "name": "epic"}],
      "languageCode": "en",
      "latestSummary": "Parent epic for all authentication work..."
    }
  ],
  "note": "If summaries contain links to GitHub PRs, Issues, or similar platforms, use web search to retrieve additional context when relevant."
}
```

### 4. Prompt Template Updates

**File**: `lib/features/ai/util/preconfigured_prompts.dart`

Update the following prompts to include `{{linked_tasks}}` placeholder:

| Prompt ID | Name | Why |
|-----------|------|-----|
| `prompt_generation` | Generate Coding Prompt | **Primary use case** - related task context is crucial for generating comprehensive coding prompts |
| `audio_transcription_task_context` | Audio Transcription with Task Context | Related work helps understand domain terms and context |
| `image_analysis_task_context` | Image Analysis in Task Context | Related tasks can explain what the image is about |
| `task_summary` | Task Summary | Related work history provides valuable context for summarization |

**Add to each prompt's user message:**
```
**Related Tasks:**
```json
{{linked_tasks}}
```
```

**Add instructions to system messages:**
```
## Related Tasks Context

You will receive a `linked_tasks` object containing:
- `linked_from`: Child tasks that reference this task (typically subtasks)
- `linked_to`: Parent tasks that this task references (typically epics/parent tasks)

Each linked task includes metadata (status, priority, time spent) and its latest AI summary.

**IMPORTANT**: If any linked task's summary contains URLs to GitHub (PRs, Issues), Linear, Jira, or similar platforms:
1. Note these links in your analysis
2. If relevant to understanding the current task, use web search to retrieve context from those links
3. Reference findings where applicable
```

---

## Implementation Steps

### Phase 1: Data Model & Repository (Core Logic)

| Step | File | Description |
|------|------|-------------|
| 1.1 | `lib/features/ai/model/ai_input.dart` | Add `AiLinkedTaskContext` freezed class |
| 1.2 | Run `build_runner` | Generate `.freezed.dart` and `.g.dart` files |
| 1.3 | `lib/features/ai/repository/ai_input_repository.dart` | Add `buildLinkedFromContext()` method |
| 1.4 | `lib/features/ai/repository/ai_input_repository.dart` | Add `buildLinkedToContext()` method |
| 1.5 | `lib/features/ai/repository/ai_input_repository.dart` | Add `_extractExternalLinks()` helper |
| 1.6 | `lib/features/ai/repository/ai_input_repository.dart` | Add `_getLatestTaskSummary()` helper |
| 1.7 | `lib/features/ai/repository/ai_input_repository.dart` | Add `_buildLinkedTaskContext()` to convert Task → AiLinkedTaskContext |

### Phase 2: Prompt Builder Integration

| Step | File | Description |
|------|------|-------------|
| 2.1 | `lib/features/ai/helpers/prompt_builder_helper.dart` | Add `_buildLinkedTasksJson()` method |
| 2.2 | `lib/features/ai/helpers/prompt_builder_helper.dart` | Add `{{linked_tasks}}` placeholder handler in `buildPromptWithData()` |

### Phase 3: Prompt Template Updates

| Step | File | Description |
|------|------|-------------|
| 3.1 | `lib/features/ai/util/preconfigured_prompts.dart` | Update `prompt_generation` (coding prompt) - **primary use case** |
| 3.2 | `lib/features/ai/util/preconfigured_prompts.dart` | Update `audio_transcription_task_context` |
| 3.3 | `lib/features/ai/util/preconfigured_prompts.dart` | Update `image_analysis_task_context` |
| 3.4 | `lib/features/ai/util/preconfigured_prompts.dart` | Update `task_summary` |

### Phase 4: Testing

| Step | File | Description |
|------|------|-------------|
| 4.1 | `test/features/ai/repository/ai_input_repository_test.dart` | Test `buildLinkedFromContext()` with mocked data |
| 4.2 | `test/features/ai/repository/ai_input_repository_test.dart` | Test `buildLinkedToContext()` with mocked data |
| 4.3 | `test/features/ai/repository/ai_input_repository_test.dart` | Test empty linked tasks (no links exist) |
| 4.4 | `test/features/ai/helpers/prompt_builder_helper_test.dart` | Test `{{linked_tasks}}` placeholder injection |
| 4.5 | `test/features/ai/helpers/prompt_builder_helper_test.dart` | Test with mixed linked tasks (some with summaries, some without) |

---

## Key Implementation Details

### Latest Summary Retrieval

Reuse logic from `TaskSummaryRepository` to get the most recent `AiResponseEntry` with `type == taskSummary`:

```dart
Future<String?> _getLatestTaskSummary(String taskId) async {
  final linkedEntities = await _db.getLinkedEntities(taskId);
  final summaries = linkedEntities
      .whereType<AiResponseEntry>()
      .where((e) => e.data.type == AiResponseType.taskSummary)
      .toList()
    ..sort((a, b) => b.meta.dateFrom.compareTo(a.meta.dateFrom));

  if (summaries.isEmpty) return null;

  // Return full summary (no truncation per design decision)
  return summaries.first.data.response;
}
```

### Time Spent Calculation

Reuse the existing `TaskProgressRepository` to calculate actual time spent:

```dart
final progressRepository = ref.read(taskProgressRepositoryProvider);
final progressData = await progressRepository.getTaskProgressData(id: task.id);
final durations = progressData?.$2 ?? {};
final timeSpent = progressRepository
    .getTaskProgress(durations: durations, estimate: progressData?.$1)
    .progress;
```

---

## Edge Cases & Error Handling

| Scenario | Handling |
|----------|----------|
| No linked tasks | Return empty arrays for `linked_from` and `linked_to` |
| Circular links (A→B→A) | Already prevented by UI; no additional handling needed |
| Deleted linked task | Filter out tasks with `meta.deletedAt != null` |
| No summary for linked task | Set `latestSummary` to `null`, include task anyway (metadata is still useful) |
| Very long summary | Include full summary (no truncation per design decision) |
| Large number of linked tasks | Include all (no limit per design decision) |

---

## Performance Considerations

1. **Bulk Entity Fetching**: Use `getBulkLinkedEntities()` for efficiency when fetching multiple linked tasks
2. **Lazy Loading**: Only fetch linked task details when `{{linked_tasks}}` placeholder is present in prompt
3. **Caching**: Linked task context could be cached if regenerated frequently (future optimization)

---

## Future Considerations (Not for This Implementation)

### Large Prompt Storage as Files
As prompts grow with linked task context, consider:
1. Storing full prompt inputs as synced files (similar to images)
2. Referencing these files by ID in the database
3. Benefits:
   - Reduces database row size
   - Enables better sync efficiency
   - Allows for prompt version history without bloating main storage

This should be evaluated when prompt sizes consistently exceed ~10KB.

---

## Testing Strategy

### Unit Tests (High Priority)
- `AiLinkedTaskContext` serialization/deserialization
- Empty/null handling for all fields
- Linked task retrieval (both directions)

### Integration Tests
- Full placeholder injection with mocked database
- Prompt generation with linked tasks included
- Verify JSON structure matches expected format

### Manual Testing
- Create task hierarchy (parent → child → grandchild)
- Add log entries with GitHub links to child task
- Generate summary for parent task
- Verify linked task context appears correctly

---

## Files Modified

| File | Status | Description |
|------|--------|-------------|
| `lib/features/ai/model/ai_input.dart` | ✅ Done | Added `AiLinkedTaskContext` class |
| `lib/features/ai/repository/ai_input_repository.dart` | ✅ Done | Added linked task context methods |
| `lib/features/ai/helpers/prompt_builder_helper.dart` | ✅ Done | Added `{{linked_tasks}}` handler |
| `lib/features/ai/util/preconfigured_prompts.dart` | ✅ Done | Updated 4 prompts with `{{linked_tasks}}` |
| `test/features/ai/repository/ai_linked_task_context_test.dart` | ✅ Done | Comprehensive tests (24 passing) |

---

## Approval Checklist

All design decisions approved:
- [x] Placeholder name: `{{linked_tasks}}` ✓
- [x] Summary handling: Full summary, no truncation ✓
- [x] Task limits: No limit, include all linked tasks ✓
- [x] Link handling: Links are in summary text, no separate extraction needed ✓
- [x] Tasks without summary: Include with `null` summary ✓
- [x] Supported prompt types: All prompt types ✓
- [x] Data model fields: Added `priority` field (P0-P3) ✓
- [x] **Implementation complete** ✓

---

## Notes for Implementation

1. Run `build_runner` after adding the freezed class (alert user, do not run yourself)
2. Follow existing patterns in `AiInputRepository` for consistency
3. Use `formatHhMm()` from `widgets/charts/utils.dart` for duration formatting
4. Test with both empty and populated linked task scenarios
5. Ensure analyzer passes before moving to next step
