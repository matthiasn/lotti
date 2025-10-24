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

- Existing tags data model needs review (`lib/models/task_tag.dart` or similar) to avoid collision;
  labels must use distinct storage keys.
- Categories already provide CRUD with color selection via Riverpod—worth auditing for reusable
  components (`lib/features/settings/categories/...`).
- Tasks persist metadata; confirm where optional metadata lives (`TaskEntity`, `TaskMetadata`) and how it syncs.
- Entry links table currently links entries-to-entries and other metadata. Need to study how link
  types are defined, validated, and synced to extend for label assignments without N+1 lookups.
- Investigate how search index uses entry links vs denormalized columns to ensure the label filter
  stays performant on both platforms.
- Review `tasks_filter` implementation and UI to confirm integration points for label filters and
  ensure filter state persists (respecting the zero-warning policy described in `AGENTS.md`).

## Data Model Options

1. **New Column per Entry**
  - Pros: Direct storage; easier query (e.g., comma-separated IDs or serialized array).
  - Cons: Requires DB migrations on all platforms; higher risk for sync conflicts; increases schema
    surface area.
2. **Entry Metadata + Entry Links (Preferred)**
  - Metadata holds canonical `labelIds` array/set.
  - Persistence layer ensures label link entries (`EntryLinkType.labelAssignment`) mirror metadata
    for fast lookup.
  - Sync treats links as derived; resync/regeneration occurs if discrepancies detected.
  - Mitigation for N+1: extend repository queries to batch-fetch relevant label links when loading
    task lists/search results.

Decision: proceed with Option 2; document the fallback column approach in case future performance
requires it.

## Design Overview

1. **Label Settings Entity**
  - Model: `LabelDefinition` (`id`, `name`, `color`, `description?`, `createdAt`, `updatedAt`).
  - Storage: synced settings table/message; Riverpod provider for CRUD; align naming with settings
    conventions.
  - UI: new Settings page reusing category management scaffolding, modern card list, color picker,
    create/edit dialogs.

2. **Assignment Workflow**
  - Task header: add label selector (pill chips or dropdown) allowing quick add/remove; keyboard
    accessible.
  - Persist `labelIds` in task metadata; ensure `TaskRepository` writes metadata and repopulates
    entry links.
  - Task cards: render chips with color + text; handle overflow via wrap or ellipsis with tooltip.

3. **Filtering**
  - Extend Tasks filter drawer to include multi-select label filters (include `Has any`, `Has all`,
    `Without` modes if feasible; start with `Any of` toggle).
  - Persist label filter state per tab (coordinate with existing persistence using new key to avoid
    collisions).
  - Search integration: interpret label filter to query via entry links or metadata, ensuring no N+1
    queries.

4. **Sync & Integrity**
  - On save/update of any entity supporting labels: reconcile metadata vs entry links (add missing,
    remove stale).
  - On label rename/delete: cascade updates across tasks (rename just affects display since metadata
    stores IDs; deletion removes ID from metadata and links).

5. **Accessibility & Visual Design**
  - Provide color contrast fallback (text color switching white/black based on luminance).
  - Add `Semantics` labels for screen readers (`Label: bug`).
  - Ensure chips shrink gracefully on mobile; support dark/light themes.

## Implementation Phases

### Phase 1 – Analysis & Infrastructure

- Deep-dive existing tag/category code to confirm reusable components and avoid regression.
- Draft `LabelDefinition` model, persistence contract, and Riverpod providers; add storage schema
  docs.
- Create entry link type extension (`label_assignment`) and validation utilities (unit tests).
- Define migration strategy: ensure persistence layer auto-populates links from metadata on
  load/save.

### Phase 2 – Settings & CRUD UI

- Implement Settings page for labels:
  - List existing labels with edit/delete actions.
  - Modal/dialog for create/edit (name, color, optional description).
  - Use shared components (color picker, modern card).
- Add Riverpod tests for CRUD flows and sync serialization.
- Update relevant feature README(s) describing settings workflow.

### Phase 3 – Task Assignment UX

- Update task detail/header widget to display current labels and allow quick assignment.
- Implement label selection sheet/dialog supporting search & multi-select; reuse across
  desktop/mobile with adaptive layout.
- Ensure state updates propagate to metadata/write-through; add widget tests covering assignment
  interactions.
- Display label chips on list cards (responsive layout, semantics, overflow handling).

### Phase 4 – Filtering & Search

- Extend Tasks filter state to include label filters; ensure persistence keys unique and
  mobile/desktop sync.
- Update repository/service queries to honor filters using entry links; add tests to prevent N+1
  regression (mock repository returning pre-batched data).
- Add optional quick filter in list header (e.g., chips representing active filters).
- Verify analytics instrumentation if filters logged; add events as needed.

### Phase 5 – Integrity, Cleanup, Docs

- Implement reconciliation routine ensuring entry links mirror metadata (run on task save, label
  deletion, sync conflict resolution).
- Add migration/backfill script to populate entry links for existing tasks once labels ship (no-op
  initially but scaffolding ready).
- Update README(s), developer docs, and `CHANGELOG.md` summarizing labels feature and QA scenarios.
- Prepare release checklist referencing downstream review flow (Claude → PR → Gemini/CodeRabbit →
  TestFlight iOS/macOS).

## Testing Strategy

- Unit tests: label provider CRUD, metadata/link reconciliation, filter serialization.
- Widget tests: label selection UI, task card chip rendering, filter drawer interactions.
- Golden tests for chip visuals across themes/sizes if feasible.
- Integration tests (optional) ensuring filter results respect labels.
- Analyzer/test runs via MCP: `dart-mcp.analyze_files`, targeted suites, then full
  `dart-mcp.run_tests`.

## Risks & Mitigations

- **Schema Drift or Sync Conflicts** — Mitigate with metadata-as-source-of-truth, deterministic link
  regeneration, and thorough unit tests.
- **Performance Regressions** — Batch-fetch entry links; add profiling logs during QA; fall back to
  denormalized column if monitoring detects issues.
- **UX Complexity** — Keep assignment UI lightweight; gather feedback before adding advanced filter
  modes.
- **Color Accessibility** — Enforce contrast checks and provide fallback palette suggestions;
  document guidelines.
- **Legacy Tags Confusion** — Clearly separate naming (labels vs tags) in UI and docs; optionally
  hide legacy tags from new flows.

## Rollout & Monitoring

- Launch behind completed QA pass ensuring label creation, assignment, filtering, and deletion work
  on mobile + desktop.
- Monitor telemetry or user feedback for label adoption and filtering accuracy.
- Plan staged rollout if necessary (feature flag per environment) and coordinate TestFlight notes.
- Schedule retro after release to decide on deprecating old tags or extending labels to other entry
  types (audio, checklists).

## Decisions

- Labels remain task-focused for the initial release; we will design the system to be extensible so journal/audio integration can be layered on later without migrations.
- Definitions stay per-workspace (single-user scope) and sync across the user’s devices; no multi-team sharing is needed today.
- We will not add new analytics events for label lifecycle or filter usage in v1, keeping telemetry footprint unchanged.
- Provide a curated 4×4 color grid (reusing category palette tokens where possible) so users can quickly pick accessible colors without auto-generated suggestions.
