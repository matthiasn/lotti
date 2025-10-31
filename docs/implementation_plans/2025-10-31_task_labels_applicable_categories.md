# Task Labels – Applicable Categories Plan

Refers to and builds on: `docs/implementation_plans/2025-10-26_task_labels_system.md`.

## Summary

- Extend labels with optional “applicable categories” so some labels are global (usable anywhere)
  while others are scoped to specific categories (e.g., Work-only labels).
- Keep the data model simple: store a list of category IDs on each `LabelDefinition`; empty or null
  means global.
- Avoid premature DB-side filtering optimizations; instead, construct an efficient in-memory lookup
  in `EntitiesCacheService` and let presentation filter via a union of “global” and “current
  category” labels.
- Fit into the existing labels architecture described in the 2025‑10‑26 plan: same storage table (
  `label_definitions`), same sync path, same repository layer.

## Goals

- Add `applicableCategoryIds` set to `LabelDefinition` and serialize it (Freezed/JSON) without 
  schema changes.
- Build a cache of available labels per category in `EntitiesCacheService`, with a separate “global”
  bucket.
- Scope the label selection UI for tasks to the union of “global” + “current task category” labels.
- Add category selection to the label editor in Settings (multi-select with add/remove affordances).
- Keep analyzer/tests green, preferably after each file edit or only a few edits; update docs and 
  CHANGELOG.

## Non‑Goals

- No DB migrations or extra indices for category → label queries (use cache).
- No “secondary search field” packing category IDs for SQL substring search.
- No server analytics changes or team/shared label semantics.

## Current Findings (grounded in code)

- `LabelDefinition` currently has no category scoping fields (Freezed union): see
  `lib/classes/entity_definitions.freezed.dart:2970`.
- Labels are cached by ID and listed via `EntitiesCacheService.sortedLabels`; privacy filtering is
  respected there: `lib/services/entities_cache_service.dart:47`.
- Settings editor for labels exists (`LabelEditorSheet`) with name/description/color/private fields:
  `lib/features/labels/ui/widgets/label_editor_sheet.dart:1`.
- Task label picker shows all visible labels (not category-scoped):
  `lib/features/tasks/ui/labels/task_labels_sheet.dart:1`.
- Repository and DB:
  - Labels CRUD via `LabelsRepository`: `lib/features/labels/repository/labels_repository.dart:1`.
  - `label_definitions` table persists serialized JSON; no migration needed for new JSON fields:
    `lib/database/database.drift:90` and mapping in `lib/database/database.dart:930`.

## Design Overview

1. Data model: add `List<String>? applicableCategoryIds` to `LabelDefinition`. Null/empty → label is
   global.
2. Cache: extend `EntitiesCacheService` to maintain:
  - `Map<String, List<LabelDefinition>> labelsByCategoryId` (per category)
  - `List<LabelDefinition> globalLabels` (no category restriction)
    Both rebuilt whenever label definitions change; optionally prune unknown category keys on
    category changes.
3. UI:
  - Task label picker uses union of `globalLabels ∪ labelsByCategoryId[currentCategoryId]`, sorted
    by name, filtered by privacy.
  - Label editor gains a “Categories” section to add/remove applicable categories (multi-select).
    Use existing category picker as an add flow.
4. Repository: plumb `applicableCategoryIds` through create/update; validate category IDs exist.
5. Notifications: reuse existing `LABELS_UPDATED` signal; picker and wrappers already react to label
   changes.

## Data Model

- Update Freezed union:
  - `LabelDefinition` → add `List<String>? applicableCategoryIds`.
  - Regenerate via build_runner; generated `*.g.dart`/`*.freezed.dart` files will handle JSON.
- Persistence remains in `label_definitions.serialized`; no schema change required.
- Backward compatibility: older labels without the field deserialize with `null` → treated as
  global.

## Caching

- Extend `EntitiesCacheService` label watcher to build fast lookups:
  - Clear and repopulate `labelsById` (existing).
  - Compute
    `globalLabels = labels.where((l) => (l.applicableCategoryIds == null || l.applicableCategoryIds!.isEmpty))`.
  - Compute `labelsByCategoryId = {}` and for each label with ids, push it into each `categoryId`
    bucket.
  - Optionally sort each bucket A→Z on name for convenient UI consumption.
  - Respect `showPrivate` at the call sites (as done today in wrappers) rather than mutating cache
    state.
- Expose a convenience method:
  - `List<LabelDefinition> availableLabelsForCategory(String? categoryId, {bool includePrivate})` →
    returns union of global + bucket for `categoryId` (or just global if null), sorted.
  - Also react to category updates: on category list changes (`watchCategories`), prune buckets for
    deleted/inactive categories and rebuild the map to avoid stale keys.

## UI & UX

1. Task label picker (`lib/features/tasks/ui/labels/task_labels_sheet.dart`)
  - Maintain reactivity with Riverpod: create
    `availableLabelsForCategoryProvider = Provider.family<List<LabelDefinition>, String?>((ref, categoryId) {
      final all = ref.watch(labelsStreamProvider).valueOrNull ?? const <LabelDefinition>[];
      final cache = getIt<EntitiesCacheService>();
      return cache.filterLabelsForCategory(all, categoryId, includePrivate: cache.showPrivateEntries);
    });`
  - Handle async entry state: `final entryState = ref.watch(entryControllerProvider(id: taskId));`
    and `final categoryId = entryState.value?.entry?.meta.categoryId;` (fall back to global-only when
    null/loading/error).
  - Source list via `ref.watch(availableLabelsForCategoryProvider(categoryId))`, then apply the local
    search filter and render.
  - Keep creation flow identical; a newly created label defaults to global unless categories are
    added in the editor.

2. Label editor (`lib/features/labels/ui/widgets/label_editor_sheet.dart` + controller)
  - Add a “Categories” section with:
    - A Wrap of selected category chips, each removable via a trailing “remove” affordance.
    - A “+ Add category” button opening `CategorySelectionModalContent` to add one at a time.
  - Persist the selected set via `LabelEditorController` state (new
    `selectedCategoryIds: Set<String>`).
  - Save path passes `applicableCategoryIds` to repository create/update.
  - For deletion in details view, support swipe/remove on the chip row as discussed.
  - Localization: add strings such as “Applicable categories”, “Add category”, and removal hints;
    add ARB keys and run `make l10n`.
  - Placement: insert the Categories section immediately after the ColorPicker container and before
    the `SwitchListTile.adaptive` (Private toggle) to group “appearance” controls above and privacy
    below.

3. Settings list (`lib/features/labels/ui/pages/labels_list_page.dart`)
  - Show small category pills under each label for discoverability.

## Repository & Validation

- `LabelsRepository.createLabel/updateLabel` → add optional `List<String>? applicableCategoryIds`.
- On save, validate that each category ID exists (`EntitiesCacheService.getCategoryById`) and
  de‑dup.
- Maintain stable sort of `applicableCategoryIds` (A→Z by category name) for predictable diffs.

## Notifications & Sync

- No new notifications required; `EntitiesCacheService` rebuild occurs on `watchLabelDefinitions()`.
- Sync continues to ship the `LabelDefinition` JSON (now with `applicableCategoryIds`) via
  `SyncMessage.entityDefinition`.

## Performance Notes

- Constructing the per‑category map is O(n · k) once per label change (n labels, k category refs).
  For typical sets (≤100 labels, ≤20 categories) this is negligible.
- Add a basic perf test measuring union computation for 50–500 labels and 5–50 categories.
- Avoid SQL substring tricks; if needed later, reconsider once we have evidence.

## Migration

- None. Old labels deserialize with `null` `applicableCategoryIds` and are treated as global.

## Testing Strategy

- Unit
  - `EntitiesCacheService.availableLabelsForCategory` with combinations: only global, only scoped,
    mixed, privacy on/off, unknown category.
  - `LabelsRepository` create/update with valid/invalid category IDs and duplicate handling.
- Widget
  - Task labels sheet filters by category and search; union of global + category bucket.
  - Label editor categories section: add, remove, persist, and reload existing values.
- Integration
  - End‑to‑end: create scoped/global labels → assign on tasks in different categories → verify
    available sets and persistence.
- CI discipline per AGENTS.md
  - `dart-mcp.analyze_files` (zero warnings), targeted `dart-mcp.run_tests` for new suites, then
    full run.

## Risks & Mitigations

- UX complexity in editor → Start simple (chips + add dialog); iterate after feedback.
- Privacy filtering inconsistencies → Continue to apply privacy at UI read time using
  `cache.showPrivateEntries`.
- Category deletions leaving orphaned IDs → UI hides unknown categories; consider a cleanup in a
  follow‑up.

## Additional Considerations

- Label deletion cascade: strip orphaned `applicableCategoryIds` on label edits/saves so the JSON
  payload stays clean.
- Sync conflicts: vector-clock merge applies to the whole `LabelDefinition`; devices missing some
  categories may temporarily hold orphaned IDs. Repository validation cleans these up on first
  subsequent edit; UI hides unknown categories meanwhile.
- Bulk assignment: add a batch action in the labels list page to select multiple labels and
  assign/remove categories at once.

## Rollout

- Land behind green analyzer/tests. No migrations required.
- Update feature READMEs (labels, tasks) and `CHANGELOG.md`.
- QA: verify union logic, editor flows, and sync across devices.

## Decisions

- Model field name: `applicableCategoryIds` (explicit and future‑proof).
- Global labels = `null`/empty list of categories.
- Cache over DB search; union at presentation time.
- Editor uses existing category selection modal for “add one at a time”.

## Step‑By‑Step Implementation (Reordered)

1. Model & Codegen
  - Add `applicableCategoryIds` to `LabelDefinition` in `lib/classes/entity_definitions.dart`.
  - Run codegen: `make build_runner`.
2. Repository
  - Extend `createLabel/updateLabel` to accept and persist `applicableCategoryIds`.
  - Validate IDs via `EntitiesCacheService.getCategoryById`, de‑dup, and keep stable order by
    category name.
3. Cache
  - Extend `EntitiesCacheService` to compute `globalLabels` and `labelsByCategoryId` on
    `watchLabelDefinitions()` and prune on `watchCategories()`.
  - Add helpers: `availableLabelsForCategory` and `filterLabelsForCategory`.
4. UI – Editor
  - `LabelEditorController`: new `selectedCategoryIds` state + setters.
  - `LabelEditorSheet`: categories chips + “Add category” flow; wire to controller; pass IDs to repo
    on save; add ARB keys and run `make l10n`.
5. UI – Task Picker
  - Add `availableLabelsForCategoryProvider` (provider.family) using `labelsStreamProvider` and the
    cache helper; handle `entryControllerProvider` AsyncValue for category ID.
  - Keep search filter and privacy behavior.
6. Docs & QA
  - Update feature READMEs and `CHANGELOG.md`.
  - Analyzer/tests via `dart-mcp` (targeted first & often, full runs before merge).
