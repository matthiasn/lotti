# Categories

Categories are how the user divides their life in Lotti — work, health, a
side project, family. Almost everything else is scoped by one.

A category is more than a label: it carries the defaults that decide how the app
behaves inside it, including whether AI runs automatically.

## What it does for the user

- **Organizes everything.** Tasks, entries, recordings and plans all belong to a
  category, and most filters and views are scoped by one.
- **Gives each area its own look.** A name, a color and an icon, so the area is
  recognizable at a glance across lists, charts and the day plan.
- **Sets per-area defaults.** Which AI profile new tasks use, which agent template
  is attached, which language recordings are in, and whether the area shows up in
  day planning.
- **Controls whether AI runs on its own.** Automatic transcription and image
  analysis are opt-in **per area** — choosing an AI profile is not the same as
  agreeing to spend tokens on every recording.
- **Teaches the app its vocabulary.** A per-area speech dictionary and a set of
  correction examples improve how recordings and suggestions come out.
- **Can be private or archived.** Private areas stay out of shared views; inactive
  ones stop appearing in pickers without deleting the history.

## What it owns

The category repository (create, update, soft delete, streamed reads, task
counts); the settings list, detail and create surfaces; and the reusable
category-picking widgets other features embed.

## Where the code lives

```text
lib/features/categories/
├── repository/ · state/
└── ui/{pages,widgets}
```

## How it works

The two read paths, the picker surfaces, the stored defaults every downstream
feature consumes, and the automatic-inference consent flag are documented in the
knowledge bundle:

**→ [knowledge/features/categories/](../../../knowledge/features/categories/)**
