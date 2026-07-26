---
type: Feature Module
title: Labels
description: A lightweight taxonomy with two separated concerns — definitions and assignment — plus the suppression coupling that feeds AI suggestions.
resource: ../../../lib/features/labels
tags: [labels, taxonomy, ai-suggestions, assignment]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T03:00:00Z }
stale_after: 2027-01-31
sources:
  - id: src
    resource: ../../../lib/features/labels
    title: Labels feature source
    last_modified: 2026-07-25
  - id: repo
    resource: ../../../lib/features/labels/repository/labels_repository.dart
    title: LabelsRepository — the write boundary
    last_modified: 2026-07-25
---

Labels are the app's lightweight taxonomy: more flexible than a single status,
less structural than categories, cheap enough to attach directly to entries. They
matter most around tasks, but **the assignment plumbing is deliberately reusable
across entry types**.

The feature keeps two concerns separate:

- **Definitions** — what labels exist, how they look, whether they are private,
  which categories they apply to.
- **Assignment** — which entry metadata carries which label ids, plus which
  labels AI should stop suggesting for a specific task.

# Three persistence concerns

| Concern | Where |
|---------|-------|
| Label definitions | `label_definitions` |
| Assignment lookup rows | `labeled` |
| Per-task AI suppression | `Task.data.aiSuppressedLabelIds` |

**The `labeled` table exists because filtering and usage counts must stay cheap.**
Recomputing label membership from serialized entity blobs on every filter change
would be the wrong trade.

**Suppression is task-local state, not definition state.** It records "do not
suggest this label again for this task" after a user or workflow explicitly
rejected it.

# The model

`LabelDefinition` carries `id`, `name`, `color`, `description`, `private`,
`applicableCategoryIds`, `deletedAt`, `createdAt`, `updatedAt`.

`sortOrder` exists on the entity, **but the current UI exposes no ordering
controls** — most surfaces sort alphabetically by name.

Category scope is intentionally simple: `null` or empty `applicableCategoryIds`
means **global**; a non-empty list means the label is in scope only for those
categories.

# The write boundary

`LabelsRepository` handles streaming definitions, reading single labels and usage
counts, definition CRUD, `{id, name}` tuples for display and AI context,
add/remove/replace of assigned ids, and task suppression maintenance.

**Definition writes normalize category scope before persisting**: trim ids, drop
empties, remove duplicates, discard unknown categories, and **sort surviving ids
by category name for stable diffs**.

**Delete is soft-delete** — `deleteLabel()` sets `deletedAt` and re-upserts.

## Assignment writes are stricter than a chip picker

- `addLabels()` appends only missing ids.
- `removeLabel()` removes one id.
- `setLabels()` replaces the full set, resolving each id **first against
  `EntitiesCacheService`** — which retains soft-deleted definitions, so cached
  deleted labels are kept — and otherwise against the DB, where only non-deleted
  definitions are accepted. It dedupes and stores ids **sorted by label name**.

For tasks, assignment writes also update suppression:

- Removing a label **adds** it to `aiSuppressedLabelIds`.
- Adding a label **removes** it from `aiSuppressedLabelIds`.
- `setLabels()` computes the diff and updates suppression **in both directions**.

**That coupling is deliberate.** "I removed this label from this task" is useful
feedback for later AI suggestions.

# Assignment UI

```mermaid
sequenceDiagram
  participant UI as "Entry or task surface"
  participant Modal as "EntityPickerSheet"
  participant Scope as "availableLabelsForCategoryProvider"
  participant Cache as "EntitiesCacheService"
  participant Repo as "LabelsRepository"
  participant Entry as "Entry metadata"

  UI->>Modal: open selector
  Modal->>Scope: request visible labels for category
  Scope-->>Modal: available labels
  Modal->>Cache: resolve currently assigned definitions
  Modal-->>Modal: union(available, assigned)
  UI->>Repo: apply selected IDs
  Repo->>Entry: setLabels(...)
```

The picker is the **shared** `EntityPickerSheet` — the same one categories use —
opened as a Wolt sheet, scoped to the entry's category but **unioned with
already-assigned labels**.

Two runtime rules matter:

- **The selector unions currently assigned labels back in, even when they are now
  out of scope**, so the user can still remove them. Without this rule, category
  scoping would create stranded labels the UI can hide but not undo.
- **Inline quick-create is allowed from the selector**, and a newly created label
  is immediately selected.

`LabelChip` is intentionally modest: neutral chrome, a coloured dot, and a
tooltip preferring the description over the bare name. The task-specific
"Add Label" surface lives in [tasks](../tasks/detail-composition.md), where
assigned labels render as filled pills.

# AI label assignment

Task-side AI assignment is **layered on top of** the general system rather than
baked into the picker.

The tool is `assign_task_labels`, whose preferred payload carries structured
labels with confidence:

```json
{"labels": [{"id": "bug", "confidence": "very_high"}]}
```

Legacy `labelIds` input is still accepted, but current parsing prefers the
structured form.

```mermaid
flowchart LR
  Context["TaskLabelHandler.buildLabelContext"] --> Tool["assign_task_labels"]
  Tool --> Parse["parseLabelCallArgs(...)"]
  Parse --> RepoAI["UnifiedAiInferenceRepository"]
  RepoAI --> Processor["LabelAssignmentProcessor"]
  Processor --> Validator["LabelValidator.validateForTask(...)"]
```

Validation and suppression run **before** anything is written, so an AI
suggestion cannot resurrect a label the user already rejected for that task.
