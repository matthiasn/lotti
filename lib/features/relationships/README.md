# Relationships

A personal CRM for a small, deliberately curated set of people. One
relationship entity per person, with a timeline of **check-ins** — structured
interaction logs (type, sentiment, topics, narrative) — and, in later phases,
a dedicated agent that tracks check-in cadence and briefs the user before the
next conversation.

This feature is landing in phases; see the
[implementation plan](../../../docs/implementation_plans/2026-08-13_relationship_management_v2.md)
and ADRs 0037–0041. What exists today (phase 1):

- **Domain model** in `lib/classes/`: `relationship_data.dart`
  (`RelationshipData`, `RelationshipStatus`, `ContactChannel`) and
  `check_in_data.dart` (`CheckInData`, interaction type and sentiment enums).
  Both ride the journal table as `JournalEntity.relationship` /
  `JournalEntity.checkIn` — payload-agnostic sync, `private` flag,
  categories, and export all apply with zero new infrastructure.
- **Linking**: `EntryLink.relationship` binds relationship → check-in (and
  later relationship → task). Check-ins also carry a denormalized
  `relationshipId` so `affectedIds` emits a precise agent wake token and the
  journal `subtype` column supports indexed check-in queries.
- `repository/` — `RelationshipRepository`: CRUD for both entity types plus
  the deletion cascade (deleting a relationship soft-deletes its check-ins;
  ADR 0037 §5).

Not yet built: UI (phase 2), the banner-channel generalization (phase 3), the
relationship agent (phases 4–5), voice check-ins (phase 6), contact linking
and quick actions (phase 7).

Privacy stance (ADR 0037): relationship data is the most sensitive class the
app holds — it describes third parties. It stays on-device, syncs only via
the user's own end-to-end encrypted Matrix rooms, and contact channels never
enter AI context.
