# Ratings

Ratings let the user attach a short, structured judgment to something they
recorded — most often "how did that work session go?".

## What it does for the user

- **Asks at the right moment.** When a timed session ends, a rating prompt
  surfaces rather than waiting to be found.
- **Asks a real set of questions**, not a single star. The current catalog covers
  four dimensions of a work session, each with its own scale.
- **Can be reopened and changed.** A rating can be revisited and edited later.
- **Keeps meaning across devices and versions.** Each answer stores the question
  and the scale it was answered against, so a rating stays readable even if the
  questions later change or the device does not know that question set.
- **Accepts a note.** Free text alongside the structured answers.

## What it owns

The rating catalog registry; the modal used to create, review and reopen a
rating; and persistence of `RatingEntry` records plus the link back to the rated
entity.

## Where the code lives

```text
lib/features/ratings/
├── data/          # the catalog registry
├── repository/ · state/
└── ui/
```

## How it works

The model, why each stored dimension snapshots its own schema, and the catalog
registry are documented in the knowledge bundle:

**→ [knowledge/features/ratings/](../../../knowledge/features/ratings/)**
