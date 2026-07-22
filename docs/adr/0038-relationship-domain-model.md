# ADR 0038: Relationship Domain Model

- Status: Proposed
- Date: 2026-07-22

## Context

A relationship is a long-running entity tied to one person — closer to a
project than to a task: it has no natural end date, it accumulates a
timeline of interactions, and it should link to tasks (a call to prepare, a
meeting scheduled as a task). Lotti has no person or contact concept today
(the old tags system was removed), so this is greenfield.

The journal core gives us everything needed:

- `JournalEntity` (`lib/classes/journal_entities.dart`) is a sealed freezed
  union of 16 subtypes sharing a `Metadata` envelope, stored as serialized
  JSON in the `journal` Drift table with denormalized query columns.
  `ProjectEntry`/`ProjectData` (`lib/classes/project_data.dart`) is the
  precedent for a long-running container entity with a status union and
  status history.
- `EntryLink` (`lib/classes/entry_link.dart`) is a freezed union
  (`basic`/`rating`/`project`) over the `linked_entries` table; the task
  timeline UI (`LinkedEntriesController`) is assembled purely from links.
- Sync is payload-agnostic for journal entities: a new subtype syncs as soon
  as its JSON round-trips and `toDbEntity` maps it — no new sync message.

## Decision

1. **New subtype `JournalEntity.relationship` with `RelationshipData`.**
   One relationship per person; the person's identity is embedded in the
   payload rather than split into a separate contact entity. Fields:
   - `title` — the person's display name (plus optional `nickname`).
   - `important` (`bool`, default `false`) — the flag that arms reminders
     (ADR 0039).
   - `status` — a `RelationshipStatus` sealed union mirroring
     `ProjectStatus` in shape (`id`, `createdAt`, `utcOffset`, optional
     `timezone`/`geolocation` per entry): `active`, `dormant` (kept but not
     currently nurtured; excluded from reminders), `archived`. With
     `statusHistory` for the trajectory.
   - `checkInCadenceDays` (`int?`) — desired check-in interval; only
     meaningful when `important` is set.
   - `birthday` (`DateTime?`) — optional, for future nudges.
   - `profileId` (`String?`) — inference profile for the relationship agent
     (ADR 0040), mirroring `ProjectData.profileId`.
   - `languageCode` (`String?`), `coverArtId` (`String?`) — same roles as on
     tasks/projects.
   - `contactChannels` (`List<ContactChannel>`, default empty) and
     `contactRefs` (per-platform contact identifiers) — communication
     channels and optional OS-contact linkage per ADR 0041; excluded from
     AI context.
   Free-form notes about the person live in the shared `entryText`.
   `meta.dateFrom` is when tracking started; `meta.dateTo` advances like a
   project's.
2. **New subtype `JournalEntity.checkIn` with `CheckInData`.** One check-in
   per logged interaction. Fields:
   - `interactionType` — enum: `inPerson`, `call`, `videoCall`, `message`,
     `other`.
   - `sentiment` (`CheckInSentiment?`) — enum: `delightful`, `good`,
     `neutral`, `strained`, `difficult`. Optional; explicit user judgment,
     never AI-filled.
   - `topics` (`List<String>`, default empty) — what was discussed.
   - `payAttentionTo` (`String?`) and `avoid` (`String?`) — the "next time"
     guidance the briefing later surfaces.
   The narrative ("what we talked about") is the entry's `entryText`; the
   interaction time is `meta.dateFrom`/`dateTo`, so check-ins sit naturally
   on calendars and timelines.
3. **Linking reuses `linked_entries` with a new `RelationshipLink` variant**
   of `EntryLink`, mirroring `ProjectLink`: relationship → check-in and
   relationship → task (and task → relationship queries via the reverse
   direction). Typed link rows allow indexed queries such as
   "relationships for task" without scanning basic links. The relationship
   timeline is the existing linked-entries mechanism — the same
   `LinkedEntriesController` path tasks use — so text, audio, and photos can
   be linked onto a relationship exactly like onto a task.
4. **No journal schema change initially.** Both subtypes ride the
   `serialized` column with `type` strings `'Relationship'` and `'CheckIn'`;
   list queries filter by `type` and links. Denormalized columns (e.g. an
   indexed `relationship_id` on check-ins) are deferred until a measured
   query needs them, following the `project_id` precedent.
5. **Reminders and briefings are not journal entities.** Reminders are
   `NotificationEntity` rows in `NotificationsDb` (ADR 0039); briefings are
   `AgentReportEntity` rows owned by the relationship agent (ADR 0040). The
   journal holds only what the user authored.
6. **Exhaustive-switch audit is the integration checklist.** Adding the two
   subtypes must update: `affectedIds` in `journal_entities.dart`, the
   `entity.map` in `lib/database/conversions.dart`, `folderForJournalEntity`
   and `typeSuffix` in `lib/utils/file_utils.dart`, the journal card switch
   in `journal_card.dart`, the detail-section switches in
   `entry_details_widget.dart`, creation ops in
   `lib/logic/persistence_logic.dart`, and the `link.map` in
   `conversions.dart` for the new link variant. The compiler enforces most
   of these.

## Consequences

- Sync, vector clocks, soft delete, `private`, categories, and export all
  work for relationships and check-ins with zero new infrastructure.
- Embedding person identity in `RelationshipData` means renaming a person is
  editing the relationship — acceptable for a 1:1 person-to-relationship
  model, and a future shared contact directory could be layered on without
  migrating existing data.
- Check-ins being ordinary journal entities means they appear in generic
  journal surfaces; those surfaces' switches need deliberate rendering
  decisions rather than falling through to defaults.
- The structured qualitative fields (`sentiment`, `payAttentionTo`, `avoid`)
  give the briefing generator explainable inputs instead of forcing it to
  infer everything from prose.

## Related

- [ADR 0037: Relationship Data Stays On-Device](./0037-relationship-on-device-storage-and-privacy.md)
- [ADR 0039: Relationship Check-In Reminders](./0039-relationship-check-in-reminders.md)
- [ADR 0040: Relationship Executive Briefing](./0040-relationship-executive-briefing.md)
- [ADR 0041: Relationship Contact Linking and Communication Actions](./0041-relationship-contact-linking.md)
- [Implementation plan](../implementation_plans/2026-07-22_relationship_management.md)
