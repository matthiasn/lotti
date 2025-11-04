# Label Suggestions Guardrails — Phased Plan (3 PRs)

References and builds on:
- 2025-10-26 — Automatic Task Label Assignment via AI Function Calls: docs/implementation_plans/2025-10-26_auto_label_assignment_via_ai_function_calls.md
- 2025-10-31 — Task Labels – Applicable Categories Plan: docs/implementation_plans/2025-10-31_task_labels_applicable_categories.md
- 2025-11-03 — Align Labels Management with Categories Scaffolding: docs/implementation_plans/2025-11-03_labels_management_alignment.md
- 2025-11-04 — Label Suggestions — Category Guardrails: docs/implementation_plans/2025-11-04_label_suggestions_category_guardrails.md

## Summary

Split the guardrails into three incremental PRs to reduce risk and clarify decisions. Phase 1 fixes the core safety bug (wrong‑category assignments and the inability to unassign). Phase 2 adds the max‑3 cap and confidence policy. Phase 3 introduces suppression (never re‑suggest user‑removed labels) with user‑visible controls.

This plan resolves the previously open decisions, specifies user messaging, and strengthens testing and telemetry.

## Decisions (resolved)

- Prompt context (assigned labels): Use Option A in Phase 2 — extend task JSON from `AiInputRepository.buildTaskDetailsJson` to include `labels: [{id,name}]` and later `suppressedLabelIds: string[]` when Phase 3 lands. Avoid extra placeholders.
- Confidence schema: String enum — `low | medium | high | very_high`. Prompt requires `very_high`; ingestion gate is optional and disabled by default via flag. A/B plan below.
- Performance: Introduce a lightweight `TaskContext` passed to `LabelAssignmentProcessor` when available; DB fallback otherwise. Processor re‑reads metadata immediately before persistence to compute remaining room, ensuring race safety.
- Existing out‑of‑category and >3 labels: Will NOT be auto‑changed. Users remain in control. We will surface assigned out‑of‑scope in the selector to allow unassignment.

### TaskContext (new)

- Define `TaskContext` as a plain data class at `lib/features/labels/models/task_context.dart`:
  - Fields: `String? categoryId; List<String> existingLabelIds; List<String>? suppressedLabelIds;`
  - Nullable `suppressedLabelIds` until Phase 3.
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
  - Replace global label list with category‑scoped set using `EntitiesCacheService.filterLabelsForCategory(all, categoryId, includePrivate)` before ranking/capping.
  - Keep current 100‑entry cap (top‑usage + next A→Z) but applied within the filtered set.
- Ingestion (`LabelAssignmentProcessor`)
  - Accept `TaskContext` (categoryId, existingLabelIds) from callers when available to avoid DB roundtrip; else fetch once.
  - Validate in scope using a new `LabelValidator.validateForCategory()` (exist + not deleted + category scope). Add skip reason `out_of_scope` to structured response.
  - Note: `validateForCategory()` is extended in Phase 3 to `validateForTask()` (adds suppression rule) without breaking API.
- UI (selector)
  - `task_labels_sheet.dart` and `label_selection_modal_content.dart`: union of available labels with currently assigned label definitions.
  - Sorting (deduplicated):
    - Assigned section: all currently assigned labels (alphabetical), regardless of scope; out‑of‑category show a subtle caption “Out of category”.
    - Available section: all available labels NOT currently assigned (alphabetical). An assigned label never appears in both sections.
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

## Phase 2 — Max‑3 Cap and Confidence Policy

Scope
- Max labels per task = 3 for AI suggestions (manual user assignment unaffected).
- Pass assigned labels into prompt context; instruct “If ≥3 assigned, do not call the tool”.
- Optional ingestion gate on confidence (string enum), default off; prompt still demands “very high”.

Design
- Constants: `LabelAssignmentConfig.maxLabelsPerTask = 3`; `minConfidenceForAssignment = 'very_high'`.
- PromptBuilderHelper & AiInputRepository
  - Extend `AiInputRepository.buildTaskDetailsJson` to include `labels: [{id,name}]`.
  - Preconfigured prompt includes an “Assigned labels” JSON section and an explicit rule: “If the task already has ≥3 labels, do not call assign_task_labels.”
- Parsing
  - Add `parseLabelCallArgs` → `{ labelIds: string[], confidence?: string }`. Keep old parser for compatibility.
- Ingestion (`LabelAssignmentProcessor`)
  - Derive `existing` (from `TaskContext` or DB). If `existing.length >= 3`, short‑circuit: assigned=0; skipped reason `max_total_reached`.
  - Else, compute `room = 3 - existing.length` and cap proposed to `room`; skipped reason `over_total_cap` for extras.
  - If flag `requireVeryHighConfidenceForLabels` enabled and `confidence != 'very_high'`, skip all with `low_confidence`.
  - Re‑read fresh metadata immediately before `addLabels` inside the processor to recompute `room` and avoid race; skipped reasons are recalculated against the fresh state to keep the structured response truthful.

Dependencies
- Phase 2 requires Phase 1 codebase (validators and prompt filtering) to be present; Phase 1 can be disabled via flags if needed. Phase 3 requires Phase 2.

User messaging
- If max reached, we don’t show an auto toast; selector continues to work for manual assignment. We’ll document that AI respects a max of 3.

Performance
- Same as Phase 1; added re‑read before persistence is a single DB call.

Flags/rollback
- Not applicable (always‑on).

Tests
- Prompt includes “Assigned labels” JSON and the max‑3 instruction when assigned ≥3.
- Ingestion: with 2 assigned and 2 proposed → assigns 1, skips 1 with `over_total_cap`.
- Ingestion: with 3 assigned → assigns none, `max_total_reached`.
- Confidence gate on: `confidence: high` → `low_confidence` skip; off → assignment proceeds.
- Concurrency: two concurrent AI calls proposing the same label → idempotent union assigns once.

Telemetry
- Same schema (domain/subDomain as Phase 1). Payload example (Phase 2):
  ```json
  {
    "taskId": "...",
    "attempted": 4,
    "assigned": 1,
    "invalid": 0,
    "skipped": {
      "over_total_cap": 2,
      "low_confidence": 1
    },
    "existingCount": 2,
    "room": 1,
    "confidence": "high",
    "phase": 2
  }
  ```

---

## Phase 3 — Suppression (Don’t Re‑suggest Removed Labels)

Scope
- Track per‑task set `aiSuppressedLabelIds`. When a user removes a label, add it to the set. AI will not suggest suppressed labels; manual user assignment still allowed (and unsuppresses).
- Prompt excludes suppressed; ingestion rejects suppressed with explicit reason.
- Provide a “Reset suggestions for this task” action.

Design
- Data model
  - Add `List<String>? aiSuppressedLabelIds` to `Metadata` (Freezed + JSON). No DB migration (serialized JSON field only).
- Repository
  - On `removeLabel`, union labelId into `aiSuppressedLabelIds`; on `addLabels`/`setLabels` user‑initiated, remove those IDs from `aiSuppressedLabelIds`.
  - Helper to normalize/persist suppressed set.
- Prompt
  - Exclude suppressed from Available labels list.
  - Include `suppressedLabelIds` in task JSON for transparency.
- Ingestion
  - `LabelValidator.validateForTask` rejects suppressed with skip reason `suppressed`.
- UI/UX
  - In selector, no change to default list (suppressed are hidden unless already assigned).
  - Task detail page (⋮ overflow): “Reset label suggestions” → clears `aiSuppressedLabelIds` with confirmation.
  - Tooltip in selector header: “AI won’t suggest labels you removed. Use ‘Reset label suggestions’ to allow again.”

User messaging
- Confirmation dialog for reset: Title “Reset label suggestions?”; Body “AI may suggest previously removed labels again for this task.”; Actions: Cancel / Reset.

Performance
- No extra DB queries beyond existing repository updates; suppressed set lives in task metadata.

Flags/rollback
- Not applicable (always‑on).

Tests
- Remove label → appears in `aiSuppressedLabelIds`; AI proposals containing it are skipped with reason `suppressed`.
- Manually re‑add suppressed label → removed from suppressed set; subsequent AI proposals may include it if in scope.
- Reset action clears suppressed set.
- Edge: label becomes deleted while suppressed → still excluded; deletion takes precedence.

Telemetry
- Same schema (domain/subDomain as prior phases). Payload example (Phase 3):
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
- UI: selector union + sectioned rendering; "Out of category" note.
- Tests: prompt, validator, ingestion, UI, edge no category.

Phase 2 — Max‑3 & Confidence
- Constants: add `maxLabelsPerTask`, `minConfidenceForAssignment`.
- AiInputRepository: include `labels: [{id,name}]` in task JSON.
- Prompts: add Assigned labels block + max‑3 instruction; include before/after diff in PR description.
- Parser: `parseLabelCallArgs` with optional `confidence`.
- Processor: cap by remaining room; enforce `very_high` confidence; re‑read meta before persist and recompute reasons.
- Tests: capped assignment, max reached, missing/invalid confidence, concurrency.

Phase 3 — Suppression
- Metadata: add `aiSuppressedLabelIds`.
- Repository: add/remove/normalize suppressed set on remove/add.
- Prompt: exclude suppressed; include `suppressedLabelIds` in task JSON.
- Validator: extend to `validateForTask()` (category + suppression).
- UI: Reset action on Task detail ⋮ with confirmation; tooltip in selector header.
- Tests: suppression skip, manual unsuppress, reset action, label deleted while suppressed (kept in metadata).
