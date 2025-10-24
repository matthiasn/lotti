# Task Labels System Plan

## Summary

- Introduce a “labels” system for tasks that mirrors Linear-style labels without
  colliding with the underused legacy tags feature.
- Provide lightweight creation, assignment, coloring, and filtering flows so users can surface
  focus-relevant subsets of tasks (e.g., `release-blocker`, `bug`, `sync`).
- Follow `AGENTS.md` expectations: rely on MCP tooling, keep analyzer/tests green, update related
  READMEs/CHANGELOG, avoid touching generated code, and maintain Riverpod-first state management.

## Goals

- Define a synced settings entity for labels (name, color, optional icon) accessible on mobile and
  desktop, including CRUD UI in Settings.
- Allow tasks (and optionally other entries) to reference label IDs, persist them reliably, and
  expose them through search/filter APIs.
- Render label chips within task headers and task list cards; enable filtering by one or more labels
  inside the Tasks tab filter drawer.
- Ensure label metadata survives renames (ID stable), remains authoritative in entry metadata, and
  is mirrored into the `labeled` denormalized table for performant filtering/search.
- Cover the feature with logic/unit/widget tests and document the new UX for QA and
  release notes.

## Non-Goals

- Reviving or replacing the existing “tags” feature beyond coexisting gracefully (no deprecation in
  this iteration).
- Reworking broader task filtering UX (statuses, categories, assignees); scope is label addition.
- Building server-side analytics for label usage; collect only what existing telemetry supports.
- Implementing custom ordering or auto-suggestion heuristics for labels (can follow up later).

## Current Findings & Research Tasks

- ✅ **Tags pattern confirmed**: Labels will follow the proven tags pattern (`lib/features/tags/repository/tags_repository.dart`) — metadata holds `List<String> labelIds` as source of truth with denormalized `labeled` table for efficient filtering queries.
- ✅ **Categories provide UI reference**: Category management (`lib/features/categories/`) offers reusable components for color pickers, CRUD flows, and Riverpod state patterns.
- ✅ **Metadata structure identified**: `Metadata` class (`lib/classes/journal_entities.dart:24`) already supports `tagIds`; adding `labelIds` follows identical pattern.
- ✅ **Denormalized table pattern**: The `tagged` table (`lib/database/database.drift:134`) demonstrates performant join-free lookups; `labeled` table will mirror this.
- ✅ **Linear research complete**: Label groups provide one level of nesting with single-selection enforcement within groups; descriptions appear on hover; workspace vs team scoping (not needed for v1).
- ✅ **Filter integration confirmed**: `JournalPageState.selectedCategoryIds` pattern (lib/blocs/journal/journal_page_state.dart:27) and `TasksFilter` model verified; `selectedLabelIds` will follow identical pattern for filter persistence.

## Data Model Decision: Tags Pattern

**Follow the proven tags pattern** — metadata-first with denormalized lookup table for filtering:

### Core Components

1. **Label Definitions as Entity**
   ```dart
   // Added to lib/classes/entity_definitions.dart
   const factory EntityDefinition.labelDefinition({
     required String id,
     required String name,
     required String color,
     String? description,
     String? groupId,       // For label groups (future enhancement)
     int? sortOrder,        // Within-group ordering
     // ... standard EntityDefinition fields (createdAt, updatedAt, vectorClock, etc.)
   }) = LabelDefinition;
   ```

2. **Label Assignment in Metadata**
   ```dart
   // Add to lib/classes/journal_entities.dart Metadata class
   const factory Metadata({
     // ... existing fields ...
     List<String>? tagIds,     // existing tags
     List<String>? labelIds,   // ← NEW: authoritative label assignments
   }) = _Metadata;
   ```

3. **Denormalized Lookup Table** (required for efficient filtering)
   ```sql
   -- lib/database/database.drift
   CREATE TABLE labeled (
     id TEXT NOT NULL UNIQUE,
     journal_id TEXT NOT NULL,
     label_id TEXT NOT NULL,
     PRIMARY KEY (id),
     FOREIGN KEY(journal_id) REFERENCES journal(id) ON DELETE CASCADE,
     UNIQUE(journal_id, label_id)
   );
   CREATE INDEX idx_labeled_journal_id ON labeled (journal_id);
   CREATE INDEX idx_labeled_label_id ON labeled (label_id);
   ```

   **Why required**: Task filtering by labels needs indexed queries. Without this table, you'd have to load all tasks into memory and deserialize metadata—completely impractical. `LabelDefinition` lives in `EntityDefinition`, so no dedicated Drift table is needed for definitions themselves—sync already persists entity definitions uniformly.

### Reconciliation Strategy

**On every entity save** (including sync ingestion), the database layer reconciles the `labeled` table with `metadata.labelIds`:

```dart
// Implementation in lib/database/database.dart (added alongside addTagged at line 240)
// More efficient than tags: calculates diff instead of delete-all-then-reinsert
Future<void> addLabeled(JournalEntity journalEntity) async {
  final id = journalEntity.meta.id;
  final authoritativeLabelIds = (journalEntity.meta.labelIds ?? []).toSet();
  final currentLabelIds = (await labeledForEntry(id)).toSet();

  // Calculate diff
  final toRemove = currentLabelIds.difference(authoritativeLabelIds);
  final toAdd = authoritativeLabelIds.difference(currentLabelIds);

  // Remove labels no longer in metadata
  for (final labelId in toRemove) {
    await deleteLabeledRow(id, labelId);
  }

  // Add new labels from metadata
  for (final labelId in toAdd) {
    await insertLabeled(uuid.v1(), id, labelId);
  }
}
```

**How this achieves self-healing:**
- Queries current state of `labeled` table for the entry
- Calculates diff: what needs to be removed vs added
- **Only deletes** labels removed from metadata (leaves existing ones untouched)
- **Only inserts** labels newly added to metadata (skips existing ones)
- Idempotent: running multiple times produces same result as running once
- More efficient than delete-all-then-reinsert pattern used by tags

**Benefits over entry links approach**:
- Single source of truth (metadata only)
- Simpler sync (no dual reconciliation needed)
- Self-healing (reconciliation corrects drift automatically)
- No risk of metadata/link inconsistency

## Design Overview

1. **Label Settings Entity**
  - Model: `LabelDefinition` as `EntityDefinition` variant (syncs via existing `SyncMessage.entityDefinition`)
  - Fields: `id`, `name`, `color`, `description?`, `groupId?` (for future label groups), `sortOrder`, standard sync fields
  - Storage: synced via `SyncMessage.entityDefinition`; Riverpod provider for CRUD
  - UI: new Settings page reusing category management scaffolding, modern card list, color picker using `flex_color_picker` package (new dependency) with both preset colors (16 curated colors) and custom color wheel for full flexibility, create/edit dialogs
  - Description tooltips: Display on hover (Linear pattern) to explain when label applies

2. **Assignment Workflow**
  - Task header: add label selector (pill chips or dropdown) allowing quick add/remove; keyboard accessible
  - Persist `labelIds` in `metadata`; database layer auto-reconciles `labeled` table on save
  - Task cards: render chips with color + text; handle overflow via wrap or ellipsis with tooltip
  - Repository: `LabelsRepository` follows `TagsRepository` pattern for add/remove operations

3. **Filtering**
  - Extend Tasks filter drawer to include label filter with "Any of" mode (default)
  - Filter queries use `labeled` table joins (efficient, no N+1 lookups)
  - Persist label filter state using `JournalPageState.selectedLabelIds` (mirrors `selectedCategoryIds` pattern)
  - Future enhancement: "All of" and "Without" modes if needed

4. **Sync & Integrity**
  - **Reconciliation runs on every save** (including sync ingestion) via `JournalDb.addLabeled()` (called from `updateJournalEntity` at line 240, mirroring `addTagged()` pattern)
  - `metadata.labelIds` is authoritative; `labeled` table mirrors it deterministically
  - Label deletion cascades: remove label ID from impacted entries' metadata and rely on reconciliation to drop `labeled` rows
  - Label rename: no action needed (metadata stores IDs, display updates automatically)
  - Self-healing: reconciliation corrects any drift between metadata and `labeled` table

5. **Accessibility & Visual Design**
  - Provide color contrast fallback (text color switching white/black based on luminance)
  - Add `Semantics` labels for screen readers (`Label: bug`)
  - Ensure chips shrink gracefully on mobile; support dark/light themes
  - Use `flex_color_picker` with `ColorPickerType.custom` (16 WCAG AA compliant preset colors) + `ColorPickerType.wheel` (full HSV color wheel) for flexible color selection

6. **Label Groups** (Future Enhancement)
  - Structure: `LabelGroup` entity + `LabelDefinition.groupId` reference
  - Constraint: max one label per group on any entry (enforced in repository)
  - UI: group sections in selection modal, visual grouping in filter drawer
  - Deferred to post-v1 to keep initial scope focused

## Implementation Phases

### Phase 1 – Data Model & Infrastructure

- ✅ Deep-dive existing tag/category code to confirm reusable components (complete)
- Add `LabelDefinition` to `EntityDefinition` sealed class (`lib/classes/entity_definitions.dart`)
- Add `labelIds` field to `Metadata` class (`lib/classes/journal_entities.dart`)
- Create `labeled` denormalized table in `lib/database/database.drift`:
  - Schema definition with foreign keys and indexes
  - Queries: `labeledForEntry` (returns Set<String> of label IDs), `deleteLabeledRow` (single row), `insertLabeled` via Drift
- Implement reconciliation in `lib/database/database.dart`:
  - `addLabeled(JournalEntity)` method called from `updateJournalEntity` (add at line 240 alongside `addTagged()`)
  - Diff-based reconciliation: query current state, calculate toAdd/toRemove sets, apply changes
  - More efficient than tags: only touches rows that need changes (not delete-all-then-reinsert)
  - Unit tests: reconciliation correctness, idempotency, edge cases (add only, remove only, mixed, no-op)
- Draft `LabelsRepository` following `TagsRepository` pattern (add/remove/list operations)
- Add Riverpod provider scaffolding for labels CRUD

### Phase 2 – Settings & CRUD UI

- Add `flex_color_picker` dependency to `pubspec.yaml`
- Create `lib/features/labels/` module structure (repository, state, ui)
- Implement Settings page for labels:
  - List existing labels with edit/delete actions
  - Modal/dialog for create/edit (name, color, optional description)
  - Color picker using `ColorPicker` widget from `flex_color_picker` package
  - Configure with `pickersEnabled: {ColorPickerType.custom: true, ColorPickerType.wheel: true}`
  - Define 16 WCAG AA compliant colors in `customColorSwatchesAndNames` for preset section:
    - Diverse color families: blues, greens, reds, oranges, yellows, purples, pinks, browns, grays
    - Minimum 4.5:1 contrast ratio against both light and dark theme backgrounds
    - Colors should be visually distinct for users with color vision deficiencies
    - Document specific hex values and contrast ratios in `lib/features/labels/README.md`
  - Enable HSV color wheel for full custom color picking
  - Reuse category picker dialog pattern but with hybrid color picker
  - Description field with hint text ("Explain when this label applies")
- Repository implementation (`LabelsRepository`):
  - CRUD operations following category pattern
  - Validation: ensure unique names, valid colors
- Riverpod controllers:
  - `LabelsListController` for list/filter management
  - `LabelDetailsController` for individual label editing
- Unit tests: CRUD flows, validation, sync serialization
- Update `lib/features/labels/README.md` describing settings workflow

### Phase 3 – Task Assignment UX

- Update task detail/header widget to display current labels and allow quick assignment
- Implement label selection modal (`LabelSelectionModalContent`):
  - Multi-select support (checkboxes or chips)
  - Search/filter functionality
  - Adaptive layout (desktop/mobile)
  - Show label descriptions on hover/long-press
- Label chips widget (`LabelChip`):
  - Display color + name
  - Semantics support for screen readers
  - Responsive sizing (shrink on mobile)
  - Tooltip showing description
- Update `metadata.labelIds` via `LabelsRepository.addLabels/removeLabels`
- Persistence layer auto-triggers reconciliation on save
- Widget tests: assignment interactions, chip rendering, overflow handling, accessibility
- Display label chips on task list cards (responsive layout, max 2-3 visible with "+N" overflow)

### Phase 4 – Filtering & Search

- Extend `JournalPageState` to include label filter:
  - Add `Set<String> selectedLabelIds` (mirrors `selectedCategoryIds` pattern)
  - Persist filter state per tab (coordinate with existing persistence)
- Update `TasksFilter` model to include `selectedLabelIds` for serialization
- Update database queries to honor label filters:
  - Query via `labeled` table joins (efficient, indexed lookups)
  - Example: `SELECT * FROM journal WHERE id IN (SELECT journal_id FROM labeled WHERE label_id IN :label_ids)`
  - Add tests to verify N+1 regression prevention
- UI: Label filter section in Tasks filter drawer
  - Multi-select chips (similar to category filter at `lib/features/tasks/ui/filtering/task_category_filter.dart`)
  - "All" / "Unassigned" / individual labels
  - Show active filters count
  - Implicit OR logic: selecting multiple labels shows tasks with ANY of the selected labels (no explicit mode selector in v1)
- Optional quick filter in list header (chips representing active filters)
- No new analytics events (per decisions section)

### Phase 5 – Polish, Testing & Documentation

- Label deletion flow:
  - Soft delete label definition (set `deletedAt`) for undo/restore window
  - Confirmation dialog warning about affected tasks (query `labeled` table for count)
  - On confirmation: cascade removal by fetching affected entries, stripping label ID from each entry's metadata, and persisting changes
  - Reconciliation (`addLabeled`) automatically drops denormalized rows from `labeled` table on next save
  - Optional cleanup job to hard-delete soft-deleted labels after retention period (e.g., 30 days)
- Comprehensive testing:
  - Integration tests: full workflow (create label → assign → filter → delete)
  - Performance tests: filtering with large label sets
  - Sync tests: ensure reconciliation works with sync ingestion
- Documentation updates:
  - `lib/features/labels/README.md` with architecture overview
  - `lib/features/tasks/README.md` updated to mention labels
  - `CHANGELOG.md` entry with feature summary and screenshots
- Release checklist: Claude → PR → Gemini/CodeRabbit → TestFlight iOS/macOS

## Testing Strategy

- **Unit tests**:
  - `LabelsRepository`: CRUD operations, validation
  - `JournalDb.addLabeled()`: reconciliation add/remove/idempotency cases
  - Label filter serialization (`TasksFilter.fromJson/toJson`)
  - Edge cases: empty labels, missing label definitions
- **Widget tests**:
  - `LabelSelectionModalContent`: multi-select, search, accessibility
  - `LabelChip`: rendering, tooltips, semantics, theme switching
  - Task card label display: overflow handling, responsive layout
  - Filter drawer: label filter section interactions
- **Integration tests**:
  - Full workflow: create label → assign to task → filter tasks → verify results
  - Sync scenario: label assignment syncs across devices, reconciliation preserves consistency
  - Performance: filtering with 50+ labels, 1000+ tasks
- **Golden tests** (optional): chip visuals across themes/sizes for regression detection
- **Analyzer/test runs via MCP**:
  - `dart-mcp.analyze_files` before each PR
  - Targeted test runs: `dart-mcp.run_tests` on `lib/features/labels` and related files
  - Full suite: `dart-mcp.run_tests` before merge

## Risks & Mitigations

- **Sync Conflicts on `metadata.labelIds`** — Standard vector clock conflict resolution applies (labelIds is just another metadata attribute); winning metadata state (per vclock comparison) becomes authoritative, reconciliation ensures `labeled` table matches; no special label-specific merge logic needed.
- **Performance with Large Label Sets** — `labeled` table with B-tree indexes provides O(log n) lookups; real benefit is avoiding loading all tasks into memory and deserializing metadata for filtering; profiling logs during QA; monitor query performance in production.
- **UX Complexity** — Keep assignment UI lightweight (start with simple multi-select); gather feedback before adding advanced filter modes ("All of", "Without").
- **Color Accessibility** — 16 preset colors (via `flex_color_picker` custom swatches) will be designed with WCAG AA contrast compliance; HSV wheel allows any color but presets encourage accessible choices; text color auto-switches (white/black) based on luminance; document color choices and contrast ratios in README.
- **Legacy Tags Confusion** — Clear naming (labels vs tags) in UI and docs; consider migration tool or deprecation notice in future release; for v1, coexist gracefully.
- **Reconciliation Performance on Bulk Sync** — Reconciliation runs per-entry, not in batches; diff-based approach helps by only touching changed labels (not all labels on every save); monitor sync performance during QA; optimize with batch inserts/deletes if needed.
- **Soft-Deleted Label References** — When label definitions are soft-deleted but still referenced in entry metadata: filter out deleted labels in UI, show warning in settings if detected, optional cleanup job to strip from metadata (opt-in).

## Rollout & Monitoring

- Launch behind completed QA pass ensuring label creation, assignment, filtering, and deletion work
  on mobile + desktop.
- Monitor telemetry or user feedback for label adoption and filtering accuracy.
- Plan staged rollout if necessary (feature flag per environment) and coordinate TestFlight notes.
- Schedule retro after release to decide on deprecating old tags or extending labels to other entry
  types (audio, checklists).

## Decisions

- **Data Model**: Follow the tags pattern — `LabelDefinition` stored via `EntityDefinition` (no extra Drift table), `metadata.labelIds` is authoritative, and the `labeled` denormalized table supports efficient filtering.
- **Reconciliation**: Runs on every entity save (including sync ingestion) to keep `labeled` table in sync with metadata; self-healing, idempotent.
- **Scope**: Labels remain task-focused for initial release; system designed to be extensible for journal/audio integration without migrations.
- **Sync**: Definitions stay per-workspace (single-user scope) and sync across devices via existing `SyncMessage.entityDefinition`; no multi-team sharing needed.
- **Analytics**: No new analytics events for label lifecycle or filter usage in v1, keeping telemetry footprint unchanged.
- **Color Picker**: Use `flex_color_picker` package (new dependency) with hybrid mode: `ColorPickerType.custom` for 16 curated WCAG AA compliant preset colors + `ColorPickerType.wheel` for full HSV custom color picking; provides both quick selection and unlimited flexibility; colors will be defined in Phase 2 as part of UI implementation.
- **Label Groups**: Deferred to post-v1; data model includes `groupId` field for future extension but no UI or validation in initial release.
- **Filter Modes**: Start with "Any of" mode (OR logic); defer "All of" (AND) and "Without" (NOT) to post-v1 based on user feedback.
- **Tags Coexistence**: Labels and tags coexist in v1; evaluate deprecation or migration strategy in post-launch retro.
- **Label Deletion**: Deleting a label cascades removal across tasks by stripping the ID from each entry’s metadata and re-saving—reconciliation then clears `labeled` rows; no orphaned IDs.
