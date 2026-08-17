# Relationships

A personal CRM for a small, deliberately curated set of people. One
relationship entity per person, with a timeline of **check-ins** — structured
interaction logs (type, sentiment, topics, narrative) — and, for people
marked important, a dedicated agent that tracks check-in cadence and briefs
the user before the next conversation.

This feature is landing in phases; see the
[implementation plan](../../../docs/implementation_plans/2026-08-13_relationship_management_v2.md)
and ADRs 0037–0041 plus 0059. What exists today (phases 1–5, behind the
`enable_relationships` flag):

- **Domain model** in `lib/classes/`: `relationship_data.dart`
  (`RelationshipData`, `RelationshipStatus`, `ContactChannel`) and
  `check_in_data.dart` (`CheckInData`, interaction type and sentiment enums).
  Both ride the journal table as `JournalEntity.relationship` /
  `JournalEntity.checkIn` — payload-agnostic sync, `private` flag,
  categories, and export all apply with zero new infrastructure.
- **Linking**: `EntryLink.relationship` binds relationship → check-in and
  relationship ↔ task. Check-ins also carry a denormalized
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

- `runtime/` + `service/` + `state/` — the **relationship agent's
  deterministic tier** (plan v2 phase 4, ADR 0059): marking a person
  important quietly creates their dedicated agent, which tracks the
  check-in cadence every day at zero AI cost. Deleting a person destroys
  their agent (the cascade's agent leg).
- `workflow/` + the rest of `service/`, `state/`, `ui/` — the **LLM tier**
  (plan v2 phase 5): a lapsed cadence, a check-in newer than the current
  briefing, a chat message, or an explicit "Brief me" triggers one AI run
  that writes an executive briefing (with a health band) and at most one
  check-in banner. The detail page mounts the briefing card ("Brief me"
  names the cloud provider first, per ADR 0037) and `/people/<id>/chat`
  opens the per-person agent chat. Banners surface through the
  kind-agnostic channel (`lib/features/nudges/`), tapping through to the
  person.

- **Voice check-ins** (plan v2 phase 6): "Speak check-in" on the capture
  sheet records through the shared recording sheet with the *person* as the
  recording's linked entity, then waits for the transcript and drops it into
  the narrative field for the user to edit and confirm. Nothing auto-saves —
  the check-in stays user-authored, and speaking never overwrites text the
  user already typed. Transcription resolves the person's inference profile
  (or their category's) because the automation path is now kind-agnostic
  rather than task-only, and the finished transcript wakes the relationship
  agent so the briefing catches up with what was just said.

  The button only needs a **transcription model** — not the category's
  automatic-inference switch. That switch governs unattended runs, so when it
  is off (or the person has no category at all) the sheet runs the
  transcription the user just asked for itself, rather than refusing. With no
  model configured anywhere it says so before recording, instead of capturing
  audio for a transcript that can never arrive — and if the recording sheet's
  speech-recognition checkbox was unticked for that take, it says so straight
  away rather than waiting out the transcription timeout.

  Transcription accuracy for names comes from the **category's
  `speechDictionary`**: terms listed there are sent to the provider as
  context bias and injected into the transcription prompt, so a category
  used for people should list the names it expects to hear. It is edited in
  category settings, and applies to every recording in that category — a
  spoken check-in included.

- `service/relationship_reminder_service.dart` — **OS check-in reminders**
  (plan v2 phase 8, ADR 0039). The banner needs the app open; this covers the
  case it cannot. The deterministic tier's cadence verdict is projected onto a
  durable notification row armed *ahead* of the due day, so the OS is already
  holding the alarm when the app closes. One row per cadence episode, retracted
  and replaced when a check-in moves the due day, and cleared outright when a
  person stops being eligible or is deleted. Lock-screen copy carries the
  person's name and nothing else about them.

Not yet built: OS contact import/linking and call/message quick actions
(phase 7). Relationships
and check-ins deliberately do not appear in the main journal timeline; the
People tab is their home.

Privacy stance (ADR 0037): relationship data is the most sensitive class the
app holds — it describes third parties. It stays on-device, syncs only via
the user's own end-to-end encrypted Matrix rooms, and contact channels never
enter AI context. Concretely, `private` covers the whole person: a check-in
inherits the relationship's `private` flag when it is created, the detail
page resolves a private person to "no longer tracked" while private entries
are hidden (the list filter alone would leave the `/people/<id>` route open),
and the delete cascade reads check-ins unfiltered so hidden ones cannot
survive the person they describe.

Why check-ins are bound to a person twice, how the People list orders by
recency without a per-person query, the status lifecycle, and what the delete
cascade does and does not reach are documented in the knowledge bundle:

**→ [knowledge/features/relationships.md](../../../knowledge/features/relationships.md)**
