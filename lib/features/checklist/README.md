# Checklist

This feature is **not** the checklist UI — checklists on tasks live in
[tasks](../tasks/README.md).

What lives here is the small service that watches how users rewrite checklist item
titles and turns that into guidance for the AI.

## What it does for the user

- **Learns from corrections.** When a user rewrites a suggested checklist item,
  that before-and-after pair becomes an example for the area, so future
  suggestions read more like the user writes.
- **Ignores noise.** Typo fixes, capitalization changes and repeated edits are
  filtered out rather than recorded as lessons.
- **Can be undone.** A rename shows an undo affordance, and the save is delayed
  long enough that undoing it means nothing was learned.

## What it owns

Capture of meaningful title corrections; delayed save with undo; duplicate and
trivial-change filtering; and persistence of correction examples onto categories.

## Where the code lives

```text
lib/features/checklist/
```

## How it works

Why the filtering and the delay matter, and where the resulting examples are
consumed, are documented in the knowledge bundle:

**→ [knowledge/features/checklist/](../../../knowledge/features/checklist/)**
