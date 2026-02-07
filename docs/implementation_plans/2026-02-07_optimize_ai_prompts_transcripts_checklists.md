# Optimize AI Prompts for Transcripts and Snappy Checklist Generation

**Date:** 2026-02-07
**Status:** GROOMED

## Problem Statement

Two regressions/annoyances have been identified after recent changes:

1. **Unnecessary Speaker Labeling:** Single-speaker audio transcriptions are prefixed with "Speaker 1:", which is noisy and unwanted. This is a side effect of the speaker hallucination fix (commit `088d2ef7c`).

2. **Slow Checklist Generation with Gemini Flash:** The model creates checklist items one at a time via individual function calls, causing multiple slow UI updates instead of a single snappy batch operation. Mistral's thinking model handles this correctly with a single batch call.

---

## Analysis of Current Code

### Issue 1: Speaker Labeling

**Affected files:**
- `lib/features/ai/util/preconfigured_prompts.dart` (lines 442-447, 470-475)

**Two prompts** contain identical speaker identification rules:

| Prompt | ID | Lines |
|--------|----|-------|
| `audioTranscriptionPrompt` | `audio_transcription` | 442-447 |
| `audioTranscriptionWithTaskContextPrompt` | `audio_transcription_task_context` | 470-475 |

**Current speaker rules (both prompts):**
```
SPEAKER IDENTIFICATION RULES (CRITICAL):
- If there are multiple speakers, label them as "Speaker 1:", "Speaker 2:", etc.
- NEVER assume or guess speaker identities or names.
- NEVER use names from the dictionary or context to identify speakers.
- You do NOT know who is speaking - only that different voices exist.
- Use ONLY generic numbered labels (e.g., "Speaker 1:", "Speaker 2:", etc.) for speaker changes.
```

**Root cause:** The rules say "If there are multiple speakers" but never explicitly say what to do when there is only one speaker. Gemini Flash interprets the presence of these rules as a signal to always label speakers, even when only one voice is detected. The rules focus entirely on the multi-speaker case without an explicit single-speaker directive.

**Note:** The `AudioTranscriptionService` at `lib/features/ai_chat/services/audio_transcription_service.dart` uses a different, simpler prompt (`'Transcribe the audio to natural text.'`) for the chat recorder voice input. This path is **not affected** as it has no speaker rules.

### Issue 2: Checklist Batching

**Affected files:**
- `lib/features/ai/util/preconfigured_prompts.dart` (lines 186, 195-198, 229, 268-275)
- `lib/features/ai/functions/checklist_completion_functions.dart` (lines 47-84)
- `lib/features/ai/functions/checklist_tool_selector.dart` (lines 10-24)
- `lib/features/ai/functions/lotti_checklist_handler.dart` (single-item handler, function name `add_checklist_item`)
- `lib/features/ai/functions/lotti_conversation_processor.dart` (lines 78-86, 364-389)

**Tools currently exposed to the model** (via `checklist_tool_selector.dart`):
1. `suggest_checklist_completion` - suggest item completions
2. `add_multiple_checklist_items` - batch create (primary)
3. `update_checklist_items` - batch update

The deprecated single-item tool `add_checklist_item` is **not** in the tool list, so the model shouldn't know about it. However:

1. **`LottiChecklistItemHandler`** with function name `add_checklist_item` is still instantiated in `LottiConversationProcessor` (line 78) and its calls are still processed (line 364).
2. The prompt system message (line 186) says "CRITICAL RULE: When you have 2 or more items to create, you MUST use add_multiple_checklist_items in a SINGLE function call" - but this leaves a loophole: the model can call `add_multiple_checklist_items` multiple times, each with a single `{"items": [{"title": "..."}]}` array.
3. The `tool_choice` is set to `'auto'` for both cloud and Mistral providers, which allows the model to decide how many calls to make.

**Root cause:** The prompt says to use `add_multiple_checklist_items` and to put ALL items in a single call, but Gemini Flash ignores this and makes separate calls per item. The prompt reinforcement isn't strong enough, and the system doesn't enforce batching at the infrastructure level.

---

## Proposed Changes

### Change 1: Fix Speaker Prefix for Single-Speaker Transcripts

**File:** `lib/features/ai/util/preconfigured_prompts.dart`

**Modification:** Add an explicit single-speaker directive as the **first** rule in the speaker identification section of both `audioTranscriptionPrompt` and `audioTranscriptionWithTaskContextPrompt`.

**Before (both prompts):**
```
SPEAKER IDENTIFICATION RULES (CRITICAL):
- If there are multiple speakers, label them as "Speaker 1:", "Speaker 2:", etc.
- NEVER assume or guess speaker identities or names.
- NEVER use names from the dictionary or context to identify speakers.
- You do NOT know who is speaking - only that different voices exist.
- Use ONLY generic numbered labels (e.g., "Speaker 1:", "Speaker 2:", etc.) for speaker changes.
```

**After (both prompts):**
```
SPEAKER IDENTIFICATION RULES (CRITICAL):
- If there is only ONE speaker, do NOT use any speaker labels. Just output the text directly.
- If there are MULTIPLE speakers (2 or more distinct voices), label them as "Speaker 1:", "Speaker 2:", etc.
- NEVER assume or guess speaker identities or names.
- NEVER use names from the dictionary or context to identify speakers.
- You do NOT know who is speaking - only that different voices exist.
- Use ONLY generic numbered labels (e.g., "Speaker 1:", "Speaker 2:", etc.) for speaker changes.
```

**Rationale:** By stating the single-speaker case first and explicitly, the model will check for this condition before defaulting to labeling. The emphasis on "ONE speaker" and "do NOT use any speaker labels" is clear and unambiguous.

### Change 2: Enforce Snappy Batch Checklist Creation

This is a two-part fix: prompt hardening + infrastructure coalescing.

#### Part A: Prompt Hardening

**File:** `lib/features/ai/util/preconfigured_prompts.dart`

Strengthen the system message to make the single-call requirement even more explicit and add a "DON'T" example.

**Current critical rule (line 186):**
```
CRITICAL RULE: When you have 2 or more items to create, you MUST use add_multiple_checklist_items in a SINGLE function call. Always pass a JSON array of objects: {"items": [{"title": "..."}, {"title": "...", "isChecked": true}]}.
```

**Proposed replacement:**
```
CRITICAL RULE - ONE CALL ONLY: You MUST create ALL checklist items in exactly ONE call to add_multiple_checklist_items. Never split items across multiple function calls. Always pass every item in a single JSON array: {"items": [{"title": "..."}, {"title": "...", "isChecked": true}]}.
```

Also update the examples section (around line 277) to add a DON'T example for multiple calls:

**Add to "Examples (DON'T)" section:**
```
- NEVER make multiple add_multiple_checklist_items calls — put ALL items in ONE call
```

And update function description (line 195) to reinforce:

**Current (line 195):**
```
1. add_multiple_checklist_items: Add one or more checklist items at once (ALWAYS use this)
```

**Proposed:**
```
1. add_multiple_checklist_items: Add ALL checklist items in a SINGLE call (NEVER split across multiple calls)
```

#### Part B: Infrastructure — Coalesce Batch Calls Within a Round

**File:** `lib/features/ai/functions/lotti_conversation_processor.dart`

**Problem:** When Gemini Flash sends N separate `add_multiple_checklist_items` calls in a single response (each with 1 item), the current code immediately calls `createBatchItems()` for each one inside the `for (final call in toolCalls)` loop (lines 390-419). This triggers N separate DB writes, N task refreshes, and N UI updates — making the experience feel slow and jittery.

**Solution:** Defer the DB write. Instead of calling `createBatchItems()` inside the loop, accumulate all validated items from all `add_multiple_checklist_items` calls in the round, then write them once after the loop completes.

**Proposed approach in `processToolCalls()`:**

1. Before the `for` loop, declare an accumulator:
   ```dart
   final pendingBatchItems = <Map<String, dynamic>>[];
   final pendingBatchCallIds = <String>[];
   ```

2. Inside the `add_multiple_checklist_items` branch (line 390), replace the immediate `createBatchItems()` call with accumulation:
   ```dart
   } else if (call.function.name == batchChecklistHandler.functionName) {
     final result = batchChecklistHandler.processFunctionCall(call);
     if (result.success) {
       // Accumulate items for deferred batch write
       final items = (result.data['items'] as List<dynamic>)
           .whereType<Map<String, dynamic>>()
           .toList();
       pendingBatchItems.addAll(items);
       pendingBatchCallIds.add(call.id);
     } else {
       _hadErrors = true;
       _failedResults.add(result);
       manager.addToolResponse(
         toolCallId: call.id,
         response: batchChecklistHandler.createToolResponse(result),
       );
     }
   ```

3. After the `for` loop, flush the accumulated items in one batch:
   ```dart
   // Flush accumulated batch items in a single DB write
   if (pendingBatchItems.isNotEmpty) {
     final coalescedResult = FunctionCallResult(
       success: true,
       functionName: batchChecklistHandler.functionName,
       arguments: '',
       data: {
         'items': pendingBatchItems,
         'taskId': batchChecklistHandler.task.id,
       },
     );
     final createdCount =
         await batchChecklistHandler.createBatchItems(coalescedResult);

     // Send tool responses for each original call
     final responseJson = batchChecklistHandler.createToolResponse(coalescedResult);
     for (final callId in pendingBatchCallIds) {
       manager.addToolResponse(toolCallId: callId, response: responseJson);
     }

     if (createdCount == 0 && pendingBatchItems.isNotEmpty) {
       _hadErrors = true;
     }
     checklistHandler.addSuccessfulItems(batchChecklistHandler.successfulItems);
   }
   ```

**Why this works:**
- The model can send 1 call or 10 calls — the DB write and UI update always happen exactly once per round.
- No items are rejected or lost. Every item the model sends is created.
- Legitimate continuation across rounds (model adds more items in round 2) still works fine — each round gets its own coalesced write.
- The approach is model-agnostic: Mistral already sends one call, so it just passes through unchanged. Gemini Flash's multiple calls get coalesced silently.

#### Part C: Clean Up Deprecated Single-Item Handler Reference

**File:** `lib/features/ai/functions/lotti_conversation_processor.dart`

The `LottiChecklistItemHandler` (function name `add_checklist_item`) is still instantiated (line 78) and its calls are still processed (line 364), even though the tool is no longer exposed to the model. While the model shouldn't call it, some models hallucinate function names.

**Proposed:** Update the handler at line 364 to redirect single-item calls into the batch handler instead of processing them through the legacy path. This consolidates all creation into the batch handler.

```dart
if (call.function.name == checklistHandler.functionName) {
  // Redirect deprecated single-item calls to batch handler
  manager.addToolResponse(
    toolCallId: call.id,
    response: 'The function "add_checklist_item" is not available. '
        'Use add_multiple_checklist_items with '
        '{"items": [{"title": "your item"}]} instead.',
  );
```

Also update the `suggest_checklist_completion` redirect message (line 632) to remove the reference to `add_checklist_item`:

**Current:** `'Please use add_checklist_item or add_multiple_checklist_items to create the suggested items.'`
**Proposed:** `'Please use add_multiple_checklist_items to create the suggested items.'`

---

## Verification Steps

### 1. Automated Tests

- [ ] **Existing tests pass:** Run the full test suite to ensure no regressions.
- [ ] **Prompt content tests:** If tests exist that verify prompt text content, update assertions to match the new speaker rules and checklist instructions.

### 2. Manual Verification — Speaker Labeling

- [ ] Record or use a single-speaker audio file.
- [ ] Trigger transcription via the `audioTranscriptionPrompt` path (audio attached to a journal entry without task context).
- [ ] Verify the output has **no** "Speaker 1:" prefix.
- [ ] Record or use a multi-speaker audio file.
- [ ] Trigger transcription and verify speakers are labeled as "Speaker 1:", "Speaker 2:", etc.

### 3. Manual Verification — Checklist Batching

- [ ] Create a task and add a voice entry with 5+ action items.
- [ ] Trigger checklist creation via Gemini Flash.
- [ ] Verify the UI updates once (snappy), not incrementally per item.
- [ ] Check logs: even if the model sent multiple `add_multiple_checklist_items` calls, only one batch DB write should occur per round.
- [ ] Repeat with Mistral thinking model to confirm it still works.

### 4. Edge Cases

- [ ] Single checklist item: Verify a request like "Add milk" still works with the batch function.
- [ ] Coalescing: If the model sends 3 separate calls with 1 item each, verify all 3 items are created in a single DB write and the UI updates once.
- [ ] Continuation across rounds: If the model adds more items in a second round, verify those are also created (coalesced within that round).
- [ ] Deprecated function fallback: If a model hallucinates `add_checklist_item`, verify it gets a redirect message.

---

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/ai/util/preconfigured_prompts.dart` | Add single-speaker directive; strengthen batch-only wording |
| `lib/features/ai/functions/lotti_conversation_processor.dart` | Coalesce batch calls within a round; redirect deprecated single-item handler; fix suggest_checklist_completion message |

## Files Not Modified

| File | Reason |
|------|--------|
| `lib/features/ai_chat/services/audio_transcription_service.dart` | Uses a separate simple prompt for chat input; not affected by speaker labeling issue |
| `lib/features/ai/functions/checklist_completion_functions.dart` | Tool definitions are already correct (batch-only) |
| `lib/features/ai/functions/checklist_tool_selector.dart` | Already excludes single-item tool |
| `lib/features/ai/functions/lotti_checklist_handler.dart` | Will still be used internally for bookkeeping; its calls are just redirected |
