# Journal

The journal is Lotti's entry workspace — the place where everything the user
records lives, and the substrate almost every other feature builds on.

An "entry" here is not just a note. Tasks, events, voice recordings, photos,
measurements, survey responses, workouts, habit completions, checklists, AI
responses and ratings are all journal entries with different shapes.

## What it does for the user

- **Keeps one place for everything recorded.** Text notes, voice memos, photos,
  screenshots, measurements — all in one chronological logbook.
- **Reads and writes comfortably on any screen.** On a wide window the logbook
  sits beside the entry being read; on a phone it opens as its own page. The
  desktop view opens on the newest entry so there is something to read
  immediately.
- **Finds entries by text or by meaning.** Full-text search, and — when enabled —
  semantic search that finds entries by what they are about rather than the exact
  words.
- **Filters the feed.** By entry type, category, label, starred, flagged or
  private, with the filter state remembered per tab.
- **Links entries together.** Any entry can be linked to any other, with the
  linked list sortable, filterable, and able to highlight whatever is currently
  being timed.
- **Captures quickly.** Create from the button, paste an image from the
  clipboard, drag a file onto an entry, take a screenshot, or start a recording —
  all from the same place.
- **Never silently loses an edit.** Unsaved text is kept as a draft, survives
  navigating away, and can be discarded deliberately.
- **Corrects times honestly.** Start and end times are edited together with a
  calendar and time wheels, including entries that cross midnight, with the
  timezone preserved.

## What it owns

Single-entry detail pages and the shared detail controller; the paged
journal/tasks browse controller and its persisted filter state; full-text and
vector search orchestration; create, import and paste entry points; linked-entry
rendering, link mutation, focus intents and scroll highlighting; and repository
helpers for common entry and link mutations.

It does not own every entity-specific summary or form. Tasks, ratings, speech,
AI, measurements and projects plug their own UI into the journal surface — the
journal feature is the switchboard they plug into.

## Where the code lives

```text
lib/features/journal/
├── model/ · repository/ · state/
├── ui/
│   ├── mixins/ · pages/
│   └── widgets/{create,editor,entry_details}
└── util/ · utils/
```

## How it works

The runtime architecture — the two controller centers, the split-pane routing
model, the detail state machine and its save path, the page controller's search
modes and pagination, and the linked-entry machinery — is documented in the
knowledge bundle:

**→ [knowledge/features/journal/](../../../knowledge/features/journal/)**
