# Relationships

A personal CRM for a small, deliberately curated set of people. One
relationship entity per person, with a timeline of **check-ins** — structured
interaction logs (type, sentiment, topics, narrative) — and, in later phases,
a dedicated agent that tracks check-in cadence and briefs the user before the
next conversation.

This feature is landing in phases; see the
[implementation plan](../../../docs/implementation_plans/2026-08-13_relationship_management_v2.md)
and ADRs 0037–0041. What exists today (phases 1–2, behind the
`enable_relationships` flag):

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
- `repository/` — `RelationshipRepository`: CRUD for both entity types
  (create, edit, delete — relationship deletion cascades to its check-ins,
  ADR 0037 §5) plus the recency-ordered list used by the People tab.
- `ui/` + `state/` — the flag-gated **People tab** (`/people`, its own
  beamer location): the relationship list ordered by last-check-in recency,
  the per-person detail page (status/cadence/nickname chips, contact
  channels, a linked-tasks section — `RelationshipLink` both ways, with a
  task picker and per-row unlink — and the check-in log, with edit and
  delete actions), the add/edit person modal (name, nickname, importance,
  cadence presets, status, and the manual contact-channel editor — desktop
  parity per ADR 0041 §2), and the check-in capture sheet (interaction
  type, date, user-set sentiment — never AI-filled, ADR 0038 — topics,
  narrative, next-time guidance; editable and deletable afterwards).

Not yet built: the banner-channel generalization (phase 3), the relationship
agent (phases 4–5), voice check-ins (phase 6), OS contact import/linking and
call/message quick actions (phase 7), OS reminders (phase 8). Relationships
and check-ins deliberately do not appear in the main journal timeline; the
People tab is their home.

Privacy stance (ADR 0037): relationship data is the most sensitive class the
app holds — it describes third parties. It stays on-device, syncs only via
the user's own end-to-end encrypted Matrix rooms, and contact channels never
enter AI context.

Why check-ins are bound to a person twice, how the People list orders by
recency without a per-person query, the status lifecycle, and what the delete
cascade does and does not reach are documented in the knowledge bundle:

**→ [knowledge/features/relationships.md](../../../knowledge/features/relationships.md)**
