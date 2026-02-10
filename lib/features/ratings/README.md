# Ratings Feature

Ratings let users rate any target entry (time recordings, tasks, day plans,
etc.) across multiple configurable dimensions with an optional freeform note.
Which dimensions are shown — and how they are collected — is defined by a
rating catalog rather than being hard-coded, so new rating contexts (e.g.
morning check-in, task completion review) can be added without code changes.

## Architecture

### Catalog-Driven Design

Rating questions are defined in **catalogs** — localized question sets
registered in `data/rating_catalogs.dart`. The `ratingCatalogRegistry` maps a
`catalogId` string to a factory function that produces a `List<RatingQuestion>`
given the current `AppLocalizations`.

Each question specifies:
- `key` — unique dimension identifier (e.g. `'productivity'`)
- `question` — localized prompt shown to the user
- `description` — human-readable explanation stored for analytics
- `inputType` — `'tapBar'` (continuous 0-1) or `'segmented'` (discrete choices)
- `options` — for segmented inputs, a list of `(label, value)` pairs

### Self-Describing Records

When a rating is saved, each `RatingDimension` snapshots the question metadata
(question text, description, inputType, optionLabels) from the catalog at that
moment. This makes stored ratings fully self-describing — they can be rendered
without access to the original catalog definition.

### Unknown Catalog Guard

Ratings with an unrecognized `catalogId` (e.g. received via sync from a newer
client) render in **read-only mode**: stored dimensions are displayed using
their snapshotted metadata, with no save button.

### Label Fallback Chain

When displaying a dimension label, the summary view resolves through:
1. **Stored `dimension.question`** (captured at rating time)
2. **Catalog lookup** (if the catalogId is registered locally)
3. **Dimension `key`** (last resort)

## Directory Structure

```
ratings/
  data/
    rating_catalogs.dart    # Catalog registry and session catalog definition
  repository/
    rating_repository.dart  # Persistence: create, update, fetch ratings
  state/
    rating_controller.dart  # Riverpod async controller per (targetId, catalogId)
    rating_prompt_controller.dart  # Triggers the rating modal after timer stop
  ui/
    session_rating_modal.dart   # Modal bottom sheet (editable + read-only views)
    rating_summary.dart         # Read-only summary shown in entry details
    rating_input_widgets.dart   # Reusable input widgets (RatingTapBar, RatingSegmentedInput)
    rating_prompt_listener.dart # Widget-tree listener that shows the modal
```

## Data Model

- `RatingData` — stored in `JournalEntity.rating`, contains `targetId`,
  `catalogId`, `dimensions`, and optional `note`
- `RatingDimension` — a single rated dimension with `key`, `value` (0.0-1.0),
  and optional snapshotted metadata (`question`, `description`, `inputType`,
  `optionLabels`)
- `RatingEntry` is linked to its target entry (`targetId`) via `RatingLink`

## Adding a New Catalog

1. Define a factory function in `data/rating_catalogs.dart` that returns
   `List<RatingQuestion>` given `AppLocalizations`
2. Register it in `ratingCatalogRegistry` with a unique `catalogId`
3. Add localized strings to all `.arb` files
4. Call `RatingModal.show(context, targetId, catalogId: 'your_id')` or
   use `RatingPromptController.requestRating(targetId: ..., catalogId: ...)`
