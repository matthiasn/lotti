# Labels Feature

The labels feature adds Linear-style task labels that can be created, edited, and deleted from
Settings. Tasks can later assign labels (Phase 3) while leveraging synchronized definitions and a
denormalized lookup table for efficient filtering.

## Architecture

- **EntityDefinition**: `LabelDefinition` variant lives alongside other entity definitions. It
  stores id, name, color, description, private flag, and optional metadata required for future
  enhancements (groupId, sortOrder).
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
- `LabelChip`: Reusable chip with dynamic text color based on label color brightness.

## Color Picker Configuration

The editor sheet limits the picker to two modes:

- **Quick presets** (16 curated WCAG AA compliant colors) sourced from
  `lib/features/labels/constants/label_color_presets.dart`.
- **Custom color wheel** for users needing finer control.

This balances accessibility (encouraged presets) with flexibility.

## Testing

Unit tests cover controller state transitions, validation paths, duplicate detection, and stream
updates. Widget-level coverage currently focuses on the chip component (`label_chip_test.dart`); the
editor/list widgets will receive fuller widget/integration coverage alongside Phase 3 task
assignment flows.

Run the label-related tests with:

```
dart test test/features/labels/state
dart test test/features/labels/ui
```
