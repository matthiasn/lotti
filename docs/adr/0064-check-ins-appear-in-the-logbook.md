# ADR 0064: Check-ins Appear in the Logbook

- Status: Accepted
- Date: 2026-09-19
- Amends: ADR 0038 Decision 2 (where check-ins are shown); keeps ADR 0037's
  search boundary

## Context

ADR 0038 made a check-in an ordinary journal entry, dated at the interaction,
so that it "sits naturally on calendars and timelines". In practice the
Logbook never showed one: its entry-type filter listed neither relationship
variant, and the relationships concept recorded that absence as deliberate,
alongside ADR 0037's rule that a person cannot be found by name outside the
People tab.

A design panel on 2026-09-19 decided that a check-in is a moment of the user's
day like any other and belongs in the Logbook's timeline, while the people
themselves — and finding them — stay in People.

## Decision

1. **`CheckIn` is a Logbook entry type** with its own filter chip, gated on the
   relationships feature flag like events and habits: with People off, check-ins
   are neither queried nor offered.
2. **The row names the person and opens in People.** It reads "Check-in with
   {name}", shows the note it was logged with, and opens the check-in on the
   person's page with the opens-elsewhere glyph, as an event row opens in
   Events. A person hidden as private, or gone, leaves the row naming the kind
   alone, and a rename or a change in private visibility reaches a row already
   on screen.
3. **People stay out, and so does search.** `Relationship` is not a Logbook
   type. A text search leaves `CheckIn` out of the queried types, and check-ins
   are not embedded for vector search, so a check-in's note cannot surface a
   person outside People — ADR 0037's boundary is unchanged.
4. **Saved selections gain the type once, when it is offered.** A Logbook
   selection saved before the type existed has never had the chance to deselect
   it. It stays pending until the filter offers it — immediately with People
   on, or whenever People is turned on — then joins the selection once; a
   record of the types each saved selection was made with keeps a later
   deselection in place.

## Consequences

- The Logbook reflects the whole day, including the people the user spent it
  with, without widening who can find them.
- A new Logbook entry type no longer disappears for everyone who has ever
  saved a filter: the pending mechanism in `JournalFilterPersistence` applies
  to any type added later.
- Search results and the feed differ for check-ins on purpose; the feed shows
  them, a search never returns them.

## Related

- [ADR 0037: Relationship Data Stays On-Device](./0037-relationship-on-device-storage-and-privacy.md)
- [ADR 0038: Relationship Domain Model](./0038-relationship-domain-model.md)
- [ADR 0062: Check-ins Hold Entries](./0062-check-ins-hold-entries.md)
