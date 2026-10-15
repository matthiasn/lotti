# ADR 0138: A Person's Timeline Is Their Relationship Links

- Status: Accepted
- Date: 2026-10-15
- Amends: [ADR 0038](./0038-relationship-domain-model.md) decision 3 (what a
  `RelationshipLink` may point at) and [ADR 0040](./0040-relationship-executive-briefing.md)
  decision 4 (what the briefing reads)

## Context

A person page shows check-ins and, in a separate card, linked tasks. Nothing
else about a person can be recorded. There is no note about where you met,
no gift idea, no photo, and no next meeting. The redesign
([plan](../implementation_plans/2026-10-15_person_timeline_redesign.md))
puts everything about a person on one chronological timeline. That needs a
rule for what "on the person's timeline" means in storage.

Two links already run from a person to journal entries:

- **`RelationshipLink`** binds the person to their check-ins and tasks. It
  syncs, and readers resolve its target by the target's journal `type`.
  Check-ins are read through the indexed `subtype` column, and tasks through
  `getLiveTasksByIds`, which filters `type = 'Task'`.
- **`BasicLink`** from the person carries the avatar and banner pictures, and
  every dictation take, which is recorded against the person before its
  check-in exists. A take whose check-in was discarded keeps only this link.

## Decision

1. **The timeline is the `RelationshipLink` targets from the person, plus
   their check-ins.**
   - The targets may now also be a note (`JournalEntry`), a voice note
     (`JournalAudio`), a photo (`JournalImage`) or a meeting (`JournalEvent`).
   - Each one inherits the person's category and `private` flag.
   - No link variant, entity variant or schema change is needed, so ADR 0042
     needs no amendment.
   - Readers on older builds keep filtering by type, so they ignore the new
     targets rather than misreading them.
2. **A `BasicLink` from the person never puts anything on the timeline.**
   The pictures and stray takes it carries are not things the user put
   there, so the two link types stay distinct on purpose.
3. **A pinned note is a starred note.** `meta.starred` on a timeline note
   places it under the person's *About*. No new field is added.
4. **Deleting the person deletes the notes, voice notes and photos only they
   hold.**
   - This follows ADR 0037: no orphaned data about a person.
   - The rule is the one that already applies to a check-in's entries: an
     entry that something else still live also links is left alone.
   - Meetings and tasks are things of their own and survive, as linked tasks
     always have.
   - Deleting a check-in leaves alone an entry that is still on the live
     person's timeline.
5. **Timeline entries are searchable.**
   - Search and embeddings are local-only (Ollama is the sole embedding path)
     and only the user can run them, so excluding these entries would protect
     nothing.
   - The `private` flag, which they inherit, covers the shared-screen case.
   - Check-ins themselves became searchable too, by
     [ADR 0139](./0139-check-ins-are-searchable.md).
6. **The briefing reads the timeline.**
   - ADR 0040 decision 4's context boundary gains bounded sections: pinned
     and recent notes, voice-note transcripts, and upcoming meetings.
   - Contact channels and the avatar and banner pictures stay out.
   - A change to a timeline entry counts as new evidence, exactly as a change
     to a check-in does, so the briefing goes out of date.

## Consequences

- `PersonTimelineRepository` owns writing to the timeline (`addToTimeline`,
  `removeFromTimeline`, `createNote`) and reading it. Every surface that
  creates something "for this person" goes through it.
- `JournalDb.getLiveEntitiesOfTypesByIds` resolves link targets by type,
  respecting the private filter. `getLiveTasksByIds` shares its row query.
- `RelationshipLink` rows can no longer be assumed to point at a check-in or a
  task. Every reader must resolve by type, as both existing readers already
  do.
- Older builds sync the new links and entries, and show the entries only in
  the Logbook until they upgrade.

## Related

- [ADR 0037: Relationship Data Stays On-Device](./0037-relationship-on-device-storage-and-privacy.md)
- [ADR 0062: Check-ins hold entries](./0062-check-ins-hold-entries.md)
- [ADR 0064: Check-ins appear in the Logbook](./0064-check-ins-appear-in-the-logbook.md)
