# Events

Events are the moments worth remembering — a trip, a birthday, a wedding, a race
coming up — with their own destination rather than a row in the logbook.

Behind the **Enable Events** flag. With it off, events are hidden everywhere.

## What it does for the user

- **Gives a moment its own page.** A photographic detail page with a cover image,
  a title, when it happened, its status and its rating.
- **Collects everything about it.** Photos, notes and voice memos added to the
  event link straight back to it and appear on its timeline.
- **Turns into work when needed.** A task can be created from an event and stays
  linked to it.
- **Rates a memory, but only once it is a memory.** Stars appear once the event
  has happened, so a plan is not asked to rate itself.
- **Picks its own cover.** The first linked photo becomes the cover; after that
  the user can choose any linked photo.
- **Reads in the user's language.** Statuses and relative dates are rendered in
  the active language, so switching language changes the wording immediately.

## What it owns

The events overview and its grouping; the event detail page and its hero
interactions; the pure view models and mapping logic behind both; and the linked
event card other surfaces render.

An event is its own entity, not a task variant — it reuses the shared entry
infrastructure without inheriting task behaviour.

## Where the code lives

```text
lib/features/events/
├── model/ · state/
└── ui/{pages,widgets}
```

## How it works

Why events are their own entity, the pure view layer with locale resolved at the
presentation boundary, and the hero interaction surface are documented in the
knowledge bundle:

**→ [knowledge/features/events/](../../../knowledge/features/events/)**
