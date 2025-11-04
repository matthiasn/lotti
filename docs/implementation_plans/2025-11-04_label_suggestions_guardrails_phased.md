# Label Suggestions Guardrails — Phased Plan (3 PRs)

References and builds on:
- 2025-10-26 — Automatic Task Label Assignment via AI Function Calls: docs/implementation_plans/2025-10-26_auto_label_assignment_via_ai_function_calls.md
- 2025-10-31 — Task Labels – Applicable Categories Plan: docs/implementation_plans/2025-10-31_task_labels_applicable_categories.md
- 2025-11-03 — Align Labels Management with Categories Scaffolding: docs/implementation_plans/2025-11-03_labels_management_alignment.md
- 2025-11-04 — Label Suggestions — Category Guardrails: docs/implementation_plans/2025-11-04_label_suggestions_category_guardrails.md

## Summary

Split the guardrails into three incremental PRs to reduce risk and clarify decisions. Phase 1 fixes the core safety bug (wrong‑category assignments and the inability to unassign). Phase 2 adds the max‑3 cap and confidence policy. Phase 3 introduces per‑task suppression (never re‑suggest user‑removed labels) powered by a simple set stored on the task, without new tables.

This plan resolves the previously open decisions, specifies user messaging, and strengthens testing and telemetry.

## Decisions (resolved)

- Prompt context (assigned labels): Use Option A in Phase 2 — extend task JSON from `AiInputRepository.buildTaskDetailsJson` to include `labels: [{id,name}]`. In Phase 3, also include `aiSuppressedLabelIds: string[]` and a `suppressedLabels: [{id,name}]` block so the model can see explicit “do not use” names.
- Confidence schema: String enum — `low | medium | high | very_high`. Prompt requires `very_high`; ingestion gate will be enforced in Phase 2. We will monitor confidence distribution post‑launch and adjust the threshold in a follow‑up PR if needed.
- Performance: Introduce a lightweight `TaskContext` passed to `LabelAssignmentProcessor` when available; DB fallback otherwise. Processor re‑reads metadata immediately before persistence to compute remaining room, ensuring race safety.
- Existing out‑of‑category and >3 labels: Will NOT be auto‑changed. Users remain in control. We will surface assigned out‑of‑scope in the selector to allow unassignment.

### TaskContext (new)

- Define `TaskContext` as a plain data class at `lib/features/labels/models/task_context.dart`:
  - Fields: `String? categoryId; List<String> existingLabelIds; List<String>? suppressedLabelIds;`
  - Nullable `suppressedLabelIds` until Phase 3; populated from `TaskData.aiSuppressedLabelIds`.
- Constructed by call sites that already have the task (preferred):
  - `lib/features/ai/repository/unified_ai_inference_repository.dart`
  - `lib/features/ai/functions/lotti_conversation_processor.dart`
- If unavailable, `LabelAssignmentProcessor` will fetch the task once to assemble the missing fields.

## Rollout

All phases ship as always‑on behavior (no runtime flags). We will monitor via telemetry and adjust thresholds via follow‑up PRs if needed.

## Success Metrics

- ≥90% reduction in mis‑categorized AI label assignments within 2 weeks of Phase 1.
- 0 AI assignments on tasks already having ≥3 labels (Phase 2 enabled).
- <5% of AI attempts rejected due to low confidence after initial tuning (Phase 2, when enabled).
- <2% of sessions showing repeated suggestions of previously removed labels after Phase 3.

---

## Phase 1 — Category Guardrails (Core Safety)

Scope
- Prompt: `{{labels}}` must include only labels valid for the task’s category (global ∪ scoped(category)).
- Ingestion: Reject/ignore IDs not available for the task’s category or deleted.
- UI: Selector shows currently assigned labels even if out‑of‑scope to enable unassigning.
- Telemetry: Count and log skip reason `out_of_scope`.

Design
- PromptBuilderHelper
  - Replace global label list with category‑scoped set. For testability, the implementation uses a local category filter function equivalent to `EntitiesCacheService.filterLabelsForCategory` (to avoid GetIt dependencies in tests). Long‑term, consider refactoring `EntitiesCacheService` to be easily mockable and unify the logic.
  - Keep current 100‑entry cap (top‑usage + next A→Z) but applied within the filtered set.
- Ingestion (`LabelAssignmentProcessor`)
  - Accept `TaskContext` (categoryId, existingLabelIds) from callers when available to avoid DB roundtrip; else fetch once.
  - Validate in scope using a new `LabelValidator.validateForCategory()` (exist + not deleted + category scope). Add skip reason `out_of_scope` to structured response.
  - Note: `validateForCategory()` is extended in Phase 3 to `validateForTask()` (adds suppression rule) without breaking API.
- UI (selector)
  - `task_labels_sheet.dart` and `label_selection_modal_content.dart`: union of available labels with currently assigned label definitions.
  - Ordering (deduplicated): Assigned labels are listed before available labels within a single list. Out‑of‑category assigned labels include a subtle “Out of category” caption. Section headers may be introduced later if needed.
  - Touch targets remain `CheckboxListTile` (meets current sizing).

User messaging
- In selector row subtitle for out‑of‑scope assigned labels: “Out of category”.
- No new toasts for rejections; logging only (avoid noise). The assigned chips remain unchanged.

Performance
- Use cache (`EntitiesCacheService`) for scoping; usage counts read as today.
- Processor prefers caller‑provided context; at most one DB fetch if missing.

Flags/rollback
- Not applicable (always‑on).

Tests
- Prompt: `{{labels}}` excludes out‑of‑scope labels; respects privacy flag; retains cap.
- Validator: valid if in scope; invalid if deleted; invalid if out‑of‑scope.
- Ingestion: mixed IDs → assigns only in‑scope; others skipped with `out_of_scope`.
- UI: selector shows an assigned out‑of‑scope label in the Assigned section and allows unchecking.
- Edge: task with no category → prompt shows global only; ingestion treats only global as in‑scope.

Telemetry
- Unified schema via `LoggingService`:
  - `domain: 'labels_ai_assignment'`, `subDomain: 'processor'`
  - Payload example (Phase 1):
    ```json
    {
      "taskId": "...",
      "attempted": 3,
      "assigned": 2,
      "invalid": 0,
      "skipped": {
        "out_of_scope": 1
      },
      "phase": 1
    }
    ```

---

## Phase 2 — Max‑3 by Confidence (Top‑3; exclude low)

Scope
- Max labels per task = 3 for AI suggestions (manual user assignment unaffected).
- Pass assigned labels into prompt context; instruct “If ≥3 assigned, do not call the tool”.
- Confidence‑driven selection: drop all `low`, sort remaining by confidence (very_high > high > medium) while preserving input order, then select top 3. For legacy payloads with only `labelIds`, treat all as `medium` and cap at 3.

Design
- Constants: `LabelAssignmentConfig.maxLabelsPerTask = 3`.
- PromptBuilderHelper & AiInputRepository
  - Extend `AiInputRepository.buildTaskDetailsJson` to include `labels: [{id,name}]`.
  - Preconfigured prompt includes an “Assigned labels” JSON section and an explicit rule: “If the task already has ≥3 labels, do not call assign_task_labels.”
  - Prompt instructs the model to return per‑label confidences and to order suggestions by confidence (omit `low`).
- Parsing
  - Extend parser to accept `{ labels: [{ id, confidence }] }` while keeping `{ labelIds: [] }` for backward compatibility.
  - Normalize into ranks (very_high=3, high=2, medium=1, low=0), drop `low`, stable‑sort by rank desc, take top 3. Legacy payload: treat all as `medium` and take first 3.
- Ingestion (`LabelAssignmentProcessor`)
  - If `existing.length >= 3`, short‑circuit: assigned=0; skipped reason `max_total_reached`.
  - Otherwise, use the cap‑and‑ranked list from parsing (already ≤3) and apply Phase‑1 category scope checks and assignment.
  - Re‑read fresh metadata immediately before `addLabels` to recompute remaining room safely.

Dependencies
- Phase 2 builds on Phase 1 codebase (validators and prompt filtering). Phase 3 builds on Phase 2. All phases are always‑on; there are no runtime flags.

User messaging
- If max reached, we don’t show an auto toast; selector continues to work for manual assignment. We’ll document that AI respects a max of 3.

Performance
- Same as Phase 1; added re‑read before persistence is a single DB call.

Flags/rollback
- Not applicable (always‑on).

Tests
- Prompt includes “Assigned labels” JSON and the max‑3 instruction when assigned ≥3.
- Parser selects top‑3 by confidence (drops `low`), preserves order among equals, and handles legacy `labelIds`.
- Ingestion: with 3 assigned → assigns none, `max_total_reached`.
- Concurrency: two concurrent AI calls proposing the same label → idempotent union assigns once.

Telemetry
- Same schema (domain/subDomain as Phase 1). Payload example (Phase 2):
  ```json
  {
    "taskId": "...",
    "attempted": 5,
    "assigned": 3,
    "invalid": 0,
    "skipped": {
      "dropped_low": 1,
      "legacy_capped": 1
    },
    "confidenceBreakdown": {"very_high": 2, "high": 2, "medium": 1},
    "phase": 2
  }
  ```

---

## Phase 3 — Suppression (Don’t Re‑suggest Removed Labels)

Scope
- Track per‑task set `aiSuppressedLabelIds` on `TaskData` (Set<String>?, serialized as array). When a user removes a label, add it to the set. Manual user assignment is always allowed and implicitly unsuppresses.
- Prompt exposes suppressed labels by id and name and instructs the model not to suggest them; callers also hard‑filter: any suppressed IDs in tool calls are dropped before processing.
- Ingestion rejects suppressed with explicit reason for defense‑in‑depth.
  

Design
- Data model (no new tables)
  - Add `Set<String>? aiSuppressedLabelIds` to `TaskData` (Freezed + JSON). Serialize as array; keep null/empty distinction minimal (empty set serializes to `[]`).
- Repository
  - On `removeLabel`, add the labelId to `aiSuppressedLabelIds`.
  - On `addLabels`/`setLabels` (manual user flows), unsuppress: subtract newly added IDs from the set.
  - Provide ergonomic helpers: `addSuppressedLabels(taskId, Set<String>)` and `removeSuppressedLabels(taskId, Set<String>)`.
  - No database table; suppression lives in the task’s data blob.
- Prompt
  - Exclude suppressed from the “Available Labels” list.
  - Include a separate “Suppressed Labels” block with `[{id,name}]` for clarity.
  - Task JSON also includes `aiSuppressedLabelIds` for transparency.
- Callers (AI function ingestion)
  - After `parseLabelCallArgs`, subtract `aiSuppressedLabelIds` from the selected IDs.
  - If all candidates are suppressed, return a structured no‑op tool response; do not call the processor.
- Ingestion
  - `LabelValidator.validateForTask` rejects suppressed with skip reason `suppressed` (defense‑in‑depth).
- UI/UX
  - Default selector behavior unchanged; suppressed labels are simply not suggested by AI.
  - Manual re‑adding implicitly unsuppresses and is always allowed.

User messaging
  

Performance
- No extra DB queries beyond existing repository updates; suppression set lives in task data.

Flags/rollback
- Not applicable (always‑on).

Tests
- Remove label → labelId added to `aiSuppressedLabelIds`; AI proposals containing it are dropped by callers and rejected by validator if they slip through.
- Manually re‑add suppressed label → labelId removed from suppressed set; subsequent AI proposals may include it if in scope.
- Callers: partial suppression (some candidates dropped) and full suppression (no‑op response; processor not called).
- Prompt builder: “Suppressed Labels” JSON block contains id+name; rule text present.
  
- Edge: label becomes deleted while suppressed → still excluded; deletion takes precedence.

Telemetry
- Same schema (domain/subDomain as prior phases). Optionally include `suppressed_skipped` count. Payload example (Phase 3):
  ```json
  {
    "taskId": "...",
    "attempted": 2,
    "assigned": 1,
    "invalid": 0,
    "skipped": {
      "suppressed": 1
    },
    "suppressedIds": ["sync"],
    "phase": 3
  }
  ```

---

## Risk & Race Conditions

- Compute remaining room right before persistence (re‑read task meta) to handle concurrent edits.
- Repository union (`addLabels`) remains idempotent; duplicates are ignored.
- If category changes mid‑flight, ingestion validation re‑evaluates scope based on fresh metadata and rejects accordingly.

## Testing Matrix (concrete cases)

1. Prompt filters to category (no category → global only)
2. Ingestion rejects out‑of‑scope (skip reason recorded)
3. Selector shows assigned out‑of‑scope with “Out of category” note
4. With 3 assigned, prompt instructs no tool call
5. With 3 assigned, ingestion returns `max_total_reached`
6. With 2 assigned, 2 proposed → assigns 1, `over_total_cap` for 1
7. Confidence gate off: assigns; gate on + `high` → `low_confidence`
8. Concurrent AI calls propose the same label: assigned once
9. Remove label → AI proposals with it get `suppressed`; manual add unsuppresses
10. Reset suggestions clears suppressed and allows proposals again
11. Missing `confidence` when gate enabled → all skipped with `confidence_missing_or_invalid`
12. Invalid `confidence` value → skipped with `confidence_missing_or_invalid`
13. Category deleted mid‑flight → treat as no category; only global labels in scope

## CHANGELOG and User‑Facing Copy

- Added: Category‑scoped AI label suggestions; Max‑3 per task (AI only); Optional “very high” confidence gate; Per‑task suppressed labels with reset action.
- Fixed: AI assigning labels not available for the task’s category; selector now shows assigned out‑of‑scope labels so users can unassign.
- Notes: Manual assignment is unchanged; existing tasks with out‑of‑scope or >3 labels are not auto‑modified.

## Diagram (validation flow)

Phase 1: User message → PromptBuilder (category filter) → AI → Tool call → Processor (category validator) → Repository (union) → Event/Telemetry → UI

Phase 3 adds: PromptBuilder reads suppressedIds; Processor validates against suppressed; Repository.removeLabel updates suppressedIds

---

## Confidence Policy Justification

- Rationale: False‑positive labels degrade utility; user reports indicate low‑confidence drift. We enforce an explicit “very_high” policy to bias toward precision over recall starting with Phase 2.
- Monitoring: Collect `confidence` distribution from tool calls for 1–2 weeks after Phase 2 to verify policy fit. If the distribution suggests a better threshold, we will adjust in a follow‑up PR.

## Telemetry Aggregation for Metrics

- Aggregate over 14 days using our analytics sink fed by `LoggingService`.
- Queries (pseudo):
  - Mis‑categorized rate ≈ sum(skipped.out_of_scope) / sum(attempted)
  - Max‑cap adherence ≈ sum(skipped.max_total_reached + skipped.over_total_cap) where phase=2
  - Suppression effectiveness ≈ sum(skipped.suppressed) / sessions with suppression enabled
- Dashboard: add a simple timeseries per counter and a weekly summary widget.

## Phase Dependencies

- Phase 2 builds on Phase 1 code (validators and prompt filtering). Phase 3 builds on Phase 2.

## Implementation Steps (per phase)

Phase 1 — Category Guardrails
- Add `TaskContext` model: `lib/features/labels/models/task_context.dart`.
- Prompt: `PromptBuilderHelper` category‑scoped labels.
- Validator: `validateForCategory()` in `label_validator.dart`.
- Processor: accept `TaskContext`, apply category scope; log telemetry payload (Phase 1 schema).
- UI: selector union + assigned‑first ordering; "Out of category" note.
- UI: extract small utilities for union and subtitle to reduce duplication.
- Tests: prompt, validator, ingestion, UI, edge no category.

Phase 2 — Max‑3 & Confidence
- Constants: add `maxLabelsPerTask`, `minConfidenceForAssignment`.
- AiInputRepository: include `labels: [{id,name}]` in task JSON.
- Prompts: add Assigned labels block + max‑3 instruction; include before/after diff in PR description.
- Parser: `parseLabelCallArgs` with optional `confidence`.
- Processor: cap by remaining room; enforce `very_high` confidence; re‑read meta before persist and recompute reasons.
- Tests: capped assignment, max reached, missing/invalid confidence, concurrency.

Phase 3 — Suppression (No DB tables)
- TaskData: add `aiSuppressedLabelIds: Set<String>?` to persist labels the user removed from the task.
  - Purpose: used only to suppress AI suggestions; manual assignment remains unrestricted.
  - Backward compatible (nullable; treat null as empty).
- JSON shape remains an array (`string[]`) for serialization; the in-memory type is a Set for efficient lookups and dedupe.
- Repository (setLabels): when applying a new `labelIds` set, compute `removed = previous \ new` and update
  `task.data.aiSuppressedLabelIds = (existingSuppressed ∪ removed)`; and remove from suppressed when labels are re‑added manually (implicit unsuppress).
- Prompt + Task JSON:
  - AiInputRepository: include `aiSuppressedLabelIds: string[]` in the task JSON alongside `labels: [{id,name}]`.
  - PromptBuilderHelper: inject a "Suppressed Labels" JSON block as an array of objects `[{id, name}]`.
    - Resolve names at prompt construction (batch `getAllLabelDefinitions` or cached filter), falling back to the ID if missing.
  - Preconfigured prompt (checklist_updates): add an explicit rule: "Do not propose or use any IDs listed in Suppressed Labels when calling assign_task_labels; prefer alternatives or assign none."
- Callers (hard filter before processor): in both unified and conversation paths:
  - Subtract `aiSuppressedLabelIds` from the parser‑selected IDs (even if the model sent them anyway).
  - If all proposed IDs are suppressed, short‑circuit with an empty assignment and a structured response indicating suppression.
- Telemetry (optional): if desired, include a `suppressed_skipped` counter when suppressed labels were filtered by callers.
- UI: no additional controls required in this phase (optional future "unsuppress" affordance can be added later). Manual selection remains free.
- Tests:
  - Repository: removing labels appends them to `aiSuppressedLabelIds`; adding labels removes them from `aiSuppressedLabelIds` (implicit unsuppress).
  - Prompt: aiSuppressedLabelIds appears in the task JSON; and the prompt contains a "Suppressed Labels" block with id+name pairs; explicit suppression rule present.
  - Callers: suppressed labels filtered from candidates before processor; when all candidates are suppressed, processor is not called and a no‑op assignment is returned.
