# Checklist Suggestions — Current‑Entry Hint + Fallback to Task, Back‑References, and Completion Tools (2025‑11‑11)

## Summary

- Invocation semantics:
  - When the user runs Checklist Updates from the recording modal for a task (new audio with transcript), we pass that entry as Current Entry and prioritize extracting new items from it.
  - When the user runs Checklist Updates from the task‑level AI popup (no specific entry selected), there is no Current Entry; analyze the full task context instead.
  - We do NOT introduce a new prompt type; the same prompt accepts an optional Current Entry hint and degrades gracefully when it’s absent. Task context remains available for de‑duplication, completions, and language/labels.
- Explicit back‑references: allow users to reference prior entries when they want items 
  extracted from earlier context. Example could be "in the previous two entries" or "in the entry from around lunchtime".
- Tooling: keep `add_multiple_checklist_items` (array‑only); add `complete_checklist_items` for direct check‑offs; retain `suggest_checklist_completion` for model‑proposed completions.
- Guard against re‑creation of deleted items by passing a deleted‑items list to prompts and adding an app‑side filter.
- Minimal surface changes: prompt template and prompt‑builder injection; optionally thread the linked entry through the unified AI pipeline; avoid DB schema changes.

Terminology
- currentEntryId (aka linkedEntityId in code): optional ID of the entry (audio/text/image) that should be treated as the Current Entry hint while the prompt still runs on the task. This is a runtime hint only.

Related prior work to respect and build on:

- 2025‑11‑06 — Checklist Items — Array‑Only Multi‑Create, Single‑Item Tool Deprecation
- 2025‑11‑09 — Checklist Updates — Entry‑Scoped Directives and “Single‑Item Plan” Handling
- 2025‑10‑28 — Checklist Item Parsing Hardening (now superseded by array‑only approach)
- 2025‑10‑20 — Audio Recording Modal — Automatic Prompt Checkboxes Visibility

## Problem

When running “Checklist Updates” with full task context, the model sometimes derives items from
older log entries, already removed items, or meta/plan‑style notes. Even with entry‑scoped
directives, the model still sees the entire task log, which increases noise. Users want the default
behavior to only consider the current entry for new items while retaining task context for
de‑duplication, completion hints, and language/labels.

## Goals

- Prioritize: when provided, create new items from the Current Entry (e.g., the latest recording transcript run from the recording modal).
- Fallback: when no Current Entry is provided (e.g., invoked from the task AI popup), analyze the entire task including all linked entries.
- Keep task context available to: prevent duplicates, suggest completions of existing items, set
  language, and propose labels (when enabled).
- Allow explicit back‑reference to earlier entries when the user asks mentions them.
- Add a direct completion tool for existing items to pair with suggestion‑only flows.
- Avoid re‑creating deleted items by providing visibility of recently deleted titles to the model.

## Non‑Goals

- Changing task summary behavior (it should still consider entire task history).
- Broad UI redesign of the AI popup or recorder modal (beyond clarifying text/tooling).
- DB schema changes (prefer prompt/input enrichment and small helpers over migrations).

## Design Overview

1) Prompt Template Adjustments (Checklist Updates)

- System message: strengthen scope rules
  - If a Current Entry section is present, prioritize new items from that section. Use Task Details primarily for de‑duplication, evidence to mark existing items complete, language detection, and labels. Only extract new items outside of Current Entry when explicitly back‑referenced or when no Current Entry is provided.
  - Keep and reference the existing “Entry‑Scoped Directives” (ignore/plan‑only) from 2025‑11‑09.
  - Add “Back‑reference” guidance: when the user explicitly references a prior entry by timestamp or
    ID, the model may extract items from that referenced entry as well.
- User message: add an optional Current Entry section (machine‑readable JSON)
  - Example block:
    ```
    Current Entry:
    {
      "id": "<entryId>",
      "createdAt": "2025-11-11T17:20:00Z",
      "entryType": "audio|text|image",
      "text": "…", // plain text body; for audio use entry.entryText (user‑edited), NOT latest auto transcript
    }
    ```
  - Keep Task Details (existing `{{task}}`) as a separate block.
  - Include Active Checklist Items and Deleted Checklist Items lists (see 3).
  - Template change: introduce a new `{{current_entry}}` placeholder and remove the unused `{{prompt}}` block from the default template to avoid leaking an unresolved token. When no Current Entry is available, replace `{{current_entry}}` with an empty string.
- Function usage priority (unchanged intent, tightened wording):
  - First: if Current Entry is present, add new items (array‑only) from it; otherwise scan Task Details; then complete existing items if mentioned as completed; finally set language and label assignments.

2) Pipeline Threading (minimal change path)

- Option A (recording modal and task popup): keep invoking Checklist Updates on the task entity but thread the optional “current entry” as a separate context into the prompt builder.
  - Recording modal: pass `linkedEntityId` (the audio/text/image entry) so the builder injects the Current Entry block. Users may skip auto‑trigger and run later from the audio entry popup; editing the transcript is optional — often recommended for terminology/spelling, especially when words are used for the first time in a task — but not required.
  - Task‑level AI popup: do not pass a `linkedEntityId`; the builder omits the Current Entry block and the model analyzes the entire task.
- Enable audio entry popup (Checklist Updates only): allow invoking the Checklist Updates prompt from an audio entry card linked to a task (manual run; editing optional — often recommended for terminology/spelling, especially for first‑use words). Implementation: relax the active‑prompt check **only** for prompts with `aiResponseType == ChecklistUpdates` so they appear for `JournalAudio` entries linked to a task; still run the prompt “on the task” while passing that entry as `linkedEntityId`.

Required signature updates for threading the hint cleanly:
- `UnifiedAiInferenceRepository.runInference(..., { String? linkedEntityId })`
- `PromptBuilderHelper.buildPromptWithData(..., { String? linkedEntityId })`

3) Prompt Builder Enhancements

- New placeholders/sections injected when AiResponseType == ChecklistUpdates:
  - Optional `Current Entry` JSON block injected via `{{current_entry}}` (sourced by fetching the entry by `linkedEntityId`). Omit entirely when not available by substituting an empty string.
  - `Active Checklist Items` (id/title/isChecked) — already available via
    `AiInputTaskObject.actionItems`; keep.
  - `Deleted Checklist Items` (titles and deletedAt) — new helper that resolves all deleted checklist
    items linked to the task and emits a compact array of `{ title, deletedAt }`.
  - Maintain existing labels blocks (`assigned_labels`, `suppressed_labels`, `labels`) and language
    handling.

Notes:
- The Current Entry block is populated by directly loading the entry referenced by `linkedEntityId` and extracting: `id`, `createdAt`, `entryType`, and `text`.
- For audio entries, use the user‑editable entry text (`entry.entryText?.plainText`), NOT the latest auto transcript. For text entries, use the plain text body. For images, use an empty string or a caption if available.
- This does not require adding `id` to `AiInputLogEntryObject`. Optional enhancement: add `id` later for better back‑reference UX; not required for this phase.

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
- App‑side: no hard drop filter. Rely on the model to avoid re‑creating previously deleted items by example and instruction. Consider telemetry to monitor any regressions (e.g., how often proposals resemble recently deleted titles) and refine prompts accordingly.

6) UI/UX Notes (small clarifications only)

- Recorder checkboxes: keep existing visibility rules; add helper text to Checklist Updates like “By
  default, this uses only this recording.”
- Add quick directive chips (optional): “Ignore for checklist” / “Plan only (single item)”. Pure UX;
  can come later.

## Implementation Plan

Phase 1 — Prompt + Builder Foundations

- Update `lib/features/ai/util/preconfigured_prompts.dart` (Checklist Updates):
  - Add an optional “Current Entry” section and strengthen scope language (prioritize Current Entry when present; otherwise analyze Task Details).
  - Introduce `{{current_entry}}` placeholder and remove the unused `{{prompt}}` block from the default template.
  - Keep Entry‑Scoped Directives block from 2025‑11‑09.
- Extend `PromptBuilderHelper.buildPromptWithData`:
  - Accept an optional `linkedEntityId` and inject the `{{current_entry}}` JSON block when present; omit when absent.
  - Add helper to build Deleted Checklist Items JSON.
  - Leave existing labels/assigned/suppressed injection untouched.
  - Add unit tests to assert: when an entry is supplied, blocks are present and prioritized; when no entry is supplied, prompt contains only Task Details.

Phase 2 — Thread Current Entry Through the Pipeline

- `UnifiedAiController`/`UnifiedAiInferenceRepository`:
  - Thread `linkedEntityId` to the prompt builder for Checklist Updates when present (update signatures as noted above).
  - Recording modal/manual run: pass the audio entry’s ID as `linkedEntityId` so Current Entry is populated with the user‑edited entry text.
  - Task‑level AI popup: do not pass `linkedEntityId` — prompt runs on entire task.
  - Audio entry popup: with the relaxed availability rule, allow running the same prompt from an audio entry linked to a task; pass that entry ID as `linkedEntityId` and run for the linked task.
- Tests: targeted integration verifying both flows:
  - Recording‑modal path: prompt contains the correct Current Entry block and primarily creates items from that content by default.
  - Task‑level path: prompt contains no Current Entry block and considers the full task context.
  - Audio entry popup path: prompt is available on audio entries linked to a task; Current Entry block reflects the audio entry’s user‑edited text.

Phase 3 — New Tool: `complete_checklist_items`

- ✅ Add function definition in `lib/features/ai/functions/checklist_completion_functions.dart` including schema + 20-item cap.
- ✅ Conversation path: `LottiConversationProcessor` now handles `complete_checklist_items` by delegating to `ChecklistRepository.completeChecklistItemsForTask` and returning structured responses.
- ✅ Non-conversation path: `UnifiedAiInferenceRepository.processToolCalls` parses the payload, calls the repository helper, and invalidates checklist controllers.
- ✅ Tests updated (conversation strategy, repository, tool schema, inference repository).

Phase 4 — Deleted Items Guardrails

- ✅ Builder helper fetches and exposes the deleted checklist items list for the task (titles + deletedAt; includes all task-linked items).
- ✅ Database query pulls soft-deleted checklist items joined via `linked_entries`.
- ✅ Prompt updated with the deleted list and explicit instruction; model-side avoidance only (no app drop).
- Additional telemetry/monitoring can be added later if needed.

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
- Integration tests (focus on seams; defer heavy LLM stubbing)
  - Recording modal flow (with Current Entry): repository/controller pass `linkedEntityId` through to the builder; prompt contains the Current Entry block.
  - Task‑level AI popup flow (without Current Entry): prompt contains no Current Entry block; only Task Details.
  - Deleted‑items guard: verify prompt injection and system/user instructions are present; rely on manual/telemetry validation for LLM behavior (no time/window limits).
  - Back‑reference: covered by prompt text rules; deeper LLM behavior can be added later.

## Risks & Mitigations

- Model ignores scope rule → Prompt includes explicit “Current Entry only” instruction with
  examples; tests assert presence; telemetry monitors dropped items by guard.
- Over‑filtering on deleted titles → Windowed filter; explicit re‑add override; log counts.
- Confusion between suggestion vs direct completion → Clear tool descriptions; system message
  priority order; keep both paths for robustness.

## Open Questions (for maintainer)

1) Back‑reference format (v2 scope): prefer “previous entry at 2025‑11‑10 17:46” (local time) or stable IDs? For v1, rely on Task Details log and the single Current Entry hint; add structured back‑reference support later if needed.
2) Deleted‑items window: 30 days vs last 50 deletions vs both? OK to make this configurable via a
   flag?
3) Auto‑apply completion suggestions with high confidence (e.g., ≥ high) or always require a direct
   function call? If auto‑apply, where should this policy live?
4) Option B vs A: keep Option A (thread `linkedEntityId`) for v1 to avoid prompt proliferation; evaluate Option B (run on entry entity) later if UX/data warrants.
5) Any preference for the default single “plan only” item title (localized), e.g., “Draft
   implementation plan”?
6) Should the UI surface directive quick‑chips in the recorder (Ignore / Plan only), or keep it
   implicit for now?

## Acceptance Criteria

- When invoked with a Current Entry (recording modal), Checklist Updates prioritizes creating items from that entry; older logs do not produce new items unless explicitly back‑referenced.
- When invoked without a Current Entry (task‑level AI popup), Checklist Updates analyzes the entire task context.
- Function set includes `add_multiple_checklist_items` (array‑only) and `complete_checklist_items`;
  suggestion flow remains available.
- Deleted items are not silently re‑created by default; prompt includes examples and explicit instructions to avoid re‑creation unless explicitly asked (no app‑side exact‑title drop).
- Analyzer clean; targeted tests for builder, handlers, and conversation path pass; manual sanity
  verified.

## Related Plans

- 2025‑11‑06_checklist_multi_create_array_only_unification.md
- 2025‑11‑09_checklist_updates_entry_directives_and_scoping.md
- 2025‑10‑28_checklist_item_parsing_hardening.md
- 2025‑10‑20_audio_recording_prompt_checkboxes_visibility.md
