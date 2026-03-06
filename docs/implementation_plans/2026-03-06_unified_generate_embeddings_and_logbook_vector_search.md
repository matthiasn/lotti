# Unified Generate Embeddings & Logbook Vector Search

**Date:** 2026-03-06
**Branch:** `feat/unified-generate-embeddings`

## Goal

Consolidate the two separate embedding maintenance actions ("Backfill Embeddings"
and "Re-index All Embeddings") into a single "Generate Embeddings" action with
multi-category selection, and enable vector/semantic search in the Logbook tab.

## Steps

### Step 1: Rename labels in all ARB files

Replace "Backfill Embeddings" with "Generate Embeddings" across all 6 locale
files (`app_en.arb`, `app_cs.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`,
`app_ro.arb`). Keys affected:

- `maintenanceBackfillEmbeddings` -> title
- `maintenanceBackfillEmbeddingsConfirm` -> confirm button
- `maintenanceBackfillEmbeddingsDescription` -> subtitle
- `maintenanceBackfillEmbeddingsMessage` -> modal message

Also update the message to reflect multi-select: "Select categories to generate
embeddings for."

### Step 2: Multi-select category picker with select/unselect all

**File:** `lib/features/ai/ui/settings/embedding_backfill_modal.dart`

- Replace `ValueNotifier<CategoryDefinition?>` with
  `ValueNotifier<Set<String>>` for selected category IDs.
- Switch `CategorySelectionModalContent` to `multiSelect: true`.
- Add a "Select All / Unselect All" toggle above the category list.
- Enable the confirm button when at least one category is selected.

### Step 3: Remove "Re-index All Embeddings" maintenance card

**File:** `lib/features/settings/ui/pages/advanced/maintenance_page.dart`

- Remove the second `AdaptiveSettingsCard` that calls
  `EmbeddingBackfillModal.showReindexAll`.
- Remove the `showReindexAll` static method from `EmbeddingBackfillModal`.
- Remove the `reindexAll()` method from `EmbeddingBackfillController`.
- Remove the orphaned ARB keys: `embeddingReindexAllButton`,
  `embeddingReindexAllDescription`, `embeddingReindexAllWarning`.

### Step 4: Controller accepts multiple category IDs

**File:** `lib/features/ai/state/embedding_backfill_controller.dart`

- Replace `backfillCategory(String categoryId)` with
  `backfillCategories(Set<String> categoryIds)`.
- Collect entity IDs across all selected categories, compute a combined total,
  and process them in a single progress run.

### Step 5: Enable vector search in the Logbook tab

**File:** `lib/widgets/app_bar/journal_sliver_appbar.dart`

- Remove the `state.showTasks` guard from `showVectorToggle` so the search
  mode row also appears on the journal (logbook) tab.

**File:** `lib/features/journal/state/journal_page_controller.dart`

- In `_runQuery`, relax the `_showTasks` gate on vector search so both
  tasks and journal pages can run vector queries.
- The vector search already calls `VectorSearchRepository.searchRelatedTasks`
  which resolves non-task results to parent tasks. For the logbook tab, the
  search should return all matching entity types, not just tasks.

**File:** `lib/features/ai/repository/vector_search_repository.dart`

- Add a `searchRelatedEntries` method (or generalise the existing one) that
  returns any journal entity, not only tasks.

### Step 6: Update tests

- Update `embedding_backfill_modal_test.dart` for multi-select flow.
- Update `embedding_backfill_controller_test.dart` for `backfillCategories`.
- Add/update journal page controller tests for logbook vector search.

### Step 7: Update CHANGELOG and metainfo

- Add entry under the current version in `CHANGELOG.md`.
- Mirror in `flatpak/com.matthiasn.lotti.metainfo.xml`.

### Step 8: Run l10n, format, analyze, test

- `make l10n && make sort_arb_files`
- `dart format .`
- Analyze and fix any warnings.
- Run targeted tests.
