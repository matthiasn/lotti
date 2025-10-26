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
- **Sync**: Because labels reuse the entity definition sync pipeline, updates automatically flow to
  other devices. Soft deletions flip `deletedAt` so reconciliation drops associations without losing
  history.

## State Management

- `labelsStreamProvider` / `LabelsListController`: Watches the repository stream and exposes an
  `AsyncValue<List<LabelDefinition>>` for the settings list UI; supports delete operations with error
  surfacing.
- `LabelEditorController`: Manages create/edit form state, validation, change tracking, and
  duplicate detection before persisting via `LabelsRepository`.
- Both controllers rely on Riverpod notifiers and follow the same disposal patterns as categories.

## UI Components

- `LabelsListPage`: Settings surface with search, empty/error states, and per-label actions.
- `LabelEditorSheet`: Bottom sheet used for creating/editing labels. Provides:
  - Name + optional description fields (with trimming/validation).
  - `flex_color_picker` hybrid color picker (WCAG-friendly presets + HSV wheel).
  - Private toggle description to clarify scope.
- `LabelChip`: Reusable chip with dynamic text color based on label color brightness plus tooltip
  support so descriptions surface on hover/long-press contexts.
- `TaskLabelsSheet` + `TaskLabelsWrapper`: Provide multi-select assignment with search, inline
  “create label” CTA, and a long-press description dialog for mobile discoverability.
- `TaskLabelQuickFilter`: Mirrors the filter drawer selections in the task list header so users can
  quickly audit/clear active label filters.

## AI Label Assignment

Lotti can automatically assign labels to a task via AI function-calling during checklist updates.

- Prompt enrichment: The checklistUpdates prompt injects a compact JSON array of available labels
  (`[{"id":"…","name":"…"}]`) under the `{{labels}}` placeholder when the
  `enable_ai_label_assignment` flag is enabled. The list is capped to 100 entries (top 50 by usage,
  then 50 alphabetical) and optionally excludes private labels based on the
  `include_private_labels_in_prompts` flag. Data is JSON-encoded to avoid prompt injection.
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

- Unit tests cover processor logic (group exclusivity, caps, rate limiting, shadow mode) and helper
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
and repository edge cases. Widget-level coverage now exercises the editor sheet, settings list,
assignment sheet/wrapper, filter chips, and accessibility semantics. Integration + performance
tests validate the reconciliation workflow and filtering performance across 1k+ tasks.

Run the label-related tests with:

```
dart test test/features/labels/state
dart test test/features/labels/ui
dart test test/features/labels/integration
dart test test/database/labels_performance_test.dart
```
