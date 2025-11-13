# Checklist Suggestions — Current‑Entry Default Scope, Back‑References, and Completion Tools (2025‑11‑11)

## Summary

- Default scope change: new checklist items are created from the “current entry” only (recording/text/image being processed), not from the entire task log. Task context remains
  available for de‑duplication, completions, and language/labels.
- Explicit back‑references: allow users to reference prior entries (by timestamp/ID) when they want items extracted from earlier context.
- Tooling: keep `add_multiple_checklist_items` (array‑only); add `complete_checklist_items` for
  direct check‑offs; retain `suggest_checklist_completion` for model‑proposed completions.
- Guard against re‑creation of deleted items by passing a deleted‑items list to prompts and adding an app‑side filter.
- Minimal surface changes: prompt template and prompt‑builder injection; optionally thread the linked entry through the unified AI pipeline; avoid DB schema changes.

Related prior work to respect and build on:

- 2025‑11‑06 — Checklist Items — Array‑Only Multi‑Create, Single‑Item Tool Deprecation
- 2025‑11‑09 — Checklist Updates — Entry‑Scoped Directives and “Single‑Item Plan” Handling
- 2025‑10‑28 — Checklist Item Parsing Hardening (now superseded by array‑only approach)
- 2025‑10‑20 — Audio Recording Modal — Automatic Prompt Checkboxes Visibility

## Problem

When running “Checklist Updates” with full task context, the model sometimes derives items from older log entries, already removed items, or meta/plan‑style notes. Even with entry‑scoped directives, the model still sees the entire task log, which increases noise. Users want the default behavior to only consider the current entry for new items while retaining task context for de‑duplication, completion hints, and language/labels.

## Goals

- Default: create new items from the current entry only.
- Keep task context available to: prevent duplicates, suggest completions of existing items, set
  language, and propose labels (when enabled).
- Allow explicit back‑reference to earlier entries (by timestamp/ID) when the user asks.
- Add a direct completion tool for existing items to pair with suggestion‑only flows.
- Avoid re‑creating deleted items by providing visibility of recently deleted titles to the model and filtering on the app side.

## Non‑Goals

- Changing task summary behavior (it should still consider entire task history).
- Broad UI redesign of the AI popup or recorder modal (beyond clarifying text/tooling).
- DB schema changes (prefer prompt/input enrichment and small helpers over migrations).

## Design Overview

1) Prompt Template Adjustments (Checklist Updates)

- System message: strengthen scope rules
  - Default: “Create new items only from the Current Entry section. Use Task Details only for de‑duplication, evidence to mark existing items complete, language detection, and labels.”
  - Keep and reference the existing “Entry‑Scoped Directives” (ignore/plan‑only) from 2025‑11‑09.
  - Add “Back‑reference” guidance: when the user explicitly references a prior entry by timestamp or ID, the model may extract items from that referenced entry as well.
- User message: add a dedicated Current Entry section (machine‑readable JSON)
  - Example block:
    ```
    Current Entry:
    {
      "id": "<entryId>",
      "createdAt": "2025-11-11T17:20:00Z",
      "entryType": "audio|text|image",
      "text": "…", // plain text body
    }
    ```
  - Keep Task Details (existing `{{task}}`) as a separate block.
  - Include Active Checklist Items and Deleted Checklist Items lists (see 3).
- Function usage priority (unchanged intent, tightened wording):
  - First: add new items (array‑only) from Current Entry; then complete existing items; finally set language and label assignments.

2) Pipeline Threading (minimal change path)

- Option A (recommended now): keep invoking Checklist Updates on the task entity but thread the “current entry” as a separate context into the prompt builder.
  - Pass `linkedEntityId` (the recorder/text/image entry) along to prompt building so
    `Current Entry` can be injected even when the primary entity is the task.
- Option B (follow‑up, optional): allow prompts that require `task` context to run on entry
  entities (audio/text/image) if they are linked to a task. This needs a small relaxation in `getActivePromptsForContext` or dual‑modality requirement on the prompt.

3) Prompt Builder Enhancements

- New placeholders/sections injected when AiResponseType == ChecklistUpdates:
  - `Current Entry` JSON block as above (sourced from `linkedEntityId` when provided, or from the
    entity itself if the entity is the entry).
  - `Active Checklist Items` (id/title/isChecked) — already available via
    `AiInputTaskObject.actionItems`; keep.
  - `Deleted Checklist Items` (titles and deletedAt) — new helper that resolves deleted 
    checklist items linked to the task and emits a compact array of `{ title, deletedAt }`. If 
    fetching deleted items is expensive, include last N (e.g., 50) or recent time window (e.g.,  
    30 days). <= not a problem, there
- Maintain existing labels blocks (`assigned_labels`, `suppressed_labels`, `labels`) and language
  handling.

4) Tools: add direct completion and keep array‑only create

- Keep: `add_multiple_checklist_items` (array of objects only), enforced and covered by tests.
- Add: `complete_checklist_items`
  - Parameters: `{ items: ["<checklistItemId>", ...], reason?: string }`
  - Behavior: set `isChecked = true` for each provided ID in a single atomic batch (pre‑validate IDs
    belong to the current task, skip already‑checked, cap batch size to 20, return
    `{ updated: [ids], skipped: [ids], reason?: string }`).
  - Prompt guidance: prefer this over suggestion when the entry clearly says it is done (e.g., “I
    finished X”). Keep suggestions for ambiguous evidence in transcript/screenshot.
- Keep: `suggest_checklist_completion` (proposal path) — continue to surface to the UI and/or
  auto‑apply with a high‑confidence threshold as a separate policy (not changed here).

5) Deleted‑Items Guardrails

- Prompt‑side: include the “Deleted Checklist Items” list and instruct the model: “Do not re‑create
  titles from this list unless explicitly asked (e.g., ‘Re‑add <title>’)”. Allow near‑duplicate
  detection heuristics (basic string‑similarity guidance).
- App‑side: before creation, drop proposals whose title is exactly equal to a recently deleted
  title (within a configurable window). Log denominator to telemetry (how many items dropped) to
  tune prompts later.

6) UI/UX Notes (small clarifications only)

- Recorder checkboxes: keep existing visibility rules; add helper text to Checklist Updates like “By
  default, this uses only this recording.”
- Add quick directive chips (optional): “Ignore for checklist” / “Plan only (single item)”. Pure UX;
  can come later.

## Implementation Plan

Phase 1 — Prompt + Builder Foundations

- Update `lib/features/ai/util/preconfigured_prompts.dart` (Checklist Updates):
  - Add “Current Entry” section and strengthen scope language.
  - Keep Entry‑Scoped Directives block from 2025‑11‑09.
- Extend `PromptBuilderHelper.buildPromptWithData`:
  - Accept an optional `currentEntry` (looked up from `linkedEntityId` when provided) and inject the
    JSON block.
  - Add helper to build Deleted Checklist Items JSON.
  - Leave existing labels/assigned/suppressed injection untouched.
- Add unit tests to assert new blocks are present with realistic content when an entry is supplied.

Phase 2 — Thread Current Entry Through the Pipeline

- `UnifiedAiController`/`UnifiedAiInferenceRepository`:
  - Thread `linkedEntityId` to the prompt builder for Checklist Updates when present.
  - Automatic audio flow: in `automatic_prompt_trigger.dart`, keep invoking Checklist Updates on the
    task entity, but pass the audio entry’s ID as `linkedEntityId` so Current Entry is populated
    with its latest transcript.
- Tests: targeted integration verifying that an audio recording triggers Checklist Updates that
  contain the correct Current Entry block and only create items from that content by default.

Phase 3 — New Tool: `complete_checklist_items`

- Add function definition in `lib/features/ai/functions/checklist_completion_functions.dart` (or a
  dedicated file): array of IDs, optional reason, batch semantics, 20‑item cap.
- Implement handler path in conversation and non‑conversation flows:
  - Conversation: `LottiConversationProcessor` strategy delegates to a repository method that
    performs batched completion (reusing `ChecklistRepository.updateChecklistItem`).
  - Non‑conversation fallback: extend the streamed tool‑call processing path to handle this
    function.
- Tests: tool schema, handler unit tests (valid/invalid IDs, already checked, batch caps),
  end‑to‑end test with a short transcript stating completion.

Phase 4 — Deleted Items Guardrails

- Add builder helper to fetch and expose deleted checklist items for the task (titles + deletedAt;
  window: last 30 days or last 50 deletions).
- Update Checklist Updates prompt: “Do not re‑create titles from this list unless explicitly asked;
  prefer editing an existing item instead.”
- Apply app‑side filter in the add‑items handler to drop exact‑title matches within the window; log
  counts.
- Tests: ensure prompt contains deleted list; handler drops exact matches; verify opt‑in re‑add
  behavior when the entry explicitly asks.

Phase 5 — Polish, Docs, and Rollout

- Analyzer + format; ensure zero warnings.
- Update `lib/features/ai/README.md` with the Current Entry section and new tool.
- CHANGELOG entry.
- Manual sanity flows: audio with “plan only” directive, explicit back‑reference by timestamp,
  re‑adding a previously deleted item with explicit instruction, and direct completion call from a
  transcript.

## Data/Code Touchpoints

- Prompts: `lib/features/ai/util/preconfigured_prompts.dart` (Checklist Updates system/user text)
- Builder: `lib/features/ai/helpers/prompt_builder_helper.dart` (+ helper for deleted items)
- Pipeline: `lib/features/ai/state/unified_ai_controller.dart`,
  `lib/features/ai/repository/unified_ai_inference_repository.dart` (thread `linkedEntityId` to
  builder for Checklist Updates)
- Tools/Handlers:
  - Add `complete_checklist_items` to `checklist_completion_functions.dart`
  - Conversation path in `lib/features/ai/functions/lotti_conversation_processor.dart`
  - Streamed tool handling in `lib/features/ai/repository/unified_ai_inference_repository.dart`
- Optional: `AiInputLogEntryObject` add `id` in `lib/features/ai/model/ai_input.dart` to improve
  back‑reference UX (requires build_runner regen) — can be deferred since `createdAt` +
  `entryType` + text/transcript is already present.

## Testing Strategy

- Unit tests
  - Prompt builder injects Current Entry JSON, Active Items, Deleted Items.
  - Deleted‑items helper: windowing, empty states.
  - `complete_checklist_items`: schema + handler (valid/invalid IDs, already checked, batch cap).
  - Prompt text assertions for scope rules and examples.
- Integration tests
  - Audio → transcription → checklist updates: created items come from Current Entry only by
    default.
  - Back‑reference case: explicit timestamp/ID reference enables extraction from a prior entry.
  - Deleted‑items guard: proposals matching recent deletions are dropped unless explicitly re‑add.

## Risks & Mitigations

- Model ignores scope rule → Prompt includes explicit “Current Entry only” instruction with
  examples; tests assert presence; telemetry monitors dropped items by guard.
- Over‑filtering on deleted titles → Windowed filter; explicit re‑add override; log counts.
- Confusion between suggestion vs direct completion → Clear tool descriptions; system message
  priority order; keep both paths for robustness.

## Open Questions (for maintainer)

1) Back‑reference format: prefer “previous entry at 2025‑11‑10 17:46” (local time) or stable IDs?
   Should we expose entry IDs in the prompt for copyability?
2) Deleted‑items window: 30 days vs last 50 deletions vs both? OK to make this configurable via a
   flag?
3) Auto‑apply completion suggestions with high confidence (e.g., ≥ high) or always require a direct
   function call? If auto‑apply, where should this policy live?
4) Should Checklist Updates prompts be made valid on entry entities (audio/text/image) without
   adding `audioFiles/images` to requiredInputData (Option B), or do we stick with threading
   `linkedEntityId` (Option A)?
5) Any preference for the default single “plan only” item title (localized), e.g., “Draft
   implementation plan”?
6) Should the UI surface directive quick‑chips in the recorder (Ignore / Plan only), or keep it
   implicit for now?

## Acceptance Criteria

- By default, Checklist Updates only creates items from the current entry; older logs do not produce
  new items unless explicitly referenced.
- Function set includes `add_multiple_checklist_items` (array‑only) and `complete_checklist_items`;
  suggestion flow remains available.
- Deleted items are not silently re‑created by default; prompt and app‑side guard prevent it unless
  explicitly asked.
- Analyzer clean; targeted tests for builder, handlers, and conversation path pass; manual sanity
  verified.

## Related Plans

- 2025‑11‑06_checklist_multi_create_array_only_unification.md
- 2025‑11‑09_checklist_updates_entry_directives_and_scoping.md
- 2025‑10‑28_checklist_item_parsing_hardening.md
- 2025‑10‑20_audio_recording_prompt_checkboxes_visibility.md
