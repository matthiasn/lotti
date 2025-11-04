# Labels Feature

The labels feature adds Linear-style task labels that can be created, edited, and deleted from
Settings. Tasks can later assign labels (Phase 3) while leveraging synchronized definitions and a
denormalized lookup table for efficient filtering.

## Architecture

- **EntityDefinition**: `LabelDefinition` variant lives alongside other entity definitions. It
  stores id, name, color, description, private flag, and optional metadata (e.g., sortOrder).
- **Database**:
  - `label_definitions` table: mirrors the existing category/habit tables so label metadata can be
    fetched efficiently with unique-name constraints.
  - `labeled` table: denormalized join table mapping journal entries to label ids. Reconciled on
    every entity save via `JournalDb.addLabeled`.
- **Reconciliation**: Diff-based reconciliation compares the authoritative metadata (`meta.labelIds`)
  with the denormalized table, inserting/removing rows as needed.
## Sync

Labels reuse the entity definition sync pipeline, so updates automatically flow to other devices.
Soft deletions flip `deletedAt` so reconciliation drops associations without losing history.

- Manual sync: You can trigger a one-off sync of label definitions from the Sync page via the
  "Sync Entities" modal. Select "Labels" (and any other steps) to enqueue current definitions for
  sync. This is useful after adding labels offline or when bringing a new device online.

## State Management

- `labelsStreamProvider` / `LabelsListController`: Watches the repository stream and exposes an
  `AsyncValue<List<LabelDefinition>>` for the settings list UI; supports delete operations with error
  surfacing.
- `LabelEditorController`: Manages create/edit form state, validation, change tracking, and
  duplicate detection before persisting via `LabelsRepository`.
- Both controllers rely on Riverpod notifiers and follow the same disposal patterns as categories.

### Description normalization and clearing semantics

- Input normalization happens in the controller via a sanitize helper:
  - Trims whitespace and strips common invisible chars (NBSP/ZWSP/BOM).
  - Stores `null` in state when the normalized value is empty.
- Persistence semantics are explicit to avoid accidental resurrection of trimmed characters:
  - Create: controller passes `description: null` when empty; repository persists `null`.
  - Update: controller passes `description: ''` (empty string) to signal “clear this field”.
  - Repository interprets values as:
    - `null` → unchanged (keep existing)
    - `''` (empty after trim) → clear (persist as `null`)
    - non‑empty → trimmed value

This guarantees that deleting the last remaining character in the description clears it on save and
does not reappear due to null-as-unchanged merges downstream.

## UI Components

- `LabelsListPage`: Settings surface with search, empty/error states, and per-label actions.
- `LabelEditorSheet`: Bottom sheet used for creating/editing labels. Provides:
  - Name + optional description fields (with trimming/validation).
  - `flex_color_picker` hybrid color picker (WCAG-friendly presets + HSV wheel).
  - Private toggle description to clarify scope.
  - Keyboard shortcuts: Cmd+S (macOS) / Ctrl+S (Windows/Linux) triggers Save.
  - Text fields are seeded once per label to avoid cursor jumps; user edits aren’t clobbered by
    rebuilds.
- `LabelChip`: Reusable chip with dynamic text color based on label color brightness plus tooltip
  support so descriptions surface on hover/long-press contexts.
- `TaskLabelsSheet` + `TaskLabelsWrapper`: Provide multi-select assignment with search, inline
  “create label” CTA, and a long-press description dialog for mobile discoverability.
- `TaskLabelQuickFilter`: Mirrors the filter drawer selections in the task list header so users can
  quickly audit/clear active label filters.

### Applicable Categories (Scoped Labels)

- Model: `LabelDefinition` includes optional `applicableCategoryIds: List<String>?`.
  - `null` or empty → global (available in all categories)
  - Non-empty → label appears in each listed category
- Caching: `EntitiesCacheService` maintains `global` and per‑category buckets and prunes unknown
  categories on category updates.
- Reactivity: `availableLabelsForCategoryProvider(categoryId)` computes the union of
  `global ∪ scoped(categoryId)` based on `labelsStreamProvider`, preserving Riverpod updates when
  labels change.
- UI:
  - Label editor adds an "Applicable categories" section with chips and an add button that opens the
    category selection modal.
  - Task label picker shows only labels applicable to the task’s current category (unioned with
    global labels), sorted by name. When the task has no category, only global labels are shown.
 - Repository normalizes category IDs: trims, de‑duplicates, validates against cache, and sorts by
   category name (case‑insensitive) for stable diffs. Empty lists persist as `null` (global).

## AI Label Assignment

Lotti can automatically assign labels to a task via AI function-calling during checklist updates.

- Prompt enrichment: The checklistUpdates prompt injects a compact JSON array of available labels
  (`[{"id":"…","name":"…"}]`) under the `{{labels}}` placeholder when the
  `enable_ai_label_assignment` flag is enabled. The list is capped to 100 entries (top 50 by usage,
  then 50 alphabetical) and optionally excludes private labels based on the
  `include_private_labels_in_prompts` flag. Data is JSON-encoded to avoid prompt injection.
  When the total number of labels exceeds the cap, a short note is appended after the JSON block in the
  prompt indicating the subset size, for example: `(Note: showing 100 of 150 labels)`.
- Function tool: The model calls `assign_task_labels` with `labelIds: string[]`. The system
  enforces add‑only semantics (no removal) and caps assignments per call using
  `kMaxLabelsPerAssignment` (default 5).
- Rate limiting: A shared `LabelAssignmentRateLimiter` prevents repeated assignments for the same
  task within a 5‑minute window.
- Shadow mode: When `ai_label_assignment_shadow` is true, assignments are computed and reported to
  the model but not persisted.
- UI feedback: After successful persistence, a non‑blocking SnackBar appears in Task Details listing
  assigned label names with an `Undo` action that removes these labels.
- Events: The `LabelAssignmentProcessor` publishes a `LabelAssignmentEvent` on success, consumed by
  `TaskLabelsWrapper` to show the SnackBar.

### Feature Flags

- `enable_ai_label_assignment` (bool): gates tool registration and prompt label injection.
- `include_private_labels_in_prompts` (bool): includes/excludes private labels from the injected list.
- `ai_label_assignment_shadow` (bool): runs shadow mode (no persistence) while still returning
  structured tool responses.

### Observability

- Logging domain: `labels_ai_assignment` records attempted/assigned/invalid/skipped counts.
- Tool responses include a structured JSON payload for debugging and analytics.

### Testing

- Unit tests cover processor logic (caps, rate limiting, shadow mode) and helper
  prompt injection (caps, escaping, flag gating). Conversation and unified repo tests exercise the
  function call path end‑to‑end.

## Color Picker Configuration

The editor sheet limits the picker to two modes:

- **Quick presets** (16 curated WCAG AA compliant colors) sourced from
  `lib/features/labels/constants/label_color_presets.dart`.
- **Custom color wheel** for users needing finer control.

This balances accessibility (encouraged presets) with flexibility.

## Testing

Unit tests cover controller state transitions, validation paths, duplicate detection, stream updates
and repository edge cases (including clearing the last description character). Widget-level coverage now exercises the editor sheet, settings list,
assignment sheet/wrapper, filter chips, and accessibility semantics. Integration + performance
tests validate the reconciliation workflow and filtering performance across 1k+ tasks.

Run the label-related tests with:

```
dart test test/features/labels/state
dart test test/features/labels/ui
dart test test/features/labels/integration
dart test test/database/labels_performance_test.dart
```
