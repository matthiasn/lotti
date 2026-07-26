# Labels

Labels are Lotti's flexible tagging layer — more casual than an area, more
expressive than a status, and cheap to attach to anything.

## What it does for the user

- **Tags anything.** Labels attach to entries and tasks, with a name, a color and
  an optional description.
- **Stays relevant per area.** A label can be global or limited to specific areas,
  so the picker for a work task does not offer household labels.
- **Never strands a label.** A label already assigned stays visible in the picker
  even if it is now out of scope for that area — so it can always be removed.
- **Creates on the spot.** A new label can be created from inside the picker and
  is selected immediately.
- **Can be suggested by AI, with memory.** Agents can propose labels for a task;
  removing a suggested label tells the app not to suggest it for that task again.
- **Can be private.** Private labels stay out of shared surfaces.
- **Shows where it is used.** The settings list shows how many entries carry each
  label.

## What it owns

Label definition CRUD; visibility-aware definition streams; category-scoped
availability filtering; usage counts; reusable label display and picker helpers;
and the task-side AI assignment validation, suppression and add-only persistence.

It does not own every label UI surface — the shared picker lives here, but the
task header's label surface lives in [tasks](../tasks/README.md).

## Where the code lives

```text
lib/features/labels/
├── constants/ · repository/ · services/ · state/
└── ui/{pages,widgets}
```

## How it works

The separation of definitions from assignment, the three persistence concerns,
the suppression coupling that feeds AI suggestions, and the AI assignment flow
are documented in the knowledge bundle:

**→ [knowledge/features/labels/](../../../knowledge/features/labels/)**
