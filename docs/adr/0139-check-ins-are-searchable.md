# ADR 0139: Check-ins Are Searchable

- Status: Accepted
- Date: 2026-10-15
- Supersedes: [ADR 0064](./0064-check-ins-appear-in-the-logbook.md) decision 3

## Context

ADR 0064 put check-ins in the Logbook feed and kept them out of search:
a typed search dropped `CheckIn` from the queried types, and check-ins were
not embedded. It cited "ADR 0037's boundary" as the reason.

ADR 0037 states no such boundary. Its decisions are local storage,
end-to-end encrypted sync, no retention outside the user's devices, the
`private` flag, and the delete cascade. None of them mentions search.

The exclusion protected nothing:

- Search runs on the device, against the device's own database, for its own
  user. Nothing about a person leaves the device because of it.
- The check-ins it hid were already in the feed, a scroll away.
- The `private` flag already covers the case where someone else sees the
  screen.

It did have a cost. ADR 0138 made the notes, voice notes and photos on a
person's timeline searchable, for the reasons above. So a note about a call
was found, while the call's own check-in was not.

## Decision

1. **A typed Logbook search returns check-ins like any other entry.**
   `JournalQueryRunner` no longer drops `CheckIn` when a query is present.
2. **A check-in is indexed by more than its note.** The full-text index also
   carries its topics and its *Pay attention to* / *Avoid* lines, so a
   search for what a conversation was about finds it.
3. **Privacy is the `private` flag, as everywhere else.** A check-in
   inherits its person's flag when it is written. No surface changes a
   person's privacy afterwards today; one that is added must carry the
   change to the person's check-ins and timeline entries, which is what
   ADR 0037's "private covers the whole person" requires.
4. **Embeddings are unchanged.** Vector search resolves its hits to tasks
   only, so embedding check-ins would add work and no result. A check-in's
   comments and transcripts were already embedded as the entries they are.

## Consequences

- A person's name is still not a search term by itself. A person is not a
  Logbook type (ADR 0064 decision 1 stands); their check-ins are found by
  what they say.
- `knowledge/features/relationships.md` and the feature README no longer
  describe check-ins as unsearchable.

## Related

- [ADR 0037: Relationship Data Stays On-Device](./0037-relationship-on-device-storage-and-privacy.md)
- [ADR 0064: Check-ins appear in the Logbook](./0064-check-ins-appear-in-the-logbook.md)
- [ADR 0138: A Person's Timeline Is Their Relationship Links](./0138-a-persons-timeline-is-their-relationship-links.md)
