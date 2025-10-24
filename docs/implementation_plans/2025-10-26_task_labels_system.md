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
  is reflected in entry links for performant search.
- Cover the feature with migration/logic/unit/widget tests and document the new UX for QA and
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
- Review `tasks_filter` implementation and UI to confirm integration points for label filters and ensure filter state persists (respecting the zero-warning policy described in `AGENTS.md`).

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

   **Why required**: Task filtering by labels needs indexed queries. Without this table, you'd have to load all tasks into memory and deserialize metadata—completely impractical.

### Reconciliation Strategy

**On every entity save** (including sync ingestion), the persistence layer reconciles the `labeled` table with `metadata.labelIds`:

```dart
// Pseudo-code for lib/logic/persistence_logic.dart
Future<void> _reconcileLabels(JournalEntity entity) async {
  final authoritativeLabelIds = entity.meta.labelIds ?? [];
  final currentLabelIds = await db.labeledForEntry(entity.meta.id);

  // Calculate diff
  final toAdd = authoritativeLabelIds - currentLabelIds;
  final toRemove = currentLabelIds - authoritativeLabelIds;

  // Apply changes (idempotent, self-healing)
  for (final labelId in toRemove) {
    await db.deleteLabeledRow(entity.meta.id, labelId);
  }
  for (final labelId in toAdd) {
    await db.insertLabeledRow(uuid.v1(), entity.meta.id, labelId);
  }
}
```

**Benefits over entry links approach**:
- Single source of truth (metadata only)
- Simpler sync (no dual reconciliation needed)
- Self-healing (reconciliation corrects drift automatically)
- Proven pattern (identical to tags implementation)
- No risk of metadata/link inconsistency

## Design Overview

1. **Label Settings Entity**
  - Model: `LabelDefinition` as `EntityDefinition` variant (syncs via existing `SyncMessage.entityDefinition`)
  - Fields: `id`, `name`, `color`, `description?`, `groupId?` (for future label groups), `sortOrder`, standard sync fields
  - Storage: synced via `SyncMessage.entityDefinition`; Riverpod provider for CRUD
  - UI: new Settings page reusing category management scaffolding, modern card list, curated 4×4 color picker, create/edit dialogs
  - Description tooltips: Display on hover (Linear pattern) to explain when label applies

2. **Assignment Workflow**
  - Task header: add label selector (pill chips or dropdown) allowing quick add/remove; keyboard accessible
  - Persist `labelIds` in `metadata`; persistence layer auto-reconciles `labeled` table on save
  - Task cards: render chips with color + text; handle overflow via wrap or ellipsis with tooltip
  - Repository: `LabelsRepository` follows `TagsRepository` pattern for add/remove operations

3. **Filtering**
  - Extend Tasks filter drawer to include label filter with "Any of" mode (default)
  - Filter queries use `labeled` table joins (efficient, no N+1 lookups)
  - Persist label filter state using `JournalPageState.selectedLabelIds` (mirrors `selectedCategoryIds` pattern)
  - Future enhancement: "All of" and "Without" modes if needed

4. **Sync & Integrity**
  - **Reconciliation runs on every save** (including sync ingestion) via `PersistenceLogic._reconcileLabels`
  - `metadata.labelIds` is authoritative; `labeled` table mirrors it deterministically
  - On label deletion: option to remove label ID from all entries' metadata (cascade cleanup) or leave orphaned IDs
  - Label rename: no action needed (metadata stores IDs, display updates automatically)
  - Self-healing: reconciliation corrects any drift between metadata and `labeled` table

5. **Accessibility & Visual Design**
  - Provide color contrast fallback (text color switching white/black based on luminance)
  - Add `Semantics` labels for screen readers (`Label: bug`)
  - Ensure chips shrink gracefully on mobile; support dark/light themes
  - Curated color grid (4×4) reusing category palette tokens for consistent branding

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
  - Queries: `labeledForEntry`, `deleteLabeledRow`, insert via Drift
- Implement reconciliation logic in `lib/logic/persistence_logic.dart`:
  - `_reconcileLabels(JournalEntity)` runs on every `updateDbEntity` call
  - Syncs `labeled` table with `metadata.labelIds` (add missing, remove stale)
  - Unit tests: reconciliation correctness, idempotency, edge cases
- Draft `LabelsRepository` following `TagsRepository` pattern (add/remove/list operations)
- Add Riverpod provider scaffolding for labels CRUD

### Phase 2 – Settings & CRUD UI

- Create `lib/features/labels/` module structure (repository, state, ui)
- Implement Settings page for labels:
  - List existing labels with edit/delete actions
  - Modal/dialog for create/edit (name, color, optional description)
  - Curated 4×4 color grid reusing category palette tokens
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
  - Multi-select chips (similar to category filter)
  - "All" / "Unassigned" / individual labels
  - Show active filters count
- Optional quick filter in list header (chips representing active filters)
- No new analytics events (per decisions section)

### Phase 5 – Polish, Testing & Documentation

- Migration/backfill for existing entries:
  - One-time script to populate `labeled` table for entries with `labelIds`
  - Runs on first app launch after upgrade
  - No-op if table already populated
- Label deletion flow:
  - Confirmation dialog warning about affected tasks
  - Option to remove label from all tasks or leave orphaned IDs
  - Soft delete pattern (set `deletedAt`) with cleanup job
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
  - `PersistenceLogic._reconcileLabels`: add/remove/idempotency cases
  - Label filter serialization (`TasksFilter.fromJson/toJson`)
  - Edge cases: empty labels, missing label definitions, orphaned IDs
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

- **Sync Conflicts on `metadata.labelIds`** — Mitigate with metadata-as-source-of-truth, reconciliation auto-corrects drift, vector clock conflict resolution via existing sync logic.
- **Performance with Large Label Sets** — `labeled` table with indexes ensures O(1) lookups; profiling logs during QA; monitor query performance in production.
- **UX Complexity** — Keep assignment UI lightweight (start with simple multi-select); gather feedback before adding advanced filter modes ("All of", "Without").
- **Color Accessibility** — Curated 4×4 palette enforces WCAG AA contrast; text color auto-switches (white/black) based on luminance; document guidelines in README.
- **Legacy Tags Confusion** — Clear naming (labels vs tags) in UI and docs; consider migration tool or deprecation notice in future release; for v1, coexist gracefully.
- **Reconciliation Performance on Bulk Sync** — Reconciliation runs per-entry, not in batches; monitor sync performance during QA; optimize with batch inserts/deletes if needed.
- **Orphaned Label IDs** — Handle gracefully: filter out deleted labels in UI, show warning in settings if orphaned IDs detected, cleanup job to remove from metadata (opt-in).

## Rollout & Monitoring

- Launch behind completed QA pass ensuring label creation, assignment, filtering, and deletion work
  on mobile + desktop.
- Monitor telemetry or user feedback for label adoption and filtering accuracy.
- Plan staged rollout if necessary (feature flag per environment) and coordinate TestFlight notes.
- Schedule retro after release to decide on deprecating old tags or extending labels to other entry
  types (audio, checklists).

## Decisions

- **Data Model**: Follow the tags pattern — `metadata.labelIds` is authoritative, `labeled` denormalized table required for efficient filtering, no entry links approach.
- **Reconciliation**: Runs on every entity save (including sync ingestion) to keep `labeled` table in sync with metadata; self-healing, idempotent.
- **Scope**: Labels remain task-focused for initial release; system designed to be extensible for journal/audio integration without migrations.
- **Sync**: Definitions stay per-workspace (single-user scope) and sync across devices via existing `SyncMessage.entityDefinition`; no multi-team sharing needed.
- **Analytics**: No new analytics events for label lifecycle or filter usage in v1, keeping telemetry footprint unchanged.
- **Color Picker**: Curated 4×4 color grid reusing category palette tokens for consistent branding and accessibility.
- **Label Groups**: Deferred to post-v1; data model includes `groupId` field for future extension but no UI or validation in initial release.
- **Filter Modes**: Start with "Any of" mode (OR logic); defer "All of" (AND) and "Without" (NOT) to post-v1 based on user feedback.
- **Tags Coexistence**: Labels and tags coexist in v1; evaluate deprecation or migration strategy in post-launch retro.
