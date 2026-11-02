# Events

Events are the moments worth remembering — a trip, a birthday, a wedding, a race
coming up — with their own destination rather than a row in the logbook.

Behind the **Enable Events** flag. With it off, events are hidden everywhere.

## What it does for the user

- **Gives a moment its own page.** A photographic detail page with a cover image,
  a title, when it happened, its status and its rating.
- **Collects everything about it.** Photos, notes and voice memos added to the
  event link straight back to it and appear on its timeline. Photos open in a
  swipeable full-screen gallery that follows phone rotation on iOS and Android.
- **Grows from one bar.** An event's page ends in the same bar an entry's page
  has: **Add a task** creates a preparation or follow-up task linked to the
  event and opens it, the record button captures a voice memo for it, and the
  plus opens the full **Add** menu for photos, notes and the rest. The
  **Tasks** section appears once the first task is linked.
- **Finds a moment fast.** The overview's search field matches event titles and
  notes as you type, and the filter narrows to one or more categories — the
  same header, filter sheet and removable chips as the Tasks tab.
- **Shows up on the day.** An event with a start and end sits on the Daily OS
  Day timeline at that time, beside recorded work, and opens from there. A
  cancelled, missed or postponed one stays off it.
- **Rates a memory, but only once it is a memory.** Stars appear once the event
  has happened, so a plan is not asked to rate itself, and sit in the header's
  state row beside the category and status.
- **Remembers who it was with.** People from the People page can be added
  to an event; each one is a chip that opens their page, and the event
  appears on each person's timeline — adding someone to an event and
  putting the event on their timeline are the same thing.
- **Says what happened.** With an event agent attached, its recap's one-liner
  reads under the title and its summary in the card below; each photo on the
  timeline carries the one-line caption its image analysis wrote, or the
  user's own note. An event without an agent offers **Assign Agent** in that
  card, the same row a task without one shows.
- **Describes a photo for what it shows.** A photo added to an event is
  analysed in the light of the event — its title, time and note — never as
  if it belonged to a task, and a tap on it in the timeline opens the whole
  analysis, with the way through to the photo's own entry.
- **Keeps one language.** The event agent sets the event's language from its
  first voice memo; the recap, its suggestions, the photo analyses and the
  recording summaries are written in it. It shows beside the status, where
  the user can pick another — a choice the agent never overrides.
- **Suggests what you did not write down.** Besides the people the event
  names and follow-up tasks, the agent can suggest a note of what happened,
  shown in full under the recap; confirming adds it to the timeline as the
  user's own note.
- **Can be found by asking.** With on-device search on, an event and its
  recap are indexed, so the journal's questions can find it by what happened
  and who was there.
- **Picks its own cover, until told otherwise.** The newest linked photo stands
  in as the cover until the user chooses one — from the full-screen viewer with
  **Set cover** on the photo in view, or from the **Change cover** picker in
  the header's menu. The gallery badges the chosen cover, and the header says
  **Set cover** while the cover is only the default.
- **Reads in the user's language.** Statuses and relative dates are rendered in
  the active language, so switching language changes the wording immediately.

## What it owns

The events overview, its search and category filter, and its grouping; the event detail page and its hero
interactions; the pure view models and mapping logic behind both; and the linked
event card other surfaces render.

An event is its own entity, not a task variant — it reuses the shared entry
infrastructure without inheriting task behaviour.

## Where the code lives

```text
lib/features/events/
├── state/
└── ui/{model,pages,widgets}
```

## How it works

Why events are their own entity, the pure view layer with locale resolved at the
presentation boundary, the hero interaction surface and the docked action bar
are documented in the knowledge bundle:

**→ [knowledge/features/events.md](../../../knowledge/features/events.md)**
