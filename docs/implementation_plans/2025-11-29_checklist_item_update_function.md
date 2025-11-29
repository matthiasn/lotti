# Checklist Item Update Function — Status and Text Updates via AI (2025-11-29)

## Summary

- Add an AI function to update existing checklist items by ID, supporting both status changes
  (`isChecked`) and text updates (title corrections).
- Primary use case: When a user mentions completing a task in voice input (e.g., "I went to the
  supermarket and bought the dog food"), the AI can mark the corresponding checklist item as done.
- Secondary use case: Correct common transcription errors in checklist item titles (e.g., "mac OS"
  → "macOS", "i Phone" → "iPhone").
- Requires a new function definition, handler, prompt updates, and tests.

## Problem

Currently, the AI has two checklist-related modification capabilities:

1. `add_multiple_checklist_items` — Creates new items with `{ title, isChecked? }`
2. `complete_checklist_items` — Marks existing items as completed by ID only (no text updates)

There is no way for the AI to:

- Update the text/title of an existing checklist item
- Partially update an item (e.g., fix spelling without changing status)
- Uncheck an item that was incorrectly marked as done

The existing `complete_checklist_items` function is "fire and forget" — it can only set
`isChecked: true` and cannot modify the title or revert the checked status.

## Goals

- Provide a single function `update_checklist_items` that accepts an array of updates, each
  containing:
  - `id` (required): The checklist item ID to update
  - `isChecked` (optional): New checked status (true/false)
  - `title` (optional): Updated title text
- At least one of `isChecked` or `title` must be provided per update.
- Replace the existing `complete_checklist_items` function entirely with the new unified function.
- Update prompts to guide the AI on when to use the update function vs. create function.
- Ensure robust validation: item must exist, must belong to task's checklists, and at least one
  field must change.
- Return structured results showing which items were updated vs. skipped.

## Non-Goals

- Building a "spelling correction library" or template system for common transcription fixes (future
  enhancement).
- Automatic spelling correction without AI involvement.
- Bulk title normalization across all tasks (this is per-invocation, context-aware).
- UI for manual inline editing (already exists; this is AI-driven only).

## Use Cases

### Primary: Status Update from Voice Context

User voice input: "Okay, so I went to the store and picked up the dog food, also grabbed some milk."

Existing checklist items on task:

- [ ] Buy dog food
- [ ] Get milk
- [ ] Call the vet

Expected AI behavior: Call `update_checklist_items` with:

```json
{
  "items": [
    {
      "id": "item-uuid-1",
      "isChecked": true
    },
    {
      "id": "item-uuid-2",
      "isChecked": true
    }
  ]
}
```

### Secondary: Spelling/Formatting Corrections

User voice input: "I need to update the mac OS settings..."

Existing checklist item: "Update mac OS preferences" (transcription error)

Expected AI behavior: Call `update_checklist_items` with:

```json
{
  "items": [
    {
      "id": "item-uuid-3",
      "title": "Update macOS preferences"
    }
  ]
}
```

### Combined: Status + Title Update

User voice input: "Done with the i Phone setup, it's actually iPhone 15 Pro."

Existing checklist item: "i Phone setup" (transcription error, unchecked)

Expected AI behavior:

```json
{
  "items": [
    {
      "id": "item-uuid-4",
      "isChecked": true,
      "title": "iPhone 15 Pro setup"
    }
  ]
}
```

## Design Options

### Option A: New Separate Function (Recommended)

Create `update_checklist_items` as a distinct function from `complete_checklist_items`.

**Pros:**

- Clear separation of concerns
- Backward compatible — existing `complete_checklist_items` continues to work
- Easier to teach models via separate tool descriptions
- Can have different validation rules (update requires existing item; complete is more lenient)

**Cons:**

- Two functions for related operations
- Models might be confused about when to use which

### Option B: Extend `complete_checklist_items`

Add optional `title` field to the existing function and rename to `update_checklist_items`.

**Pros:**

- Single function for all modifications
- Simpler tool surface for models

**Cons:**

- Breaking change if models rely on existing behavior
- Function name (`complete_...`) becomes misleading if used for unchecking or title-only updates

### Option C: Replace with Unified Function

Deprecate `complete_checklist_items` entirely, replace with `update_checklist_items`.

**Pros:**

- Clean slate, no legacy baggage
- Single source of truth for item modifications

**Cons:**

- Must update all prompts and tool exposure sites
- Risk of regression during transition

## Function Schema

```dart
const ChatCompletionTool(
  type: ChatCompletionToolType.function,
  function: FunctionObject(
    name: 'update_checklist_items',
    description:
        'Update one or more existing checklist items. Use to mark items as done/undone or to '
        'correct titles (e.g., fix transcription errors like "mac OS" → "macOS"). '
        'Each update requires the item ID and at least one field to change.',
    parameters: {
      'type': 'object',
      'properties': {
        'items': {
          'type': 'array',
          'minItems': 1,
          'maxItems': 20,
          'items': {
            'type': 'object',
            'properties': {
              'id': {
                'type': 'string',
                'description': 'The ID of the checklist item to update',
              },
              'isChecked': {
                'type': 'boolean',
                'description':
                    'New checked status. Set true when user indicates completion, '
                    'false to uncheck if user explicitly says to uncheck.',
              },
              'title': {
                'type': 'string',
                'minLength': 1,
                'maxLength': 400,
                'description':
                    'Updated title text. Use to fix transcription errors or clarify wording.',
              },
            },
            'required': ['id'],
          },
          'description':
              'Array of updates. Each must have id and at least one of isChecked or title.',
        },
      },
      'required': ['items'],
    },
  ),
),
```

## Handler Design

### New Handler: `LottiChecklistUpdateHandler`

```dart
class LottiChecklistUpdateHandler extends FunctionHandler {
  LottiChecklistUpdateHandler({
    required this.task,
    required this.checklistRepository,
    this.onTaskUpdated,
  });

  final Task task;
  final ChecklistRepository checklistRepository;
  final void Function(Task)? onTaskUpdated;

  @override
  String get functionName => 'update_checklist_items';

  @override
  FunctionCallResult processFunctionCall(ChatCompletionMessageToolCall call) {
    // 1. Validate function name
    // 2. Parse JSON arguments
    // 3. Validate items array (non-empty, each has id + at least one update field)
    // 4. Return validated items for execution
  }

  Future<UpdateResult> executeUpdates(FunctionCallResult result) async {
    // 1. For each item:
    //    a. Verify item exists in DB
    //    b. Verify item belongs to task's checklists
    //    c. Apply updates via checklistRepository.updateChecklistItem()
    // 2. Return { updated: [...], skipped: [...], errors: [...] }
  }
}
```

### Validation Rules

1. **Item existence**: Item ID must resolve to a `ChecklistItem` entity
2. **Task ownership**: Item must be linked to one of the task's checklists
3. **Change detection**: At least one of `isChecked` or `title` must differ from current value
4. **Title constraints**: If provided, title must be 1-400 chars after normalization
5. **Whitespace normalization**: Trim leading/trailing whitespace and collapse multiple internal
   spaces to single spaces
6. **Batch size**: Max 20 items per call (consistent with other batch functions)

### Return Value

```json
{
  "updatedItems": [
    {
      "id": "...",
      "title": "...",
      "isChecked": true,
      "changes": [
        "isChecked"
      ]
    }
  ],
  "skippedItems": [
    {
      "id": "...",
      "reason": "Item not found"
    },
    {
      "id": "...",
      "reason": "No changes detected"
    }
  ]
}
```

## Prompt Updates

### System Message Addition (Checklist Updates Prompt)

Add to the existing checklist updates system message:

```
## Updating Existing Items

When the user indicates they have completed a task, use `update_checklist_items` to mark
matching checklist items as done.

- **Marking complete**: When the user says "I did X" or "X is done", find the matching checklist
  item and set `isChecked: true`.
- **Unchecking**: When the user explicitly says to uncheck an item (e.g., "actually I didn't do X"
  or "uncheck X"), set `isChecked: false`.
- **Title corrections**: Only fix transcription errors when the user explicitly mentions or
  references the item, or some obvious common fixes, these include:
  - "mac OS" → "macOS"
  - "i Phone" → "iPhone"
  - "git hub" → "GitHub"
  - "test flight" → "TestFlight"
  - Capitalization fixes for proper nouns
- **Combined updates**: You can update both status and title in a single call.

Do NOT proactively fix spelling errors in items the user has not mentioned.
Do NOT create new items for tasks that already exist in the checklist; update the existing ones
instead.
```

### Tool Exposure

The `update_checklist_items` function is exposed in the same contexts as the old
`complete_checklist_items`:

- Checklist Updates prompt
- Task Summary prompt (when function calling is enabled)
- Audio transcription with task context

## Code Touchpoints

### New Files

- `lib/features/ai/functions/lotti_checklist_update_handler.dart` — Handler implementation

### Modified Files

- `lib/features/ai/functions/checklist_completion_functions.dart` — Replace `complete_checklist_items`
  with `update_checklist_items` schema
- `lib/features/ai/functions/checklist_tool_selector.dart` — Update tool selection to use new function
- `lib/features/ai/repository/unified_ai_inference_repository.dart` — Tool injection points
- `lib/features/ai/functions/lotti_conversation_processor.dart` — Handler registration (replace
  completion handler with update handler)
- `lib/features/ai/util/preconfigured_prompts.dart` — Prompt updates for update guidance
- `lib/features/ai/README.md` — Documentation updates

### Removed Files

- Handler for `complete_checklist_items` (functionality absorbed into new update handler)

### Repository Method

The existing `ChecklistRepository.updateChecklistItem()` already supports both `isChecked` and
`title` updates via `ChecklistItemData`. No repository changes needed.

```dart
// Existing method signature (already supports our needs)
Future<bool> updateChecklistItem({
  required String checklistItemId,
  required ChecklistItemData data,
  required String? taskId,
})
```

## Tests

### Unit Tests

- `test/features/ai/functions/lotti_checklist_update_handler_test.dart`
  - Valid update with isChecked: true (marking complete)
  - Valid update with isChecked: false (unchecking)
  - Valid update with title only
  - Valid update with both fields
  - Whitespace normalization: "  foo   bar  " → "foo bar"
  - Rejects empty items array
  - Rejects item without id
  - Rejects item without any update field
  - Rejects title exceeding 400 chars after normalization
  - Handles non-existent item ID gracefully
  - Handles item not belonging to task
  - Skips items with no actual changes
  - Batch of mixed valid/invalid items
  - Max batch size enforcement (20)

### Integration Tests

- `test/features/ai/functions/lotti_conversation_processor_checklist_update_test.dart`
  - Full conversation flow: user mentions completion → AI calls update → item is checked
  - Spelling correction flow: AI detects error → calls update → title is fixed
  - Error recovery: invalid ID → retry prompt → successful update

### Prompt Tests

- `test/features/ai/util/preconfigured_prompts_test.dart`
  - Verify update guidance present in system message
  - Verify example corrections mentioned

## Implementation Plan

**Important**: Use MCP tools (`mcp__dart-mcp-local__run_tests`, `mcp__dart-mcp-local__analyze_files`,
`mcp__dart-mcp-local__dart_format`, `mcp__dart-mcp-local__dart_fix`) for all validation steps.
Run analyzer, formatter, and relevant tests after each step — do not batch validation to the end.

### Phase 1: Core Function and Handler

1. Replace `complete_checklist_items` schema with `update_checklist_items` in
   `checklist_completion_functions.dart`
   - Run: `dart_format`, `analyze_files`
   - Run: existing schema tests

2. Create `LottiChecklistUpdateHandler` with validation logic
   - Run: `dart_format`, `analyze_files`

3. Write comprehensive unit tests for handler (target ~100% handler coverage)
   - Run: `run_tests` for new handler tests
   - Run: `analyze_files`

4. Replace completion handler with update handler in `lotti_conversation_processor.dart`
   - Run: `dart_format`, `analyze_files`
   - Run: `run_tests` for conversation processor tests

### Phase 2: Integration

5. Update tool selector to use new function (remove references to `complete_checklist_items`)
   - Run: `dart_format`, `analyze_files`
   - Run: `run_tests` for tool selector tests

6. Update tool injection in `unified_ai_inference_repository.dart`
   - Run: `dart_format`, `analyze_files`
   - Run: `run_tests` for repository tests

7. Write integration tests for full conversation flow
   - Run: `run_tests` for integration tests
   - Run: `analyze_files`

8. Remove old completion handler code
   - Run: `dart_format`, `dart_fix`, `analyze_files`
   - Run: `run_tests` (full AI feature tests to catch any regressions)

### Phase 3: Prompts and Documentation

9. Update `preconfigured_prompts.dart` with update guidance
   - Run: `dart_format`, `analyze_files`
   - Run: `run_tests` for prompt tests

10. Update `lib/features/ai/README.md`
    - No code validation needed

11. Update/add prompt tests to verify new guidance
    - Run: `run_tests` for prompt tests
    - Run: `analyze_files`

### Phase 4: Final Validation

12. Run `dart_fix` to apply any automatic fixes
13. Run `dart_format` on all modified files
14. Run `analyze_files` — must have zero warnings
15. Run full test suite via `run_tests` — all tests must pass
16. Verify test coverage is close to 100% for new code
17. Manual testing with voice input

## Risks & Mitigations

### Risk: Model Confusion Between Create and Update

Models might call `add_multiple_checklist_items` when they should call `update_checklist_items`.

**Mitigation:**

- Clear, distinct function descriptions
- Prompt guidance emphasizing "update existing" vs. "create new"
- Validation in create handler could warn if title closely matches existing item

### Risk: Unintended Title Changes

Model might "improve" titles that the user intentionally wrote a certain way.

**Mitigation:**

- Conservative prompt guidance: only fix obvious transcription errors
- Require explicit user mention for significant rewording
- Return detailed change log so user sees what was modified

### Risk: Race Conditions with Concurrent Edits

User might be editing an item in the UI while AI is updating it.

**Mitigation:**

- Use existing repository pattern (read-current-write)
- Last write wins (consistent with existing behavior)
- Task summary refresh triggers on completion show final state

## Acceptance Criteria

### Functional

- [x] New `update_checklist_items` function exposed to AI with correct schema
- [x] Handler validates all inputs and provides helpful error messages
- [x] Status updates (`isChecked`) work for both checking and unchecking
- [x] Title updates work and respect character limits (400 chars after normalization)
- [x] Whitespace normalization applied to titles (trim + collapse internal spaces)
- [x] Combined updates (status + title) work in single call
- [x] Items not belonging to task are rejected with clear reason
- [x] Return value shows which items were updated vs. skipped
- [x] Prompts guide AI on when to use update vs. create
- [x] Task summary refresh triggers after updates
- [x] Old `complete_checklist_items` function fully removed

### Quality Gates (enforced via MCP tools)

- [x] `mcp__dart-mcp-local__analyze_files` — zero warnings
- [x] `mcp__dart-mcp-local__dart_format` — all code formatted
- [x] `mcp__dart-mcp-local__run_tests` — all tests pass
- [x] Test coverage close to 100% for new handler code (46 unit tests for handler)
- [x] Validation run after each implementation step, not batched

## Decisions

1. **Function design**: Replace `complete_checklist_items` entirely with `update_checklist_items`.
   No backward compatibility shim — clean replacement. This gives us a single unified function for
   all checklist item modifications instead of separate functions for completion vs. updates.

2. **Spelling corrections**: Reactive only. The AI only fixes transcription errors (e.g., "mac OS"
   → "macOS", "test flight" → "TestFlight") when the user explicitly mentions or references the
   item. No proactive corrections to avoid unwanted changes to items the user hasn't touched.

3. **Provider exposure**: Universal. The function is exposed to all AI providers without gating.
   Unlike `add_multiple_checklist_items` which has provider-specific logic for GPT-OSS models,
   updates work uniformly across all providers.

4. **Unchecking support**: Allowed when explicitly requested. Users can say "actually I didn't do X"
   or "uncheck X" and the AI will set `isChecked: false`. This supports correcting mistakes without
   requiring manual UI interaction.

5. **Reason field**: Omitted from schema. Reduces complexity and token usage. The update context is
   already clear from the conversation, and we don't need the AI to justify each change.

6. **Whitespace handling**: Normalize all. Trim leading/trailing whitespace and collapse multiple
   internal spaces to single spaces (e.g., `"  foo   bar  "` → `"foo bar"`). Ensures consistent
   formatting regardless of transcription quirks.

## Related

- `docs/implementation_plans/2025-11-06_checklist_multi_create_array_only_unification.md`
- `docs/implementation_plans/2025-10-28_checklist_item_parsing_hardening.md`
- `lib/features/ai/functions/checklist_completion_functions.dart`
- `lib/features/tasks/repository/checklist_repository.dart`

## Status

- [x] Ready for implementation
- [x] Implementation completed (2025-11-29)

### Summary of Implementation

All phases completed successfully:

1. **Phase 1 (Core)**: Created `LottiChecklistUpdateHandler` with 46 comprehensive unit tests
2. **Phase 2 (Integration)**: Updated conversation processor, tool selector, and repository
3. **Phase 3 (Prompts)**: Updated `preconfigured_prompts.dart` with update guidance
4. **Phase 4 (Validation)**: All tests pass (70 tests for related files), analyzer clean, code formatted

### Files Modified

- `lib/features/ai/functions/checklist_completion_functions.dart` - New `update_checklist_items` schema
- `lib/features/ai/functions/lotti_checklist_update_handler.dart` - **New file** - Handler implementation
- `lib/features/ai/functions/lotti_conversation_processor.dart` - Uses new handler
- `lib/features/ai/functions/checklist_tool_selector.dart` - Updated tool references
- `lib/features/ai/repository/unified_ai_inference_repository.dart` - Updated tool injection
- `lib/features/ai/util/preconfigured_prompts.dart` - Added update guidance
- `lib/features/ai/README.md` - Documentation updated
- `test/features/ai/functions/lotti_checklist_update_handler_test.dart` - **New file** - 46 tests
- `test/features/ai/functions/checklist_completion_functions_test.dart` - Updated test
- `test/features/ai/functions/lotti_conversation_processor_test.dart` - Updated tests
- `test/features/ai/util/preconfigured_prompts_test.dart` - Added update guidance test
